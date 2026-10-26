import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../stats/game_record.dart';
import '../stats/player_stats.dart';

/// End of a match: the winner, the figures of this game per player, and undo, new game or back to the menu.
Future<void> showWinnerDialog(
  BuildContext context, {
  required String winner,
  required GameRecord record,
  required VoidCallback onUndo,
  required WidgetBuilder newGame,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.matchWonBy(winner)),
      content: SingleChildScrollView(child: GameSummary(record: record)),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onUndo();
          },
          child: Text(l10n.undo),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: newGame));
          },
          child: Text(l10n.newGame),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pop();
          },
          child: Text(l10n.backToMenu),
        ),
      ],
    ),
  );
}

/// The figures of one game per player (#117), from the same statistics as the statistics page
class GameSummary extends StatelessWidget {
  const GameSummary({super.key, required this.record});

  final GameRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String n(double? v, [int decimals = 1]) => v == null ? '–' : v.toStringAsFixed(decimals);
    String percent(double? v) => v == null ? '–' : '${(100 * v).round()} %';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final player in record.players)
          Builder(
            builder: (context) {
              final s = computePlayerStats([record], player);
              final figures = <(String, String)>[
                (l10n.statsDarts, '${s.darts}'),
                ...switch (record.mode) {
                  GameMode.x01 => [
                    (l10n.statsLegs, '${s.legsWon}'),
                    (l10n.average, n(s.threeDartAverage)),
                    (l10n.statsFirst9, n(s.first9Average)),
                    (l10n.statsCheckoutRate, percent(s.checkoutRate)),
                    if (s.highestFinish != null) (l10n.statsHighestFinish, '${s.highestFinish}'),
                    if (s.visits100 > 0) ('100+', '${s.visits100}'),
                    if (s.visits140 > 0) ('140+', '${s.visits140}'),
                    if (s.visits180 > 0) ('180', '${s.visits180}'),
                  ],
                  GameMode.cricket => [(l10n.statsMarksPerRound, n(s.marksPerRound, 2))],
                  GameMode.aroundTheClock => [(l10n.statsClockHitRate, percent(s.clockHitRate))],
                  GameMode.grouping => [(l10n.precisionSpread, '${n(s.history.firstOrNull?.spreadMm)} mm')],
                },
              ];
              return Padding(
                key: ValueKey('summary-$player'),
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (label, value) in figures)
                          Chip(
                            key: ValueKey('summary-$player-$label'),
                            visualDensity: VisualDensity.compact,
                            label: Text('$label $value'),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
