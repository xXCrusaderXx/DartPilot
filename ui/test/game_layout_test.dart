import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/display.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

void main() {
  const players = ['Anna', 'Ben', 'Carla', 'Dieter'];
  for (final (device, size, textSize) in [
    ('a phone upright', Size(412, 915), TextSize.normal),
    ('a phone on its side', Size(915, 412), TextSize.normal),
    ('a phone upright with the largest text', Size(412, 915), TextSize.larger),
  ]) {
    for (final mode in ['X01', 'Cricket', 'Around the Clock']) {
      testWidgets('$mode with four players fits $device, Undo included', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(players));
        await statistics.load();
        final display = DisplaySettings(store: false)..textSize = textSize;
        await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics, display: display));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('play-offline'), skipOffstage: false));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('play-offline')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(mode, skipOffstage: false));
        await tester.pumpAndSettle();
        await tester.tap(find.text(mode));
        await tester.pumpAndSettle();
        await pickPlayers(tester, players);
        await tester.ensureVisible(find.byKey(const ValueKey('start-game'), skipOffstage: false));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('start-game')));
        await tester.pumpAndSettle();

        // Overflow is reported as an exception while laying out.
        expect(tester.takeException(), isNull);
        final undo = find.widgetWithText(OutlinedButton, 'Rückgängig');
        await tester.ensureVisible(undo);
        await tester.pumpAndSettle();
        expect(tester.getRect(undo).bottom, lessThanOrEqualTo(size.height));
      });
    }
    for (final training in ['Gruppieren', 'Doppel-Training', 'Checkout-Trainer']) {
      testWidgets('$training fits $device, Undo included', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna']));
        await statistics.load();
        final display = DisplaySettings(store: false)..textSize = textSize;
        await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics, display: display));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('play-offline'), skipOffstage: false));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('play-offline')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Präzisionstraining', skipOffstage: false));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Präzisionstraining'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(training));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('start-game'), skipOffstage: false));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('start-game')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final undo = find.widgetWithText(OutlinedButton, 'Rückgängig');
        await tester.ensureVisible(undo);
        await tester.pumpAndSettle();
        expect(tester.getRect(undo).bottom, lessThanOrEqualTo(size.height));
      });
    }
  }
}
