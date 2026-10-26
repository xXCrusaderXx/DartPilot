import 'package:flutter/material.dart';

import '../board/dart_throw.dart';
import '../games/dart_game.dart';
import '../input/game_input.dart';
import '../input/takeout_gate.dart';
import '../widgets/leave_game_guard.dart';
import 'game_layout.dart';
import 'watched_board.dart';

/// The frame every game screen shares: its title, the board or keypad to enter darts (only the board while another
/// display's game is watched), the score [panel] beside or below it, and the question before leaving a game in
/// progress.
class GameScaffold extends StatelessWidget {
  const GameScaffold({
    super.key,
    required this.title,
    required this.game,
    required this.shownThrows,
    required this.onDart,
    required this.onChanged,
    required this.panel,
    this.takeout,
    this.watching = false,
    this.panelWidth = 340,
  });

  final String title;
  final DartGame game;

  /// The darts the board marks: usually the visit in progress
  final List<DartThrow> shownThrows;
  final ValueChanged<DartThrow> onDart;
  final VoidCallback onChanged;
  final Widget panel;
  final TakeoutGate? takeout;
  final bool watching;
  final double panelWidth;

  @override
  Widget build(BuildContext context) {
    return LeaveGameGuard(
      canLeave: watching || game.isFinished || game.throws.isEmpty,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        // Clear of a notch in landscape and of the home indicator under Undo
        body: SafeArea(
          child: GameLayout(
            input: watching
                ? WatchedBoard(throws: shownThrows)
                : GameInput(
                    game: game,
                    takeout: takeout,
                    shownThrows: shownThrows,
                    onDart: onDart,
                    onChanged: onChanged,
                  ),
            panel: panel,
            panelWidth: panelWidth,
          ),
        ),
      ),
    );
  }
}
