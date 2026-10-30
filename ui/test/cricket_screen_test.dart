import 'package:dartpilot/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

void main() {
  Future<void> start(WidgetTester tester, String mode) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
    await playOffline(tester);
    await tester.tap(find.text(mode));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
  }

  Future<void> dart(WidgetTester tester, String modifier, String key) async {
    if (modifier.isNotEmpty) {
      await tester.tap(find.text(modifier));
      await tester.pump();
    }
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('a solo Cricket game until everything is closed', (tester) async {
    final semantics = tester.ensureSemantics();
    await start(tester, 'Cricket');
    for (final n in [20, 19, 18, 17, 16, 15]) {
      await dart(tester, 'Triple', 'keypad-$n');
    }
    // The marks are drawn; screen readers hear them
    expect(find.bySemanticsLabel('Geschlossen'), findsNWidgets(6));
    await dart(tester, '', 'keypad-bull');
    expect(find.bySemanticsLabel('2 Treffer'), findsOneWidget);
    await dart(tester, '', 'keypad-25');
    // Alone there is nobody to beat: the game ends on how it went, not on a win.
    expect(find.text('Anna gewinnt!'), findsNothing);
    expect(find.text('Spiel beendet'), findsOneWidget);
    expect(find.text('Alles zu in 8 Darts'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('back on the winner dialog leaves the finished game for the menu', (tester) async {
    await start(tester, 'Cricket');
    for (final n in [20, 19, 18, 17, 16, 15]) {
      await dart(tester, 'Triple', 'keypad-$n');
    }
    await dart(tester, '', 'keypad-bull');
    await dart(tester, '', 'keypad-25');
    expect(find.text('Spiel beendet'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Spiel beendet'), findsNothing);
    expect(find.byKey(const ValueKey('keypad-20')), findsNothing);
    expect(find.text('Cricket'), findsOneWidget);
  });

  testWidgets('a solo Around the Clock game without the bull', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
    await playOffline(tester);
    await tester.tap(find.text('Around the Clock'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    await tester.tap(find.text('Mit Bull beenden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();

    await dart(tester, '', 'keypad-5');
    expect(tester.widget<Text>(find.byKey(const ValueKey('target-Anna'))).data, '1');
    for (var n = 1; n <= 20; ++n) {
      await dart(tester, '', 'keypad-$n');
    }
    expect(find.text('Einmal rum in 21 Darts'), findsOneWidget);
  });
  // Bull decides most Cricket games, so its row must not hide below the fold of a phone.
  for (final size in [const Size(412, 915), const Size(915, 412)]) {
    for (final players in [
      ['Anna', 'Ben'],
      ['Anna', 'Ben', 'Cleo'],
    ]) {
      testWidgets('on a ${size.width.round()}x${size.height.round()} phone with ${players.length} players the Cricket '
          'table shows every number down to the bull', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
        await tester.pumpAndSettle();
        // On a low screen the connection page and the games list build their entries only near the screen
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('play-offline')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await playOffline(tester);
        await tester.scrollUntilVisible(find.text('Cricket'), 200, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cricket'));
        await tester.pumpAndSettle();
        for (final name in players) {
          await tester.ensureVisible(find.byKey(const ValueKey('pick-new-profile')));
          await tester.pumpAndSettle();
          await pickPlayers(tester, [name]);
        }
        final start = find.byKey(const ValueKey('start-game'));
        await tester.scrollUntilVisible(start, 200, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(start);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final bull = tester.getRect(find.byKey(const ValueKey('cricket-row-25')));
        // The table clips what it scrolls, so the bull is in view only above the visit darts
        final darts = tester.getRect(find.byKey(const ValueKey('visit-dart-0')));
        expect(bull.bottom, lessThanOrEqualTo(darts.top));
        final undo = tester.getRect(find.widgetWithText(OutlinedButton, 'Rückgängig'));
        expect(undo.bottom, lessThanOrEqualTo(size.height));
      });
    }
  }
}
