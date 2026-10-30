import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import '../../l10n/app_localizations.dart';
import '../board/scoring.dart';
import '../engine/engine_connection.dart';
import '../stats/backup.dart';
import '../stats/backup_file.dart';
import '../stats/export.dart';
import '../stats/export_save.dart';
import '../stats/game_record.dart';
import '../stats/player_stats.dart';
import '../stats/precision.dart';
import '../stats/statistics.dart';
import '../stats/training_best.dart';
import '../widgets/average_trend.dart';
import '../widgets/hit_heatmap.dart';
import '../widgets/player_picker.dart';
import '../widgets/precision_plot.dart';
import '../widgets/precision_text.dart';
import 'game_throws_screen.dart';
import 'round_game_screen.dart';
import 'x01_setup_screen.dart';

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
          FilledButton(
            key: const ValueKey('delete-profile-confirm'),
            style: destructiveButtonStyle(context),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await statistics.removeProfile(player);
  }

  Future<void> _rename(BuildContext context, String player) => showDialog<void>(
    context: context,
    builder: (_) => _RenameDialog(player: player),
  );

  /// Reads a backup the player picks and adds what it holds after they confirm; a file that is no backup changes
  /// nothing.
  Future<void> _import(BuildContext context, Statistics statistics) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final Backup backup;
    try {
      final text = await pickBackupText();
      if (text == null) return;
      backup = Backup.parse(text);
    } on Object catch (e) {
      debugPrint('The backup cannot be read: $e');
      messenger.showSnackBar(SnackBar(key: const ValueKey('backup-invalid'), content: Text(l10n.backupInvalid)));
      return;
    }
    final ids = {for (final g in statistics.games) g.id};
    final names = {for (final p in statistics.profiles) p.toLowerCase()};
    final newGames = backup.games.where((g) => !ids.contains(g.id)).length;
    final newProfiles = backup.profiles.where((p) => !names.contains(p.trim().toLowerCase())).length;
    if (!context.mounted) return;
    if (newGames == 0 && newProfiles == 0) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupNothingNew)));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backupImportTitle),
        content: Text(
          [
            l10n.backupImportText(l10n.backupGames(newGames), l10n.backupProfiles(newProfiles)),
            if (backup.unreadable > 0) l10n.backupUnreadable(backup.unreadable),
          ].join('\n\n'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            key: const ValueKey('backup-add'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.backupAdd),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final added = await statistics.importBackup(backup);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.backupImported(l10n.backupGames(added.games), l10n.backupProfiles(added.profiles)))),
    );
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
      final where = kind == 'csv'
          ? await saveExport('dartpilot-darts-$stamp.csv', dartsCsv(statistics.games))
          : await saveExport(
              'dartpilot-games-$stamp.json',
              gamesJson(statistics.games, statistics.players, colours: statistics.chosenColours),
            );
      messenger.showSnackBar(
        SnackBar(
          key: const ValueKey('export-done'),
          content: Text(kIsWeb ? l10n.exportDownloaded(where) : l10n.exportSaved(where)),
          duration: const Duration(seconds: 8),
          action: kIsWeb
              ? null
              : SnackBarAction(
                  label: l10n.copyPath,
                  onPressed: () => Clipboard.setData(ClipboardData(text: where)),
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
          if (statistics != null)
            PopupMenuButton<String>(
              key: const ValueKey('stats-export'),
              icon: const Icon(Icons.import_export),
              tooltip: l10n.statsDataMenu,
              onSelected: (kind) =>
                  kind == 'import' ? _import(context, statistics) : _export(context, statistics, kind),
              itemBuilder: (_) => [
                if (statistics.games.isNotEmpty || statistics.profiles.isNotEmpty)
                  PopupMenuItem(
                    value: 'json',
                    key: const ValueKey('export-json'),
                    child: ListTile(leading: const Icon(Icons.save_alt), title: Text(l10n.exportGamesJson)),
                  ),
                PopupMenuItem(
                  value: 'import',
                  key: const ValueKey('backup-import'),
                  child: ListTile(leading: const Icon(Icons.restore), title: Text(l10n.backupImport)),
                ),
                if (statistics.games.isNotEmpty)
                  PopupMenuItem(
                    value: 'csv',
                    key: const ValueKey('export-csv'),
                    child: ListTile(leading: const Icon(Icons.table_chart_outlined), title: Text(l10n.exportDartsCsv)),
                  ),
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
                                        if (stats.playedGames > 0) l10n.statsGamesCount(stats.playedGames),
                                        if (stats.trainings > 0) l10n.statsTrainingRounds(stats.trainings),
                                        if (average != null) l10n.x01PlayerFigures(_number(l10n, average)),
                                      ].join('  ·  '),
                              ),
                              trailing: PopupMenuButton<void>(
                                key: ValueKey('profile-menu-$player'),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    key: ValueKey('profile-rename-$player'),
                                    onTap: () => _rename(context, player),
                                    child: Text(l10n.renameProfile),
                                  ),
                                  PopupMenuItem(
                                    key: ValueKey('profile-colour-$player'),
                                    onTap: () => _pickColour(context, statistics, player),
                                    child: Text(l10n.playerColour),
                                  ),
                                  PopupMenuItem(
                                    onTap: () => _delete(context, statistics, player),
                                    child: Text(
                                      l10n.deleteProfile,
                                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                                    ),
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

/// The player's initial on their colour: white, unless the colour is too light for it
class _Avatar extends StatelessWidget {
  const _Avatar({required this.player, required this.colour});

  final String player;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final colour = this.colour;
    final initial = Text(player.characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600));
    if (colour == null) return CircleAvatar(child: initial);
    final onColour = contrastRatio(colour, Colors.white) >= 3 ? Colors.white : Colors.black;
    return CircleAvatar(backgroundColor: colour, foregroundColor: onColour, child: initial);
  }
}

/// Renames a profile; its games and colour follow the new name.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.player});

  final String player;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.player);
  ProfileError? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = await StatisticsScope.read(context)!.renameProfile(widget.player, _name.text);
    if (error == null) await LastX01.renamePlayer(widget.player, _name.text.trim());
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.renameProfileTitle(widget.player)),
      content: TextField(
        key: const ValueKey('rename-profile-name'),
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: l10n.profileName,
          errorText: switch (_error) {
            ProfileError.empty => l10n.profileNameEmpty,
            ProfileError.exists => l10n.profileNameExists,
            null => null,
          },
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(key: const ValueKey('rename-profile-save'), onPressed: _save, child: Text(l10n.renameProfile)),
      ],
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

  /// The history lists the newest games until the player asks for all of them.
  bool _allGames = false;
  static const _gamesShown = 5;

  /// From the start of a day, so the period stays the same between rebuilds and its figures are computed once
  DateTime? _since(List<GameRecord> games) {
    final now = DateTime.now();
    return switch (_period) {
      StatsPeriod.all => null,
      StatsPeriod.week => DateTime(now.year, now.month, now.day - 7),
      StatsPeriod.month => DateTime(now.year, now.month, now.day - 30),
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
    final training =
        statistics?.trainingOf(widget.player, since: since) ?? computeTrainingProgress(games, widget.player);
    String n(double? v, [int decimals = 1]) => v == null ? '–' : _number(l10n, v, decimals);
    String percent(double? v) => v == null ? '–' : percentText(l10n, v);
    String day(DateTime d) => DateFormat.yMd(l10n.localeName).format(d);
    // X01 games played to their end, oldest first, the last 30
    final x01Games = [
      for (final g in stats.history.reversed)
        if (g.average != null && g.finished) g,
    ];
    if (x01Games.length > 30) x01Games.removeRange(0, x01Games.length - 30);
    final measured = [
      for (final p in precision)
        if (p.darts >= minRankedDarts) p,
    ];
    final fewDarts = [
      for (final p in precision)
        if (p.darts < minRankedDarts) p,
    ];

    // Only the figures of what the player played in the period; a mode never played has nothing to say. Games and
    // legs are one figure each when every one of them was a match; milestones not reached yet stay out.
    final figures = <(String, String)>[
      if (stats.playedGames > 0)
        if (stats.matches == stats.playedGames)
          (l10n.statsGames, '${stats.playedGames} (${l10n.statsWon(stats.gamesWon)})')
        else ...[
          (l10n.statsGames, '${stats.playedGames}'),
          if (stats.matches > 0) (l10n.statsMatches, '${stats.matches} (${l10n.statsWon(stats.gamesWon)})'),
        ],
      if (stats.darts > 0) (l10n.statsDartsInGames, '${stats.darts}'),
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
        if (stats.visits180 > 0) ('180', '${stats.visits180}'),
        if (stats.visits140 > 0) ('140+', '${stats.visits140}'),
        if (stats.visits100 > 0) ('100+', '${stats.visits100}'),
        if (stats.matchLegs == stats.legs)
          (l10n.statsLegs, '${stats.legs} (${l10n.statsWon(stats.legsWon)})')
        else ...[
          (l10n.statsLegs, '${stats.legs}'),
          if (stats.matchLegs > 0) (l10n.statsMatchLegs, '${stats.matchLegs} (${l10n.statsWon(stats.legsWon)})'),
        ],
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
                if (figures.isNotEmpty) _FigureGrid(figures: figures),
                if (stats.trainings > 0) ...[
                  if (figures.isNotEmpty) const SizedBox(height: 24),
                  Text(l10n.statsTraining, style: theme.textTheme.titleMedium),
                  Text(
                    l10n.statsTrainingDarts(
                      l10n.statsTrainingRounds(stats.trainings),
                      l10n.statsDartsCount(stats.trainingDarts),
                    ),
                    key: const ValueKey('training-summary'),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  _TrainingProgressGrid(progress: training),
                ],
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
                for (final game in history) _HistoryTile(game: game, player: widget.player),
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
                              '${l10n.statsDartsCount(p.darts)}  ·  '
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
                          child: Text(
                            value,
                            key: ValueKey('figure-$label'),
                            style: scoreStyle(theme.textTheme.headlineSmall)?.copyWith(fontWeight: FontWeight.w600),
                          ),
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

/// The training tracks in equal columns: the last round's figure, the best, and the rounds as a small line
class _TrainingProgressGrid extends StatelessWidget {
  const _TrainingProgressGrid({required this.progress});

  final List<TrainingProgress> progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final columns = (constraints.maxWidth / 300).floor().clamp(1, 3);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final p in progress)
              SizedBox(
                width: width,
                child: Card(
                  key: ValueKey('training-${p.track.mode.name}-${p.track.range?.name ?? p.track.target?.label ?? ''}'),
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_trackName(l10n, p.track), style: theme.textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _trackValue(l10n, p.track, p.last),
                              style: scoreStyle(theme.textTheme.headlineSmall)?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    if (p.lastIsBest)
                                      TextSpan(
                                        text: l10n.statsTrainingNewBest,
                                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                      )
                                    else
                                      TextSpan(text: l10n.statsTrainingBest(_trackValue(l10n, p.track, p.best))),
                                    TextSpan(text: '  ·  ${l10n.statsTrainingRounds(p.rounds.length)}'),
                                  ],
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        if (p.rounds.length >= 2) ...[
                          const SizedBox(height: 4),
                          AverageTrend(
                            averages: [for (final r in p.rounds) _trackPlotted(p.track, r.value)],
                            unit: _trackUnit(p.track),
                            height: 72,
                          ),
                        ],
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

String _trackName(AppLocalizations l10n, TrainingTrack track) => switch (track.mode) {
  GameMode.doubles => l10n.statsTrainingDoubles,
  GameMode.grouping => l10n.statsTrainingGrouping(track.target!.label),
  _ when track.isLadder => l10n.statsTrainingLadder,
  _ => l10n.statsTrainingCheckout('${track.range!.lowest}', '${track.range!.highest}'),
};

/// Rates as percent, the ladder as the score checked out, the grouping in mm
String _trackValue(AppLocalizations l10n, TrainingTrack track, double value) => switch (track.mode) {
  GameMode.grouping => mmText(l10n, value),
  _ when track.isLadder => value.round().toString(),
  _ => percentText(l10n, value),
};

double _trackPlotted(TrainingTrack track, double value) =>
    track.mode == GameMode.grouping || track.isLadder ? value : value * 100;

String? _trackUnit(TrainingTrack track) => switch (track.mode) {
  GameMode.grouping => 'mm',
  _ when track.isLadder => null,
  _ => '%',
};

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
          '${l10n.statsDartsCount(precision.darts)}  ·  '
          '${l10n.labelValue(l10n.hitRate, percentText(l10n, precision.hitRate))}',
        ),
        if (precision.points.isEmpty) ...[
          const SizedBox(height: 4),
          Text(l10n.precisionNeedsPoints, style: theme.textTheme.bodySmall),
        ] else ...[
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
            if (precision.points.isEmpty) figures else Wrap(spacing: 16, runSpacing: 12, children: [plot, figures]),
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

/// A kept game's name in the history: the start score for X01, the training and its target for trainings
String gameTitle(AppLocalizations l10n, GameRecord record) => switch (record.mode) {
  GameMode.x01 => '${record.x01Settings.startScore}',
  GameMode.cricket => record.settings['cut_throat'] == true ? '${l10n.modeCricket} Cut-Throat' : l10n.modeCricket,
  GameMode.aroundTheClock => l10n.modeAroundTheClock,
  GameMode.grouping => '${l10n.modeGrouping} ${record.groupingTarget.label}',
  GameMode.doubles => l10n.modeDoubles,
  GameMode.checkout => record.settings['ladder'] == true ? l10n.modeLadder : l10n.modeCheckout,
  GameMode.shanghai || GameMode.bobs27 || GameMode.halveIt => RoundGameScreen.title(l10n, record.mode),
  GameMode.killer => l10n.modeKiller,
};

/// The figure a game is judged by for the player, as "label: value"; empty when it has none
String gameFigure(AppLocalizations l10n, PlayedGame game) {
  final record = game.record;
  if (game.average != null) return l10n.labelValue(l10n.average, _number(l10n, game.average!));
  if (game.marksPerRound != null) {
    return l10n.labelValue(l10n.statsMarksPerRound, _number(l10n, game.marksPerRound!, 2));
  }
  if (game.hitRate != null) {
    return l10n.labelValue(
      record.mode == GameMode.doubles ? l10n.hitRate : l10n.statsClockHitRate,
      percentText(l10n, game.hitRate!),
    );
  }
  if (game.spreadMm != null) return l10n.labelValue(l10n.precisionSpread, mmText(l10n, game.spreadMm!));
  if (game.checkoutRate != null) return l10n.labelValue(l10n.statsCheckoutRate, percentText(l10n, game.checkoutRate!));
  if (game.ladderBest != null) return l10n.ladderBest('${game.ladderBest}');
  if (game.points != null) return l10n.labelValue(l10n.points, '${game.points}');
  if (game.lives != null) return l10n.labelValue(l10n.statsLivesLeft, '${game.lives}');
  return '';
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.game, required this.player});

  final PlayedGame game;
  final String player;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final record = game.record;
    final figure = gameFigure(l10n, game);
    final people = [
      for (var i = 0; i < record.players.length; ++i)
        if (!record.bots.containsKey(i) && record.players[i] != player) record.players[i],
    ];
    final title = [gameTitle(l10n, record), if (figure.isNotEmpty) figure].join('  ·  ');
    // A won match earns the trophy; the others say what kind of game it was, so a loss is not marked as one.
    final (icon, colour) = switch (game) {
      PlayedGame(won: true) => (Icons.emoji_events, StatusColors.of(context).warning),
      PlayedGame(finished: false) => (Icons.timelapse, theme.colorScheme.onSurfaceVariant),
      _ when trainingModes.contains(record.mode) => (Icons.track_changes, theme.colorScheme.onSurfaceVariant),
      _ when record.players.length > 1 => (Icons.groups_outlined, theme.colorScheme.onSurfaceVariant),
      _ => (Icons.person_outline, theme.colorScheme.onSurfaceVariant),
    };
    return ListTile(
      key: ValueKey('history-${record.id}'),
      contentPadding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GameThrowsScreen(record: record, title: title),
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      leading: Icon(icon, color: colour),
      title: Text(title),
      subtitle: Text(
        [
          DateFormat.yMMMd(l10n.localeName).add_Hm().format(record.ended),
          l10n.statsDartsCount(game.darts),
          if (people.isNotEmpty) l10n.statsAgainst(people.join(', ')),
          if (record.bots.isNotEmpty) l10n.statsAgainstBots(record.bots.values.join(', ')),
          if (record.players.length == 1 && !trainingModes.contains(record.mode)) l10n.statsSolo,
          if (!game.finished) l10n.statsUnfinished,
        ].join('  ·  '),
      ),
    );
  }
}
