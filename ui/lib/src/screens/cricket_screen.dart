import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../games/cricket.dart';
import '../bots/bot_turns.dart';
import '../games/dart_game.dart';
import '../input/takeout_gate.dart';
import '../sound/caller.dart';
import '../sound/game_calls.dart';
import '../sound/x01_calls.dart';
import '../stats/game_record.dart';
import '../stats/statistics.dart';
import '../widgets/winner_dialog.dart';
import 'my_darts_screen.dart';
import 'game_layout.dart';
import 'game_scaffold.dart';
import 'players_setup_screen.dart';
import '../board/score_text.dart';
import '../display.dart';
import '../widgets/cricket_mark.dart';
import '../theme.dart';
import '../widgets/celebration.dart';
import '../widgets/game_result.dart';
import '../widgets/precision_text.dart';
import '../stats/personal_best.dart';

class CricketScreen extends StatefulWidget {
  const CricketScreen({
    super.key,
    required this.names,
    this.cutThroat = false,
    this.bots = const {},
    this.replay = const [],
    this.watching = false,
  });

  final List<String> names;

  /// Cut-Throat Cricket: points go to the opponents, the lowest score wins
  final bool cutThroat;

  /// Bot level per player index; the others are people
  final Map<int, int> bots;

  /// Darts already thrown, for a game rebuilt from a shared record
  final List<DartThrow> replay;

  /// Only shows another app's game: no input, nothing kept or shared (#116)
  final bool watching;

  static Widget setup(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlayersSetupScreen(
      title: l10n.cricketSetup,
      rules: l10n.cricketRules,
      options: [(l10n.cutThroat, false)],
      start: (names, bots, options) => CricketScreen(names: names, cutThroat: options.first, bots: bots),
    );
  }

  @override
  State<CricketScreen> createState() => _CricketScreenState();
}

class _CricketScreenState extends State<CricketScreen> with RecordsGame, BotTurns {
  @override
  bool get watching => widget.watching;

  late final CricketGame _game = replayed(CricketGame(widget.names, cutThroat: widget.cutThroat), widget.replay);
  final TakeoutGate _takeout = TakeoutGate();
  final Celebrations _celebrations = Celebrations();

  @override
  void dispose() {
    _celebrations.dispose();
    super.dispose();
  }

  @override
  bool get waitsForTakeout => _takeout.isClosed(_game);

  @override
  GameRecord buildRecord(String id, DateTime started, DateTime ended) => GameRecord(
    id: id,
    mode: GameMode.cricket,
    started: started,
    ended: ended,
    players: widget.names,
    settings: {if (widget.cutThroat) 'cut_throat': true},
    throws: _game.throws,
    bots: widget.bots,
  );

  @override
  Map<int, int> get botPlayers => widget.bots;
  @override
  DartGame get botGame => _game;
  @override
  int get playerAtOche => _game.current;
  @override
  void addBotDart(DartThrow dart) => _add(dart);

  void _add(DartThrow dart) {
    setState(() => _game.add(dart));
    if (!widget.watching) CallerScope.read(context).call(cricketCalls(_game), callLanguage);
    final l10n = AppLocalizations.of(context);
    final marks = _game.currentVisit.fold(0, (sum, d) => sum + d.marks);
    if (_game.currentVisit.length == 3 && marks >= 6) _celebrations.show(l10n.celebrateMarks(marks));
    if (_game.isFinished) _showEnd();
  }

  /// The end of the game, after its last dart or a correction that ended it
  void _showEnd() {
    final l10n = AppLocalizations.of(context);
    if (_game.players.length > 1) {
      showWinnerDialog(
        context,
        winner: _game.players[_game.winner!].name,
        record: currentRecord,
        onUndo: () => setState(_game.undo),
        newGame: CricketScreen.setup,
      );
      return;
    }
    // Alone there is nobody to beat: the game ends on the darts it took and the marks per round against the best.
    final player = _game.players.single;
    final history = StatisticsScope.read(context)?.statsOf(player.name).history ?? const [];
    final best = personalBest(history, currentRecord);
    String mpr(double v) => l10n.labelValue(l10n.statsMarksPerRound, decimal(l10n, v, digits: 2));
    showGameResult(
      context,
      title: l10n.gameOver,
      content: SoloResult(
        headline: l10n.resultAllClosed(player.dartsThrown),
        details: mpr(player.marksPerRound),
        value: player.marksPerRound,
        best: best,
        bestText: best == null ? null : mpr(best),
      ),
      onUndo: () => setState(_game.undo),
      newGame: CricketScreen.setup,
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.watching) return;
      scheduleBotTurn();
      shareGame();
      if (mounted && !_game.isFinished) useDartsOf(context, _game.players[_game.current].name);
    });
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // While its darts are in the board, the visit that ended stays on the scoreboard with its player; a new visit
    // starts with no darts.
    final waiting = _takeout.isClosed(_game);
    final atOche = _game.isFinished
        ? null
        : waiting
        ? (_game.current + _game.players.length - 1) % _game.players.length
        : _game.current;
    final shown = waiting || _game.isFinished || _game.dartsInVisit > 0 ? _game.currentVisit : const <CricketDart>[];
    final players = _game.players;

    // The column at the oche in the display style: a bright block on the scoreboard, a tint in the clear style
    final display = DisplayScope.of(context);
    final window = WindowClass.of(context);
    final scoreboard = display.styleFor(window) == DisplayStyle.scoreboard;
    final far = display.farFor(window);
    final palette = AppPalette.of(context);
    final statistics = StatisticsScope.maybeOf(context);
    final activeFill = scoreboard ? palette.highlight : theme.colorScheme.primary.withValues(alpha: 0.18);
    final labelWidth = far ? 96.0 : 60.0;
    final divider = BorderSide(color: theme.dividerColor);

    Widget cell(int i, Widget child) => Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: i == atOche ? activeFill : null,
          border: Border(left: divider),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
    Color? onCell(int i) => i == atOche && scoreboard ? palette.onHighlight : null;

    // In a tight panel, such as a phone on its side, the points sit beside the name, so the numbers keep their rows.
    Widget header(bool short, bool tight, double width) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: labelWidth),
          for (var i = 0; i < players.length; ++i)
            cell(
              i,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Flex(
                  direction: tight ? Axis.horizontal : Axis.vertical,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // One line, cut short rather than broken inside a word; in a narrow column the player's colour
                    // is a bar under the name, so the dot leaves the name its room.
                    Flexible(
                      fit: FlexFit.loose,
                      flex: tight ? 1 : 0,
                      child: Builder(
                        builder: (context) {
                          final colour = statistics?.colourOf(players[i].name);
                          final narrow = (width - labelWidth) / players.length < 88;
                          final name = Text(
                            players[i].name,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: (far ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)?.copyWith(
                              fontWeight: i == atOche ? FontWeight.w800 : FontWeight.w600,
                              color: onCell(i),
                            ),
                          );
                          if (narrow) {
                            return Column(
                              children: [
                                name,
                                if (colour != null)
                                  Container(
                                    height: 4,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(2)),
                                  ),
                              ],
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (colour != null) ...[PlayerDot(colour, ring: onCell(i)), const SizedBox(width: 6)],
                              Flexible(child: name),
                            ],
                          );
                        },
                      ),
                    ),
                    if (tight) const SizedBox(width: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${players[i].points}',
                        key: ValueKey('points-${players[i].name}'),
                        style: scoreStyle(
                          far
                              ? theme.textTheme.displayMedium
                              : short
                              ? theme.textTheme.titleLarge
                              : theme.textTheme.headlineMedium,
                        )?.copyWith(fontWeight: FontWeight.w800, color: onCell(i), height: 1.1),
                      ),
                    ),
                    if (!short && !tight)
                      Text(
                        '${l10n.marksPerRoundShort} ${decimal(l10n, players[i].marksPerRound, digits: 2)}',
                        key: ValueKey('mpr-${players[i].name}'),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onCell(i) ?? theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    // A number every player closed scores for nobody any more: dimmed and struck through
    Widget targetRow(int target, double height) {
      final label = target == 25 ? l10n.bull : '$target';
      final dead = players.every((p) => p.isClosed(target));
      final markSize = (height * 0.62).clamp(14.0, far ? 84.0 : 44.0);
      return Container(
        key: ValueKey('cricket-row-$target'),
        height: height,
        decoration: BoxDecoration(border: Border(top: divider)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: labelWidth,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: scoreStyle(far ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: dead ? TextDecoration.lineThrough : null,
                      color: dead ? theme.colorScheme.onSurface.withValues(alpha: 0.4) : null,
                    ),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < players.length; ++i)
              cell(
                i,
                Opacity(
                  opacity: dead ? 0.4 : 1,
                  child: CricketMark(
                    players[i].marks[target]!,
                    key: ValueKey('marks-${players[i].name}-$label'),
                    size: markSize,
                    color: onCell(i),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final footer = [
      VisitDarts([for (final d in shown) d.dart.score.text(l10n)]),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _game.canUndo && !widget.watching ? () => setState(_game.undo) : null,
        icon: const Icon(Icons.undo),
        label: Text(l10n.undo),
      ),
    ];
    // The marks grow into the room the panel has and shrink to fit a phone, upright or on its side, down to the bull;
    // only where even that is too little do they scroll between names and Undo.
    final panel = LayoutBuilder(
      builder: (context, constraints) {
        final short = constraints.maxHeight < 420;
        final tight = constraints.maxHeight < 360;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(short, tight, constraints.maxWidth),
            Expanded(
              child: LayoutBuilder(
                builder: (context, rows) {
                  final height = (rows.maxHeight / cricketTargets.length).clamp(far ? 56.0 : 22.0, far ? 140.0 : 72.0);
                  final table = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final target in cricketTargets) targetRow(target, height)],
                  );
                  return height * cricketTargets.length > rows.maxHeight
                      ? SingleChildScrollView(child: table)
                      : Align(alignment: Alignment.topCenter, child: table);
                },
              ),
            ),
            const SizedBox(height: 12),
            ...footer,
          ],
        );
      },
    );
    return GameScaffold(
      title: l10n.modeCricket,
      game: _game,
      takeout: _takeout,
      shownThrows: [for (final d in shown) d.dart],
      watching: widget.watching,
      onDart: (dart) {
        // While a bot is at the oche, its darts are its own.
        if (!isBotTurn) _add(dart);
      },
      onChanged: () => setState(() {}),
      onOutcomeChanged: (_) {
        if (_game.isFinished) _showEnd();
      },
      panel: panel,
      panelWidth: 120.0 + 90.0 * players.length.clamp(2, 4),
      celebrations: _celebrations,
    );
  }
}
