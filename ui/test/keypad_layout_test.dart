import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';
import 'preview_test.dart' show hello;

void main() {
  for (final (name, size) in [
    ('a tablet upright', const Size(1200, 1400)),
    ('a phone upright', const Size(412, 915)),
  ]) {
    testWidgets('on $name the whole keypad stays in view after the first dart', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = EngineConnection.forTest((_) {});
      addTearDown(engine.dispose);
      final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna', 'Ben']));
      await statistics.load();
      await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine, statistics: statistics));
      engine.receiveForTest(jsonEncode(hello));
      await tester.pumpAndSettle();
      // On a phone the card about new cameras pushes the games down.
      await tester.scrollUntilVisible(find.text('X01'), 200);
      await tester.tap(find.text('X01'));
      await tester.pumpAndSettle();
      await pickPlayers(tester, ['Anna', 'Ben']);
      await tester.tap(find.text('301'));
      await tester.tap(find.byKey(const ValueKey('start-game')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tastenfeld'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; ++i) {
        // The last row as well, below the numbers that the recent darts push down
        for (final key in ['keypad-20', 'keypad-miss']) {
          final box = tester.getRect(find.byKey(ValueKey(key)));
          expect(
            tester.getRect(find.byType(Scrollable).first).contains(box.center),
            isTrue,
            reason: '$key after $i darts',
          );
        }
        await tester.tap(find.byKey(const ValueKey('keypad-20')));
        await tester.pumpAndSettle();
      }
      expect(tester.widget<Text>(find.byKey(const ValueKey('remaining-Anna'))).data, '241');
    });
  }
}
