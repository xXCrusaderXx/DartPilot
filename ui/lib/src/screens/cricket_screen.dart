import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../games/cricket.dart';
import '../bots/bot_turns.dart';
import '../games/dart_game.dart';
import '../input/takeout_gate.dart';
import '../sound/effects.dart';
import '../sound/sfx.dart';
import '../sound/game_calls.dart';
import '../stats/game_record.dart';
import '../stats/statistics.dart';
import '../widgets/board_check.dart';
import '../widgets/player_picker.dart';
import '../widgets/winner_dialog.dart';
import 'my_darts_screen.dart';
import 'game_layout.dart';
import 'game_flow.dart';
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

  /// The kept line-up of Cricket games
  static const lineUpKey = 'cricket';

  static Widget setup(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlayersSetupScreen(
      title: l10n.cricketSetup,
      game: lineUpKey,
      rules: l10n.cricketRules,
      options: [(l10n.cutThroat, false)],
      start: (names, bots, options) => CricketScreen(names: names, cutThroat: options.first, bots: bots),
    );
  }

  @override
  State<CricketScreen> createState() => _CricketScreenState();
}

class _CricketScreenState extends State<CricketScreen> with RecordsGame, BotTurns, HoldsVisits {
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
  DartGame get heldGame => _game;

  // A bot waits until the players have seen the visit before it.
  @override
  bool get waitsForTakeout => _takeout.isClosed(_game) || holding;

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
    final bot = isBotTurn;
    setState(() {
      _game.add(dart);
      holdEndedVisit(bot: bot);
    });
    if (!widget.watching) {
      final effect = gameEffect(dart, finished: _game.isFinished, visitEnded: _game.dartsInVisit == 0);
      dartFeedback(context, dart, effect: effect, calls: cricketCalls(_game), bot: bot);
    }
    final l10n = AppLocalizations.of(context);
    final marks = _game.currentVisit.fold(0, (sum, d) => sum + d.marks);
    // A bot's strong visit is routine for it, and not worth covering the next player's column.
    if (_game.currentVisit.length == 3 && marks >= 6 && !bot) _celebrations.show(l10n.celebrateMarks(marks));
    if (_game.isFinished) _showEnd();
  }

  /// The same game again with the next player first
  CricketScreen _rematch() {
    final next = LineUp(widget.names, bots: widget.bots, options: [widget.cutThroat]).rematch(CricketScreen.lineUpKey);
    return CricketScreen(names: next.players, cutThroat: widget.cutThroat, bots: next.bots);
  }

  /// The end of the game, after its last dart or a correction that ended it
  void _showEnd() {
    final l10n = AppLocalizations.of(context);
    if (_game.players.length > 1) {
      final players = _game.players;
      // The winner first, then by points (fewest first in cut-throat) and by marks
      final lines = rankedLines([
        for (var i = 0; i < players.length; ++i)
          (
            ResultLine(
              players[i].name,
              value: '${players[i].points}',
              figures: '${l10n.marksPerRoundShort} ${decimal(l10n, players[i].marksPerRound, digits: 2)}',
            ),
            [
              i == _game.winner ? 0 : 1,
              widget.cutThroat ? players[i].points : -players[i].points,
              -players[i].totalMarks,
            ],
          ),
      ]);
      showWinnerDialog(
        context,
        winner: players[_game.winner!].name,
        record: currentRecord,
        result: widget.cutThroat ? l10n.cutThroatLowestWins : l10n.resultPoints(players[_game.winner!].points),
        lines: lines,
        onUndo: () => setState(_game.undo),
        newGame: CricketScreen.setup,
        rematch: widget.watching ? null : (_) => _rematch(),
        readyForRematch: () => confirmBoardEmpty(context),
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
      again: (_) => _rematch(),
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
    final waiting = _takeout.isClosed(_game) || holding;
    final atOche = _game.isFinished
        ? null
        : waiting
        ? (_game.current + _game.players.length - 1) % _game.players.length
        : _game.current;
    final shown = waiting || _game.isFinished || _game.dartsInVisit > 0 ? _game.currentVisit : const <CricketDart>[];
    final players = _game.players;

    // The column at the oche in the display style: on the scoreboard its name and points as a bright block over a faint
    // column, so the marks are not read on yellow; in the clear style a tint
    final display = DisplayScope.of(context);
    final window = WindowClass.of(context);
    final scoreboard = display.styleFor(window) == DisplayStyle.scoreboard;
    final far = display.farFor(window);
    final palette = AppPalette.of(context);
    final statistics = StatisticsScope.maybeOf(context);
    final activeFill = scoreboard
        ? palette.highlight.withValues(alpha: 0.14)
        : theme.colorScheme.primary.withValues(alpha: 0.18);
    final labelWidth = far ? 96.0 : 60.0;
    final divider = BorderSide(color: theme.dividerColor);
    // Who leads on points: the most, or in cut-throat the fewest; nobody while all are level
    final points = [for (final p in players) p.points];
    final bestPoints = widget.cutThroat ? points.reduce(math.min) : points.reduce(math.max);
    final leads = [for (final p in points) players.length > 1 && points.toSet().length > 1 && p == bestPoints];

    Widget cell(int i, Widget child, {bool head = false}) => Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: i == atOche ? (head && scoreboard ? palette.highlight : activeFill) : null,
          border: Border(left: divider),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
    Color? onCell(int i) => i == atOche && scoreboard ? palette.onHighlight : null;

    // In a tight panel, such as a phone on its side, the points sit beside the name, so the numbers keep their rows.
    TextStyle? pointsStyle(bool short) => scoreStyle(
      far
          ? theme.textTheme.displayMedium
          : short
          ? theme.textTheme.titleLarge
          : theme.textTheme.headlineMedium,
    )?.copyWith(fontWeight: FontWeight.w800, height: 1.1);

    Widget header(bool short, bool tight, double width) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: labelWidth),
          for (var i = 0; i < players.length; ++i)
            cell(
              i,
              head: true,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Flex(
                  direction: tight ? Axis.horizontal : Axis.vertical,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // One line, never broken inside a word; in a narrow column the player's colour is a bar under
                    // the name, so the dot leaves the name its room.
                    Flexible(
                      fit: FlexFit.loose,
                      flex: tight ? 1 : 0,
                      child: Builder(
                        builder: (context) {
                          final colour = statistics?.colourOf(players[i].name);
                          final narrow = (width - labelWidth) / players.length < 88;
                          // A bot goes by its level beside its icon: "Stark" for "Bot · Stark"
                          final bot = widget.bots.containsKey(i);
                          final label = bot ? botShortName(l10n, players[i].name) : players[i].name;
                          final style = (far ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)?.copyWith(
                            fontWeight: i == atOche ? FontWeight.w800 : FontWeight.w600,
                            color: onCell(i),
                          );
                          final iconSize = far ? 20.0 : 14.0;
                          // The column less its padding, the icon or dot before the name and, in a low panel, the
                          // points beside it
                          final room =
                              (width - labelWidth) / players.length -
                              8 -
                              (bot ? iconSize : (!narrow && colour != null ? 18 : 0)) -
                              (tight ? 8 + _textWidth(context, '${players[i].points}', pointsStyle(short)) : 0);
                          // Shrunk a little to the column before it is cut short, never to a size the oche cannot
                          // read; a bot too long for that goes by its level number, which always fits.
                          final Widget name = room >= _textWidth(context, label, style) * 0.85
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(label, maxLines: 1, softWrap: false, style: style),
                                )
                              : Text(
                                  bot ? '${widget.bots[i]}' : label,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: style,
                                );
                          final botIcon = Icon(Icons.smart_toy_outlined, size: iconSize, color: onCell(i));
                          if (narrow) {
                            return Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (bot) botIcon,
                                    Flexible(child: name),
                                  ],
                                ),
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
                              if (bot)
                                botIcon
                              else if (colour != null) ...[
                                PlayerDot(colour, ring: onCell(i)),
                                const SizedBox(width: 6),
                              ],
                              Flexible(child: name),
                            ],
                          );
                        },
                      ),
                    ),
                    if (tight) const SizedBox(width: 8),
                    Builder(
                      builder: (context) {
                        // Beside the name in a low panel there is no room for the cup: the leader's points take
                        // the highlight colour instead.
                        final style = pointsStyle(short)
                            ?.copyWith(color: onCell(i) ?? (tight && leads[i] ? palette.highlight : null));
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // The leader on points, which in cut-throat is the lowest figure
                              if (leads[i] && !tight)
                                Icon(
                                  Icons.emoji_events,
                                  key: ValueKey('leader-${players[i].name}'),
                                  size: (style?.fontSize ?? 24) * 0.6,
                                  color: onCell(i) ?? palette.highlight,
                                ),
                              Text('${players[i].points}', key: ValueKey('points-${players[i].name}'), style: style),
                            ],
                          ),
                        );
                      },
                    ),
                    if (!short && !tight)
                      Text(
                        '${l10n.marksPerRoundShort} ${decimal(l10n, players[i].marksPerRound, digits: 2)}',
                        key: ValueKey('mpr-${players[i].name}'),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: GameText.of(context).detail
                            ?.copyWith(color: onCell(i) ?? theme.colorScheme.onSurfaceVariant),
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
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final footer = [
      VisitDarts([for (final d in shown) d.dart.score.text(l10n)], darts: [for (final d in shown) d.dart]),
      const SizedBox(height: 8),
      GameUndoButton(onPressed: _game.canUndo && !widget.watching ? () => setState(_game.undo) : null),
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
            // Cut-throat turns the meaning of the points round, which those who join later must see; where the panel
            // is too low for the line, the title and the leader's cup say it.
            if (widget.cutThroat && !tight)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l10n.cutThroatLowestWins,
                  key: const ValueKey('cut-throat-note'),
                  textAlign: TextAlign.center,
                  style: (far ? theme.textTheme.titleLarge : theme.textTheme.labelLarge)?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
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
      title: widget.cutThroat ? l10n.modeCricketCutThroat : l10n.modeCricket,
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

/// The width of [text] on one line in [style], as this screen's text scale draws it
double _textWidth(BuildContext context, String text, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
