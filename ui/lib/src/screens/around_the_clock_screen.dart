import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/score_text.dart';
import '../board/dart_throw.dart';
import '../games/around_the_clock.dart';
import '../bots/bot_turns.dart';
import '../games/dart_game.dart';
import '../input/takeout_gate.dart';
import '../sound/effects.dart';
import '../sound/sfx.dart';
import '../sound/game_calls.dart';
import '../stats/game_record.dart';
import '../stats/statistics.dart';
import '../widgets/board_check.dart';
import '../widgets/target_tile.dart';
import '../widgets/winner_dialog.dart';
import 'my_darts_screen.dart';
import 'game_layout.dart';
import 'game_flow.dart';
import 'game_scaffold.dart';
import 'players_setup_screen.dart';
import '../widgets/precision_text.dart';
import '../widgets/player_row.dart';
import '../widgets/celebration.dart';
import '../widgets/game_result.dart';
import '../widgets/players_panel.dart';
import '../stats/personal_best.dart';

class AroundTheClockScreen extends StatefulWidget {
  const AroundTheClockScreen({
    super.key,
    required this.names,
    this.endWithBull = true,
    this.bots = const {},
    this.replay = const [],
    this.watching = false,
  });

  final List<String> names;
  final bool endWithBull;

  /// Bot level per player index; the others are people
  final Map<int, int> bots;

  /// Darts already thrown, for a game rebuilt from a shared record
  final List<DartThrow> replay;

  /// Only shows another app's game: no input, nothing kept or shared (#116)
  final bool watching;

  /// The kept line-up of Around the Clock games
  static const lineUpKey = 'around_the_clock';

  static Widget setup(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlayersSetupScreen(
      title: l10n.aroundTheClockSetup,
      game: lineUpKey,
      rules: l10n.aroundTheClockRules,
      options: [(l10n.endWithBull, true)],
      start: (names, bots, options) => AroundTheClockScreen(names: names, endWithBull: options[0], bots: bots),
    );
  }

  @override
  State<AroundTheClockScreen> createState() => _AroundTheClockScreenState();
}

class _AroundTheClockScreenState extends State<AroundTheClockScreen> with RecordsGame, BotTurns, HoldsVisits {
  @override
  bool get watching => widget.watching;

  late final AroundTheClockGame _game = replayed(
    AroundTheClockGame(widget.names, endWithBull: widget.endWithBull),
    widget.replay,
  );
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
    mode: GameMode.aroundTheClock,
    started: started,
    ended: ended,
    players: widget.names,
    settings: {'end_with_bull': widget.endWithBull},
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
      dartFeedback(context, dart, effect: effect, calls: aroundTheClockCalls(_game), bot: bot);
    }
    final l10n = AppLocalizations.of(context);
    // Three of three is routine for a bot, and not worth covering the next player's row.
    if (_game.currentVisit.length == 3 && _game.currentVisit.every((d) => d.$2) && !bot) {
      _celebrations.show(l10n.celebrateThreeHits);
    }
    if (_game.isFinished) _showEnd();
  }

  /// The same game again with the next player first
  AroundTheClockScreen _rematch() {
    final next = LineUp(
      widget.names,
      bots: widget.bots,
      options: [widget.endWithBull],
    ).rematch(AroundTheClockScreen.lineUpKey);
    return AroundTheClockScreen(names: next.players, endWithBull: widget.endWithBull, bots: next.bots);
  }

  /// The end of the game, after its last dart or a correction that ended it
  void _showEnd() {
    final l10n = AppLocalizations.of(context);
    if (_game.players.length > 1) {
      final players = _game.players;
      final winner = players[_game.winner!];
      showWinnerDialog(
        context,
        winner: winner.name,
        record: currentRecord,
        result: l10n.resultRoundTheClock(winner.dartsThrown),
        // The winner first, then by how far round each got, and the fewer darts for it
        lines: rankedLines([
          for (var i = 0; i < players.length; ++i)
            (
              ResultLine(
                players[i].name,
                value: '${players[i].position}/${_game.targetCount}',
                figures: percentText(l10n, players[i].hitRate),
              ),
              [i == _game.winner ? 0 : 1, -players[i].position, players[i].dartsThrown],
            ),
        ]),
        onUndo: () => setState(_game.undo),
        newGame: AroundTheClockScreen.setup,
        rematch: widget.watching ? null : (_) => _rematch(),
        readyForRematch: () => confirmBoardEmpty(context),
      );
      return;
    }
    // Alone there is nobody to beat: the game ends on the darts it took and the hit rate against the best so far.
    final player = _game.players.single;
    final history = StatisticsScope.read(context)?.statsOf(player.name).history ?? const [];
    final best = personalBest(history, currentRecord);
    showGameResult(
      context,
      title: l10n.gameOver,
      content: SoloResult(
        headline: l10n.resultRoundTheClock(player.dartsThrown),
        details: l10n.labelValue(l10n.hitRate, percentText(l10n, player.hitRate)),
        value: player.hitRate,
        best: best,
        bestText: best == null ? null : l10n.labelValue(l10n.hitRate, percentText(l10n, best)),
      ),
      onUndo: () => setState(_game.undo),
      newGame: AroundTheClockScreen.setup,
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
    // While its darts are in the board, the visit that ended stays on the scoreboard with its player; a new visit
    // starts with no darts.
    final waiting = _takeout.isClosed(_game) || holding;
    final atOche = _game.isFinished
        ? null
        : waiting
        ? (_game.current + _game.players.length - 1) % _game.players.length
        : _game.current;
    final shown = waiting || _game.isFinished || _game.dartsInVisit > 0
        ? _game.currentVisit
        : const <(DartThrow, bool)>[];
    String target(int i) => _game.targetLabel(_game.players[i].position.clamp(0, _game.targetCount - 1));
    final tile = atOche != null && readFromAfar(context);
    final panel = PlayersPanel(
      // The target of the player at the oche as a target, and every row's number marked as one, not read as points
      header: [
        // From afar there is room to show it as the panel's headline as well.
        if (tile) ...[
          TargetTile(
            target: target(atOche),
            round:
                '${_game.players[atOche].name} · '
                '${l10n.countOf(_game.players[atOche].position, _game.targetCount)}',
          ),
          const SizedBox(height: 12),
        ],
      ],
      active: atOche,
      players: [
        for (var i = 0; i < _game.players.length; ++i)
          PlayerRow(
            name: _game.players[i].name,
            active: i == atOche,
            details:
                '${l10n.statsDartsCount(_game.players[i].dartsThrown)} · '
                '${l10n.labelValue(l10n.hitRate, percentText(l10n, _game.players[i].hitRate))}',
            value: target(i),
            valueLabel: l10n.roundTarget,
            valueKey: ValueKey('target-${_game.players[i].name}'),
            // With the tile the target is shown large once, not twice
            heroValue: !tile,
          ),
      ],
      footer: [
        VisitDarts(
          [for (final (dart, _) in shown) dart.score.text(l10n)],
          hits: [for (final (_, hit) in shown) hit],
          darts: [for (final (dart, _) in shown) dart],
        ),
        const SizedBox(height: 8),
        GameUndoButton(onPressed: _game.canUndo && !widget.watching ? () => setState(_game.undo) : null),
      ],
    );
    return GameScaffold(
      title: l10n.modeAroundTheClock,
      game: _game,
      takeout: _takeout,
      shownThrows: [for (final (dart, _) in shown) dart],
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
      celebrations: _celebrations,
    );
  }
}
