import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../games/cricket.dart';
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
import '../board/score_text.dart';
import '../display.dart';
import '../theme.dart';

class CricketScreen extends StatefulWidget {
  const CricketScreen({
    super.key,
    required this.names,
    this.cutThroat = false,
    this.bots = const {},
    this.replay = const [],
    this.watching = false,
  });

  final List<String> names;

  /// Cut-Throat Cricket: points go to the opponents, the lowest score wins
  final bool cutThroat;

  /// Bot level per player index; the others are people
  final Map<int, int> bots;

  /// Darts already thrown, for a game rebuilt from a shared record
  final List<DartThrow> replay;

  /// Only shows another app's game: no input, nothing kept or shared (#116)
  final bool watching;

  static Widget setup(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlayersSetupScreen(
      title: l10n.cricketSetup,
      options: [(l10n.cutThroat, false)],
      start: (names, bots, options) => CricketScreen(names: names, cutThroat: options.first, bots: bots),
    );
  }

  @override
  State<CricketScreen> createState() => _CricketScreenState();
}

class _CricketScreenState extends State<CricketScreen> with RecordsGame, BotTurns {
  @override
  bool get watching => widget.watching;

  late final CricketGame _game = replayed(CricketGame(widget.names, cutThroat: widget.cutThroat), widget.replay);
  final TakeoutGate _takeout = TakeoutGate();

  @override
  bool get waitsForTakeout => _takeout.isClosed(_game);

  @override
  GameRecord buildRecord(String id, DateTime started, DateTime ended) => GameRecord(
    id: id,
    mode: GameMode.cricket,
    started: started,
    ended: ended,
    players: widget.names,
    settings: {if (widget.cutThroat) 'cut_throat': true},
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
    if (!widget.watching) CallerScope.read(context).call(cricketCalls(_game), callLanguage);
    if (!_game.isFinished) return;
    showWinnerDialog(
      context,
      winner: _game.players[_game.winner!].name,
      record: currentRecord,
      onUndo: () => setState(_game.undo),
      newGame: CricketScreen.setup,
    );
  }

  static String _markSymbol(int marks) => switch (marks) {
    0 => '',
    1 => '/',
    2 => '✕',
    _ => 'Ⓧ',
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
    // While its darts are in the board, the visit that ended stays on the scoreboard with its player.
    final atOche = _takeout.isClosed(_game)
        ? (_game.current + _game.players.length - 1) % _game.players.length
        : _game.current;
    final players = _game.players;

    // The column at the oche in the display style: a bright block on the scoreboard, a tint in the clear style
    final display = DisplayScope.of(context);
    final window = WindowClass.of(context);
    final scoreboard = display.styleFor(window) == DisplayStyle.scoreboard;
    final far = display.farFor(window);
    final activeFill = scoreboard ? AppColors.warning : theme.colorScheme.primary.withValues(alpha: 0.18);
    final markStyle = far ? theme.textTheme.displaySmall : theme.textTheme.titleLarge;
    TableRow row(String label, List<String> cells, {TextStyle? style}) => TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: far ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium,
          ),
        ),
        for (var i = 0; i < cells.length; ++i)
          Container(
            color: i == atOche ? activeFill : null,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              cells[i],
              textAlign: TextAlign.center,
              style: (style ?? markStyle)?.copyWith(
                fontWeight: i == atOche ? FontWeight.w800 : null,
                color: i == atOche && scoreboard ? AppColors.background : null,
              ),
            ),
          ),
      ],
    );

    final panel = ScrollingPanel(
      top: [
        Table(
          border: TableBorder.symmetric(inside: BorderSide(color: theme.dividerColor)),
          children: [
            row('', [for (final p in players) p.name], style: theme.textTheme.titleSmall),
            for (final target in cricketTargets)
              row(target == 25 ? l10n.bull : '$target', [for (final p in players) _markSymbol(p.marks[target]!)]),
            row(l10n.points, [for (final p in players) '${p.points}']),
          ],
        ),
        const SizedBox(height: 12),
        VisitDarts([for (final d in _game.currentVisit) d.dart.score.text(l10n)]),
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
      title: l10n.modeCricket,
      game: _game,
      takeout: _takeout,
      shownThrows: [for (final d in _game.currentVisit) d.dart],
      watching: widget.watching,
      onDart: (dart) {
        // While a bot is at the oche, its darts are its own.
        if (!isBotTurn) _add(dart);
      },
      onChanged: () => setState(() {}),
      panel: panel,
      panelWidth: 120.0 + 90.0 * players.length.clamp(2, 4),
    );
  }
}
