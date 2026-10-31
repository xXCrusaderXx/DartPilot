import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/screens/game_scaffold.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'game_input_test.dart' show throwJson;
import 'navigation.dart';
import 'preview_test.dart' show hello;
import 'takeout_test.dart' show takeoutJson;

String correctionJson(String id, String action, {double x = 0, double y = 103}) => jsonEncode({
  'type': 'throw_corrected',
  'throw_id': id,
  'action': action,
  'board_point': action == 'rejected' ? null : {'x_mm': x, 'y_mm': y},
  'client': 'setup',
});

void main() {
  String remaining(WidgetTester tester, String player) =>
      tester.widget<Text>(find.byKey(ValueKey('remaining-$player'))).data!;

  /// X01 301 for Anna and Ben with a connected engine; the messages the app sends land in `sent`
  Future<EngineConnection> startEngineGame(
    WidgetTester tester,
    List<Map<String, dynamic>> sent, {
    List<String> players = const ['Anna', 'Ben'],
  }) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna', 'Ben']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine, statistics: statistics));
    await playOffline(tester);
    engine.state = EngineConnectionState.connected;
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, players);
    await tester.tap(find.text('301'));
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    return engine;
  }

  Future<void> receive(WidgetTester tester, EngineConnection engine, String message) async {
    engine.receiveForTest(message);
    await tester.pumpAndSettle();
  }

  testWidgets('the same engine dart sent twice counts once', (tester) async {
    final engine = await startEngineGame(tester, []);
    await receive(tester, engine, throwJson('s/1', 0, 103));
    await receive(tester, engine, throwJson('s/1', 0, 103));
    await receive(tester, engine, correctionJson('s/1', 'added'));
    expect(remaining(tester, 'Anna'), '241');
  });

  testWidgets('an undo tells the engine, and darts held for the next visit are not replayed into it', (tester) async {
    final sent = <Map<String, dynamic>>[];
    final engine = await startEngineGame(tester, sent);
    for (var i = 1; i <= 3; ++i) {
      await receive(tester, engine, throwJson('s/$i', 0, 103));
    }
    // Ben's dart while Anna's are still in the board waits for the takeout.
    await receive(tester, engine, throwJson('s/4', 0, 103));
    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    expect(remaining(tester, 'Anna'), '181');
    expect([
      for (final m in sent.where((m) => m['type'] == 'reject_throw')) m['throw_id'],
    ], unorderedEquals(['s/3', 's/4']));

    await receive(tester, engine, throwJson('s/5', 0, 103));
    await receive(tester, engine, takeoutJson);
    expect(remaining(tester, 'Anna'), '121');
    expect(remaining(tester, 'Ben'), '301');
  });

  testWidgets('a dart rejected elsewhere is taken out wherever it is in the visit', (tester) async {
    final engine = await startEngineGame(tester, []);
    await receive(tester, engine, throwJson('s/1', 0, 103));
    await receive(tester, engine, throwJson('s/2', 0, 57)); // S20
    expect(remaining(tester, 'Anna'), '221');
    await receive(tester, engine, correctionJson('s/1', 'rejected'));
    expect(remaining(tester, 'Anna'), '281');
    expect(tester.widget<Text>(find.byKey(const ValueKey('visit-dart-0'))).data, '20');
  });

  testWidgets('a dart rejected elsewhere that lets a later dart win announces the winner', (tester) async {
    final engine = await startEngineGame(tester, [], players: ['Anna']);
    var id = 0;
    Future<void> visit(List<(double, double)> darts) async {
      for (final (x, y) in darts) {
        await receive(tester, engine, throwJson('s/${++id}', x, y));
      }
    }

    const t20 = (0.0, 103.0), s20 = (0.0, 57.0), s1 = (17.6, 54.2), d20 = (0.0, 166.0);
    await visit([t20, t20, t20]);
    await receive(tester, engine, takeoutJson);
    await visit([t20, s20, s1]);
    await receive(tester, engine, takeoutJson);
    expect(remaining(tester, 'Anna'), '40');
    // S1 leaves 39, so D20 busts; without the S1 the same D20 wins.
    await visit([s1, d20]);
    expect(remaining(tester, 'Anna'), '40');
    expect(find.text('Anna gewinnt!'), findsNothing);
    await receive(tester, engine, correctionJson('s/7', 'rejected'));
    expect(find.text('Anna gewinnt!'), findsOneWidget);
  });

  testWidgets('a dart added elsewhere while the darts are in the board belongs to the next visit', (tester) async {
    final engine = await startEngineGame(tester, []);
    for (var i = 1; i <= 3; ++i) {
      await receive(tester, engine, throwJson('s/$i', 0, 103));
    }
    await receive(tester, engine, correctionJson('s/9', 'added'));
    expect(remaining(tester, 'Ben'), '301');
    await receive(tester, engine, takeoutJson);
    expect(remaining(tester, 'Anna'), '121');
    expect(remaining(tester, 'Ben'), '241');
  });

  testWidgets('in a bot game, undo takes back the player\'s own dart and the bot waits for the next', (tester) async {
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
    await tester.tap(find.byKey(const ValueKey('bot-level-10')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('301'));
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; ++i) {
      await tester.tap(find.byKey(const ValueKey('keypad-20')));
      await tester.pump();
    }
    // Two of the bot's darts
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump();
    await tester.tap(find.text('Rückgängig'));
    // Anna is at the oche again, so no bot dart is due while the scores settle.
    await tester.pumpAndSettle();
    expect(remaining(tester, 'Anna'), '261');
    expect(remaining(tester, 'Bot · Profi'), '301');
    await tester.pump(const Duration(seconds: 3));
    expect(remaining(tester, 'Bot · Profi'), '301');

    await tester.tap(find.byKey(const ValueKey('keypad-19')));
    await tester.pump();
    for (var i = 0; i < 3; ++i) {
      await tester.pump(const Duration(milliseconds: 950));
    }
    await tester.pumpAndSettle();
    expect(remaining(tester, 'Anna'), '242');
    expect(int.parse(remaining(tester, 'Bot · Profi')), lessThan(301));
  });

  testWidgets('a game closed on its result counts and does not come back as interrupted', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = MemoryGameStore();
    final statistics = Statistics(store, MemoryProfileStore(['Anna']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    await tester.tap(find.text('301'));
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    for (final (modifier, key) in [
      ('Triple', 'keypad-20'),
      ('Triple', 'keypad-20'),
      ('Triple', 'keypad-20'),
      ('Triple', 'keypad-20'),
      ('Triple', 'keypad-15'),
      ('Double', 'keypad-8'),
    ]) {
      await tester.tap(find.text(modifier));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }
    expect(find.text('Anna gewinnt!'), findsOneWidget);
    expect(store.running?.isFinished, isTrue);

    // Killed on the result: the next start counts the game.
    final afterKill = MemoryGameStore()..running = store.running;
    final restarted = Statistics(afterKill, MemoryProfileStore(['Anna']));
    await restarted.load();
    expect(restarted.interrupted, isNull);
    expect(restarted.games, hasLength(1));
    expect(afterKill.records, hasLength(1));
    expect(afterKill.running, isNull);

    // Undo from the result plays on: the kept game is running again.
    await tester.tap(find.byKey(const ValueKey('result-undo')));
    await tester.pumpAndSettle();
    expect(store.running?.isFinished, isFalse);
  });

  testWidgets('undo back to no darts leaves no game to resume', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = MemoryGameStore();
    final statistics = Statistics(store, MemoryProfileStore(['Anna']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keypad-20')));
    await tester.pumpAndSettle();
    expect(store.running?.throws, hasLength(1));
    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    expect(store.running, isNull);
  });

  testWidgets('a game screen keeps the screen on until it is left', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final keeper = ScreenAwake.keepOn;
    final calls = <bool>[];
    ScreenAwake.keepOn = calls.add;
    addTearDown(() => ScreenAwake.keepOn = keeper);
    await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
    await playOffline(tester);
    expect(ScreenAwake.held, isFalse);
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    expect(ScreenAwake.held, isTrue);
    Navigator.of(tester.element(find.text('Tastenfeld'))).pop();
    await tester.pumpAndSettle();
    expect(ScreenAwake.held, isFalse);
    expect(calls, [true, false]);
  });

  testWidgets('a shared game of an unexpected shape shows as ended instead of failing', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(hello));
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Ben']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine, statistics: statistics));
    await tester.pumpAndSettle();
    final good = GameRecord(
      id: 'g1',
      mode: GameMode.x01,
      started: DateTime(2026, 10, 25),
      ended: DateTime(2026, 10, 25),
      players: ['Anna', 'Ben'],
      settings: {'start_score': 301},
      throws: [DartThrow(fieldCentre(Ring.triple), ThrowInput.keypad)],
    ).toJson();
    engine.receiveForTest(jsonEncode({'type': 'shared_game', 'client': 'tablet', 'game': good}));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shared-game')));
    await tester.pumpAndSettle();

    engine.receiveForTest(
      jsonEncode({
        'type': 'shared_game',
        'client': 'tablet',
        'game': {...good, 'players': 'Anna'},
      }),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('shared-game-ended')), findsOneWidget);
  });

  test('a record with a field of an unexpected type is skipped, not thrown', () {
    expect(GameRecord.tryParse({'mode': 'x01', 'id': 1}), isNull);
    expect(GameRecord.tryParse('not a record'), isNull);
    expect(GameRecord.tryParse(null), isNull);
  });
}
