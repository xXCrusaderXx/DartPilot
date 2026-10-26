import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'game_input_test.dart' show throwJson;
import 'navigation.dart';

final String takeoutJson = jsonEncode({'type': 'takeout', 'event_ns': 1, 'darts_removed': 3});

/// An X01 game of 301 with a connected engine and these players; `bot` adds a pro after them
Future<EngineConnection> startGame(WidgetTester tester, List<String> players, {bool bot = false}) async {
  tester.view.physicalSize = const Size(1400, 1100);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final engine = EngineConnection.forTest((_) {});
  addTearDown(engine.dispose);
  final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(players));
  await statistics.load();
  await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine, statistics: statistics));
  await playOffline(tester);
  engine.state = EngineConnectionState.connected;
  await tester.tap(find.text('X01'));
  await tester.pumpAndSettle();
  await pickPlayers(tester, players);
  if (bot) {
    await tester.tap(find.byKey(const ValueKey('pick-bot')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bot-level-10')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('301'));
  await tester.tap(find.byKey(const ValueKey('start-game')));
  await tester.pumpAndSettle();
  return engine;
}

void main() {
  String remaining(WidgetTester tester, String player) =>
      tester.widget<Text>(find.byKey(ValueKey('remaining-$player'))).data!;

  /// The player shown as at the oche
  String atOche(WidgetTester tester) {
    final remainingText = find.descendant(
      of: find.byKey(const ValueKey('active-player')),
      matching: find.byWidgetPredicate((w) => w.key.toString().contains('remaining-')),
    );
    return (tester.widget<Text>(remainingText).key! as ValueKey<String>).value.substring('remaining-'.length);
  }

  testWidgets('after three darts the next visit waits for the takeout, and darts meanwhile wait too', (tester) async {
    final engine = await startGame(tester, ['Anna', 'Ben']);
    for (var i = 1; i <= 3; ++i) {
      engine.receiveForTest(throwJson('s/$i', 0, 103));
      await tester.pumpAndSettle();
    }
    expect(remaining(tester, 'Anna'), '121');
    expect(find.text('Darts entfernen'), findsOneWidget);
    // Anna's visit stays on the scoreboard until her darts are out.
    expect(atOche(tester), 'Anna');
    expect(tester.widget<Text>(find.byKey(const ValueKey('visit-dart-2'))).data, 'T20');

    // A dart before the takeout counts only once the board is empty again.
    engine.receiveForTest(throwJson('s/4', 0, 103));
    await tester.pumpAndSettle();
    expect(remaining(tester, 'Ben'), '301');

    // Tapping the board does not start the next visit either.
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keypad-20')));
    await tester.pumpAndSettle();
    expect(remaining(tester, 'Ben'), '301');

    engine.receiveForTest(takeoutJson);
    await tester.pumpAndSettle();
    expect(find.text('Darts entfernen'), findsNothing);
    expect(remaining(tester, 'Ben'), '241');
    expect(atOche(tester), 'Ben');
  });

  testWidgets('the player ends the wait when the engine missed the takeout', (tester) async {
    final engine = await startGame(tester, ['Anna', 'Ben']);
    for (var i = 1; i <= 3; ++i) {
      engine.receiveForTest(throwJson('s/$i', 0, 103));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('darts-removed')));
    await tester.pumpAndSettle();
    expect(find.text('Darts entfernen'), findsNothing);
    engine.receiveForTest(throwJson('s/4', 0, 103));
    await tester.pumpAndSettle();
    expect(remaining(tester, 'Ben'), '241');
  });

  testWidgets('undo reopens the visit that waited for its takeout', (tester) async {
    final engine = await startGame(tester, ['Anna', 'Ben']);
    for (var i = 1; i <= 3; ++i) {
      engine.receiveForTest(throwJson('s/$i', 0, 103));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    expect(find.text('Darts entfernen'), findsNothing);
    expect(remaining(tester, 'Anna'), '181');
  });

  testWidgets('a bot waits until the darts of the player before it are out', (tester) async {
    final engine = await startGame(tester, ['Anna'], bot: true);
    for (var i = 1; i <= 3; ++i) {
      engine.receiveForTest(throwJson('s/$i', 0, 103));
      await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(seconds: 3));
    expect(remaining(tester, 'Bot · Profi'), '301');

    engine.receiveForTest(takeoutJson);
    for (var i = 0; i < 3; ++i) {
      await tester.pump(const Duration(milliseconds: 950));
    }
    await tester.pumpAndSettle();
    expect(int.parse(remaining(tester, 'Bot · Profi')), lessThan(301));
  });

  testWidgets('without an engine the next visit starts at once', (tester) async {
    final engine = await startGame(tester, ['Anna', 'Ben']);
    engine.state = EngineConnectionState.disconnected;
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; ++i) {
      await tester.tap(find.byKey(const ValueKey('keypad-20')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Darts entfernen'), findsNothing);
    expect(remaining(tester, 'Ben'), '281');
  });
}
