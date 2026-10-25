import 'package:dartpilot/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

void main() {
  testWidgets('a whole 301 game with the keypad', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
    await playOffline(tester);
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna', 'Ben']);
    await tester.tap(find.text('301'));
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    Future<void> dart(String modifier, String key) async {
      if (modifier.isNotEmpty) {
        await tester.tap(find.text(modifier));
        await tester.pump();
      }
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    for (var i = 0; i < 3; ++i) {
      await dart('Triple', 'keypad-20');
    }
    expect(tester.widget<Text>(find.byKey(const ValueKey('remaining-Anna'))).data, '121');
    for (var i = 0; i < 3; ++i) {
      await dart('', 'keypad-miss');
    }
    expect(tester.widget<Text>(find.byKey(const ValueKey('remaining-Ben'))).data, '301');
    expect(tester.widget<Text>(find.byKey(const ValueKey('checkout'))).data, 'T20  T15  D8');

    await dart('Triple', 'keypad-20');
    await dart('Triple', 'keypad-15');
    await dart('Double', 'keypad-8');
    expect(find.text('Anna gewinnt!'), findsOneWidget);
    // The summary of this game: 301 in six darts with a 180 and a 121 finish
    Finder chip(String text) =>
        find.descendant(of: find.byKey(const ValueKey('summary-Anna')), matching: find.text(text));
    expect(chip('Darts 6'), findsOneWidget);
    // Average and first-9 average are the same over six darts.
    expect(
      find.descendant(of: find.byKey(const ValueKey('summary-Anna')), matching: find.textContaining('150.5')),
      findsNWidgets(2),
    );
    expect(chip('180 1'), findsOneWidget);
    expect(chip('Höchstes Finish 121'), findsOneWidget);

    // Undo from the dialog takes the winning dart back.
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Rückgängig')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('remaining-Anna'))).data, '16');
  });
}
