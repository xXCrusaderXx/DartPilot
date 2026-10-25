import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../games/around_the_clock.dart';
import '../bots/bot_turns.dart';
import '../games/dart_game.dart';
import '../input/game_input.dart';
import '../input/takeout_gate.dart';
import '../stats/game_record.dart';
import '../stats/statistics.dart';
import '../widgets/winner_dialog.dart';
import 'my_darts_screen.dart';
import 'watched_board.dart';
import 'game_layout.dart';
import 'players_setup_screen.dart';

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

  static Widget setup(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlayersSetupScreen(
      title: l10n.aroundTheClockSetup,
      options: [(l10n.endWithBull, true)],
      start: (names, bots, options) => AroundTheClockScreen(names: names, endWithBull: options[0], bots: bots),
    );
  }

  @override
  State<AroundTheClockScreen> createState() => _AroundTheClockScreenState();
}

class _AroundTheClockScreenState extends State<AroundTheClockScreen> with RecordsGame, BotTurns {
  @override
  bool get watching => widget.watching;

  late final AroundTheClockGame _game = replayed(
    AroundTheClockGame(widget.names, endWithBull: widget.endWithBull),
    widget.replay,
  );
  final TakeoutGate _takeout = TakeoutGate();

  @override
  bool get waitsForTakeout => _takeout.isClosed(_game);

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
    setState(() => _game.add(dart));
    if (!_game.isFinished) return;
    showWinnerDialog(
      context,
      winner: _game.players[_game.winner!].name,
      record: currentRecord,
      onUndo: () => setState(_game.undo),
      newGame: AroundTheClockScreen.setup,
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
    // While its darts are in the board, the visit that ended stays on the scoreboard with its player.
    final atOche = _takeout.isClosed(_game)
        ? (_game.current + _game.players.length - 1) % _game.players.length
        : _game.current;
    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _game.players.length; ++i)
          Card(
            color: i == atOche ? theme.colorScheme.secondaryContainer : null,
            child: ListTile(
              leading: i == atOche ? const Icon(Icons.arrow_right) : null,
              title: Text(_game.players[i].name),
              subtitle: Text(
                '${_game.players[i].dartsThrown} ${l10n.darts} · '
                '${l10n.hitRate} ${(100 * _game.players[i].hitRate).toStringAsFixed(0)} %',
              ),
              trailing: Text(
                _game.targetLabel(_game.players[i].position.clamp(0, _game.targetCount - 1)),
                key: ValueKey('target-${_game.players[i].name}'),
                style: theme.textTheme.displaySmall,
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
      appBar: AppBar(title: Text(l10n.modeAroundTheClock)),
      body: GameLayout(
        input: widget.watching
            ? WatchedBoard(throws: [for (final (dart, _) in _game.currentVisit) dart])
            : GameInput(
                game: _game,
                takeout: _takeout,
                shownThrows: [for (final (dart, _) in _game.currentVisit) dart],
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
