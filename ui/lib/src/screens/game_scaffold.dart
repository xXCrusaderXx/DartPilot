import 'package:flutter/material.dart';

import '../board/dart_throw.dart';
import '../games/dart_game.dart';
import '../input/game_input.dart';
import '../input/takeout_gate.dart';
import '../widgets/celebration.dart';
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
    this.celebrations,
    this.outcome,
    this.onOutcomeChanged,
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

  /// The 180s and checkouts to show over the screen, in games that have them
  final Celebrations? celebrations;

  /// How the game stands, such as the leg and the winner; by default whether it is finished
  final Object? Function()? outcome;

  /// Called with the outcome before when a correction changed it, so a corrected dart that wins a leg or the game is
  /// handled as that dart would have been
  final ValueChanged<Object?>? onOutcomeChanged;

  @override
  State<GameScaffold> createState() => _GameScaffoldState();
}

class _GameScaffoldState extends State<GameScaffold> {
  /// The input's notice, shown at the top of the score panel
  final ValueNotifier<Widget?> _notice = ValueNotifier(null);

  /// The outcome as the screen last handled it: after its own darts, or as the last build showed it
  late Object? _outcome = _currentOutcome();

  Object? _currentOutcome() => widget.outcome?.call() ?? widget.game.isFinished;

  void _onDart(DartThrow dart) {
    widget.onDart(dart);
    _outcome = _currentOutcome();
  }

  /// Corrections change the game outside the screen's own darts: compared here, once for every game.
  void _onChanged() {
    final before = _outcome;
    final after = _currentOutcome();
    _outcome = after;
    widget.onChanged();
    if (before != after) widget.onOutcomeChanged?.call(before);
  }

  @override
  void dispose() {
    _notice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _outcome = _currentOutcome();
    final layout = GameNoticeSlot(
      notice: _notice,
      child: GameLayout(
        input: widget.watching
            ? WatchedBoard(throws: widget.shownThrows)
            : GameInput(
                game: widget.game,
                takeout: widget.takeout,
                shownThrows: widget.shownThrows,
                onDart: _onDart,
                onChanged: _onChanged,
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
    );
    final celebrations = widget.celebrations;
    return LeaveGameGuard(
      canLeave: widget.watching || widget.game.isFinished || widget.game.throws.isEmpty,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        // Clear of a notch in landscape and of the home indicator under Undo
        body: SafeArea(
          child: celebrations == null ? layout : CelebrationOverlay(celebrations: celebrations, child: layout),
        ),
      ),
    );
  }
}
