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
import '../stats/statistics.dart';
import '../widgets/average_trend.dart';
import '../widgets/hit_heatmap.dart';
import '../widgets/player_picker.dart';

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
      floatingActionButton: statistics == null
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
                  child: Text(l10n.statisticsEmpty, textAlign: TextAlign.center),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    for (final player in players)
                      Builder(
                        builder: (context) {
                          final stats = computePlayerStats(statistics!.games, player);
                          final average = stats.threeDartAverage;
                          return Card(
                            child: ListTile(
                              key: ValueKey('stats-player-$player'),
                              leading: CircleAvatar(child: Text(player.characters.first.toUpperCase())),
                              title: Text(player),
                              subtitle: Text(
                                stats.games == 0
                                    ? l10n.statsNoGamesYet
                                    : [
                                        l10n.statsGamesCount(stats.games),
                                        if (average != null) '${l10n.average} ${_number(l10n, average)}',
                                      ].join('  ·  '),
                              ),
                              trailing: PopupMenuButton<void>(
                                key: ValueKey('profile-menu-$player'),
                                itemBuilder: (_) => [
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
    final games = StatisticsScope.maybeOf(context)?.games ?? const <GameRecord>[];
    final stats = computePlayerStats(games, widget.player, since: _since(games));
    String n(double? v, [int decimals = 1]) => v == null ? '–' : _number(l10n, v, decimals);
    String percent(double? v) => v == null ? '–' : '${_number(l10n, 100 * v, 0)} %';
    // X01 games, oldest first, the last 30
    final averages = [for (final g in stats.history.reversed) ?g.average];
    if (averages.length > 30) averages.removeRange(0, averages.length - 30);

    final figures = <(String, String)>[
      (l10n.statsGames, '${stats.games} (${l10n.statsWon(stats.gamesWon)})'),
      (l10n.statsDarts, '${stats.darts}'),
      (l10n.average, n(stats.threeDartAverage)),
      (l10n.statsFirst9, n(stats.first9Average)),
      (l10n.statsLegs, '${stats.legs} (${l10n.statsWon(stats.legsWon)})'),
      (l10n.statsBestLeg, stats.bestLegDarts == null ? '–' : l10n.statsDartsCount(stats.bestLegDarts!)),
      (l10n.statsCheckoutRate, percent(stats.checkoutRate)),
      (l10n.statsHighestFinish, stats.highestFinish?.toString() ?? '–'),
      ('100+', '${stats.visits100}'),
      ('140+', '${stats.visits140}'),
      ('180', '${stats.visits180}'),
      (l10n.statsMarksPerRound, n(stats.marksPerRound, 2)),
      (l10n.statsClockHitRate, percent(stats.clockHitRate)),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.player)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<StatsPeriod>(
                  segments: [
                    ButtonSegment(value: StatsPeriod.lastGame, label: Text(l10n.periodLastGame)),
                    ButtonSegment(value: StatsPeriod.week, label: Text(l10n.periodWeek)),
                    ButtonSegment(value: StatsPeriod.month, label: Text(l10n.periodMonth)),
                    ButtonSegment(value: StatsPeriod.all, label: Text(l10n.periodAll)),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) => setState(() => _period = s.first),
                ),
              ),
              const SizedBox(height: 16),
              if (stats.games == 0)
                Text(l10n.statsNoGamesInPeriod)
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, value) in figures)
                      SizedBox(
                        width: 160,
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: theme.textTheme.bodySmall),
                                const SizedBox(height: 4),
                                Text(value, key: ValueKey('figure-$label'), style: theme.textTheme.titleLarge),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (averages.length >= 2) ...[
                  const SizedBox(height: 24),
                  Text(l10n.statsAverageTrend, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  AverageTrend(key: const ValueKey('average-trend'), averages: averages),
                ],
                const SizedBox(height: 24),
                Text(l10n.statsHitBoard, style: theme.textTheme.titleMedium),
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
                const SizedBox(height: 24),
                Text(l10n.statsHistory, style: theme.textTheme.titleMedium),
                for (final game in stats.history) _HistoryTile(game: game),
              ],
            ],
          ),
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
      GameMode.cricket => l10n.modeCricket,
      GameMode.aroundTheClock => l10n.modeAroundTheClock,
    };
    final figure = game.average != null
        ? '${l10n.average} ${_number(l10n, game.average!)}'
        : game.marksPerRound != null
        ? '${l10n.statsMarksPerRound} ${_number(l10n, game.marksPerRound!, 2)}'
        : game.hitRate != null
        ? '${l10n.statsClockHitRate} ${_number(l10n, 100 * game.hitRate!, 0)} %'
        : '';
    final others = record.players.length - 1;
    return ListTile(
      contentPadding: EdgeInsets.zero,
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
