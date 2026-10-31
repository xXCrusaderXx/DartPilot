import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../display.dart';
import '../stats/game_record.dart';
import '../stats/player_stats.dart';
import '../stats/statistics.dart';
import '../theme.dart';
import 'precision_text.dart';
import 'leave_game_guard.dart';

/// One player's line in a match result: [value] large at its end (such as the legs won or the points), [figures]
/// before it, and the player's [place] in front where the game ranks its players
class ResultLine {
  const ResultLine(this.name, {this.value, this.figures, this.place});

  final String name;
  final String? value;
  final String? figures;

  /// 1 for the best; players level on what decides the game share a place
  final int? place;

  ResultLine at(int place) => ResultLine(name, value: value, figures: figures, place: place);
}

/// [entries] best first with their places: by their keys compared in order, a lower key being better. Players with
/// the same keys share a place and keep their order among themselves.
List<ResultLine> rankedLines(List<(ResultLine, List<num>)> entries) {
  int compare(List<num> a, List<num> b) {
    for (var i = 0; i < a.length && i < b.length; ++i) {
      final c = a[i].compareTo(b[i]);
      if (c != 0) return c;
    }
    return 0;
  }

  final order = [for (var i = 0; i < entries.length; ++i) i]
    ..sort((a, b) {
      final c = compare(entries[a].$2, entries[b].$2);
      return c != 0 ? c : a.compareTo(b);
    });
  final lines = <ResultLine>[];
  var place = 0;
  for (var i = 0; i < order.length; ++i) {
    if (i == 0 || compare(entries[order[i]].$2, entries[order[i - 1]].$2) != 0) place = i + 1;
    lines.add(entries[order[i]].$1.at(place));
  }
  return lines;
}

/// End of a match, readable from the oche: the winner large in their colour, or the draw, the [result] (such as the
/// legs and the winning checkout), a line per player, and the figures of this game behind Details. A rematch with the
/// same players is the first way on when the game offers one; a new game, the menu and undo follow. The result stays
/// open until [readyForRematch] agrees, so a player who cancels that check is back at the result, not at a finished
/// game. Without a [winner] the game is a draw between the [tied] players.
Future<void> showWinnerDialog(
  BuildContext context, {
  required String? winner,
  required GameRecord record,
  required VoidCallback onUndo,
  required WidgetBuilder newGame,
  List<String> tied = const [],
  String? result,
  List<ResultLine> lines = const [],
  WidgetBuilder? rematch,
  Future<bool> Function()? readyForRematch,
}) {
  final l10n = AppLocalizations.of(context);
  final summary = GameSummary(record: record);
  return _showEnd(
    context,
    onUndo: onUndo,
    newGame: newGame,
    again: rematch,
    againKey: const ValueKey('result-rematch'),
    againLabel: l10n.rematch,
    readyForAgain: readyForRematch,
    details: lines.isEmpty ? null : summary,
    content: (context, far) {
      final theme = Theme.of(context);
      final statistics = StatisticsScope.maybeOf(context);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            winner == null ? l10n.gameDraw : l10n.matchWonBy(winner),
            key: const ValueKey('winner-title'),
            style: scoreStyle(far ? theme.textTheme.displayMedium : theme.textTheme.headlineLarge)?.copyWith(
              color: (winner == null ? null : statistics?.colourOf(winner)) ?? theme.colorScheme.primary,
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
          else
            for (final line in lines)
              _ResultRow(line: line, winner: line.name == winner || tied.contains(line.name), big: far),
        ],
      );
    },
  );
}

/// What every end of a game shares: its [content], the figures behind Details, and the ways on. [again], a rematch or
/// another round, stands out across the dialog with the others small above it; without it the menu is the main way.
Future<void> _showEnd(
  BuildContext context, {
  required Widget Function(BuildContext context, bool far) content,
  required VoidCallback onUndo,
  required Key againKey,
  required String againLabel,
  WidgetBuilder? newGame,
  WidgetBuilder? again,
  Future<bool> Function()? readyForAgain,
  Widget? details,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final far = DisplayScope.of(dialogContext).farFor(WindowClass.of(dialogContext));
      void close() => Navigator.of(dialogContext).pop();
      void menu() {
        close();
        Navigator.of(context).pop();
      }

      Future<void> play(WidgetBuilder next, {bool check = false}) async {
        if (check && readyForAgain != null && !await readyForAgain()) return;
        if (!dialogContext.mounted || !context.mounted) return;
        close();
        Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: next));
      }

      final undo = TextButton(
        key: const ValueKey('result-undo'),
        onPressed: () {
          close();
          onUndo();
        },
        child: Text(l10n.undo),
      );
      final newGameButton = newGame == null
          ? null
          : TextButton(
              key: const ValueKey('result-new-game'),
              onPressed: () => play(newGame),
              child: Text(l10n.newGame),
            );
      final Widget buttons = again == null
          ? OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              children: [
                undo,
                ?newGameButton,
                FilledButton(
                  key: const ValueKey('result-menu'),
                  autofocus: true,
                  onPressed: menu,
                  child: Text(l10n.backToMenu),
                ),
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
                    ?newGameButton,
                    TextButton(key: const ValueKey('result-menu'), onPressed: menu, child: Text(l10n.backToMenu)),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: againKey,
                  // Enter on a keyboard or remote plays the rematch
                  autofocus: true,
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(far ? 72 : 52),
                    textStyle: far ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium,
                  ),
                  onPressed: () => play(again, check: true),
                  icon: const Icon(Icons.replay),
                  label: Text(againLabel),
                ),
              ],
            );
      return EndOfGameBack(
        gameContext: context,
        child: Dialog(
          insetPadding: EdgeInsets.all(far ? 48 : 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: far ? 880 : 560),
            // The ways on stay at the foot, the result above them scrolls where the window is short, as a phone on
            // its side
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(far ? 32 : 24, far ? 32 : 24, far ? 32 : 24, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        content(dialogContext, far),
                        if (details != null)
                          Theme(
                            // A plain fold, without the lines an expansion tile draws around itself
                            data: theme.copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              key: const ValueKey('result-details'),
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(bottom: 8),
                              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                              title: Text(l10n.resultDetails),
                              children: [details],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(padding: EdgeInsets.fromLTRB(far ? 32 : 24, 16, far ? 32 : 24, far ? 32 : 24), child: buttons),
              ],
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
    final nameStyle = (big ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)?.copyWith(
      fontWeight: winner ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      key: ValueKey('result-${line.name}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (line.place != null)
            SizedBox(
              width: big ? 40 : 28,
              child: Text(
                '${line.place}.',
                key: ValueKey('place-${line.name}'),
                style: scoreStyle(nameStyle)?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          if (colour != null) ...[PlayerDot(colour), const SizedBox(width: 12)],
          Expanded(
            child: Text(line.name, overflow: TextOverflow.ellipsis, style: nameStyle),
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
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: big ? 72 : 48),
              child: Text(
                line.value!,
                key: ValueKey('result-value-${line.name}'),
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

/// End of a game played alone, or of a training round, in the same calm layout as a match: a small [title], the
/// [content] large (see [SoloResult]), [details] behind Details, and another round with the same settings as the
/// first way on.
Future<void> showSoloEnd(
  BuildContext context, {
  required String title,
  required Widget content,
  required VoidCallback onUndo,
  required WidgetBuilder again,
  WidgetBuilder? newGame,
  Widget? details,
}) {
  final l10n = AppLocalizations.of(context);
  return _showEnd(
    context,
    onUndo: onUndo,
    newGame: newGame,
    again: again,
    againKey: const ValueKey('round-again'),
    againLabel: l10n.roundAgain,
    details: details,
    content: (context, far) {
      final theme = Theme.of(context);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            key: const ValueKey('result-title'),
            style: (far ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          content,
          const SizedBox(height: 8),
        ],
      );
    },
  );
}

/// End of a training round: what it gave, large, how it stands against the earlier rounds, and another round first
Future<void> showRoundResult(
  BuildContext context, {
  required Widget content,
  required VoidCallback onUndo,
  required WidgetBuilder again,
  Widget? details,
}) => showSoloEnd(
  context,
  title: AppLocalizations.of(context).roundDone,
  content: content,
  onUndo: onUndo,
  again: again,
  details: details,
);

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
