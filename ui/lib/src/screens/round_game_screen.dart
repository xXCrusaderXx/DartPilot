import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../bots/bot_turns.dart';
import '../games/dart_game.dart';
import '../games/round_games.dart';
import '../input/game_input.dart';
import '../input/takeout_gate.dart';
import '../sound/caller.dart';
import '../sound/game_calls.dart';
import '../sound/x01_calls.dart';
import '../stats/game_record.dart';
import '../stats/statistics.dart';
import '../widgets/winner_dialog.dart';
import 'game_layout.dart';
import 'my_darts_screen.dart';
import 'players_setup_screen.dart';
import 'watched_board.dart';
import '../widgets/precision_text.dart';

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
  static WidgetBuilder setup(GameMode mode) => (context) {
    final l10n = AppLocalizations.of(context);
    return PlayersSetupScreen(
      title: title(l10n, mode),
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
    setState(() => _game.add(dart));
    if (!widget.watching) {
      CallerScope.read(context).call(roundCalls(_game, player: player, scoreBefore: scoreBefore), callLanguage);
    }
    if (!_game.isFinished) return;
    showWinnerDialog(
      context,
      winner: _game.players[_game.winner!].name,
      record: currentRecord,
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
    final theme = Theme.of(context);
    final visit = [for (final (dart, _) in _game.currentVisit) dart];
    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.roundOf((_game.round + 1).clamp(1, _game.targets.length), _game.targets.length),
                key: const ValueKey('round'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              _targetText(l10n, _game.target),
              key: const ValueKey('round-target'),
              style: theme.textTheme.displaySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _game.players.length; ++i)
          Card(
            color: i == _game.current && !_game.isFinished ? theme.colorScheme.secondaryContainer : null,
            child: ListTile(
              leading: i == _game.current && !_game.isFinished ? const Icon(Icons.arrow_right) : null,
              title: Text(_game.players[i].name),
              subtitle: Text(
                [
                  '${_game.players[i].dartsThrown} ${l10n.darts}',
                  '${l10n.hitRate} ${percentText(l10n, _game.players[i].hitRate)}',
                  if (_game.players[i].out) l10n.playerOut,
                ].join(' · '),
              ),
              trailing: Text(
                '${_game.players[i].score}',
                key: ValueKey('score-${_game.players[i].name}'),
                style: theme.textTheme.headlineMedium,
              ),
            ),
          ),
        const SizedBox(height: 12),
        VisitDarts([for (final (dart, hit) in _game.currentVisit) '${dart.score.label} ${hit ? '✓' : '✗'}']),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _game.canUndo && !widget.watching ? () => setState(_game.undo) : null,
          icon: const Icon(Icons.undo),
          label: Text(l10n.undo),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: Text(RoundGameScreen.title(l10n, widget.mode))),
      body: GameLayout(
        input: widget.watching
            ? WatchedBoard(throws: visit)
            : GameInput(
                game: _game,
                takeout: _takeout,
                shownThrows: visit,
                onDart: (dart) {
                  // While a bot is at the oche, its darts are its own.
                  if (!isBotTurn) _add(dart);
                },
                onChanged: () => setState(() {}),
              ),
        panel: panel,
      ),
    );
  }
}
