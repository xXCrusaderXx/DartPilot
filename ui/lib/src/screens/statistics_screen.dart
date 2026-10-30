import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import '../../l10n/app_localizations.dart';
import '../board/scoring.dart';
import '../engine/engine_connection.dart';
import '../stats/export.dart';
import '../stats/game_record.dart';
import '../stats/player_stats.dart';
import '../stats/precision.dart';
import '../stats/statistics.dart';
import '../widgets/average_trend.dart';
import '../widgets/hit_heatmap.dart';
import '../widgets/player_picker.dart';
import '../widgets/precision_plot.dart';
import '../widgets/precision_text.dart';
import 'game_throws_screen.dart';
import 'round_game_screen.dart';

/// The player profiles of this device with their statistics; profiles are created and deleted here.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  Future<void> _delete(BuildContext context, Statistics statistics, String player) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProfile),
        content: Text(l10n.deleteProfileText(player)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirmed == true) await statistics.removeProfile(player);
  }

  Future<void> _pickColour(BuildContext context, Statistics statistics, String player) async {
    final l10n = AppLocalizations.of(context);
    final current = statistics.colourOf(player);
    final picked = await showDialog<Color?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.playerColourOf(player)),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < playerColours.length; ++i)
              Semantics(
                button: true,
                selected: playerColours[i] == current,
                label: '${i + 1}',
                child: InkResponse(
                  key: ValueKey('player-colour-$i'),
                  onTap: () => Navigator.of(context).pop(playerColours[i]),
                  child: PlayerDot(playerColours[i], size: playerColours[i] == current ? 44 : 36),
                ),
              ),
          ],
        ),
        actions: [
          if (statistics.hasOwnColour(player))
            TextButton(
              key: const ValueKey('player-colour-reset'),
              onPressed: () => Navigator.of(context).pop(Colors.transparent),
              child: Text(l10n.playerColourReset),
            ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        ],
      ),
    );
    if (picked == null) return;
    await statistics.setColour(player, picked == Colors.transparent ? null : picked);
  }

  Future<void> _export(BuildContext context, Statistics statistics, String kind) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    try {
      final file = kind == 'csv'
          ? await writeExport('dartpilot-darts-$stamp.csv', dartsCsv(statistics.games))
          : await writeExport('dartpilot-games-$stamp.json', gamesJson(statistics.games, statistics.players));
      messenger.showSnackBar(
        SnackBar(
          key: const ValueKey('export-done'),
          content: Text(l10n.exportSaved(file.path)),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: l10n.copyPath,
            onPressed: () => Clipboard.setData(ClipboardData(text: file.path)),
          ),
        ),
      );
    } on FileSystemException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed(e.message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statistics = StatisticsScope.maybeOf(context);
    final players = statistics?.players ?? const <String>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navStatistics),
        actions: [
          if (statistics != null && statistics.games.isNotEmpty)
            PopupMenuButton<String>(
              key: const ValueKey('stats-export'),
              icon: const Icon(Icons.file_download_outlined),
              tooltip: l10n.statsExport,
              onSelected: (kind) => _export(context, statistics, kind),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'csv', key: const ValueKey('export-csv'), child: Text(l10n.exportDartsCsv)),
                PopupMenuItem(value: 'json', key: const ValueKey('export-json'), child: Text(l10n.exportGamesJson)),
              ],
            ),
        ],
      ),
      floatingActionButton: statistics == null || players.isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('create-profile'),
              onPressed: () => createProfile(context),
              icon: const Icon(Icons.person_add),
              label: Text(l10n.newProfile),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: players.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_alt_1, size: 64, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(l10n.statisticsEmpty, textAlign: TextAlign.center),
                      if (statistics != null) ...[
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          key: const ValueKey('create-profile'),
                          onPressed: () => createProfile(context),
                          icon: const Icon(Icons.person_add),
                          label: Text(l10n.newProfile),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    for (final player in players)
                      Builder(
                        builder: (context) {
                          final stats = statistics!.statsOf(player);
                          final average = stats.threeDartAverage;
                          return Card(
                            child: ListTile(
                              key: ValueKey('stats-player-$player'),
                              leading: _Avatar(player: player, colour: statistics.colourOf(player)),
                              title: Text(player),
                              subtitle: Text(
                                stats.games == 0
                                    ? l10n.statsNoGamesYet
                                    : [
                                        l10n.statsGamesCount(stats.games),
                                        if (average != null) l10n.labelValue(l10n.average, _number(l10n, average)),
                                      ].join('  ·  '),
                              ),
                              trailing: PopupMenuButton<void>(
                                key: ValueKey('profile-menu-$player'),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    key: ValueKey('profile-colour-$player'),
                                    onTap: () => _pickColour(context, statistics, player),
                                    child: Text(l10n.playerColour),
                                  ),
                                  PopupMenuItem(
                                    onTap: () => _delete(context, statistics, player),
                                    child: Text(l10n.deleteProfile),
                                  ),
                                ],
                              ),
                              onTap: () =>
                                  Navigator.of(context)
                                      .push(MaterialPageRoute<void>(builder: (_) => PlayerStatsScreen(player: player))),
                            ),
                          );
                        },
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The player's initial on their colour, black or white, whichever reads better
class _Avatar extends StatelessWidget {
  const _Avatar({required this.player, required this.colour});

  final String player;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final colour = this.colour;
    final initial = Text(player.characters.first.toUpperCase());
    if (colour == null) return CircleAvatar(child: initial);
    final onColour = contrastRatio(colour, Colors.white) >= contrastRatio(colour, Colors.black)
        ? Colors.white
        : Colors.black;
    return CircleAvatar(backgroundColor: colour, foregroundColor: onColour, child: initial);
  }
}

String _number(AppLocalizations l10n, double value, [int decimals = 1]) =>
    NumberFormat.decimalPatternDigits(locale: l10n.localeName, decimalDigits: decimals).format(value);

enum StatsPeriod { lastGame, week, month, all }

/// One player's figures over a chosen period, and the games behind them
class PlayerStatsScreen extends StatefulWidget {
  const PlayerStatsScreen({super.key, required this.player});

  final String player;

  @override
  State<PlayerStatsScreen> createState() => _PlayerStatsScreenState();
}

class _PlayerStatsScreenState extends State<PlayerStatsScreen> {
  StatsPeriod _period = StatsPeriod.all;

  /// The history lists the newest games until the player asks for all of them.
  bool _allGames = false;
  static const _gamesShown = 5;

  DateTime? _since(List<GameRecord> games) {
    final now = DateTime.now();
    return switch (_period) {
      StatsPeriod.all => null,
      StatsPeriod.week => now.subtract(const Duration(days: 7)),
      StatsPeriod.month => now.subtract(const Duration(days: 30)),
      StatsPeriod.lastGame =>
        games
            .where((g) => g.players.contains(widget.player))
            .map((g) => g.ended)
            .fold<DateTime?>(null, (latest, e) => latest == null || e.isAfter(latest) ? e : latest),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final statistics = StatisticsScope.maybeOf(context);
    final games = statistics?.games ?? const <GameRecord>[];
    final since = _since(games);
    final stats = statistics?.statsOf(widget.player, since: since) ?? computePlayerStats(games, widget.player);
    final precision =
        statistics?.precisionOf(widget.player, since: since) ?? computePlayerPrecision(games, widget.player);
    String n(double? v, [int decimals = 1]) => v == null ? '–' : _number(l10n, v, decimals);
    String percent(double? v) => v == null ? '–' : percentText(l10n, v);
    String day(DateTime d) => DateFormat.yMd(l10n.localeName).format(d);
    // X01 games, oldest first, the last 30
    final x01Games = [
      for (final g in stats.history.reversed)
        if (g.average != null) g,
    ];
    if (x01Games.length > 30) x01Games.removeRange(0, x01Games.length - 30);
    final measured = [
      for (final p in precision)
        if (p.points.length >= minRankedDarts) p,
    ];
    final fewDarts = [
      for (final p in precision)
        if (p.points.length < minRankedDarts) p,
    ];

    // Only the figures of what the player played in the period; a mode never played has nothing to say.
    final figures = <(String, String)>[
      (l10n.statsGames, '${stats.games}'),
      if (stats.matches > 0) (l10n.statsMatches, '${stats.matches} (${l10n.statsWon(stats.gamesWon)})'),
      if (stats.trainings > 0) (l10n.statsTrainings, '${stats.trainings}'),
      if (stats.darts > 0) (l10n.statsDarts, '${stats.darts}'),
      if (stats.x01Darts > 0) ...[
        (l10n.average, n(stats.threeDartAverage)),
        (l10n.statsFirst9, n(stats.first9Average)),
        (
          l10n.statsCheckoutRate,
          stats.checkoutAttempts == 0
              ? '–'
              : '${percent(stats.checkoutRate)} (${stats.checkouts}/${stats.checkoutAttempts})',
        ),
        (l10n.statsHighestFinish, stats.highestFinish?.toString() ?? '–'),
        (l10n.statsHighestVisit, stats.highestVisit?.toString() ?? '–'),
        ('180', '${stats.visits180}'),
        ('140+', '${stats.visits140}'),
        ('100+', '${stats.visits100}'),
        (l10n.statsLegs, '${stats.legs}'),
        if (stats.matchLegs > 0) (l10n.statsMatchLegs, '${stats.matchLegs} (${l10n.statsWon(stats.legsWon)})'),
        for (final start in stats.bestLegByStart.keys.toList()..sort((a, b) => b.compareTo(a)))
          (l10n.statsBestLegOf(start), l10n.statsDartsCount(stats.bestLegByStart[start]!)),
      ],
      if (stats.cricketDarts > 0) (l10n.statsMarksPerRound, n(stats.marksPerRound, 2)),
      if (stats.clockDarts > 0) (l10n.statsClockHitRate, percent(stats.clockHitRate)),
    ];
    final history = _allGames ? stats.history : stats.history.take(_gamesShown);

    return Scaffold(
      appBar: AppBar(title: Text(widget.player)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 480;
                  return SegmentedButton<StatsPeriod>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: StatsPeriod.lastGame,
                        label: Text(narrow ? l10n.periodLastGameShort : l10n.periodLastGame),
                      ),
                      ButtonSegment(value: StatsPeriod.week, label: Text(l10n.periodWeek)),
                      ButtonSegment(value: StatsPeriod.month, label: Text(l10n.periodMonth)),
                      ButtonSegment(value: StatsPeriod.all, label: Text(l10n.periodAll)),
                    ],
                    selected: {_period},
                    onSelectionChanged: (s) => setState(() => _period = s.first),
                  );
                },
              ),
              const SizedBox(height: 16),
              if (stats.games == 0)
                Text(l10n.statsNoGamesInPeriod)
              else ...[
                _FigureGrid(figures: figures),
                if (x01Games.length >= 2) ...[
                  const SizedBox(height: 24),
                  Text(l10n.statsAverageTrend, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  AverageTrend(
                    key: const ValueKey('average-trend'),
                    averages: [for (final g in x01Games) g.average!],
                    from: day(x01Games.first.record.ended),
                    to: day(x01Games.last.record.ended),
                  ),
                ],
                const SizedBox(height: 24),
                Text(l10n.statsHistory, style: theme.textTheme.titleMedium),
                for (final game in history) _HistoryTile(game: game),
                if (!_allGames && stats.history.length > _gamesShown)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const ValueKey('history-all'),
                      onPressed: () => setState(() => _allGames = true),
                      child: Text(l10n.statsShowAllGames(stats.history.length)),
                    ),
                  ),
                if (stats.darts > 0) ...[
                  const SizedBox(height: 24),
                  Text(l10n.statsHitBoard, style: theme.textTheme.titleMedium),
                  Text(l10n.statsHitBoardHint, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: HitHeatmap(
                        key: const ValueKey('hit-heatmap'),
                        hits: stats.hits,
                        geometry: EngineScope.of(context).geometry,
                      ),
                    ),
                  ),
                  if (stats.rings[Ring.miss]! > 0)
                    Center(child: Text(l10n.statsMisses(stats.rings[Ring.miss]!), style: theme.textTheme.bodySmall)),
                  const SizedBox(height: 24),
                  Text(l10n.statsHits, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final (ring, label) in [
                    (Ring.triple, l10n.ringTriple),
                    (Ring.double, l10n.ringDouble),
                    (Ring.innerSingle, l10n.ringSingleInner),
                    (Ring.outerSingle, l10n.ringSingleOuter),
                    (Ring.outerBull, l10n.ringOuterBull),
                    (Ring.innerBull, l10n.ringBull),
                    (Ring.miss, l10n.ringMiss),
                  ])
                    _ShareBar(label: label, share: stats.ringShare(ring), text: percent(stats.ringShare(ring))),
                  if (stats.favouriteDoubles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(l10n.statsFavouriteDoubles, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(stats.favouriteDoubles.take(5).map((e) => '${e.key} × ${e.value}').join('   ')),
                  ],
                ],
                const SizedBox(height: 24),
                Text(l10n.statsPrecision, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                if (precision.isEmpty)
                  Text(l10n.statsPrecisionEmpty, key: const ValueKey('precision-empty'))
                else ...[
                  Text(l10n.statsPrecisionHelp, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  for (final target in measured) _TargetPrecisionCard(precision: target),
                  if (fewDarts.isNotEmpty)
                    ExpansionTile(
                      key: const ValueKey('precision-few-darts'),
                      tilePadding: EdgeInsets.zero,
                      title: Text(l10n.statsFewDartsTargets(fewDarts.length, minRankedDarts)),
                      children: [
                        for (final p in fewDarts)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(p.target.label),
                            trailing: Text(
                              '${l10n.statsDartsCount(p.points.length)}  ·  '
                              '${l10n.labelValue(l10n.hitRate, percentText(l10n, p.hitRate))}',
                            ),
                          ),
                      ],
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The player's figures as cards in equal columns: two on a phone, more as the page gets wider
class _FigureGrid extends StatelessWidget {
  const _FigureGrid({required this.figures});

  final List<(String, String)> figures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final columns = (constraints.maxWidth / 170).floor().clamp(2, 5);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (label, value) in figures)
              SizedBox(
                width: width,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(value, key: ValueKey('figure-$label'), style: theme.textTheme.titleLarge),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Spread and offset of the darts at one target, their plot, and the spread week by week
class _TargetPrecisionCard extends StatelessWidget {
  const _TargetPrecisionCard({required this.precision});

  final TargetPrecision precision;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spread = precision.spread;
    final label = precision.target.label;
    final figures = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.headlineSmall),
        Text(
          '${l10n.statsDartsCount(precision.points.length)}  ·  '
          '${l10n.labelValue(l10n.hitRate, percentText(l10n, precision.hitRate))}',
        ),
        const SizedBox(height: 8),
        Text(
          l10n.labelValue(l10n.precisionSpread, spread == null ? '–' : mmText(l10n, spread.spreadMm)),
          key: ValueKey('precision-spread-$label'),
        ),
        Text(
          l10n.labelValue(
            l10n.precisionOffset,
            spread == null ? '–' : offsetText(l10n, spread.offsetXMm, spread.offsetYMm),
          ),
          key: ValueKey('precision-offset-$label'),
        ),
      ],
    );
    final plot = SizedBox(
      width: 180,
      child: PrecisionPlot(key: ValueKey('precision-plot-$label'), target: precision.target, points: precision.points),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: 16, runSpacing: 12, children: [plot, figures]),
            if (precision.weeks.length >= 2) ...[
              const SizedBox(height: 12),
              Text(l10n.statsPrecisionTrend, style: theme.textTheme.titleSmall),
              AverageTrend(
                key: ValueKey('precision-trend-$label'),
                averages: [for (final w in precision.weeks) w.spread.spreadMm],
                unit: 'mm',
                from: DateFormat.yMd(l10n.localeName).format(precision.weeks.first.week),
                to: DateFormat.yMd(l10n.localeName).format(precision.weeks.last.week),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.label, required this.share, required this.text});

  final String label;
  final double share;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(
          child: LinearProgressIndicator(value: share, minHeight: 10, borderRadius: BorderRadius.circular(5)),
        ),
        SizedBox(width: 56, child: Text(text, textAlign: TextAlign.right)),
      ],
    ),
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.game});

  final PlayedGame game;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final record = game.record;
    final mode = switch (record.mode) {
      GameMode.x01 => '${record.x01Settings.startScore}',
      GameMode.cricket => record.settings['cut_throat'] == true ? '${l10n.modeCricket} Cut-Throat' : l10n.modeCricket,
      GameMode.aroundTheClock => l10n.modeAroundTheClock,
      GameMode.grouping => '${l10n.modeGrouping} ${record.groupingTarget.label}',
      GameMode.doubles => l10n.modeDoubles,
      GameMode.checkout => l10n.modeCheckout,
      GameMode.shanghai || GameMode.bobs27 || GameMode.halveIt => RoundGameScreen.title(l10n, record.mode),
      GameMode.killer => l10n.modeKiller,
    };
    final figure = game.average != null
        ? l10n.labelValue(l10n.average, _number(l10n, game.average!))
        : game.marksPerRound != null
        ? l10n.labelValue(l10n.statsMarksPerRound, _number(l10n, game.marksPerRound!, 2))
        : game.hitRate != null
        ? l10n.labelValue(
            record.mode == GameMode.doubles ? l10n.hitRate : l10n.statsClockHitRate,
            percentText(l10n, game.hitRate!),
          )
        : game.spreadMm != null
        ? l10n.labelValue(l10n.precisionSpread, mmText(l10n, game.spreadMm!))
        : game.checkoutRate != null
        ? l10n.labelValue(l10n.statsCheckoutRate, percentText(l10n, game.checkoutRate!))
        : game.points != null
        ? l10n.labelValue(l10n.points, '${game.points}')
        : '';
    final others = record.players.length - 1;
    return ListTile(
      key: ValueKey('history-${record.id}'),
      contentPadding: EdgeInsets.zero,
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GameThrowsScreen(record: record))),
      trailing: const Icon(Icons.chevron_right),
      leading: Icon(
        game.won ? Icons.emoji_events : Icons.sports_score,
        color: game.won ? StatusColors.of(context).warning : null,
      ),
      title: Text('$mode  ·  $figure'),
      subtitle: Text(
        [
          DateFormat.yMMMd(l10n.localeName).add_Hm().format(record.ended),
          l10n.statsDartsCount(game.darts),
          if (others - record.bots.length > 0) l10n.statsOpponents(others - record.bots.length),
          if (record.bots.isNotEmpty) l10n.statsAgainstBots(record.bots.values.join(', ')),
          if (others == 0) l10n.statsSolo,
        ].join('  ·  '),
      ),
    );
  }
}
