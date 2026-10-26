import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../games/dart_game.dart';
import '../games/doubles.dart';
import '../input/takeout_gate.dart';
import '../stats/game_record.dart';
import '../stats/player_stats.dart';
import '../stats/precision.dart';
import '../stats/statistics.dart';
import '../widgets/board_check.dart';
import '../widgets/player_picker.dart';
import '../widgets/precision_plot.dart';
import '../widgets/precision_text.dart';
import 'game_scaffold.dart';
import 'my_darts_screen.dart';
import '../widgets/winner_dialog.dart';

/// Doubles practice (#125): one visit at each double, with the miss of every dart, and the doubles ranked by the
/// player's own hit rate and spread.
class DoublesScreen extends StatefulWidget {
  const DoublesScreen({
    super.key,
    required this.player,
    required this.targets,
    this.dartsPerTarget = 3,
    this.replay = const [],
    this.watching = false,
  });

  final String player;
  final List<PrecisionTarget> targets;
  final int dartsPerTarget;

  /// Darts already thrown, for a game rebuilt from a shared record
  final List<DartThrow> replay;

  /// Only shows another app's game: no input, nothing kept or shared (#116)
  final bool watching;

  static Widget setup(BuildContext context) => const DoublesSetupScreen();

  @override
  State<DoublesScreen> createState() => _DoublesScreenState();
}

/// One line of a ranking: "D16  67 %  ·  14,2 mm"
String rankingLine(AppLocalizations l10n, TargetPrecision p) {
  final spread = p.spread;
  return [
    '${p.target.label}  ${percentText(l10n, p.hitRate)}',
    if (spread != null) mmText(l10n, spread.spreadMm),
  ].join('  ·  ');
}

class _DoublesScreenState extends State<DoublesScreen> with RecordsGame {
  @override
  bool get watching => widget.watching;

  late final DoublesGame _game = replayed(
    DoublesGame(widget.targets, dartsPerTarget: widget.dartsPerTarget),
    widget.replay,
  );
  final TakeoutGate _takeout = TakeoutGate();

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
    if (_game.isFinished) _showResult();
  }

  Future<void> _showResult() {
    final l10n = AppLocalizations.of(context);
    final ranking = _roundRanking;
    return showRoundResult(
      context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.resultHitRate(percentText(l10n, _game.hitRate)), key: const ValueKey('doubles-result-rate')),
          const SizedBox(height: 8),
          for (final p in ranking) Text(rankingLine(l10n, p)),
        ],
      ),
      onUndo: () => setState(_game.undo),
      again: (_) =>
          DoublesScreen(player: widget.player, targets: widget.targets, dartsPerTarget: widget.dartsPerTarget),
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

    final panel = ListView(
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.player, style: theme.textTheme.titleMedium)),
            Text(shown.label, key: const ValueKey('doubles-target'), style: theme.textTheme.displaySmall),
          ],
        ),
        Text(
          '${l10n.groupingProgress((throws.length + 1).clamp(1, _game.dartCount), _game.dartCount)}  ·  '
          '${l10n.labelValue(l10n.hitRate, percentText(l10n, _game.hitRate))}',
          key: const ValueKey('doubles-progress'),
        ),
        if (next != null)
          Text(l10n.checkoutAim(next.label), key: const ValueKey('doubles-next'), style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: PrecisionPlot(key: const ValueKey('doubles-plot'), target: shown, points: atTarget),
          ),
        ),
        for (final i in shownIndexes.reversed)
          MissTile(key: ValueKey('doubles-dart-$i'), number: i + 1, dart: throws[i], target: shown),
        if (throws.length > _game.dartsPerTarget) ...[
          const SizedBox(height: 12),
          Text(l10n.doublesRound, style: theme.textTheme.titleSmall),
          for (final p in _roundRanking) Text(rankingLine(l10n, p)),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: throws.isEmpty || widget.watching ? null : () => setState(_game.undo),
          icon: const Icon(Icons.undo),
          label: Text(l10n.undo),
        ),
      ],
    );
    return GameScaffold(
      title: l10n.modeDoubles,
      game: _game,
      takeout: _takeout,
      shownThrows: _game.dartsAt(shown),
      watching: widget.watching,
      onDart: _add,
      onChanged: () => setState(() {}),
      panel: panel,
    );
  }
}

enum DoublesSet { top10, all, weakest }

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
    final ranking = player == null
        ? const <TargetPrecision>[]
        : doublesRanking(computePlayerPrecision(statistics?.games ?? const [], player));
    final weakest = ranking.length >= 5 ? [for (final p in ranking.reversed.take(5)) p.target] : null;
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
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('start-game'),
                onPressed: player == null
                    ? null
                    : () async {
                        if (!await confirmBoardEmpty(context) || !context.mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => DoublesScreen(player: player, targets: targets),
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
