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
import '../widgets/winner_dialog.dart';
import 'game_layout.dart';
import 'game_scaffold.dart';
import 'my_darts_screen.dart';
import 'players_setup_screen.dart';
import '../widgets/precision_text.dart';
import '../widgets/player_row.dart';
import '../widgets/celebration.dart';
import '../widgets/game_result.dart';
import '../widgets/players_panel.dart';
import '../stats/personal_best.dart';
import '../display.dart';
import '../theme.dart';

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

class _RoundGameScreenState extends State<RoundGameScreen> with RecordsGame, BotTurns {
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
  bool get waitsForTakeout => _takeout.isClosed(_game);

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
    setState(() => _game.add(dart));
    if (!widget.watching) {
      final effect = gameEffect(dart, finished: _game.isFinished, visitEnded: _game.dartsInVisit == 0);
      final calls = roundCalls(_game, player: player, scoreBefore: scoreBefore);
      dartFeedback(context, dart, effect: effect, calls: calls, bot: bot);
    }
    final l10n = AppLocalizations.of(context);
    if (_game.wonAtOnce) {
      _celebrations.show(l10n.celebrateShanghai);
    } else if (_game.currentVisit.length == 3 && _game.currentVisit.every((d) => d.$2)) {
      _celebrations.show(l10n.celebrateThreeHits);
    }
    if (_game.isFinished) _showEnd();
  }

  /// The end of the game, after its last dart or a correction that ended it
  void _showEnd() {
    final l10n = AppLocalizations.of(context);
    if (_game.players.length == 1) {
      _showSoloResult(l10n);
    } else if (_game.winner == null) {
      final leaders = _game.leaders;
      showGameResult(
        context,
        title: l10n.gameDraw,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.drawBetween(
                [for (final i in leaders) _game.players[i].name].join(', '),
                _game.players[leaders.first].score,
              ),
              key: const ValueKey('draw'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            GameSummary(record: currentRecord),
          ],
        ),
        onUndo: () => setState(_game.undo),
        newGame: RoundGameScreen.setup(widget.mode),
      );
    } else {
      showWinnerDialog(
        context,
        winner: _game.players[_game.winner!].name,
        record: currentRecord,
        onUndo: () => setState(_game.undo),
        newGame: RoundGameScreen.setup(widget.mode),
      );
    }
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
    final waiting = _takeout.isClosed(_game);
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
        RoundTargetTile(
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

/// The round's target as the panel's headline, with the round below it: what every player in the round aims at
class RoundTargetTile extends StatelessWidget {
  const RoundTargetTile({super.key, required this.target, required this.round});

  final String target;
  final String round;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = DisplayScope.of(context);
    final window = WindowClass.of(context);
    final far = display.farFor(window);
    // A phone on its side has no height to spare.
    final short = MediaQuery.sizeOf(context).height < 500;
    final targetStyle = scoreStyle(
      far
          ? theme.textTheme.displayLarge
          : short
          ? theme.textTheme.headlineMedium
          : theme.textTheme.displayMedium,
    )?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary, height: 1.0);
    // From afar the target grows with the panel, as the score of the player at the oche does.
    return LayoutBuilder(
      builder: (context, constraints) => _tile(
        context,
        far ? targetStyle?.copyWith(fontSize: (constraints.maxWidth * 0.14).clamp(57, 120).toDouble()) : targetStyle,
        far: far,
        short: short,
      ),
    );
  }

  Widget _tile(BuildContext context, TextStyle? targetStyle, {required bool far, required bool short}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: short ? 8 : 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary, width: 2),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.roundTarget.toUpperCase(), style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 1.2)),
              Text(
                round,
                key: const ValueKey('round'),
                style: far ? theme.textTheme.titleLarge : theme.textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(target, key: const ValueKey('round-target'), style: targetStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
