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
import '../widgets/celebration.dart';
import '../widgets/winner_dialog.dart';
import 'my_darts_screen.dart';
import 'game_layout.dart';
import 'x01_panel.dart';
import '../display.dart';
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

  @override
  State<X01Screen> createState() => _X01ScreenState();
}

class _X01ScreenState extends State<X01Screen> with RecordsGame, BotTurns {
  @override
  bool get watching => widget.watching;

  late final X01Game _game = replayed(X01Game(widget.settings), widget.replay);
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

  void _add(DartThrow dart) {
    final legBefore = _game.legNumber;
    final playerBefore = _game.current;
    final visitsBefore = _game.visits.length;
    setState(() => _game.add(dart));
    final l10n = AppLocalizations.of(context);
    if (!widget.watching) {
      CallerScope.read(context).call(x01Calls(_game, visitsBefore: visitsBefore, legBefore: legBefore), callLanguage);
    }
    if (_game.legNumber != legBefore || _game.isFinished) {
      _celebrations.show(l10n.celebrateCheckout(_game.players[playerBefore].checkouts.last));
    } else if (_game.visits.length > visitsBefore && _game.visits[_game.visits.length - 2].points == 180) {
      _celebrations.show('180');
    }
    if (_game.isFinished) {
      _showWinner();
    } else if (_game.legNumber != legBefore) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.legWonBy(_game.players[playerBefore].name))));
    }
  }

  Future<void> _showWinner() {
    return showWinnerDialog(
      context,
      winner: _game.players[_game.winner!].name,
      record: currentRecord,
      onUndo: () => setState(_game.undo),
      newGame: (_) => const X01SetupScreen(),
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
    // While its darts are in the board, the visit that ended stays on the scoreboard with its player.
    final waiting = _takeout.isClosed(_game);
    final visit = waiting ? _game.visits[_game.visits.length - 2] : _game.currentVisit;
    final checkout = waiting ? null : _game.checkoutSuggestion;

    final display = DisplayScope.of(context);
    final window = WindowClass.of(context);
    final scoreboard = ScrollingPanel(
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
        ),
      ],
      bottom: [
        OutlinedButton.icon(
          onPressed: _game.canUndo && !widget.watching ? () => setState(_game.undo) : null,
          icon: const Icon(Icons.undo),
          label: Text(l10n.undo),
        ),
      ],
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
      panel: scoreboard,
      celebrations: _celebrations,
    );
  }

  String _dartText(AppLocalizations l10n, X01Dart dart) => switch (dart.result) {
    DartResult.notIn => '${dart.dart.score.text(l10n)} (${l10n.notIn})',
    _ => dart.dart.score.text(l10n),
  };
}
