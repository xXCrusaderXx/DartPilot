import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../board/dart_throw.dart';
import '../games/cricket.dart';
import '../input/throw_input_panel.dart';
import '../widgets/winner_dialog.dart';
import 'game_layout.dart';
import 'players_setup_screen.dart';

class CricketScreen extends StatefulWidget {
  const CricketScreen({super.key, required this.names});

  final List<String> names;

  static Widget setup(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlayersSetupScreen(
      title: l10n.cricketSetup,
      start: (names, _) => CricketScreen(names: names),
    );
  }

  @override
  State<CricketScreen> createState() => _CricketScreenState();
}

class _CricketScreenState extends State<CricketScreen> {
  late final CricketGame _game = CricketGame(widget.names);

  void _add(DartThrow dart) {
    setState(() => _game.add(dart));
    if (!_game.isFinished) return;
    final l10n = AppLocalizations.of(context);
    showWinnerDialog(
      context,
      winner: _game.players[_game.winner!].name,
      lines: [
        for (final p in _game.players)
          '${p.name}: ${p.points} ${l10n.points}, ${l10n.marksPerRound} ${p.marksPerRound.toStringAsFixed(2)}',
      ],
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
        input: ThrowInputPanel(shownThrows: [for (final d in _game.currentVisit) d.dart], onThrow: _add),
        panel: panel,
        panelWidth: 120.0 + 90.0 * players.length.clamp(2, 4),
      ),
    );
  }
}
