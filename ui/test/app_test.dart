import 'package:dartpilot/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('free throwing with board and keypad', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
    expect(find.text('Spiel wählen'), findsOneWidget);
    await tester.tap(find.text('Freies Werfen'));
    await tester.pumpAndSettle();

    // The centre of the board is the bull.
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('dartboard'))));
    await tester.pump();
    String visitDart(int i) => tester.widget<Text>(find.byKey(ValueKey('visit-dart-$i'))).data!;
    expect(visitDart(0), '50');

    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Triple'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('keypad-20')));
    await tester.pump();
    expect(visitDart(1), 'T20');
    expect(find.descendant(of: find.byKey(const ValueKey('total-points')), matching: find.text('110')), findsOneWidget);

    await tester.tap(find.text('Rückgängig'));
    await tester.pump();
    expect(visitDart(1), '–');
  });

  testWidgets('English follows the locale', (tester) async {
    await tester.pumpWidget(const DartPilotApp(locale: Locale('en')));
    expect(find.text('Choose a game'), findsOneWidget);
    expect(find.text('Free throwing'), findsOneWidget);
  });
}
