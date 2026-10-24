import 'package:dartpilot/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> start(WidgetTester tester, String mode) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
    await tester.tap(find.text(mode));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Spieler entfernen').last);
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
    await start(tester, 'Cricket');
    for (final n in [20, 19, 18, 17, 16, 15]) {
      await dart(tester, 'Triple', 'keypad-$n');
    }
    expect(find.text('Ⓧ'), findsNWidgets(6));
    await dart(tester, '', 'keypad-bull');
    expect(find.text('✕'), findsOneWidget);
    await dart(tester, '', 'keypad-25');
    expect(find.text('Spieler 1 gewinnt!'), findsOneWidget);
  });

  testWidgets('a solo Around the Clock game without the bull', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
    await tester.tap(find.text('Around the Clock'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Spieler entfernen').last);
    await tester.tap(find.text('Mit Bull beenden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();

    await dart(tester, '', 'keypad-5');
    expect(tester.widget<Text>(find.byKey(const ValueKey('target-Spieler 1'))).data, '1');
    for (var n = 1; n <= 20; ++n) {
      await dart(tester, '', 'keypad-$n');
    }
    expect(find.text('Spieler 1 gewinnt!'), findsOneWidget);
  });
}
