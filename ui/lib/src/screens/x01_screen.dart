import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../games/x01.dart';
import '../sound/caller.dart';
import '../sound/game_calls.dart';
import '../sound/x01_calls.dart';
import '../bots/bot_turns.dart';
import '../games/dart_game.dart';
import '../input/takeout_gate.dart';
import '../stats/game_record.dart';
import '../stats/statistics.dart';
import '../widgets/board_check.dart';
import '../widgets/celebration.dart';
import '../widgets/precision_text.dart';
import '../widgets/winner_dialog.dart';
import 'my_darts_screen.dart';
import 'game_layout.dart';
import 'x01_panel.dart';
import '../display.dart';
import '../engine/engine_connection.dart';
import 'game_scaffold.dart';
import 'x01_setup_screen.dart';
import '../board/score_text.dart';

class X01Screen extends StatefulWidget {
  const X01Screen({
    super.key,
    required this.settings,
    this.bots = const {},
    this.replay = const [],
    this.watching = false,
  });

  final X01Settings settings;

  /// Bot level per player index; the others are people
  final Map<int, int> bots;

  /// Darts already thrown, for a game rebuilt from a shared record
  final List<DartThrow> replay;

  /// Only shows another app's game: no input, nothing kept or shared (#116)
  final bool watching;

  /// How long a visit that ended stays on the panel when no takeout holds it, unless the next dart comes first
  static const Duration holdTime = Duration(milliseconds: 1500);

  @override
  State<X01Screen> createState() => _X01ScreenState();
}

class _X01ScreenState extends State<X01Screen> with RecordsGame, BotTurns {
  @override
  bool get watching => widget.watching;

  late final X01Game _game = replayed(X01Game(widget.settings), widget.replay);
  final TakeoutGate _takeout = TakeoutGate();
  final Celebrations _celebrations = Celebrations();

  /// The visit that ended stays on show while the game has this many darts
  int? _heldAt;
  Timer? _holdTimer;
  Timer? _winnerTimer;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _winnerTimer?.cancel();
    _celebrations.dispose();
    super.dispose();
  }

  /// Whether the visit that just ended is still on show: an undo or the next dart ends that
  bool get _holding =>
      _heldAt == _game.throws.length &&
      !_game.isFinished &&
      _game.currentVisit.darts.isEmpty &&
      _game.visits.length > 1;

  void _hold() {
    _holdTimer?.cancel();
    _heldAt = _game.throws.length;
    _holdTimer = Timer(X01Screen.holdTime, () {
      if (mounted) setState(() => _heldAt = null);
    });
  }

  // A bot waits until the players have seen the visit before it.
  @override
  bool get waitsForTakeout => _takeout.isClosed(_game) || _holding;

  @override
  GameRecord buildRecord(String id, DateTime started, DateTime ended) => GameRecord(
    id: id,
    mode: GameMode.x01,
    started: started,
    ended: ended,
    players: widget.settings.players,
    settings: GameRecord.settingsOfX01(widget.settings),
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

  /// The leg and the winner: what a dart or a correction can change about the match
  (int, int?) get _outcome => (_game.legNumber, _game.winner);

  void _add(DartThrow dart) {
    if (_game.isFinished) return;
    final before = _outcome;
    final legBefore = _game.legNumber;
    final visitsBefore = _game.visits.length;
    // With an engine, the player's darts wait for their takeout instead; a bot's darts never go to the board.
    final holds = isBotTurn || !EngineScope.read(context).isConnected;
    setState(() {
      _game.add(dart);
      // The visit that ended stays on show for a moment, so its total or bust is seen before the next player's.
      if (holds && _game.visits.length > visitsBefore && !_game.isFinished) _hold();
    });
    if (!widget.watching) {
      CallerScope.read(context).call(x01Calls(_game, visitsBefore: visitsBefore, legBefore: legBefore), callLanguage);
    }
    if (_outcome != before) {
      _outcomeChanged(before);
    } else if (_game.visits.length > visitsBefore && _game.visits[_game.visits.length - 2].points == 180) {
      _celebrations.show('180');
    }
  }

  /// A leg or the match won, by a dart or by a correction: the checkout is celebrated, and the winner shown after it.
  /// A correction that takes a win back needs nothing more; the panel follows the game.
  void _outcomeChanged(Object? before) {
    final (legBefore, winnerBefore) = before as (int, int?);
    final won = _game.isFinished && winnerBefore == null;
    if (!won && _game.legNumber <= legBefore) return;
    final checkout = _game.visits.lastWhere((v) => v.isCheckout);
    final l10n = AppLocalizations.of(context);
    // A ton-plus finish gets the large plate, any other the small one.
    _celebrations.show(l10n.celebrateCheckout(checkout.startRemaining), big: checkout.startRemaining >= 100);
    if (!won) return;
    _winnerTimer?.cancel();
    _winnerTimer = Timer(Celebrations.playTime(context), () {
      if (mounted && _game.isFinished) _showWinner();
    });
  }

  /// The players in the order of a rematch: the one after this game's first player begins.
  X01Screen _rematch() {
    final s = widget.settings;
    final n = s.players.length;
    final settings = X01Settings(
      players: [for (var i = 0; i < n; ++i) s.players[(i + 1) % n]],
      startScore: s.startScore,
      doubleIn: s.doubleIn,
      doubleOut: s.doubleOut,
      legsToWin: s.legsToWin,
    );
    final bots = {for (final e in widget.bots.entries) (e.key - 1 + n) % n: e.value};
    LastX01(settings, bots).save();
    return X01Screen(settings: settings, bots: bots);
  }

  Future<void> _showWinner() {
    final l10n = AppLocalizations.of(context);
    final players = _game.players;
    final winner = players[_game.winner!];
    final legs = _game.settings.legsToWin > 1;
    String average(X01PlayerState p) =>
        l10n.x01PlayerFigures(p.dartsThrown == 0 ? '–' : decimal(l10n, p.threeDartAverage));
    return showWinnerDialog(
      context,
      winner: winner.name,
      record: currentRecord,
      result: [
        if (legs && players.length == 2) '${winner.legsWon}:${players.firstWhere((p) => p != winner).legsWon}',
        l10n.celebrateCheckout(winner.checkouts.last),
      ].join(' · '),
      lines: [for (final p in players) ResultLine(p.name, value: legs ? '${p.legsWon}' : null, figures: average(p))],
      onUndo: () => setState(_game.undo),
      newGame: (_) => const X01SetupScreen(),
      rematch: widget.watching ? null : (_) => _rematch(),
      readyForRematch: () => confirmBoardEmpty(context),
    );
  }

  /// Who won the leg just ended, until the next leg's first dart
  String? _legWon(AppLocalizations l10n) {
    final visits = _game.visits;
    if (_game.isFinished || visits.length < 2 || _game.currentVisit.darts.isNotEmpty) return null;
    final checkout = visits[visits.length - 2];
    if (!checkout.isCheckout) return null;
    final winner = _game.players[checkout.player];
    final players = _game.players;
    final score = players.length == 2 && _game.settings.legsToWin > 1
        ? ' · ${winner.legsWon}:${players.firstWhere((p) => p != winner).legsWon}'
        : '';
    return '${l10n.legWonBy(winner.name)}$score';
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
    // While its darts are in the board, and a moment longer without an engine, the visit that ended stays on the
    // scoreboard with its player.
    final waiting = _takeout.isClosed(_game) || _holding;
    final visit = waiting ? _game.visits[_game.visits.length - 2] : _game.currentVisit;
    final checkout = waiting ? null : _game.checkoutSuggestion;

    final display = DisplayScope.of(context);
    final window = WindowClass.of(context);
    // The panel's height lets the score shrink where it would push the other players and Undo out of view.
    final scoreboard = LayoutBuilder(
      builder: (context, constraints) => ScrollingPanel(
        top: [
          X01Panel(
            game: _game,
            visit: visit,
            dartTexts: [for (final d in visit.darts) _dartText(l10n, d)],
            checkout: checkout,
            onCallCheckout: () => CallerScope.read(context).say([callRoute(checkout!)], callLanguage),
            style: display.styleFor(window),
            far: display.farFor(window),
            details: display.panelDetails,
            legWon: _legWon(l10n),
            height: constraints.maxHeight,
          ),
        ],
        bottom: [
          OutlinedButton.icon(
            onPressed: _game.canUndo && !widget.watching ? () => setState(_game.undo) : null,
            icon: const Icon(Icons.undo),
            label: Text(l10n.undo),
            // From the oche the button is read and hit like the rest of the panel.
            style: display.farFor(window)
                ? OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    iconSize: 28,
                    textStyle: Theme.of(context).textTheme.titleLarge,
                  )
                : null,
          ),
        ],
      ),
    );
    return GameScaffold(
      title: '${widget.settings.startScore}',
      game: _game,
      takeout: _takeout,
      shownThrows: [for (final d in visit.darts) d.dart],
      watching: widget.watching,
      onDart: (dart) {
        // While a bot is at the oche, its darts are its own.
        if (!isBotTurn) _add(dart);
      },
      onChanged: () => setState(() {}),
      outcome: () => _outcome,
      onOutcomeChanged: _outcomeChanged,
      panel: scoreboard,
      celebrations: _celebrations,
    );
  }

  String _dartText(AppLocalizations l10n, X01Dart dart) => switch (dart.result) {
    DartResult.notIn => '${dart.dart.score.text(l10n)} (${l10n.notIn})',
    _ => dart.dart.score.text(l10n),
  };
}
