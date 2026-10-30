import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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

  /// The dart the input's notice is about, framed in the panel's visit
  final ValueNotifier<DartThrow?> _marked = ValueNotifier(null);

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
  void initState() {
    super.initState();
    ScreenAwake.hold();
  }

  @override
  void dispose() {
    ScreenAwake.release();
    _notice.dispose();
    _marked.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _outcome = _currentOutcome();
    final celebrations = widget.celebrations;
    final layout = GameNoticeSlot(
      notice: _notice,
      marked: _marked,
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
        // The notices never take the room the panel needs to keep Undo at its foot: where room is short they keep to
        // their titles, and the most pressing of them stay.
        panel: LayoutBuilder(
          builder: (context, constraints) {
            final room = math.max(0.0, constraints.maxHeight - ScrollingPanel.pinnedFrom);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: room),
                  child: CompactNotices(
                    compact: constraints.maxHeight < CompactNotices.below,
                    room: room,
                    child: SingleChildScrollView(
                      child: ValueListenableBuilder(
                        valueListenable: _notice,
                        builder: (context, notice, _) => notice ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                // Over the score, where the moment belongs, and never over the board or keypad the next dart goes in
                Expanded(
                  child: celebrations == null
                      ? widget.panel
                      : CelebrationOverlay(celebrations: celebrations, child: widget.panel),
                ),
              ],
            );
          },
        ),
        panelWidth: widget.panelWidth,
      ),
    );
    return LeaveGameGuard(
      canLeave: widget.watching || widget.game.isFinished || widget.game.throws.isEmpty,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        // Clear of a notch in landscape and of the home indicator under Undo
        body: SafeArea(child: layout),
      ),
    );
  }
}

/// Keeps the screen on while a game screen is open: with darts scored by the engine nobody touches the device for a
/// whole leg. Counted, so a new game opened from the result of the last one keeps it on.
abstract final class ScreenAwake {
  static int _holders = 0;

  /// Whether a game screen keeps the screen on now
  static bool get held => _holders > 0;

  /// What turns keeping the screen on on and off: the platform's wake lock, or another for tests, which have none
  static ValueChanged<bool> keepOn = _wakeLock;

  static void hold() {
    if (_holders++ == 0) keepOn(true);
  }

  static void release() {
    if (_holders > 0 && --_holders == 0) keepOn(false);
  }

  static void _wakeLock(bool on) {
    // Where the platform cannot keep the screen on, the game goes on as before.
    WakelockPlus.toggle(enable: on).catchError((Object e) => debugPrint('The screen cannot be kept on: $e'));
  }
}
