import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../sound/effects.dart';
import '../sound/sfx.dart';
import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../games/dart_game.dart';
import '../games/grouping.dart';
import '../input/takeout_gate.dart';
import '../stats/game_record.dart';
import '../stats/precision.dart';
import '../stats/statistics.dart';
import '../stats/training_best.dart';
import '../widgets/board_check.dart';
import '../widgets/player_picker.dart';
import '../widgets/precision_plot.dart';
import '../widgets/precision_text.dart';
import 'game_layout.dart';
import '../widgets/player_row.dart';
import 'game_scaffold.dart';
import 'my_darts_screen.dart';
import '../widgets/winner_dialog.dart';

/// Grouping training (#125): darts at one target, with the miss of every dart and the group's spread in mm.
class GroupingScreen extends StatefulWidget {
  const GroupingScreen({
    super.key,
    required this.player,
    required this.target,
    this.dartCount = 9,
    this.replay = const [],
    this.watching = false,
  });

  final String player;
  final PrecisionTarget target;
  final int dartCount;

  /// Darts already thrown, for a game rebuilt from a shared record
  final List<DartThrow> replay;

  /// Only shows another app's game: no input, nothing kept or shared (#116)
  final bool watching;

  static Widget setup(BuildContext context) => const GroupingSetupScreen();

  @override
  State<GroupingScreen> createState() => _GroupingScreenState();
}

class _GroupingScreenState extends State<GroupingScreen> with RecordsGame {
  @override
  bool get watching => widget.watching;

  late final GroupingGame _game = replayed(GroupingGame(widget.target, dartCount: widget.dartCount), widget.replay);
  final TakeoutGate _takeout = TakeoutGate();

  /// The player's earlier rounds at this target as kept now: the round played just before is kept only after this
  /// screen opened, when its screen is gone
  TrainingComparison? get _earlier => watching
      ? null
      : compareWithEarlier(StatisticsScope.read(context)?.games ?? const [], currentRecord, widget.player);

  @override
  GameRecord buildRecord(String id, DateTime started, DateTime ended) => GameRecord(
    id: id,
    mode: GameMode.grouping,
    started: started,
    ended: ended,
    players: [widget.player],
    settings: {'target': widget.target.label, 'darts': widget.dartCount},
    throws: _game.throws,
  );

  void _add(DartThrow dart) {
    setState(() => _game.add(dart));
    dartFeedback(context, dart, effect: gameEffect(dart, finished: _game.isFinished, training: true));
    if (_game.isFinished) _showResult();
  }

  Future<void> _showResult() {
    final l10n = AppLocalizations.of(context);
    final spread = _game.spread;
    final earlier = _earlier;
    return showRoundResult(
      context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.resultSpread(spread == null ? '–' : mmText(l10n, spread.spreadMm)),
            key: const ValueKey('grouping-result-spread'),
          ),
          if (spread != null) Text(l10n.resultOffset(offsetText(l10n, spread.offsetXMm, spread.offsetYMm))),
          if (spread != null && earlier != null) ...[
            const SizedBox(height: 8),
            PersonalBestLine(comparison: earlier, value: spread.spreadMm, format: (v) => mmText(l10n, v)),
          ],
        ],
      ),
      onUndo: () => setState(_game.undo),
      again: (_) => GroupingScreen(player: widget.player, target: widget.target, dartCount: widget.dartCount),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.watching) return;
      shareGame();
      if (mounted && !_game.isFinished) useDartsOf(context, widget.player);
    });
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final throws = _game.throws;
    final spread = _game.spread;
    final unmeasured = throws.length - _game.measured.length;
    final far = readFromAfar(context);
    final figureStyle = (far ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final labelStyle = far ? theme.textTheme.titleLarge : null;
    // From the oche only the last darts' misses are listed; the plot shows them all.
    final listed = far ? math.min(3, throws.length) : throws.length;

    final panel = ScrollingPanel(
      top: [
        PlayerRow(
          name: widget.player,
          value: widget.target.label,
          valueKey: const ValueKey('grouping-target'),
          details: l10n.groupingProgress((throws.length + 1).clamp(1, widget.dartCount), widget.dartCount),
          detailsKey: const ValueKey('grouping-progress'),
          detailsFromAfar: true,
          active: true,
        ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: PrecisionPlot(
              key: const ValueKey('grouping-plot'),
              target: widget.target,
              points: [for (final t in _game.measured) t.point],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Figure(
          label: l10n.precisionSpread,
          labelStyle: labelStyle,
          value: spread == null ? '–' : mmText(l10n, spread.spreadMm),
          valueKey: const ValueKey('grouping-spread'),
          valueStyle: figureStyle,
        ),
        _Figure(
          label: l10n.precisionOffset,
          labelStyle: labelStyle,
          value: spread == null ? '–' : offsetText(l10n, spread.offsetXMm, spread.offsetYMm),
          valueStyle: far ? figureStyle : theme.textTheme.titleMedium,
        ),
        if (unmeasured > 0 && !far) Text(l10n.groupingNotMeasured, style: theme.textTheme.bodySmall),
        for (var i = throws.length - 1; i >= throws.length - listed; --i)
          MissTile(key: ValueKey('grouping-dart-$i'), number: i + 1, dart: throws[i], target: widget.target),
      ],
      bottom: [
        OutlinedButton.icon(
          onPressed: throws.isEmpty || widget.watching ? null : () => setState(_game.undo),
          icon: const Icon(Icons.undo),
          label: Text(l10n.undo),
        ),
      ],
    );
    return GameScaffold(
      title: '${l10n.modeGrouping} ${widget.target.label}',
      game: _game,
      takeout: _takeout,
      shownThrows: throws,
      watching: widget.watching,
      onDart: _add,
      onChanged: () => setState(() {}),
      onOutcomeChanged: (_) {
        if (_game.isFinished) _showResult();
      },
      panel: panel,
    );
  }
}

/// A figure of the group: its name, and the value beside it or, when that does not fit, below it
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.labelStyle, this.valueStyle, this.valueKey});

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(label, style: labelStyle ?? Theme.of(context).textTheme.bodyLarge),
        Text(value, key: valueKey, style: valueStyle),
      ],
    ),
  );
}

/// Who throws, at which target, and how many darts
class GroupingSetupScreen extends StatefulWidget {
  const GroupingSetupScreen({super.key});

  @override
  State<GroupingSetupScreen> createState() => _GroupingSetupScreenState();
}

class _GroupingSetupScreenState extends State<GroupingSetupScreen> {
  String? _player;
  PrecisionTarget _target = trainingTargets.first;
  int _dartCount = 9;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profiles = StatisticsScope.maybeOf(context)?.players ?? const <String>[];
    final player = _player ?? profiles.firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.modeGrouping)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProfileChoice(selected: player, onSelected: (name) => setState(() => _player = name)),
              const SizedBox(height: 24),
              Text(l10n.groupingTarget, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final target in trainingTargets)
                    ChoiceChip(
                      key: ValueKey('target-${target.label}'),
                      label: Text(target.label),
                      selected: target == _target,
                      onSelected: (_) => setState(() => _target = target),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(l10n.groupingDartCount, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  for (final n in const [9, 15, 30]) ButtonSegment(value: n, label: Text('$n')),
                ],
                selected: {_dartCount},
                onSelectionChanged: (s) => setState(() => _dartCount = s.first),
              ),
              const SizedBox(height: 16),
              Text(l10n.precisionNeedsPoints, style: theme.textTheme.bodySmall),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('start-game'),
                onPressed: player == null
                    ? null
                    : () async {
                        if (!await confirmBoardEmpty(context) || !context.mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => GroupingScreen(player: player, target: _target, dartCount: _dartCount),
                          ),
                        );
                      },
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.startGame),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
