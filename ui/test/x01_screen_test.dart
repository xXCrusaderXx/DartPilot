import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/screens/x01_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    for (var i = 0; i < 2; ++i) {
      await dart('Triple', 'keypad-20');
    }
    // The visit's darts come to a total beside them.
    expect(tester.widget<Text>(find.byKey(const ValueKey('visit-total'))).data, '120');
    await dart('Triple', 'keypad-20');
    expect(tester.widget<Text>(find.byKey(const ValueKey('remaining-Anna'))).data, '121');
    for (var i = 0; i < 3; ++i) {
      await dart('', 'keypad-miss');
    }
    await tester.pump(X01Screen.holdTime);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('remaining-Ben'))).data, '301');
    expect(tester.widget<Text>(find.byKey(const ValueKey('checkout'))).data, 'T20  T15  D8');

    await dart('Triple', 'keypad-20');
    await dart('Triple', 'keypad-15');
    await dart('Double', 'keypad-8');
    // The checkout is celebrated first; the result follows once it has played.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Anna gewinnt!'), findsOneWidget);
    expect(find.text('Checkout 121'), findsOneWidget);
    // Ben threw only misses: no average to speak of
    expect(find.descendant(of: find.byKey(const ValueKey('result-Ben')), matching: find.text('Ø 0,0')), findsOneWidget);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    // The summary of this game: 301 in six darts with a 180 and a 121 finish
    Finder chip(String text) =>
        find.descendant(of: find.byKey(const ValueKey('summary-Anna')), matching: find.text(text));
    expect(chip('Darts 6'), findsOneWidget);
    // Average and first-9 average are the same over six darts.
    expect(
      find.descendant(of: find.byKey(const ValueKey('summary-Anna')), matching: find.textContaining('150,5')),
      findsNWidgets(2),
    );
    expect(chip('180 1'), findsOneWidget);
    expect(chip('Höchstes Finish 121'), findsOneWidget);

    // Undo from the dialog takes the winning dart back.
    await tester.tap(find.byKey(const ValueKey('result-undo')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('remaining-Anna'))).data, '16');
  });

  testWidgets('leaving a game with darts asks first, and a miss reads in German', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
    await playOffline(tester);
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('keypad-miss')));
    await tester.pumpAndSettle();
    expect(find.text('miss'), findsNothing);
    expect(tester.widget<Text>(find.byKey(const ValueKey('visit-dart-0'))).data, 'Daneben');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Spiel verlassen?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('visit-dart-0')), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('leave-game')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('visit-dart-0')), findsNothing);
  });

  Future<void> startGame(
    WidgetTester tester,
    List<String> players, {
    String score = '301',
    int legs = 1,
    Size size = const Size(1400, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
    await playOffline(tester);
    await tester.tap(find.byKey(const ValueKey('mode-X01')));
    await tester.pumpAndSettle();
    await pickPlayers(tester, players);
    await tester.tap(find.text(score));
    for (var i = 1; i < legs; ++i) {
      await tester.tap(find.byTooltip('Ein Leg mehr'));
    }
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
  }

  Future<void> dart(WidgetTester tester, String key, {String modifier = ''}) async {
    if (modifier.isNotEmpty) {
      await tester.tap(find.text(modifier));
      await tester.pump();
    }
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pump();
  }

  String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  testWidgets('a bust stays on show a moment, then the next player steps up without the score rolling', (tester) async {
    await startGame(tester, ['Anna', 'Ben']);
    for (var i = 0; i < 3; ++i) {
      await dart(tester, 'keypad-20', modifier: 'Triple');
    }
    await tester.pump(X01Screen.holdTime);
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; ++i) {
      await dart(tester, 'keypad-miss');
    }
    await tester.pump(X01Screen.holdTime);
    await tester.pumpAndSettle();
    // Ben's last visit shows beside his name while Anna throws.
    expect(find.textContaining('Zuletzt 0'), findsOneWidget);

    await dart(tester, 'keypad-20', modifier: 'Triple');
    await dart(tester, 'keypad-20', modifier: 'Triple');
    await tester.pumpAndSettle();
    expect(text(tester, 'visit-total'), 'Überworfen');
    expect(text(tester, 'remaining-Anna'), '121');

    await tester.pump(X01Screen.holdTime);
    // Ben's 301 shows at once, not counted up from Anna's 121.
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('301'), findsWidgets);
    expect(find.text('Zuletzt überworfen'), findsOneWidget);
    expect(text(tester, 'visit-total'), '–');
  });

  testWidgets('correcting a dart into the winning double ends the match as that dart would have', (tester) async {
    await startGame(tester, ['Anna']);
    for (var i = 0; i < 3; ++i) {
      await dart(tester, 'keypad-20', modifier: 'Triple');
    }
    await tester.pump(X01Screen.holdTime);
    await dart(tester, 'keypad-20', modifier: 'Triple');
    await dart(tester, 'keypad-15', modifier: 'Triple');
    await dart(tester, 'keypad-8');
    await tester.pumpAndSettle();
    expect(text(tester, 'remaining-Anna'), '8');

    // The S8 was a D8 after all.
    await tester.tap(find.byKey(const ValueKey('recent-5')));
    await tester.pumpAndSettle();
    await dart(tester, 'keypad-8', modifier: 'Double');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Anna gewinnt!'), findsOneWidget);
  });

  testWidgets('legs show from afar, a won leg says so, and a rematch starts with the other player', (tester) async {
    await startGame(tester, ['Anna', 'Ben'], legs: 2, size: const Size(1920, 1080));
    expect(text(tester, 'legs-Anna'), '0 Legs');
    expect(text(tester, 'legs-Ben'), '0 Legs');
    Future<void> checkout121() async {
      for (var i = 0; i < 3; ++i) {
        await dart(tester, 'keypad-20', modifier: 'Triple');
      }
      await tester.pump(X01Screen.holdTime);
      for (var i = 0; i < 3; ++i) {
        await dart(tester, 'keypad-miss');
      }
      await tester.pump(X01Screen.holdTime);
      await dart(tester, 'keypad-20', modifier: 'Triple');
      await dart(tester, 'keypad-15', modifier: 'Triple');
      await dart(tester, 'keypad-8', modifier: 'Double');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }

    await checkout121();
    expect(text(tester, 'legs-Anna'), '1 Leg');
    expect(find.text('Anna gewinnt das Leg · 1:0'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    // Ben starts the second leg; the line goes with his first dart.
    await dart(tester, 'keypad-miss');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('leg-won')), findsNothing);
    await dart(tester, 'keypad-miss');
    await dart(tester, 'keypad-miss');
    await tester.pump(X01Screen.holdTime);
    await checkout121();

    expect(find.text('Anna gewinnt!'), findsOneWidget);
    expect(find.text('2:0 · Checkout 121'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('result-rematch')));
    await tester.pumpAndSettle();
    // Same match, Ben throws first now.
    expect(find.text('Leg 1 · 2 zum Sieg'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('active-player')), matching: find.text('Ben')),
      findsOneWidget,
    );
    expect(text(tester, 'legs-Anna'), '0 Legs');
  });

  testWidgets('the setup keeps the last line-up and options, says why it cannot start, and Home offers it again', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
    await playOffline(tester);
    await tester.tap(find.byKey(const ValueKey('mode-X01')));
    await tester.pumpAndSettle();
    expect(find.text('Wähl mindestens einen Spieler, um zu starten.'), findsOneWidget);
    await pickPlayers(tester, ['Anna', 'Ben']);
    expect(find.byKey(const ValueKey('start-needs-player')), findsNothing);
    // Ben throws first.
    await tester.tap(find.byKey(const ValueKey('first-Ben')));
    await tester.pump();
    expect(find.text('Reihenfolge: Ben → Anna'), findsOneWidget);
    await tester.tap(find.text('701'));
    await tester.tap(find.byTooltip('Ein Leg mehr'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Tastenfeld'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Nochmal: 701 · Ben vs Anna'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mode-X01')));
    await tester.pumpAndSettle();
    expect(find.text('Reihenfolge: Ben → Anna'), findsOneWidget);
    expect(text(tester, 'legs-to-win'), '2');
    Navigator.of(tester.element(find.byKey(const ValueKey('start-game')))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('quick-start')));
    await tester.pumpAndSettle();
    expect(find.text('Leg 1 · 2 zum Sieg'), findsOneWidget);
  });

  testWidgets('the only profile is picked already', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
    await playOffline(tester);
    await tester.tap(find.byKey(const ValueKey('mode-X01')));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    Navigator.of(tester.element(find.byKey(const ValueKey('start-game')))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-X01')));
    await tester.pumpAndSettle();
    expect(find.text('Reihenfolge: Anna'), findsOneWidget);
  });
}
