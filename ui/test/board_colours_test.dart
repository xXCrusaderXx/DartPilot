import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/display.dart';
import 'package:dartpilot/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'navigation.dart';

void main() {
  test('every dart colour stands out on the dark singles of every board', () {
    for (final fields in BoardColours.values) {
      for (final dart in dartSwatches) {
        expect(contrastRatio(dart, fields.darkSingle), greaterThanOrEqualTo(3), reason: '$dart on ${fields.name}');
      }
    }
  });

  test('the double and triple stand out on the singles of their own sector on every board', () {
    for (final fields in BoardColours.values) {
      expect(contrastRatio(fields.darkRing, fields.darkSingle), greaterThanOrEqualTo(3), reason: fields.name);
      expect(contrastRatio(fields.lightRing, fields.lightSingle), greaterThanOrEqualTo(3), reason: fields.name);
    }
  });

  test('board and dart colours are kept per device and survive a preset', () async {
    SharedPreferences.setMockInitialValues({});
    final display = DisplaySettings();
    await display.set(boardColours: BoardColours.colourSafe);
    await display.setDartColour(dartSwatches[2]);
    await display.applyPreset(AppearancePreset.highContrast);

    final loaded = DisplaySettings();
    await loaded.load();
    expect(loaded.boardColours, BoardColours.colourSafe);
    expect(loaded.dartColour, dartSwatches[2]);

    await display.setDartColour(null);
    await loaded.load();
    expect(loaded.dartColour, isNull);
  });

  testWidgets('the settings page changes board and dart colours', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final display = DisplaySettings(store: false);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), display: display));
    await playOffline(tester);
    await openSettingsPage(tester, 'game-screen');

    await showSettingsEntry(tester, 'board-colours');
    await tester.ensureVisible(find.byKey(const ValueKey('board-colours')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('board-colours')), matching: find.text('Farbsicher')),
    );
    await tester.pumpAndSettle();
    expect(display.boardColours, BoardColours.colourSafe);

    await tester.ensureVisible(find.byKey(const ValueKey('dart-colour-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dart-colour-1')));
    await tester.pumpAndSettle();
    expect(display.dartColour, dartSwatches[1]);
    expect(find.byKey(const ValueKey('board-preview')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dart-colour-accent')));
    await tester.pumpAndSettle();
    expect(display.dartColour, isNull);
    expect(tester.takeException(), isNull);
  });
}
