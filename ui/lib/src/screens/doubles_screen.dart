import 'package:flutter/material.dart';

import '../sound/effects.dart';
import '../sound/sfx.dart';
import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../games/dart_game.dart';
import '../games/doubles.dart';
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
import '../widgets/game_result.dart';
import '../widgets/winner_dialog.dart';

/// Doubles practice (#125): one visit at each double, with the miss of every dart, and the doubles ranked by the
/// player's own hit rate and spread.
class DoublesScreen extends StatefulWidget {
  const DoublesScreen({
    super.key,
    required this.player,
    required this.targets,
    this.dartsPerTarget = 3,
    this.weakest = false,
    this.replay = const [],
    this.watching = false,
  });

  final String player;
  final List<PrecisionTarget> targets;
  final int dartsPerTarget;

  /// Whether [targets] are the player's five weakest doubles, which another round finds anew
  final bool weakest;

  /// Darts already thrown, for a game rebuilt from a shared record
  final List<DartThrow> replay;

  /// Only shows another app's game: no input, nothing kept or shared (#116)
  final bool watching;

  static Widget setup(BuildContext context) => const DoublesSetupScreen();

  @override
  State<DoublesScreen> createState() => _DoublesScreenState();
}

/// One line of a ranking, with the darts it rests on: "D16  4/6  ·  67 %  ·  14,2 mm"
String rankingLine(AppLocalizations l10n, TargetPrecision p) {
  final spread = p.spread;
  return [
    '${p.target.label}  ${p.hits}/${p.darts}',
    percentText(l10n, p.hitRate),
    if (spread != null) mmText(l10n, spread.spreadMm),
  ].join('  ·  ');
}

class _DoublesScreenState extends State<DoublesScreen> with RecordsGame, ComparesTraining {
  @override
  String get trainingPlayer => widget.player;

  @override
  bool get watching => widget.watching;

  late final DoublesGame _game = replayed(
    DoublesGame(widget.targets, dartsPerTarget: widget.dartsPerTarget),
    widget.replay,
  );
  final TakeoutGate _takeout = TakeoutGate();

  TrainingComparison? get _earlier => earlierRounds(StatisticsScope.read(context)?.games ?? const []);

  @override
  GameRecord buildRecord(String id, DateTime started, DateTime ended) => GameRecord(
    id: id,
    mode: GameMode.doubles,
    started: started,
    ended: ended,
    players: [widget.player],
    settings: {
      'targets': [for (final t in widget.targets) t.label],
      'darts_per_target': widget.dartsPerTarget,
      if (widget.weakest) 'weakest': true,
    },
    throws: _game.throws,
  );

  /// This round's doubles, best first
  List<TargetPrecision> get _roundRanking => doublesRanking(
    computePrecision([
      for (var i = 0; i < _game.throws.length; ++i)
        (target: _game.targetOf(i), dart: _game.throws[i], thrown: DateTime.now()),
    ]),
  );

  void _add(DartThrow dart) {
    setState(() => _game.add(dart));
    dartFeedback(context, dart, effect: doublesEffect(_game, dart));
    if (_game.isFinished) _showResult();
  }

  Future<void> _showResult() {
    final l10n = AppLocalizations.of(context);
    final ranking = _roundRanking;
    final earlier = _earlier;
    return showRoundResult(
      context,
      content: SoloResult(
        headline: l10n.resultHitRate(percentText(l10n, _game.hitRate)),
        headlineKey: const ValueKey('doubles-result-rate'),
        comparison: earlier == null
            ? null
            : PersonalBestLine(comparison: earlier, value: _game.hitRate, format: (v) => percentText(l10n, v)),
      ),
      // The doubles of the round, best first, for those who want to look closer
      details: Column(
        key: const ValueKey('doubles-result-ranking'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final p in ranking) Text(rankingLine(l10n, p))],
      ),
      onUndo: () => setState(_game.undo),
      again: (context) => DoublesScreen(
        player: widget.player,
        // The weakest doubles are found again, now with this round's darts among them.
        targets: widget.weakest
            ? weakestDoubles(StatisticsScope.read(context)?.games ?? const [], widget.player) ?? widget.targets
            : widget.targets,
        dartsPerTarget: widget.dartsPerTarget,
        weakest: widget.weakest,
      ),
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
    // The double just finished stays on show with its misses until the next dart; the next double is named above it.
    final shown = throws.isEmpty ? _game.current : _game.targetOf(throws.length - 1);
    final next = _game.isFinished || shown == _game.current ? null : _game.current;
    final atTarget = [
      for (final t in _game.dartsAt(shown))
        if (hasMeasuredPoint(t)) t.point,
    ];
    final shownIndexes = [
      for (var i = 0; i < throws.length; ++i)
        if (_game.targetOf(i) == shown) i,
    ];
    final far = readFromAfar(context);
    final unmeasured = throws.any((t) => !hasMeasuredPoint(t));

    final panel = ScrollingPanel(
      top: [
        PlayerRow(
          name: widget.player,
          value: shown.label,
          valueKey: const ValueKey('doubles-target'),
          details:
              '${l10n.groupingProgress((throws.length + 1).clamp(1, _game.dartCount), _game.dartCount)}  ·  '
              '${l10n.labelValue(l10n.hitRate, percentText(l10n, _game.hitRate))}',
          detailsKey: const ValueKey('doubles-progress'),
          detailsFromAfar: true,
          active: true,
        ),
        if (next != null) AimLine(field: next.label, fieldKey: const ValueKey('doubles-next')),
        // Darts from the keypad have no spot: without a measured dart the plot would be an empty grid.
        if (throws.any(hasMeasuredPoint)) ...[
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: PrecisionPlot(key: const ValueKey('doubles-plot'), target: shown, points: atTarget),
            ),
          ),
        ],
        for (final i in shownIndexes.reversed)
          MissTile(key: ValueKey('doubles-dart-$i'), number: i + 1, dart: throws[i], target: shown),
        if (unmeasured && !far) ...[
          const SizedBox(height: 8),
          Text(l10n.precisionNeedsPoints, style: theme.textTheme.bodySmall),
        ],
        // From the oche the round's ranking is left for the result at the end.
        if (throws.length > _game.dartsPerTarget && !far) ...[
          const SizedBox(height: 12),
          Text(l10n.doublesRound, style: theme.textTheme.titleSmall),
          for (final p in _roundRanking) Text(rankingLine(l10n, p)),
        ],
      ],
      bottom: [GameUndoButton(onPressed: throws.isEmpty || widget.watching ? null : () => setState(_game.undo))],
    );
    return GameScaffold(
      title: l10n.modeDoubles,
      game: _game,
      takeout: _takeout,
      shownThrows: _game.dartsAt(shown),
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

enum DoublesSet { top10, all, weakest }

/// The five doubles [player] hits least often, among those with enough darts to rank; null with fewer than five
List<PrecisionTarget>? weakestDoubles(List<GameRecord> games, String? player) {
  if (player == null) return null;
  final ranking = doublesRanking(computePlayerPrecision(games, player), minDarts: minRankedDarts);
  return ranking.length >= 5 ? [for (final p in ranking.reversed.take(5)) p.target] : null;
}

/// Who throws and at which doubles, with the player's ranking so far
class DoublesSetupScreen extends StatefulWidget {
  const DoublesSetupScreen({super.key});

  @override
  State<DoublesSetupScreen> createState() => _DoublesSetupScreenState();
}

class _DoublesSetupScreenState extends State<DoublesSetupScreen> {
  String? _player;
  DoublesSet _set = DoublesSet.top10;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final statistics = StatisticsScope.maybeOf(context);
    final player = _player ?? statistics?.players.firstOrNull;
    final precision = player == null
        ? const <TargetPrecision>[]
        : statistics?.precisionOf(player) ?? const <TargetPrecision>[];
    // Only doubles with enough darts are ranked; one lucky dart is no strong double.
    final ranking = doublesRanking(precision, minDarts: minRankedDarts);
    final unranked = [
      for (final p in doublesRanking(precision))
        if (p.darts < minRankedDarts) p.target.label,
    ];
    final weakest = weakestDoubles(statistics?.games ?? const [], player);
    final set = _set == DoublesSet.weakest && weakest == null ? DoublesSet.top10 : _set;
    final targets = switch (set) {
      DoublesSet.top10 => allDoubles.take(10).toList(),
      DoublesSet.all => allDoubles,
      DoublesSet.weakest => weakest!,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.modeDoubles)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProfileChoice(selected: player, onSelected: (name) => setState(() => _player = name)),
              const SizedBox(height: 24),
              Text(l10n.doublesSet, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label) in [
                    (DoublesSet.top10, l10n.doublesTop10),
                    (DoublesSet.all, l10n.doublesAll),
                    (DoublesSet.weakest, l10n.doublesWeakest),
                  ])
                    ChoiceChip(
                      key: ValueKey('doubles-set-${value.name}'),
                      label: Text(label),
                      selected: value == set,
                      onSelected: value == DoublesSet.weakest && weakest == null
                          ? null
                          : (_) => setState(() => _set = value),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(targets.map((t) => t.label).join('  '), key: const ValueKey('doubles-targets')),
              if (ranking.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(l10n.doublesRanking, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                for (final p in ranking) Text(rankingLine(l10n, p)),
              ],
              if (unranked.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.doublesTooFewDarts(unranked.join(' ')),
                  key: const ValueKey('doubles-unranked'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
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
                            builder: (_) =>
                                DoublesScreen(player: player, targets: targets, weakest: set == DoublesSet.weakest),
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
