import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

void main() {
  testWidgets('a bot added in the setup throws its own darts when it is at the oche', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    await tester.tap(find.byKey(const ValueKey('pick-bot')));
    await tester.pumpAndSettle();
    expect(find.text('Average etwa 65'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bot-level-10')));
    await tester.pumpAndSettle();
    expect(find.text('Reihenfolge: Anna → Bot · Profi'), findsOneWidget);
    await tester.tap(find.text('301'));
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; ++i) {
      await tester.tap(find.byKey(const ValueKey('keypad-20')));
      await tester.pump();
    }
    String remaining(String player) => tester.widget<Text>(find.byKey(ValueKey('remaining-$player'))).data!;
    expect(remaining('Anna'), '241');

    // The bot's turn: a keypad dart now is not counted for anyone.
    await tester.tap(find.byKey(const ValueKey('keypad-1')));
    await tester.pump();
    expect(remaining('Bot · Profi'), '301');
    for (var i = 0; i < 3; ++i) {
      await tester.pump(const Duration(milliseconds: 950));
    }
    await tester.pumpAndSettle();
    // A pro scores with three darts and hands the oche back to Anna.
    expect(int.parse(remaining('Bot · Profi')), lessThan(301));
    expect(remaining('Anna'), '241');

    Navigator.of(tester.element(find.text('Tastenfeld'))).pop();
    await tester.pumpAndSettle();
    final game = statistics.games.single;
    expect(game.bots, {1: 10});
    expect(statistics.profiles, ['Anna']);
  });
}
