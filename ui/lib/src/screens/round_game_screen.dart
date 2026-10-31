import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/score_text.dart';
import '../board/dart_throw.dart';
import '../bots/bot_turns.dart';
import '../games/dart_game.dart';
import '../games/round_games.dart';
import '../input/takeout_gate.dart';
import '../sound/effects.dart';
import '../sound/sfx.dart';
import '../sound/game_calls.dart';
import '../stats/game_record.dart';
import '../stats/statistics.dart';
import '../widgets/board_check.dart';
import '../widgets/winner_dialog.dart';
import 'game_layout.dart';
import 'game_flow.dart';
import 'game_scaffold.dart';
import 'my_darts_screen.dart';
import 'players_setup_screen.dart';
import '../widgets/precision_text.dart';
import '../widgets/player_row.dart';
import '../widgets/celebration.dart';
import '../widgets/game_result.dart';
import '../widgets/players_panel.dart';
import '../stats/personal_best.dart';
import '../widgets/target_tile.dart';

/// Shanghai, Bob's 27 and Halve-It (#118): a round's target, every player's score, and the darts of the visit.
class RoundGameScreen extends StatefulWidget {
  const RoundGameScreen({
    super.key,
    required this.mode,
    required this.names,
    this.settings = const {},
    this.bots = const {},
    this.replay = const [],
    this.watching = false,
  });

  final GameMode mode;
  final List<String> names;

  /// Shanghai: the number of rounds
  final Map<String, Object?> settings;

  /// Bot level per player index; the others are people
  final Map<int, int> bots;

  /// Darts already thrown, for a game rebuilt from a shared record
  final List<DartThrow> replay;

  /// Only shows another app's game: no input, nothing kept or shared (#116)
  final bool watching;

  static String title(AppLocalizations l10n, GameMode mode) => switch (mode) {
    GameMode.bobs27 => l10n.modeBobs27,
    GameMode.halveIt => l10n.modeHalveIt,
    _ => l10n.modeShanghai,
  };

  /// The setup of [mode]: the players, and for Shanghai whether all 20 numbers are played
  static String rules(AppLocalizations l10n, GameMode mode) => switch (mode) {
    GameMode.bobs27 => l10n.bobs27Rules,
    GameMode.halveIt => l10n.halveItRules,
    _ => l10n.shanghaiRules,
  };

  static WidgetBuilder setup(GameMode mode) => (context) {
    final l10n = AppLocalizations.of(context);
    return PlayersSetupScreen(
      title: title(l10n, mode),
      game: mode.name,
      rules: rules(l10n, mode),
      options: [if (mode == GameMode.shanghai) (l10n.shanghaiAllNumbers, false)],
      start: (names, bots, options) => RoundGameScreen(
        mode: mode,
        names: names,
        bots: bots,
        settings: {if (mode == GameMode.shanghai) 'rounds': options.first ? 20 : 7},
      ),
    );
  };

  @override
  State<RoundGameScreen> createState() => _RoundGameScreenState();
}

class _RoundGameScreenState extends State<RoundGameScreen> with RecordsGame, BotTurns, HoldsVisits {
  @override
  bool get watching => widget.watching;

  late final RoundGame _game = replayed(
    GameRecord(
      id: '',
      mode: widget.mode,
      started: DateTime(0),
      ended: DateTime(0),
      players: widget.names,
      settings: widget.settings,
      throws: const [],
    ).roundGame,
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
    mode: widget.mode,
    started: started,
    ended: ended,
    players: widget.names,
    settings: widget.settings,
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
    final player = _game.current;
    final scoreBefore = _game.players[player].score;
    final bot = isBotTurn;
    setState(() {
      _game.add(dart);
      holdEndedVisit(bot: bot);
    });
    if (!widget.watching) {
      final effect = gameEffect(dart, finished: _game.isFinished, visitEnded: _game.dartsInVisit == 0);
      final calls = roundCalls(_game, player: player, scoreBefore: scoreBefore);
      dartFeedback(context, dart, effect: effect, calls: calls, bot: bot);
    }
    final l10n = AppLocalizations.of(context);
    if (_game.wonAtOnce) {
      _celebrations.show(l10n.celebrateShanghai);
    } else if (_game.currentVisit.length == 3 && _game.currentVisit.every((d) => d.$2) && !bot) {
      // Three of three is routine for a bot, and not worth covering the next player's row.
      _celebrations.show(l10n.celebrateThreeHits);
    }
    if (_game.isFinished) _showEnd();
  }

  /// The same game again with the next player first
  RoundGameScreen _rematch() {
    final next = LineUp(
      widget.names,
      bots: widget.bots,
      options: [if (widget.mode == GameMode.shanghai) widget.settings['rounds'] == 20],
    ).rematch(widget.mode.name);
    return RoundGameScreen(mode: widget.mode, names: next.players, bots: next.bots, settings: widget.settings);
  }

  /// The end of the game, after its last dart or a correction that ended it
  void _showEnd() {
    final l10n = AppLocalizations.of(context);
    if (_game.players.length == 1) {
      _showSoloResult(l10n);
      return;
    }
    final players = _game.players;
    final leaders = _game.leaders;
    final winner = _game.winner;
    // A win at once first, then by points, those who went out after those who did not
    final lines = rankedLines([
      for (var i = 0; i < players.length; ++i)
        (
          ResultLine(
            players[i].name,
            value: '${players[i].score}',
            figures: players[i].out ? l10n.playerOut : percentText(l10n, players[i].hitRate),
          ),
          [i == winner ? 0 : 1, players[i].out ? 1 : 0, -players[i].score],
        ),
    ]);
    showWinnerDialog(
      context,
      winner: winner == null ? null : players[winner].name,
      tied: winner == null ? [for (final i in leaders) players[i].name] : const [],
      record: currentRecord,
      result: winner == null
          ? l10n.drawBetween([for (final i in leaders) players[i].name].join(', '), players[leaders.first].score)
          : _game.wonAtOnce
          ? l10n.celebrateShanghai
          : l10n.resultPoints(players[winner].score),
      lines: lines,
      onUndo: () => setState(_game.undo),
      newGame: RoundGameScreen.setup(widget.mode),
      rematch: widget.watching ? null : (_) => _rematch(),
      readyForRematch: () => confirmBoardEmpty(context),
    );
  }

  /// A game played alone ends on its score and how that stands against the player's best, not on a win
  void _showSoloResult(AppLocalizations l10n) {
    final player = _game.players.single;
    final record = currentRecord;
    final history = StatisticsScope.read(context)?.statsOf(player.name).history ?? const [];
    final best = personalBest(history, record);
    showGameResult(
      context,
      title: l10n.gameOver,
      content: SoloResult(
        headline: player.out
            ? l10n.resultBelowZero(_targetText(l10n, _game.targets[_game.visitRound]))
            : l10n.resultPoints(player.score),
        details: [
          l10n.statsDartsCount(player.dartsThrown),
          l10n.labelValue(l10n.hitRate, percentText(l10n, player.hitRate)),
        ].join(' · '),
        value: player.score.toDouble(),
        best: best,
        bestText: best == null ? null : l10n.resultPoints(best.round()),
      ),
      onUndo: () => setState(_game.undo),
      newGame: RoundGameScreen.setup(widget.mode),
      again: (_) => _rematch(),
    );
  }

  String _targetText(AppLocalizations l10n, RoundTarget target) => switch (target.label) {
    'D' => l10n.targetAnyDouble,
    'T' => l10n.targetAnyTriple,
    _ => target.label,
  };

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.watching) return;
      scheduleBotTurn();
      shareGame();
      if (mounted && !_game.isFinished) useDartsOf(context, _game.players[_game.current].name);
    });
    final l10n = AppLocalizations.of(context);
    // While its darts are in the board, the visit that ended stays on the scoreboard with its player, round and target;
    // a new visit starts with no darts.
    final waiting = _takeout.isClosed(_game) || holding;
    final atOche = _game.isFinished
        ? null
        : waiting
        ? _game.visitPlayer
        : _game.current;
    final round = waiting || _game.isFinished ? _game.visitRound : _game.round;
    final shown = waiting || _game.isFinished || _game.dartsInVisit > 0
        ? _game.currentVisit
        : const <(DartThrow, bool)>[];
    final visit = [for (final (dart, _) in shown) dart];
    final panel = PlayersPanel(
      header: [
        TargetTile(
          target: _targetText(l10n, _game.targets[round.clamp(0, _game.targets.length - 1)]),
          round: l10n.roundOf((round + 1).clamp(1, _game.targets.length), _game.targets.length),
        ),
        const SizedBox(height: 12),
      ],
      active: atOche,
      players: [
        for (var i = 0; i < _game.players.length; ++i)
          PlayerRow(
            name: _game.players[i].name,
            active: i == atOche,
            enabled: !_game.players[i].out,
            details: [
              l10n.statsDartsCount(_game.players[i].dartsThrown),
              l10n.labelValue(l10n.hitRate, percentText(l10n, _game.players[i].hitRate)),
              if (_game.players[i].out) l10n.playerOut,
            ].join(' · '),
            value: '${_game.players[i].score}',
            valueKey: ValueKey('score-${_game.players[i].name}'),
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
      title: RoundGameScreen.title(l10n, widget.mode),
      game: _game,
      takeout: _takeout,
      shownThrows: visit,
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
