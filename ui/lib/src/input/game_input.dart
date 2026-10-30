import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../bots/bot_turns.dart';
import '../board/scoring.dart';
import '../display.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import '../games/dart_game.dart';
import '../screens/throw_views_screen.dart';
import '../sound/effects.dart';
import '../sound/sfx.dart';
import 'key_entry.dart';
import 'takeout_gate.dart';
import 'throw_input_panel.dart';
import '../board/score_text.dart';
import '../theme.dart';
import '../widgets/precision_text.dart';

/// How far the engine counts darts now, as the game screen tells the player
enum _EngineHealth {
  /// Counting, or no engine at all
  ok,

  /// Connected, but detection is paused or unavailable, or a camera delivers no frames
  notCounting,

  /// The connection went away and the app tries to reach the engine again
  dropped,
}

/// Input of a game screen: darts from the engine when connected, manual input otherwise, uncertain darts as a
/// suggestion to confirm or correct, corrections of the last darts, and the takeout that ends a visit. While an engine
/// is connected, a finished visit waits for its takeout before the next one starts.
class GameInput extends StatefulWidget {
  const GameInput({
    super.key,
    required this.game,
    required this.onDart,
    required this.onChanged,
    this.shownThrows = const [],
    this.takeout,
  });

  final DartGame game;

  /// Adds a dart to the game; the screen reacts to legs and the match end
  final ValueChanged<DartThrow> onDart;

  /// Called after a correction changed the game
  final VoidCallback onChanged;
  final List<DartThrow> shownThrows;

  /// Closed after each visit while an engine is connected; without one, visits follow each other at once
  final TakeoutGate? takeout;

  @override
  State<GameInput> createState() => _GameInputState();
}

class _GameInputState extends State<GameInput> {
  EngineConnection? _engine;
  GameNoticeSlot? _slot;
  StreamSubscription<EngineEvent>? _subscription;
  EngineThrow? _pending;
  int? _correcting;

  /// Darts by hand on the keypad rather than the board; null until the device's choice is read
  bool? _keypad;

  /// Darts typed on a keyboard
  final KeyEntry _keys = KeyEntry();
  final FocusNode _focus = FocusNode(debugLabel: 'game input');

  _EngineHealth _health = _EngineHealth.ok;

  /// Set for a while after the engine is back from a drop: darts thrown meanwhile may be missing
  bool _back = false;
  Timer? _backTimer;

  /// A correction from another device, said for a while with the dart it changed
  ({String text, DartThrow? dart})? _elsewhere;
  Timer? _elsewhereTimer;

  /// After a takeout the player chose to enter the visit's missing darts by hand: the engine's darts of the next visit
  /// wait until they are in.
  bool _enteringMissing = false;

  /// Where the visit whose missing darts are typed in starts among the game's darts
  int _missingFrom = 0;

  /// How long a notice about something that already happened stays
  static const Duration noticeTime = Duration(seconds: 6);

  /// Engine events of the next visit, kept while the darts of the last one are still in the board
  final List<EngineEvent> _held = [];

  /// Set while the darts of a takeout's missing darts are added: that visit is out of the board already
  bool _takenOut = false;

  bool get _waiting => widget.takeout?.isClosed(widget.game) ?? false;

  /// The engine throw ids among the game's darts when the input last looked; one missing later was undone in the app.
  Set<String> _engineIds = {};

  Set<String> get _gameEngineIds => {for (final t in widget.game.throws) ?t.engineThrowId};

  @override
  void initState() {
    super.initState();
    _engineIds = _gameEngineIds;
  }

  @override
  void didUpdateWidget(GameInput old) {
    super.didUpdateWidget(old);
    _followUndo();
  }

  /// After the screen took darts back: the engine hears which of its darts no longer count, so its throw log stays the
  /// game's. When the undo reopened a visit that waited for its takeout, the darts held for the next visit are not
  /// that visit's: they are rejected rather than counted later, out of order.
  void _followUndo() {
    final ids = _gameEngineIds;
    final engine = _engine;
    for (final id in _engineIds.difference(ids)) {
      engine?.rejectThrow(id, 'undone in the app');
    }
    _engineIds = ids;
    // An undo inside that visit leaves its darts still owed; only one back past its start ends the typing in, and the
    // darts held for the visit after it are rejected below with the others. Nothing is replayed here: this runs while
    // the screen builds.
    if (_enteringMissing && widget.game.throws.length < _missingFrom) _enteringMissing = false;
    if (_held.isNotEmpty && !_waiting && !_enteringMissing) {
      for (final event in _held) {
        if (event is EngineThrow) engine?.rejectThrow(event.throwId, 'undone in the app');
      }
      _held.clear();
    }
  }

  /// Whether the engine's throw `id` is counted already, waits for the takeout, or waits as an uncertain dart: the
  /// same dart sent again must not count twice.
  bool _known(String id) =>
      _pending?.throwId == id ||
      widget.game.throws.any((t) => t.engineThrowId == id) ||
      _held.any((e) => e is EngineThrow && e.throwId == id || e is EngineThrowCorrected && e.throwId == id);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Events arrive through the stream; the input rebuilds only when the engine's health changes.
    _slot = context.getInheritedWidgetOfExactType<GameNoticeSlot>();
    final engine = EngineScope.read(context);
    if (!identical(engine, _engine)) {
      _subscription?.cancel();
      _engine?.removeListener(_engineChanged);
      _engine = engine;
      _subscription = engine.events.listen(_onEvent);
      engine.addListener(_engineChanged);
      _health = _healthOf(engine);
    }
    // With an engine the board shows where the cameras saw the darts; by hand the device's own choice
    _keypad ??= !engine.isConnected && DisplayScope.of(context).keypadInput;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _engine?.removeListener(_engineChanged);
    _backTimer?.cancel();
    _elsewhereTimer?.cancel();
    _focus.dispose();
    _slot?.notice.value = null;
    _slot?.marked.value = null;
    super.dispose();
  }

  static _EngineHealth _healthOf(EngineConnection engine) {
    if (engine.reconnecting && !engine.isConnected) return _EngineHealth.dropped;
    if (!engine.isConnected) return _EngineHealth.ok;
    final lost = engine.cameraStatus.values.any((c) => c.state == 'lost');
    return engine.detection != 'running' || lost ? _EngineHealth.notCounting : _EngineHealth.ok;
  }

  void _engineChanged() {
    final engine = _engine;
    if (engine == null || !mounted) return;
    final health = _healthOf(engine);
    if (health == _health) return;
    final back = _health == _EngineHealth.dropped && engine.isConnected;
    setState(() {
      _health = health;
      if (back) {
        _back = true;
        _backTimer?.cancel();
        _backTimer = Timer(noticeTime, () {
          if (mounted) setState(() => _back = false);
        });
      } else if (health == _EngineHealth.dropped) {
        _back = false;
      }
    });
  }

  /// Says for a while that another device changed a dart, and marks that dart
  void _changedElsewhere(String text, DartThrow? dart) {
    _elsewhereTimer?.cancel();
    setState(() => _elsewhere = (text: text, dart: dart));
    _elsewhereTimer = Timer(noticeTime, () {
      if (mounted) setState(() => _elsewhere = null);
    });
  }

  void _setKeypad(bool keypad, {bool remember = true}) {
    setState(() => _keypad = keypad);
    if (remember) DisplayScope.of(context).setKeypadInput(keypad);
  }

  /// A keyboard beside the board, as on a desktop or TV box: digits with S, D or T, Backspace undoes.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    TypedField? field;
    if (key == LogicalKeyboardKey.backspace) {
      if (!_keys.clear()) _undo();
      setState(() {});
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.escape) {
      if (!_keys.clear()) return KeyEventResult.ignored;
      setState(() {});
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_keys.pending.isEmpty) return KeyEventResult.ignored;
      field = _keys.enter();
    } else {
      final character = event.character;
      if (character == null || character.length != 1) return KeyEventResult.ignored;
      final before = _keys.pending;
      field = _keys.type(character);
      if (field == null && before == _keys.pending) return KeyEventResult.ignored;
    }
    setState(() {});
    if (field != null) {
      _onInput(
        DartThrow(
          fieldCentre(field.ring, sector: field.sector, geometry: _geometry),
          ThrowInput.keypad,
          geometry: _geometry,
        ),
      );
    }
    return KeyEventResult.handled;
  }

  void _undo() {
    final game = widget.game;
    if (game.throws.isEmpty || game.isFinished) return;
    game.undo();
    widget.onChanged();
  }

  BoardGeometry get _geometry => _engine?.geometry ?? const BoardGeometry();

  DartThrow _engineDart(BoardPoint point, String throwId, double? confidence) =>
      DartThrow(point, ThrowInput.engine, geometry: _geometry, engineThrowId: throwId, confidence: confidence);

  /// Adds a dart through the screen and closes the gate when it ended the visit
  void _add(DartThrow dart) {
    final game = widget.game;
    final before = game.throws.length;
    final inVisit = game.dartsInVisit;
    widget.onDart(dart);
    final gate = widget.takeout;
    if (_enteringMissing) {
      // That visit's darts are out of the board already: the next visit starts without waiting for a takeout.
      if (game.dartsInVisit == 0 || game.isFinished) _missingEntered();
      return;
    }
    if (gate != null &&
        !_takenOut &&
        (_engine?.isConnected ?? false) &&
        game.throws.length == before + 1 &&
        game.dartsInVisit == 0 &&
        !game.isFinished) {
      gate.close(game, inVisit + 1);
      widget.onChanged();
    }
  }

  /// The missing darts of a taken-out visit are in: the darts that waited meanwhile count now.
  void _missingEntered() {
    setState(() => _enteringMissing = false);
    final held = [..._held];
    _held.clear();
    held.forEach(_onEvent);
  }

  void _dartsRemoved() {
    widget.takeout?.open();
    widget.onChanged();
    final held = [..._held];
    _held.clear();
    held.forEach(_onEvent);
  }

  void _onEvent(EngineEvent event) {
    if (!mounted || widget.game.isFinished) return;
    if (_waiting || _enteringMissing) {
      if (event is EngineTakeout) {
        // While missing darts are typed in, a takeout belongs to the next visit's held darts and follows them
        if (_waiting) {
          _dartsRemoved();
        } else {
          _held.add(event);
        }
      } else if (event is EngineThrow) {
        if (!_known(event.throwId)) _held.add(event);
      } else if (event is EngineThrowCorrected && _holds(event)) {
        _held.add(event);
      } else {
        _onVisitEvent(event);
      }
      return;
    }
    _onVisitEvent(event);
  }

  /// A correction waits with the darts of the next visit when it adds a dart, which belongs to that visit, or changes
  /// a dart that waits already.
  bool _holds(EngineThrowCorrected event) =>
      event.action == 'added' || _held.any((e) => e is EngineThrow && e.throwId == event.throwId);

  /// Takes the dart at `index` out of the game, wherever in the game it is: the darts after it are thrown again in the
  /// same order. They keep their place, not their player, so in a bot game a bot's dart can move into the visit before.
  /// The last dart that counts goes through the screen, so a leg or match it now wins is announced as when thrown.
  void _remove(int index) {
    final game = widget.game;
    final after = game.throws.sublist(index + 1);
    for (var i = game.throws.length; i > index; --i) {
      game.undo();
    }
    after.forEach(game.add);
    // A dart fewer here is no undo: the bots must not take back further darts for it.
    context.findAncestorStateOfType<BotTurns>()?.dartsReplaced();
    if (game.throws.length > index) {
      final last = game.throws.last;
      game.undo();
      widget.onDart(last);
    }
    _engineIds = _gameEngineIds;
    widget.onChanged();
  }

  void _onVisitEvent(EngineEvent event) {
    switch (event) {
      case EngineThrow(:final accepted, :final point, :final throwId, :final confidence):
        if (_known(throwId)) return;
        if (accepted) {
          // An accepted dart without a point bounced out or landed off the board.
          _add(_engineDart(point ?? fieldCentre(Ring.miss, geometry: _geometry), throwId, confidence));
        } else {
          // The player is looking at the board, not the screen: a tick says that a dart waits for them.
          SfxScope.read(context).play(Effect.attention);
          setState(() => _pending = event);
        }
      case EngineThrowCorrected(:final client, :final throwId, :final action, :final point):
        if (client == _engine?.clientName) return;
        final index = widget.game.throws.indexWhere((d) => d.engineThrowId == throwId);
        final l10n = AppLocalizations.of(context);
        if (action == 'corrected' && index >= 0 && point != null) {
          // Said and marked, so a score that changes by itself is not taken for a fault
          final old = widget.game.throws[index].score.text(l10n);
          final dart = _engineDart(point, throwId, null);
          widget.game.replace(index, dart);
          widget.onChanged();
          _changedElsewhere(l10n.correctedElsewhere(old, dart.score.text(l10n)), dart);
        } else if (action == 'added' && point != null && !_known(throwId)) {
          _add(_engineDart(point, throwId, null));
        } else if (action == 'rejected' && index >= 0) {
          final old = widget.game.throws[index].score.text(l10n);
          _remove(index);
          _changedElsewhere(l10n.rejectedElsewhere(old), null);
        } else if (action == 'rejected' && _pending?.throwId == throwId) {
          setState(() => _pending = null);
          _pendingSettled();
        }
      case EngineTakeout():
        _onTakeout();
      default:
        break;
    }
  }

  /// A takeout while a dart was uncertain waits until the player settled that dart.
  bool _takeoutWaiting = false;

  void _pendingSettled() {
    if (!_takeoutWaiting) return;
    _takeoutWaiting = false;
    _onTakeout();
  }

  Future<void> _onTakeout() async {
    final inVisit = widget.game.dartsInVisit;
    if (_pending != null) {
      _takeoutWaiting = true;
      return;
    }
    if (inVisit == 0) return;
    final missing = 3 - inVisit;
    final l10n = AppLocalizations.of(context);
    SfxScope.read(context).play(Effect.attention);
    // Answered, never dismissed: a visit left open would take the next player's darts.
    final countAsMiss = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final text = GameText.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.missingDarts(missing), style: text.promptTitle),
          content: Text(l10n.missingDartsHint, style: text.promptBody),
          actions: [
            TextButton(
              key: const ValueKey('missing-enter'),
              style: text.action,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.enterManually),
            ),
            FilledButton(
              key: const ValueKey('missing-count-miss'),
              style: text.action,
              autofocus: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.countAsMiss),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (countAsMiss != true) {
      if (widget.game.dartsInVisit > 0) {
        setState(() {
          _enteringMissing = true;
          _missingFrom = widget.game.throws.length - widget.game.dartsInVisit;
        });
      }
      return;
    }
    _takenOut = true;
    for (var i = 0; i < missing && !widget.game.isFinished; ++i) {
      _manual(DartThrow(fieldCentre(Ring.miss, geometry: _geometry), ThrowInput.keypad, geometry: _geometry));
    }
    _takenOut = false;
  }

  /// A dart entered on the board or keypad: confirms a suggestion with a new point, corrects a dart, or is a new dart.
  void _onInput(DartThrow dart) {
    final engine = _engine;
    final pending = _pending;
    final correcting = _correcting;
    if (pending != null) {
      engine?.correctThrow(pending.throwId, dart.point);
      setState(() => _pending = null);
      _add(_engineDart(dart.point, pending.throwId, null));
      _pendingSettled();
    } else if (correcting != null && correcting < widget.game.throws.length) {
      final old = widget.game.throws[correcting];
      final id = old.engineThrowId;
      if (id != null) engine?.correctThrow(id, dart.point);
      widget.game.replace(
        correcting,
        DartThrow(dart.point, old.input, geometry: _geometry, engineThrowId: id, confidence: old.confidence),
      );
      setState(() => _correcting = null);
      widget.onChanged();
      // With cameras the board shows what they saw; the keypad was only for this correction.
      if (_engine?.isConnected ?? false) _setKeypad(false, remember: false);
    } else if (!_waiting) {
      _manual(dart);
    }
  }

  void _manual(DartThrow dart) {
    final engine = _engine;
    if (engine != null && engine.isConnected) engine.addThrow(dart.point);
    _add(dart);
  }

  void _confirmPending() {
    final pending = _pending;
    if (pending?.point == null) return;
    setState(() => _pending = null);
    _add(_engineDart(pending!.point!, pending.throwId, pending.confidence));
    _pendingSettled();
  }

  /// The player picked one of the fields an uncertain dart may be in; the engine keeps the choice with the throw.
  void _pickCandidate(int index) {
    final pending = _pending;
    if (pending == null || index >= pending.candidates.length) return;
    final point = pending.candidates[index].point;
    _engine?.correctThrow(pending.throwId, point, candidate: index);
    setState(() => _pending = null);
    _add(_engineDart(point, pending.throwId, null));
    _pendingSettled();
  }

  /// The fields an uncertain dart may be in, one per field: candidates in the same field are one choice, with their
  /// probabilities added and the most likely one's point and index, most likely first
  List<({int index, DartThrow dart, double probability})> _fields(EngineThrow? pending) {
    final byField = <String, ({int index, DartThrow dart, double probability})>{};
    final candidates = pending?.candidates ?? const <ThrowCandidate>[];
    for (var i = 0; i < candidates.length; ++i) {
      final c = candidates[i];
      final dart = DartThrow(c.point, ThrowInput.engine, geometry: _geometry);
      final label = dart.score.label;
      final known = byField[label];
      byField[label] = known == null
          ? (index: i, dart: dart, probability: c.probability)
          : (index: known.index, dart: known.dart, probability: known.probability + c.probability);
    }
    return byField.values.toList()..sort((a, b) => b.probability.compareTo(a.probability));
  }

  /// The camera views of a detected dart (#129); the player may go on to correct it from there.
  Future<void> _openViews(int index) async {
    final dart = widget.game.throws[index];
    final id = dart.engineThrowId;
    if (id == null) return;
    final correct = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ThrowViewsScreen(throwId: id, label: dart.score.text(AppLocalizations.of(context)), canCorrect: true),
      ),
    );
    if (!mounted) return;
    setState(() => _correcting = correct == true ? index : null);
  }

  void _discardPending() {
    final pending = _pending;
    if (pending == null) return;
    _engine?.rejectThrow(pending.throwId, 'rejected by the player');
    setState(() => _pending = null);
    _pendingSettled();
  }

  /// The notice about the engine's health, which stays while it holds, above any prompt
  Widget? _healthNotice(AppLocalizations l10n, ThemeData theme) {
    final colours = StatusColors.of(context);
    final warning = Color.alphaBlend(colours.warning.withValues(alpha: 0.22), theme.colorScheme.surface);
    // While missing darts are typed in, their notice offers the keypad
    final offerKeypad = _keypad != true && !_enteringMissing;
    final keypad = TextButton(
      key: const ValueKey('health-keypad'),
      onPressed: () => _setKeypad(true, remember: false),
      child: Text(l10n.inputKeypad),
    );
    final engine = _engine;
    switch (_health) {
      case _EngineHealth.dropped:
        return _Notice(
          key: const ValueKey('engine-dropped'),
          color: warning,
          icon: Icons.link_off,
          title: l10n.gameConnectionLost,
          subtitle: l10n.gameConnectionLostHint,
          actions: [if (offerKeypad) keypad],
        );
      case _EngineHealth.notCounting:
        final lost = engine?.cameraStatus.values.any((c) => c.state == 'lost') ?? false;
        return _Notice(
          key: const ValueKey('engine-not-counting'),
          color: warning,
          icon: Icons.videocam_off_outlined,
          title: l10n.gameCamerasNotCounting,
          subtitle: lost
              ? l10n.gameCameraLost
              : engine?.detection == 'paused'
              ? l10n.detectionPaused
              : l10n.detectionUnavailable,
          actions: [if (offerKeypad) keypad],
        );
      case _EngineHealth.ok:
        if (!_back) return null;
        return _Notice(
          key: const ValueKey('engine-back'),
          color: theme.colorScheme.secondaryContainer,
          icon: Icons.link,
          title: l10n.gameReconnected,
          subtitle: l10n.gameReconnectedHint,
          actions: [
            TextButton(
              onPressed: () {
                _backTimer?.cancel();
                setState(() => _back = false);
              },
              child: Text(l10n.noticeOk),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = GameText.of(context);
    final pending = _pending;
    final pendingDart = pending?.point == null
        ? null
        : _engineDart(pending!.point!, pending.throwId, pending.confidence);
    final fields = _fields(pending);
    final game = widget.game;
    final throws = game.throws;
    // The visit that ended last, with whose it was and, where the game knows, what it came to, so a bust is not read
    // as the next player's darts. While the next visit is under way it stays, dimmed, so a misread dart of it can
    // still be corrected; the new visit's darts follow after a divider.
    final inVisit = game.dartsInVisit;
    final lastVisit = game is TellsVisits ? (game as TellsVisits).lastVisit : null;
    final visitStart = throws.length - inVisit;
    final endedStart = math.max(0, visitStart - (game is TellsVisits ? lastVisit?.darts ?? 0 : 3));
    final correcting = _correcting;

    final waiting = _waiting;
    Widget? prompt;
    if (_enteringMissing) {
      prompt = _Notice(
        key: const ValueKey('enter-missing'),
        color: theme.colorScheme.primaryContainer,
        icon: Icons.dialpad,
        title: l10n.enterMissingDarts(3 - inVisit),
        subtitle: l10n.enterMissingDartsHint,
        actions: [
          if (_keypad != true)
            TextButton(
              key: const ValueKey('missing-keypad'),
              onPressed: () => _setKeypad(true),
              child: Text(l10n.inputKeypad),
            ),
        ],
      );
    } else if (waiting && correcting == null) {
      prompt = _Notice(
        key: const ValueKey('remove-darts'),
        color: theme.colorScheme.primaryContainer,
        icon: Icons.back_hand_outlined,
        title: l10n.removeDarts,
        subtitle: l10n.removeDartsHint,
        actions: [
          TextButton(key: const ValueKey('darts-removed'), onPressed: _dartsRemoved, child: Text(l10n.dartsRemoved)),
        ],
      );
    } else if (pending != null && fields.length >= 2) {
      String label(({int index, DartThrow dart, double probability}) f) =>
          '${f.dart.score.text(l10n)} (${percentText(l10n, f.probability)})';
      prompt = _Notice(
        key: const ValueKey('uncertain-candidates'),
        color: theme.colorScheme.tertiaryContainer,
        icon: Icons.help_outline,
        title: '${fields.map((f) => f.dart.score.text(l10n)).join(' ${l10n.or} ')}?',
        scoreTitle: true,
        subtitle: l10n.pickCandidate,
        actions: [
          TextButton(onPressed: _discardPending, child: Text(l10n.discard)),
          for (var i = 0; i < fields.length; ++i)
            if (i == 0)
              FilledButton(
                key: const ValueKey('candidate-0'),
                onPressed: () => _pickCandidate(fields[0].index),
                child: Text(label(fields[0])),
              )
            else
              OutlinedButton(
                key: ValueKey('candidate-$i'),
                onPressed: () => _pickCandidate(fields[i].index),
                child: Text(label(fields[i])),
              ),
        ],
      );
    } else if (pending != null) {
      prompt = _Notice(
        key: const ValueKey('uncertain-dart'),
        color: theme.colorScheme.tertiaryContainer,
        icon: Icons.help_outline,
        title: pendingDart == null
            ? l10n.uncertainNoPoint
            : l10n.uncertainDart(pendingDart.score.text(l10n), percentText(l10n, pending.confidence)),
        subtitle: l10n.tapToCorrect,
        actions: [
          TextButton(onPressed: _discardPending, child: Text(l10n.discard)),
          if (pendingDart != null) FilledButton(onPressed: _confirmPending, child: Text(l10n.confirm)),
        ],
      );
    } else if (correcting != null && correcting < throws.length) {
      prompt = _Notice(
        key: const ValueKey('correcting'),
        color: theme.colorScheme.tertiaryContainer,
        icon: Icons.edit_location_alt,
        title: l10n.correctingDart(throws[correcting].score.text(l10n)),
        actions: [
          if (throws[correcting].engineThrowId != null)
            TextButton(
              key: const ValueKey('open-throw-views'),
              onPressed: () => _openViews(correcting),
              child: Text(l10n.throwViewOpen),
            ),
          TextButton(onPressed: () => setState(() => _correcting = null), child: Text(l10n.cancel)),
        ],
      );
    }
    // What happened elsewhere is said beside whatever the player is asked now
    final health = _healthNotice(l10n, theme);
    final elsewhere = _elsewhere == null
        ? null
        : _Notice(
            key: const ValueKey('corrected-elsewhere'),
            color: theme.colorScheme.secondaryContainer,
            icon: Icons.devices_other,
            title: _elsewhere!.text,
            actions: const [],
          );
    final notices = [?health, ?elsewhere, ?prompt];
    final banner = notices.length <= 1 ? notices.firstOrNull : _NoticeStack(notices, byPriority: [?prompt, ?health]);
    // The dart the player is asked about, framed in the panel's visit as well as here
    final marked = correcting != null && correcting < throws.length ? throws[correcting] : _elsewhere?.dart;

    final slot = _slot;
    if (slot != null) {
      // After this frame: the slot's listener belongs to another part of the tree, built in the same frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        slot.notice.value = banner;
        slot.marked.value = marked;
      });
    }
    // Which darts came from where matters only where a game mixes them.
    final mixed = throws.any((t) => t.input == ThrowInput.engine) && throws.any((t) => t.input != ThrowInput.engine);
    final chipStyle = (text.far ? theme.textTheme.titleLarge : theme.textTheme.labelLarge)?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final labelStyle = text.far ? theme.textTheme.titleLarge : theme.textTheme.labelLarge;
    // The strip of last darts keeps one line of one height from the first dart on, so the keypad above never moves
    // during a visit; what does not fit scrolls, the newest darts in view. Whose visit ended stays at the left.
    final media = MediaQuery.of(context);
    final stripScaler = media.textScaler.clamp(maxScaleFactor: 1.3);
    final stripHeight = math.max(48.0, stripScaler.scale(chipStyle?.fontSize ?? 14) * 1.5 + 24);
    final Widget? stripLabel = throws.isEmpty
        ? null
        : lastVisit == null || endedStart == visitStart
        ? Text(l10n.recentDarts, style: labelStyle)
        : Text(
            [lastVisit.player, if (lastVisit.bust) l10n.bust else ?lastVisit.points?.toString()].join(' · '),
            key: const ValueKey('recent-visit'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle?.copyWith(
              color: lastVisit.bust ? theme.colorScheme.error : null,
              fontWeight: lastVisit.bust ? FontWeight.w700 : null,
            ),
          );
    final strip = MediaQuery(
      data: media.copyWith(textScaler: stripScaler),
      child: SizedBox(
        key: const ValueKey('recent-strip'),
        height: stripHeight,
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              if (stripLabel != null)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.4),
                  child: stripLabel,
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, chips) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: chips.maxWidth),
                      child: Row(
                        children: [
                          for (var i = endedStart; i < throws.length; ++i) ...[
                            if (i == visitStart && i > endedStart)
                              SizedBox(
                                key: const ValueKey('recent-divider'),
                                height: 24,
                                child: VerticalDivider(width: 9, thickness: 1, color: theme.colorScheme.outline),
                              ),
                            const SizedBox(width: 8),
                            Opacity(
                              opacity: i < visitStart && inVisit > 0 && correcting != i ? 0.55 : 1,
                              child: ChoiceChip(
                                key: ValueKey('recent-$i'),
                                labelPadding: EdgeInsets.symmetric(horizontal: mixed ? 4 : 8),
                                avatar: mixed
                                    ? Icon(
                                        throws[i].input == ThrowInput.engine ? Icons.videocam : Icons.touch_app,
                                        size: 16,
                                      )
                                    : null,
                                showCheckmark: false,
                                label: Text(throws[i].score.text(l10n), style: chipStyle),
                                tooltip: l10n.correctDartTooltip,
                                selected: correcting == i,
                                onSelected: (_) => setState(() => _correcting = correcting == i ? null : i),
                              ),
                            ),
                          ],
                          if (_keys.pending.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Text(
                              '${_keys.pending}…',
                              key: const ValueKey('key-entry'),
                              style: scoreStyle(chipStyle)?.copyWith(color: theme.colorScheme.primary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        children: [
          if (slot == null) ?banner,
          Expanded(
            child: EngineSelect(
              select: (engine) => engine.geometry,
              builder: (context, geometry) => ThrowInputPanel(
                geometry: geometry,
                keypad: _keypad ?? false,
                onKeypadChanged: _setKeypad,
                shownThrows: waiting ? widget.takeout!.darts(widget.game) : [...widget.shownThrows, ?pendingDart],
                highlights: !waiting && fields.length >= 2 ? [for (final f in fields) f.dart.score] : const [],
                onThrow: _onInput,
              ),
            ),
          ),
          const SizedBox(height: 8),
          strip,
        ],
      ),
    );
  }
}

/// A notice above the board: what happened, what to do, and its buttons, read from the oche where the screen is. On
/// narrow screens the buttons go below the text, so the notice stays low enough for the board or keypad underneath.
class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    this.subtitle,
    this.scoreTitle = false,
    required this.actions,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? subtitle;

  /// The title names fields, set in the score face
  final bool scoreTitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = GameText.of(context);
    final compact = CompactNotices.of(context);
    final titleStyle = scoreTitle
        ? scoreStyle(text.far ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)
        : text.promptTitle;
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: compact ? 2 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: titleStyle?.copyWith(fontWeight: FontWeight.w600),
        ),
        // Short of room the title says enough; the hint would take the panel's rows.
        if (subtitle != null && !compact)
          Text(subtitle!, maxLines: text.far ? 3 : 2, overflow: TextOverflow.ellipsis, style: text.promptBody),
      ],
    );
    final action = text.action;
    final buttons = Theme(
      // From the oche the buttons grow with the text
      data: action == null
          ? theme
          : theme.copyWith(
              textButtonTheme: TextButtonThemeData(style: action),
              filledButtonTheme: FilledButtonThemeData(style: action),
              outlinedButtonTheme: OutlinedButtonThemeData(style: action),
            ),
      child: Wrap(spacing: 8, runSpacing: 4, alignment: WrapAlignment.end, children: actions),
    );
    final vertical = compact ? 2.0 : (text.far ? 12.0 : 8.0);
    return Card(
      color: color,
      margin: compact ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2) : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, vertical, 8, vertical),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // A single button fits beside a short notice; several wrap under it where the width is short.
            final narrow = constraints.maxWidth < 480 && !(compact && actions.length == 1);
            final top = Row(
              children: [
                Icon(icon, size: text.far ? 36 : null),
                const SizedBox(width: 16),
                Expanded(child: texts),
                // Two or three candidates are wider than the space beside the text; they wrap instead.
                if (!narrow && actions.isNotEmpty) Flexible(child: buttons),
              ],
            );
            return narrow && actions.isNotEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      top,
                      Align(alignment: Alignment.centerRight, child: buttons),
                    ],
                  )
                : top;
          },
        ),
      ),
    );
  }
}

/// Several notices, one under the other; where compact notices have room for fewer, the first of [byPriority] stay,
/// then the others in their order.
class _NoticeStack extends StatelessWidget {
  const _NoticeStack(this.notices, {required this.byPriority});

  final List<Widget> notices;
  final List<Widget> byPriority;

  /// About the height of a compact notice with a button
  static const double compactHeight = 56;

  @override
  Widget build(BuildContext context) {
    final room = CompactNotices.roomOf(context);
    var shown = notices;
    if (room != null) {
      final fit = math.max(1, (room / compactHeight).floor());
      if (fit < notices.length) {
        final kept = [...byPriority, ...notices.where((n) => !byPriority.contains(n))].take(fit).toSet();
        shown = [
          for (final n in notices)
            if (kept.contains(n)) n,
        ];
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: shown);
  }
}

/// Tells the input's notices that the panel is short of room: they keep to their title, so the panel's rows and Undo
/// stay in view.
class CompactNotices extends InheritedWidget {
  const CompactNotices({super.key, required this.compact, required this.room, required super.child});

  final bool compact;

  /// The height the notices may take together
  final double room;

  /// Below this height of the panel with its notices, notices are compact
  static const double below = 560;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CompactNotices>()?.compact ?? false;

  /// The height compact notices may take together; null where notices are not compact
  static double? roomOf(BuildContext context) {
    final notices = context.dependOnInheritedWidgetOfExactType<CompactNotices>();
    return notices != null && notices.compact ? notices.room : null;
  }

  @override
  bool updateShouldNotify(CompactNotices old) => old.compact != compact || old.room != room;
}

/// Where a game screen shows the input's notices (an uncertain dart, darts to pull) and which dart they are about:
/// beside the board in the score panel, so the board keeps its size while the player taps it. Without a slot the
/// input shows them above the board.
class GameNoticeSlot extends InheritedWidget {
  const GameNoticeSlot({super.key, required this.notice, required this.marked, required super.child});

  final ValueNotifier<Widget?> notice;

  /// The dart a notice is about, such as one being corrected, for the panel to frame in the visit
  final ValueNotifier<DartThrow?> marked;

  static ValueNotifier<Widget?>? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GameNoticeSlot>()?.notice;

  @override
  bool updateShouldNotify(GameNoticeSlot old) => !identical(old.notice, notice) || !identical(old.marked, marked);
}

/// Builds with the dart the input marks, or null; outside a game screen always null
class MarkedDart extends StatelessWidget {
  const MarkedDart({super.key, required this.builder});

  final Widget Function(BuildContext context, DartThrow? marked) builder;

  @override
  Widget build(BuildContext context) {
    final marked = context.getInheritedWidgetOfExactType<GameNoticeSlot>()?.marked;
    if (marked == null) return builder(context, null);
    return ValueListenableBuilder(valueListenable: marked, builder: (context, dart, _) => builder(context, dart));
  }
}
