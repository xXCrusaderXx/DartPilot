import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../board/scoring.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import '../games/dart_game.dart';
import '../screens/throw_views_screen.dart';
import 'takeout_gate.dart';
import 'throw_input_panel.dart';
import '../board/score_text.dart';
import '../widgets/precision_text.dart';

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
  StreamSubscription<EngineEvent>? _subscription;
  EngineThrow? _pending;
  int? _correcting;

  /// Engine events of the next visit, kept while the darts of the last one are still in the board
  final List<EngineEvent> _held = [];

  /// Set while the darts of a takeout's missing darts are added: that visit is out of the board already
  bool _takenOut = false;

  bool get _waiting => widget.takeout?.isClosed(widget.game) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Events arrive through the stream; the input does not rebuild on every change of the connection.
    final engine = EngineScope.read(context);
    if (!identical(engine, _engine)) {
      _subscription?.cancel();
      _engine = engine;
      _subscription = engine.events.listen(_onEvent);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
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

  void _dartsRemoved() {
    widget.takeout?.open();
    widget.onChanged();
    final held = [..._held];
    _held.clear();
    held.forEach(_onEvent);
  }

  void _onEvent(EngineEvent event) {
    if (!mounted || widget.game.isFinished) return;
    if (_waiting) {
      if (event is EngineTakeout) {
        _dartsRemoved();
      } else if (event is EngineThrow) {
        _held.add(event);
      } else {
        _onVisitEvent(event);
      }
      return;
    }
    _onVisitEvent(event);
  }

  void _onVisitEvent(EngineEvent event) {
    switch (event) {
      case EngineThrow(:final accepted, :final point, :final throwId, :final confidence):
        if (accepted) {
          // An accepted dart without a point bounced out or landed off the board.
          _add(_engineDart(point ?? fieldCentre(Ring.miss, geometry: _geometry), throwId, confidence));
        } else {
          setState(() => _pending = event);
        }
      case EngineThrowCorrected(:final client, :final throwId, :final action, :final point):
        if (client == _engine?.clientName) return;
        final index = widget.game.throws.indexWhere((d) => d.engineThrowId == throwId);
        if (action == 'corrected' && index >= 0 && point != null) {
          widget.game.replace(index, _engineDart(point, throwId, null));
          widget.onChanged();
        } else if (action == 'added' && point != null) {
          _add(_engineDart(point, throwId, null));
        } else if (action == 'rejected' && index == widget.game.throws.length - 1) {
          widget.game.undo();
          widget.onChanged();
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
    final countAsMiss = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.missingDarts(missing)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.enterManually)),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.countAsMiss)),
        ],
      ),
    );
    if (countAsMiss != true || !mounted) return;
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

  String _candidateLabel(EngineThrow pending, int index) {
    final c = pending.candidates[index];
    return '${_scoreAt(c.point).text(AppLocalizations.of(context))} (${percentText(AppLocalizations.of(context), c.probability)})';
  }

  Score _scoreAt(BoardPoint point) => DartThrow(point, ThrowInput.engine, geometry: _geometry).score;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pending = _pending;
    final pendingDart = pending?.point == null
        ? null
        : _engineDart(pending!.point!, pending.throwId, pending.confidence);
    final candidates = [
      for (final c in pending?.candidates ?? const <ThrowCandidate>[])
        DartThrow(c.point, ThrowInput.engine, geometry: _geometry),
    ];
    final throws = widget.game.throws;
    final recentStart = throws.length > 3 ? throws.length - 3 : 0;
    final correcting = _correcting;

    final waiting = _waiting;
    Widget? banner;
    if (waiting && correcting == null) {
      banner = _Notice(
        key: const ValueKey('remove-darts'),
        color: theme.colorScheme.primaryContainer,
        icon: Icons.back_hand_outlined,
        title: l10n.removeDarts,
        subtitle: l10n.removeDartsHint,
        actions: [
          TextButton(key: const ValueKey('darts-removed'), onPressed: _dartsRemoved, child: Text(l10n.dartsRemoved)),
        ],
      );
    } else if (pending != null && candidates.length >= 2) {
      banner = _Notice(
        key: const ValueKey('uncertain-candidates'),
        color: theme.colorScheme.tertiaryContainer,
        icon: Icons.help_outline,
        title: '${candidates.map((c) => c.score.text(l10n)).join(' ${l10n.or} ')}?',
        subtitle: l10n.pickCandidate,
        actions: [
          TextButton(onPressed: _discardPending, child: Text(l10n.discard)),
          for (var i = 0; i < candidates.length; ++i)
            if (i == 0)
              FilledButton(
                key: const ValueKey('candidate-0'),
                onPressed: () => _pickCandidate(0),
                child: Text(_candidateLabel(pending, 0)),
              )
            else
              OutlinedButton(
                key: ValueKey('candidate-$i'),
                onPressed: () => _pickCandidate(i),
                child: Text(_candidateLabel(pending, i)),
              ),
        ],
      );
    } else if (pending != null) {
      banner = _Notice(
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
      banner = _Notice(
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

    return Column(
      children: [
        ?banner,
        Expanded(
          child: EngineSelect(
            select: (engine) => engine.geometry,
            builder: (context, geometry) => ThrowInputPanel(
              geometry: geometry,
              shownThrows: waiting ? widget.takeout!.darts(widget.game) : [...widget.shownThrows, ?pendingDart],
              highlights: !waiting && candidates.length >= 2 ? [for (final c in candidates) c.score] : const [],
              onThrow: _onInput,
            ),
          ),
        ),
        if (throws.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.recentDarts, style: theme.textTheme.labelLarge),
                for (var i = recentStart; i < throws.length; ++i)
                  ChoiceChip(
                    key: ValueKey('recent-$i'),
                    avatar: Icon(throws[i].input == ThrowInput.engine ? Icons.videocam : Icons.touch_app, size: 16),
                    label: Text(throws[i].score.text(l10n)),
                    selected: correcting == i,
                    onSelected: (_) => setState(() => _correcting = correcting == i ? null : i),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A notice above the board: what happened, what to do, and its buttons. On narrow screens the buttons go below the
/// text, so the notice stays low enough for the board or keypad underneath.
class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.actions,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (subtitle != null)
          Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
      ],
    );
    final buttons = Wrap(spacing: 8, alignment: WrapAlignment.end, children: actions);
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 480;
            final top = Row(
              children: [
                Icon(icon),
                const SizedBox(width: 16),
                Expanded(child: texts),
                // Two or three candidates are wider than the space beside the text; they wrap instead.
                if (!narrow) Flexible(child: buttons),
              ],
            );
            return narrow
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
