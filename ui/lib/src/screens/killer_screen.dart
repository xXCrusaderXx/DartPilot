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
import '../widgets/celebration.dart';
import '../widgets/player_row.dart';
import '../widgets/players_panel.dart';

/// Killer (#118): every player's number, marks on the way to killer, and lives.
class KillerScreen extends StatefulWidget {
  const KillerScreen({
    super.key,
    required this.names,
    required this.numbers,
    this.lives = 3,
    this.bots = const {},
    this.replay = const [],
    this.watching = false,
  });

  final List<String> names;

  /// Each player's number, in the order of [names]
  final List<int> numbers;

  /// Lives each player starts with
  final int lives;

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
      rules: l10n.killerRules,
      minPlayers: 2,
      options: [(l10n.killerFiveLives, false)],
      start: (names, bots, options) => KillerScreen(
        names: names,
        numbers: killerNumbers(math.Random().nextInt(1 << 31), names.length),
        lives: options.first ? 5 : 3,
        bots: bots,
      ),
    );
  }

  @override
  State<KillerScreen> createState() => _KillerScreenState();
}

class _KillerScreenState extends State<KillerScreen> with RecordsGame, BotTurns {
  @override
  bool get watching => widget.watching;

  late final KillerGame _game = replayed(KillerGame(widget.names, widget.numbers, lives: widget.lives), widget.replay);
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
    final l10n = AppLocalizations.of(context);
    for (var i = 0; i < _game.players.length; ++i) {
      final p = _game.players[i];
      if (p.out && livesBefore[i] > 0 && !_game.isFinished) {
        _celebrations.show(l10n.celebrateOut(p.name));
      } else if (p.isKiller && !killersBefore[i]) {
        _celebrations.show(l10n.celebrateKiller(p.name));
      }
    }
    if (_game.isFinished) _showEnd();
  }

  /// The end of the game, after its last dart or a correction that ended it
  void _showEnd() {
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
    // While its darts are in the board, the visit that ended stays on the scoreboard with its player; a new visit
    // starts with no darts.
    final waiting = _takeout.isClosed(_game);
    final atOche = _game.isFinished
        ? null
        : waiting
        ? _game.visitPlayer
        : _game.current;
    final visit = waiting || _game.isFinished || _game.dartsInVisit > 0 ? _game.currentVisit : const <DartThrow>[];
    final panel = PlayersPanel(
      active: atOche,
      players: [
        for (var i = 0; i < _game.players.length; ++i)
          Builder(
            builder: (context) {
              final p = _game.players[i];
              return PlayerRow(
                name: p.name,
                active: i == atOche,
                enabled: !p.out,
                leading: CircleAvatar(child: Text('${p.number}')),
                details: p.out
                    ? l10n.playerOut
                    : p.isKiller
                    ? l10n.killerIsKiller
                    : l10n.killerMarks(p.marks, KillerGame.marksToKill, 'D${p.number}'),
                detailsKey: ValueKey('killer-state-${p.name}'),
                detailsFromAfar: true,
                value: l10n.killerLives(p.lives),
                valueKey: ValueKey('lives-${p.name}'),
                valueColour: theme.colorScheme.error,
                valueIcons: Lives(p.lives.clamp(0, _game.lives), of: _game.lives),
              );
            },
          ),
      ],
      footer: [
        VisitDarts([for (final dart in visit) dart.score.text(l10n)]),
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

/// A player's lives as hearts, the lost ones as outlines
class Lives extends StatelessWidget {
  const Lives(this.lives, {super.key, required this.of});

  final int lives;
  final int of;

  @override
  Widget build(BuildContext context) {
    final lost = IconTheme.of(context).color?.withValues(alpha: 0.35);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < of; ++i) i < lives ? const Icon(Icons.favorite) : Icon(Icons.favorite_border, color: lost),
      ],
    );
  }
}
