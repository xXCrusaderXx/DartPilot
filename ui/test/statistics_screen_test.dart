import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

DartThrow at(Ring ring, [int sector = 20]) => DartThrow(fieldCentre(ring, sector: sector), ThrowInput.keypad);

void main() {
  testWidgets('a game is kept when the player leaves it, and its players are listed', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final statistics = Statistics(MemoryGameStore());
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna', 'Ben']);
    await tester.tap(find.text('301'));
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Triple'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('keypad-20')));
    await tester.pumpAndSettle();

    // Leaving the game, as the system back gesture does
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    final game = statistics.games.single;
    expect(game.mode, GameMode.x01);
    expect(game.players, ['Anna', 'Ben']);
    expect(game.x01Settings.startScore, 301);
    expect(game.throws.single.score.label, 'T20');

    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stats-player-Anna')), findsOneWidget);
    expect(find.byKey(const ValueKey('stats-player-Ben')), findsOneWidget);
  });

  testWidgets('the player page shows the figures for the chosen period and the games behind them', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    GameRecord x01(DateTime ended, List<DartThrow> throws) => GameRecord(
      id: '$ended',
      mode: GameMode.x01,
      started: ended,
      ended: ended,
      players: ['Anna'],
      settings: {'start_score': 101, 'double_out': true},
      throws: throws,
    );
    final statistics = Statistics(
      MemoryGameStore([
        // Two months ago: 101 in 4 darts (T20 S20 S1 | D10)
        x01(now.subtract(const Duration(days: 60)), [
          at(Ring.triple),
          at(Ring.outerSingle),
          at(Ring.outerSingle, 1),
          at(Ring.double, 10),
        ]),
        // Yesterday: three singles 20, unfinished
        x01(now.subtract(const Duration(days: 1)), [at(Ring.outerSingle), at(Ring.outerSingle), at(Ring.outerSingle)]),
      ]),
    );
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('2 Spiele  ·  3-Dart-Schnitt: 69,0'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stats-player-Anna')));
    await tester.pumpAndSettle();

    String figure(String label) => tester.widget<Text>(find.byKey(ValueKey('figure-$label'))).data!;
    // All: 161 points in 7 darts.
    expect(figure('3-Dart-Schnitt'), '69,0');
    expect(figure('Bestes Leg'), '4 Darts');
    expect(figure('Checkout-Quote'), '100\u00a0%');
    expect(figure('Höchstes Finish'), '20');
    expect(find.text('D10 × 1'), findsOneWidget);

    await tester.tap(find.text('7 Tage'));
    await tester.pumpAndSettle();
    expect(figure('3-Dart-Schnitt'), '60,0');
    expect(figure('Bestes Leg'), '–');
    expect(figure('Spiele'), '1 (0 gewonnen)');
  });
}
