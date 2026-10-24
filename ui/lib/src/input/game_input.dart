import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../board/scoring.dart';
import '../engine/engine_connection.dart';
import '../engine/engine_events.dart';
import '../games/dart_game.dart';
import 'throw_input_panel.dart';

/// Input of a game screen: darts from the engine when connected, manual input otherwise, uncertain darts as a
/// suggestion to confirm or correct, corrections of the last darts, and the takeout that ends a visit.
class GameInput extends StatefulWidget {
  const GameInput({
    super.key,
    required this.game,
    required this.onDart,
    required this.onChanged,
    this.shownThrows = const [],
  });

  final DartGame game;

  /// Adds a dart to the game; the screen reacts to legs and the match end
  final ValueChanged<DartThrow> onDart;

  /// Called after a correction changed the game
  final VoidCallback onChanged;
  final List<DartThrow> shownThrows;

  @override
  State<GameInput> createState() => _GameInputState();
}

class _GameInputState extends State<GameInput> {
  EngineConnection? _engine;
  StreamSubscription<EngineEvent>? _subscription;
  EngineThrow? _pending;
  int? _correcting;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = EngineScope.of(context);
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

  void _onEvent(EngineEvent event) {
    if (!mounted || widget.game.isFinished) return;
    switch (event) {
      case EngineThrow(:final accepted, :final point, :final throwId, :final confidence):
        if (accepted) {
          // An accepted dart without a point bounced out or landed off the board.
          widget.onDart(_engineDart(point ?? fieldCentre(Ring.miss, geometry: _geometry), throwId, confidence));
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
          widget.onDart(_engineDart(point, throwId, null));
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

  Future<void> _onTakeout() async {
    final inVisit = widget.game.dartsInVisit;
    if (inVisit == 0 || _pending != null) return;
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
    for (var i = 0; i < missing && !widget.game.isFinished; ++i) {
      _manual(DartThrow(fieldCentre(Ring.miss, geometry: _geometry), ThrowInput.keypad, geometry: _geometry));
    }
  }

  /// A dart entered on the board or keypad: confirms a suggestion with a new point, corrects a dart, or is a new dart.
  void _onInput(DartThrow dart) {
    final engine = _engine;
    final pending = _pending;
    final correcting = _correcting;
    if (pending != null) {
      engine?.correctThrow(pending.throwId, dart.point);
      setState(() => _pending = null);
      widget.onDart(_engineDart(dart.point, pending.throwId, null));
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
    } else {
      _manual(dart);
    }
  }

  void _manual(DartThrow dart) {
    final engine = _engine;
    if (engine != null && engine.isConnected) engine.addThrow(dart.point);
    widget.onDart(dart);
  }

  void _confirmPending() {
    final pending = _pending;
    if (pending?.point == null) return;
    setState(() => _pending = null);
    widget.onDart(_engineDart(pending!.point!, pending.throwId, pending.confidence));
  }

  void _discardPending() {
    final pending = _pending;
    if (pending == null) return;
    _engine?.rejectThrow(pending.throwId, 'rejected by the player');
    setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pending = _pending;
    final pendingDart = pending?.point == null
        ? null
        : _engineDart(pending!.point!, pending.throwId, pending.confidence);
    final throws = widget.game.throws;
    final recentStart = throws.length > 3 ? throws.length - 3 : 0;
    final correcting = _correcting;

    Widget? banner;
    if (pending != null) {
      banner = Card(
        color: theme.colorScheme.tertiaryContainer,
        child: ListTile(
          key: const ValueKey('uncertain-dart'),
          leading: const Icon(Icons.help_outline),
          title: Text(
            pendingDart == null
                ? l10n.uncertainNoPoint
                : l10n.uncertainDart(pendingDart.score.label, (100 * pending.confidence).round()),
          ),
          subtitle: Text(l10n.tapToCorrect),
          trailing: Wrap(
            spacing: 8,
            children: [
              TextButton(onPressed: _discardPending, child: Text(l10n.discard)),
              if (pendingDart != null) FilledButton(onPressed: _confirmPending, child: Text(l10n.confirm)),
            ],
          ),
        ),
      );
    } else if (correcting != null && correcting < throws.length) {
      banner = Card(
        color: theme.colorScheme.tertiaryContainer,
        child: ListTile(
          leading: const Icon(Icons.edit_location_alt),
          title: Text(l10n.correctingDart(throws[correcting].score.label)),
          trailing: TextButton(onPressed: () => setState(() => _correcting = null), child: Text(l10n.cancel)),
        ),
      );
    }

    return Column(
      children: [
        ?banner,
        Expanded(
          child: ThrowInputPanel(
            geometry: _geometry,
            shownThrows: [...widget.shownThrows, ?pendingDart],
            onThrow: _onInput,
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
                    label: Text(throws[i].score.label),
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
