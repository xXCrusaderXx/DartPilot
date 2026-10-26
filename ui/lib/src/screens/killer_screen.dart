import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../bots/bot_turns.dart';
import '../games/dart_game.dart';
import '../games/killer.dart';
import '../input/takeout_gate.dart';
import '../sound/caller.dart';
import '../sound/game_calls.dart';
import '../sound/x01_calls.dart';
import '../stats/game_record.dart';
import '../stats/statistics.dart';
import '../widgets/winner_dialog.dart';
import 'game_layout.dart';
import 'game_scaffold.dart';
import 'my_darts_screen.dart';
import 'players_setup_screen.dart';
import '../board/score_text.dart';
import '../widgets/player_row.dart';

/// Killer (#118): every player's number, marks on the way to killer, and lives.
class KillerScreen extends StatefulWidget {
  const KillerScreen({
    super.key,
    required this.names,
    required this.numbers,
    this.bots = const {},
    this.replay = const [],
    this.watching = false,
  });

  final List<String> names;

  /// Each player's number, in the order of [names]
  final List<int> numbers;

  /// Bot level per player index; the others are people
  final Map<int, int> bots;

  /// Darts already thrown, for a game rebuilt from a shared record
  final List<DartThrow> replay;

  /// Only shows another app's game: no input, nothing kept or shared (#116)
  final bool watching;

  static Widget setup(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlayersSetupScreen(
      title: l10n.modeKiller,
      minPlayers: 2,
      start: (names, bots, _) =>
          KillerScreen(names: names, numbers: killerNumbers(math.Random().nextInt(1 << 31), names.length), bots: bots),
    );
  }

  @override
  State<KillerScreen> createState() => _KillerScreenState();
}

class _KillerScreenState extends State<KillerScreen> with RecordsGame, BotTurns {
  @override
  bool get watching => widget.watching;

  late final KillerGame _game = replayed(KillerGame(widget.names, widget.numbers), widget.replay);
  final TakeoutGate _takeout = TakeoutGate();

  @override
  bool get waitsForTakeout => _takeout.isClosed(_game);

  @override
  GameRecord buildRecord(String id, DateTime started, DateTime ended) => GameRecord(
    id: id,
    mode: GameMode.killer,
    started: started,
    ended: ended,
    players: widget.names,
    settings: {'numbers': widget.numbers, 'lives': _game.lives},
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
    final livesBefore = [for (final p in _game.players) p.lives];
    final killersBefore = [for (final p in _game.players) p.isKiller];
    setState(() => _game.add(dart));
    if (!widget.watching) {
      CallerScope.read(context)
          .call(killerCalls(_game, livesBefore: livesBefore, killersBefore: killersBefore), callLanguage);
    }
    if (!_game.isFinished) return;
    showWinnerDialog(
      context,
      winner: _game.players[_game.winner!].name,
      record: currentRecord,
      onUndo: () => setState(_game.undo),
      newGame: KillerScreen.setup,
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
    final atOche = !_game.isFinished;
    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              for (var i = 0; i < _game.players.length; ++i)
                Builder(
                  builder: (context) {
                    final p = _game.players[i];
                    final current = atOche && i == _game.current;
                    return PlayerRow(
                      name: p.name,
                      active: current,
                      enabled: !p.out,
                      leading: CircleAvatar(child: Text('${p.number}')),
                      details: p.out
                          ? l10n.playerOut
                          : p.isKiller
                          ? l10n.killerIsKiller
                          : l10n.killerMarks(p.marks, KillerGame.marksToKill, 'D${p.number}'),
                      detailsKey: ValueKey('killer-state-${p.name}'),
                      detailsFromAfar: true,
                      value: '♥' * p.lives.clamp(0, _game.lives),
                      valueKey: ValueKey('lives-${p.name}'),
                      valueColour: theme.colorScheme.error,
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        VisitDarts([for (final dart in _game.currentVisit) dart.score.text(l10n)]),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _game.canUndo && !widget.watching ? () => setState(_game.undo) : null,
          icon: const Icon(Icons.undo),
          label: Text(l10n.undo),
        ),
      ],
    );
    return GameScaffold(
      title: l10n.modeKiller,
      game: _game,
      takeout: _takeout,
      shownThrows: _game.currentVisit,
      watching: widget.watching,
      onDart: (dart) {
        // While a bot is at the oche, its darts are its own.
        if (!isBotTurn) _add(dart);
      },
      onChanged: () => setState(() {}),
      panel: panel,
    );
  }
}
