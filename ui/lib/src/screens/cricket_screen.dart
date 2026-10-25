import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../games/cricket.dart';
import '../bots/bot_turns.dart';
import '../games/dart_game.dart';
import '../input/game_input.dart';
import '../stats/game_record.dart';
import '../stats/statistics.dart';
import '../widgets/winner_dialog.dart';
import 'my_darts_screen.dart';
import 'game_layout.dart';
import 'players_setup_screen.dart';

class CricketScreen extends StatefulWidget {
  const CricketScreen({super.key, required this.names, this.bots = const {}});

  final List<String> names;

  /// Bot level per player index; the others are people
  final Map<int, int> bots;

  static Widget setup(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlayersSetupScreen(
      title: l10n.cricketSetup,
      start: (names, bots, _) => CricketScreen(names: names, bots: bots),
    );
  }

  @override
  State<CricketScreen> createState() => _CricketScreenState();
}

class _CricketScreenState extends State<CricketScreen> with RecordsGame, BotTurns {
  late final CricketGame _game = CricketGame(widget.names);

  @override
  GameRecord buildRecord(String id, DateTime started, DateTime ended) => GameRecord(
    id: id,
    mode: GameMode.cricket,
    started: started,
    ended: ended,
    players: widget.names,
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
      scheduleBotTurn();
      if (mounted && !_game.isFinished) useDartsOf(context, _game.players[_game.current].name);
    });
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final players = _game.players;

    TableRow row(String label, List<String> cells, {TextStyle? style}) => TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(label, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        ),
        for (var i = 0; i < cells.length; ++i)
          Container(
            color: i == _game.current ? theme.colorScheme.secondaryContainer : null,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(cells[i], textAlign: TextAlign.center, style: style ?? theme.textTheme.titleLarge),
          ),
      ],
    );

    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        VisitDarts([for (final d in _game.currentVisit) d.dart.score.label]),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _game.canUndo ? () => setState(_game.undo) : null,
          icon: const Icon(Icons.undo),
          label: Text(l10n.undo),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.modeCricket)),
      body: GameLayout(
        input: GameInput(
          game: _game,
          shownThrows: [for (final d in _game.currentVisit) d.dart],
          onDart: (dart) {
            // While a bot is at the oche, its darts are its own.
            if (!isBotTurn) _add(dart);
          },
          onChanged: () => setState(() {}),
        ),
        panel: panel,
        panelWidth: 120.0 + 90.0 * players.length.clamp(2, 4),
      ),
    );
  }
}
