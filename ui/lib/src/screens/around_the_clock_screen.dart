import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/score_text.dart';
import '../board/dart_throw.dart';
import '../games/around_the_clock.dart';
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

  static Widget setup(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlayersSetupScreen(
      title: l10n.aroundTheClockSetup,
      rules: l10n.aroundTheClockRules,
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
    if (!widget.watching) CallerScope.read(context).call(aroundTheClockCalls(_game), callLanguage);
    final l10n = AppLocalizations.of(context);
    if (_game.currentVisit.length == 3 && _game.currentVisit.every((d) => d.$2)) {
      _celebrations.show(l10n.celebrateThreeHits);
    }
    if (!_game.isFinished) return;
    if (_game.players.length > 1) {
      showWinnerDialog(
        context,
        winner: _game.players[_game.winner!].name,
        record: currentRecord,
        onUndo: () => setState(_game.undo),
        newGame: AroundTheClockScreen.setup,
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
    final waiting = _takeout.isClosed(_game);
    final atOche = _game.isFinished
        ? null
        : waiting
        ? (_game.current + _game.players.length - 1) % _game.players.length
        : _game.current;
    final shown = waiting || _game.isFinished || _game.dartsInVisit > 0
        ? _game.currentVisit
        : const <(DartThrow, bool)>[];
    final panel = PlayersPanel(
      active: atOche,
      players: [
        for (var i = 0; i < _game.players.length; ++i)
          PlayerRow(
            name: _game.players[i].name,
            active: i == atOche,
            details:
                '${l10n.statsDartsCount(_game.players[i].dartsThrown)} · '
                '${l10n.labelValue(l10n.hitRate, percentText(l10n, _game.players[i].hitRate))}',
            value: _game.targetLabel(_game.players[i].position.clamp(0, _game.targetCount - 1)),
            valueKey: ValueKey('target-${_game.players[i].name}'),
          ),
      ],
      footer: [
        VisitDarts([for (final (dart, _) in shown) dart.score.text(l10n)], hits: [for (final (_, hit) in shown) hit]),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _game.canUndo && !widget.watching ? () => setState(_game.undo) : null,
          icon: const Icon(Icons.undo),
          label: Text(l10n.undo),
        ),
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
      panel: panel,
      celebrations: _celebrations,
    );
  }
}
