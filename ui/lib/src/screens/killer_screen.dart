import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../bots/bot_turns.dart';
import '../games/dart_game.dart';
import '../games/killer.dart';
import '../input/takeout_gate.dart';
import '../sound/effects.dart';
import '../sound/sfx.dart';
import '../sound/game_calls.dart';
import '../stats/game_record.dart';
import '../stats/statistics.dart';
import '../theme.dart';
import '../widgets/board_check.dart';
import '../widgets/precision_text.dart';
import '../widgets/target_tile.dart';
import '../widgets/winner_dialog.dart';
import 'game_layout.dart';
import 'game_flow.dart';
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

  /// The kept line-up of Killer games
  static const lineUpKey = 'killer';

  static Widget setup(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlayersSetupScreen(
      title: l10n.modeKiller,
      game: lineUpKey,
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

class _KillerScreenState extends State<KillerScreen> with RecordsGame, BotTurns, HoldsVisits {
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
  DartGame get heldGame => _game;

  // A bot waits until the players have seen the visit before it.
  @override
  bool get waitsForTakeout => _takeout.isClosed(_game) || holding;

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
    final bot = isBotTurn;
    setState(() {
      _game.add(dart);
      holdEndedVisit(bot: bot);
    });
    if (!widget.watching) {
      final effect = gameEffect(dart, finished: _game.isFinished, visitEnded: _game.dartsInVisit == 0);
      final calls = killerCalls(_game, livesBefore: livesBefore, killersBefore: killersBefore);
      dartFeedback(context, dart, effect: effect, calls: calls, bot: bot);
    }
    final l10n = AppLocalizations.of(context);
    for (var i = 0; i < _game.players.length; ++i) {
      final p = _game.players[i];
      // What a bot did is told in the small plate, clear of the row of the player who throws next.
      if (p.out && livesBefore[i] > 0 && !_game.isFinished) {
        _celebrations.show(l10n.celebrateOut(p.name), big: !bot);
      } else if (p.isKiller && !killersBefore[i]) {
        _celebrations.show(l10n.celebrateKiller(p.name), big: !bot);
      }
    }
    if (_game.isFinished) _showEnd();
  }

  /// The same game again with the next player first and new numbers
  KillerScreen _rematch() {
    final next = LineUp(widget.names, bots: widget.bots, options: [widget.lives == 5]).rematch(KillerScreen.lineUpKey);
    return KillerScreen(
      names: next.players,
      numbers: killerNumbers(math.Random().nextInt(1 << 31), next.players.length),
      lives: widget.lives,
      bots: next.bots,
    );
  }

  /// The end of the game, after its last dart or a correction that ended it
  void _showEnd() {
    final l10n = AppLocalizations.of(context);
    final players = _game.players;
    final winner = players[_game.winner!];
    // The winner first, then the players in the reverse order they went out
    int outAt(int i) => players[i].out ? _game.outOrder.indexOf(i) : players.length;
    showWinnerDialog(
      context,
      winner: winner.name,
      record: currentRecord,
      result: l10n.labelValue(l10n.statsLivesLeft, '${winner.lives}'),
      lines: rankedLines([
        for (var i = 0; i < players.length; ++i)
          (
            ResultLine(
              players[i].name,
              value: players[i].out ? null : '${players[i].lives}',
              figures: players[i].out ? l10n.playerOut : l10n.killerLives(players[i].lives),
            ),
            [i == _game.winner ? 0 : 1, -players[i].lives, -outAt(i)],
          ),
      ]),
      onUndo: () => setState(_game.undo),
      newGame: KillerScreen.setup,
      rematch: widget.watching ? null : (_) => _rematch(),
      readyForRematch: () => confirmBoardEmpty(context),
    );
  }

  /// The doubles the player at [i] throws at now: their own until they are a killer, then those of everyone still in
  String _targets(int i) {
    final p = _game.players[i];
    if (!p.isKiller) return 'D${p.number}';
    return [
      for (final o in _game.players)
        if (!identical(o, p) && !o.out) 'D${o.number}',
    ].join(' · ');
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
        ? _game.visitPlayer
        : _game.current;
    final visit = waiting || _game.isFinished || _game.dartsInVisit > 0 ? _game.currentVisit : const <DartThrow>[];
    final far = readFromAfar(context);
    final palette = AppPalette.of(context);
    final panel = PlayersPanel(
      // What matters at the oche is the double to throw at: the panel's largest figure, the lives beside the names
      header: [
        if (atOche != null) ...[
          TargetTile(
            key: const ValueKey('killer-target'),
            label: _game.players[atOche].isKiller ? l10n.killerIsKiller : l10n.roundTarget,
            target: _targets(atOche),
            round: _game.players[atOche].isKiller
                ? _game.players[atOche].name
                : '${_game.players[atOche].name} · '
                      '${l10n.countOf(_game.players[atOche].marks, KillerGame.marksToKill)}',
          ),
          const SizedBox(height: 12),
        ],
      ],
      active: atOche,
      players: [
        for (var i = 0; i < _game.players.length; ++i)
          Builder(
            builder: (context) {
              final p = _game.players[i];
              final size = far ? 52.0 : 40.0;
              return PlayerRow(
                name: p.name,
                active: i == atOche,
                enabled: !p.out,
                // The player's number as a badge, filled once they are a killer
                leading: Container(
                  key: ValueKey('killer-number-${p.name}'),
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.isKiller ? theme.colorScheme.error : theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(color: p.isKiller ? theme.colorScheme.error : palette.highlight, width: 2),
                  ),
                  child: Text(
                    '${p.number}',
                    style: scoreStyle(far ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: p.isKiller ? theme.colorScheme.onError : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                details: p.out
                    ? l10n.playerOut
                    : p.isKiller
                    ? l10n.killerIsKiller
                    : l10n.killerMarks(p.marks, KillerGame.marksToKill, 'D${p.number}'),
                detailsKey: ValueKey('killer-state-${p.name}'),
                detailsFromAfar: true,
                value: l10n.killerLives(p.lives),
                valueKey: ValueKey('lives-${p.name}'),
                valueIcons: Lives(p.lives.clamp(0, _game.lives), of: _game.lives),
                heroValue: false,
              );
            },
          ),
      ],
      footer: [
        VisitDarts([for (final dart in visit) dart.score.text(l10n)], darts: visit),
        const SizedBox(height: 8),
        GameUndoButton(onPressed: _game.canUndo && !widget.watching ? () => setState(_game.undo) : null),
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

/// A player's lives as compact pips, the lost ones as rings
class Lives extends StatelessWidget {
  const Lives(this.lives, {super.key, required this.of});

  final int lives;
  final int of;

  @override
  Widget build(BuildContext context) {
    final lost = IconTheme.of(context).color?.withValues(alpha: 0.35);
    final size = (IconTheme.of(context).size ?? 24) * 0.75;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < of; ++i)
          i < lives ? Icon(Icons.circle, size: size) : Icon(Icons.circle_outlined, color: lost, size: size),
      ],
    );
  }
}
