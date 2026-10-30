import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../display.dart';
import '../stats/game_record.dart';
import '../stats/player_stats.dart';
import '../stats/statistics.dart';
import '../theme.dart';
import 'precision_text.dart';
import 'leave_game_guard.dart';

/// One player's line in a match result: [value] large at its end (such as the legs won), [figures] before it
class ResultLine {
  const ResultLine(this.name, {this.value, this.figures});

  final String name;
  final String? value;
  final String? figures;
}

/// End of a match, readable from the oche: the winner large in their colour, the [result] (such as the legs and the
/// winning checkout), a line per player, and the figures of this game behind Details. A rematch with the same players
/// is the first way on when the game offers one; a new game, the menu and undo follow. The result stays open until
/// [readyForRematch] agrees, so a player who cancels that check is back at the result, not at a finished game.
Future<void> showWinnerDialog(
  BuildContext context, {
  required String winner,
  required GameRecord record,
  required VoidCallback onUndo,
  required WidgetBuilder newGame,
  String? result,
  List<ResultLine> lines = const [],
  WidgetBuilder? rematch,
  Future<bool> Function()? readyForRematch,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final far = DisplayScope.of(dialogContext).farFor(WindowClass.of(dialogContext));
      final statistics = StatisticsScope.maybeOf(dialogContext);
      void close() => Navigator.of(dialogContext).pop();
      void menu() {
        close();
        Navigator.of(context).pop();
      }

      void another() {
        close();
        Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: newGame));
      }

      Future<void> again(WidgetBuilder rematch) async {
        if (readyForRematch != null && !await readyForRematch()) return;
        if (!dialogContext.mounted || !context.mounted) return;
        close();
        Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: rematch));
      }

      final undo = TextButton(
        key: const ValueKey('result-undo'),
        onPressed: () {
          close();
          onUndo();
        },
        child: Text(l10n.undo),
      );
      final newGameButton = TextButton(
        key: const ValueKey('result-new-game'),
        onPressed: another,
        child: Text(l10n.newGame),
      );
      // A rematch is the one way on that stands out: across the dialog, with the others small beside undo above it.
      final Widget buttons = rematch == null
          ? OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              children: [
                undo,
                newGameButton,
                FilledButton(key: const ValueKey('result-menu'), onPressed: menu, child: Text(l10n.backToMenu)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    undo,
                    newGameButton,
                    TextButton(key: const ValueKey('result-menu'), onPressed: menu, child: Text(l10n.backToMenu)),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const ValueKey('result-rematch'),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(far ? 72 : 52),
                    textStyle: far ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium,
                  ),
                  onPressed: () => again(rematch),
                  icon: const Icon(Icons.replay),
                  label: Text(l10n.rematch),
                ),
              ],
            );
      final summary = GameSummary(record: record);
      return EndOfGameBack(
        gameContext: context,
        child: Dialog(
          insetPadding: EdgeInsets.all(far ? 48 : 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: far ? 880 : 560),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(far ? 32 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.matchWonBy(winner),
                    key: const ValueKey('winner-title'),
                    style: scoreStyle(far ? theme.textTheme.displayMedium : theme.textTheme.headlineLarge)?.copyWith(
                      color: statistics?.colourOf(winner) ?? theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (result != null && result.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      result,
                      key: const ValueKey('match-result'),
                      style: (far ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (lines.isEmpty)
                    summary
                  else ...[
                    for (final line in lines) _ResultRow(line: line, winner: line.name == winner, big: far),
                    Theme(
                      // A plain fold, without the lines an expansion tile draws around itself
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: const ValueKey('result-details'),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        title: Text(l10n.resultDetails),
                        children: [summary],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  buttons,
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.line, required this.winner, required this.big});

  final ResultLine line;
  final bool winner;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = StatisticsScope.maybeOf(context)?.colourOf(line.name);
    return Padding(
      key: ValueKey('result-${line.name}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (colour != null) ...[PlayerDot(colour), const SizedBox(width: 12)],
          Expanded(
            child: Text(
              line.name,
              overflow: TextOverflow.ellipsis,
              style: (big ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)?.copyWith(
                fontWeight: winner ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          if (line.figures != null)
            Text(
              line.figures!,
              style: (big ? theme.textTheme.titleLarge : theme.textTheme.bodyLarge)?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (line.value != null) ...[
            const SizedBox(width: 16),
            SizedBox(
              width: big ? 72 : 48,
              child: Text(
                line.value!,
                textAlign: TextAlign.end,
                style: scoreStyle(big ? theme.textTheme.displaySmall : theme.textTheme.headlineMedium)
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// End of a training round: what it gave, and undo the last dart, another round or back to the menu
Future<void> showRoundResult(
  BuildContext context, {
  required Widget content,
  required VoidCallback onUndo,
  required WidgetBuilder again,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => EndOfGameBack(
      gameContext: context,
      child: AlertDialog(
        title: Text(l10n.roundDone),
        content: SingleChildScrollView(child: content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onUndo();
            },
            child: Text(l10n.undo),
          ),
          TextButton(
            key: const ValueKey('round-again'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: again));
            },
            child: Text(l10n.roundAgain),
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
    String n(double? v, [int decimals = 1]) => v == null ? '–' : decimal(l10n, v, digits: decimals);
    String percent(double? v) => v == null ? '–' : percentText(l10n, v);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final player in record.players)
          Builder(
            builder: (context) {
              final s = computePlayerStats([record], player);
              final figures = <(String, String)>[
                (l10n.statsDarts, '${s.darts + s.trainingDarts}'),
                ...switch (record.mode) {
                  GameMode.x01 => [
                    // Solo, every leg played is the player's own
                    (l10n.statsLegs, '${record.players.length > 1 ? s.legsWon : s.legs}'),
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
                  GameMode.grouping => [
                    (
                      l10n.precisionSpread,
                      s.history.firstOrNull?.spreadMm == null ? '–' : mmText(l10n, s.history.firstOrNull!.spreadMm!),
                    ),
                  ],
                  GameMode.doubles => [(l10n.hitRate, percent(s.history.firstOrNull?.hitRate))],
                  GameMode.checkout => [(l10n.statsCheckoutRate, percent(s.history.firstOrNull?.checkoutRate))],
                  GameMode.killer => [(l10n.statsLivesLeft, '${s.history.firstOrNull?.lives ?? '–'}')],
                  GameMode.shanghai ||
                  GameMode.bobs27 ||
                  GameMode.halveIt => [(l10n.points, '${s.history.firstOrNull?.points ?? '–'}')],
                },
              ];
              // A figure without a value says nothing, and someone who never threw has only that to show.
              final shown = s.darts + s.trainingDarts == 0
                  ? figures.take(1).toList()
                  : [
                      for (final f in figures)
                        if (f.$2 != '–') f,
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
                        for (final (label, value) in shown)
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
