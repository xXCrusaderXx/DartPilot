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
class GameScaffold extends StatefulWidget {
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
  State<GameScaffold> createState() => _GameScaffoldState();
}

class _GameScaffoldState extends State<GameScaffold> {
  /// The input's notice, shown at the top of the score panel
  final ValueNotifier<Widget?> _notice = ValueNotifier(null);

  @override
  void dispose() {
    _notice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LeaveGameGuard(
      canLeave: widget.watching || widget.game.isFinished || widget.game.throws.isEmpty,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        // Clear of a notch in landscape and of the home indicator under Undo
        body: SafeArea(
          child: GameNoticeSlot(
            notice: _notice,
            child: GameLayout(
              input: widget.watching
                  ? WatchedBoard(throws: widget.shownThrows)
                  : GameInput(
                      game: widget.game,
                      takeout: widget.takeout,
                      shownThrows: widget.shownThrows,
                      onDart: widget.onDart,
                      onChanged: widget.onChanged,
                    ),
              panel: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder(
                    valueListenable: _notice,
                    builder: (context, notice, _) => notice ?? const SizedBox.shrink(),
                  ),
                  Expanded(child: widget.panel),
                ],
              ),
              panelWidth: widget.panelWidth,
            ),
          ),
        ),
      ),
    );
  }
}
