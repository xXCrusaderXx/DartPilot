import 'package:flutter/material.dart';

import '../board/dart_throw.dart';
import '../board/dartboard.dart';
import '../display.dart';
import '../games/x01.dart';
import '../screens/game_layout.dart';
import '../screens/x01_panel.dart';

/// A sample X01 game as this window would show it, shrunk to fit: every appearance setting shows on it at once.
class AppearancePreview extends StatelessWidget {
  const AppearancePreview({super.key});

  static DartThrow _dart(double rMm, double phiDeg) => DartThrow(BoardPoint.polar(rMm, phiDeg), ThrowInput.board);

  /// Anna has thrown a 180 and a treble 20 and needs 81, with a checkout route; Ben has 396
  static X01Game _sample() {
    final game = X01Game(const X01Settings(players: ['Anna', 'Ben']));
    final treble20 = _dart(103, 90);
    final single20 = _dart(140, 90);
    for (final dart in [
      ...List.filled(3, treble20),
      ...List.filled(3, single20),
      ...List.filled(3, treble20),
      ...List.filled(3, single20),
      treble20,
    ]) {
      game.add(dart);
    }
    return game;
  }

  @override
  Widget build(BuildContext context) {
    final display = DisplayScope.of(context);
    final window = MediaQuery.sizeOf(context);
    final windowClass = WindowClass.of(context);
    final game = _sample();
    final visit = game.currentVisit;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: FittedBox(
          child: SizedBox(
            key: const ValueKey('appearance-preview'),
            width: window.width,
            height: window.height - kToolbarHeight,
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: GameLayout(
                input: Center(child: Dartboard(throws: [for (final d in visit.darts) d.dart])),
                panel: LayoutBuilder(
                  builder: (context, constraints) => ScrollingPanel(
                    fill: X01Panel(
                      game: game,
                      visit: visit,
                      dartTexts: const ['T20'],
                      checkout: game.checkoutSuggestion,
                      onCallCheckout: () {},
                      style: display.styleFor(windowClass),
                      far: display.farFor(windowClass),
                      details: display.panelDetails,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
