import 'dart:io';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

void main() {
  Future<void> startX01(WidgetTester tester, Statistics statistics) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
  }

  Future<Statistics> loaded(MemoryGameStore store) async {
    final statistics = Statistics(store, MemoryProfileStore(['Anna']));
    await statistics.load();
    return statistics;
  }

  testWidgets('a game the app was killed in is played on from where it stopped', (tester) async {
    final store = MemoryGameStore();
    await startX01(tester, await loaded(store));
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Triple'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('keypad-20')));
    await tester.pumpAndSettle();
    expect(store.running?.throws, hasLength(1));

    // Killed: nothing is disposed, the next start finds only what was on disk.
    final afterKill = MemoryGameStore()..running = store.running;
    await tester.pumpWidget(const SizedBox());
    await startX01(tester, await loaded(afterKill));
    expect(find.text('Unterbrochenes Spiel: 501'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('resume-interrupted')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('remaining-Anna'))).data, '441');
  });

  testWidgets('an interrupted game that is ended counts as unfinished', (tester) async {
    final store = MemoryGameStore();
    final first = await loaded(store);
    await startX01(tester, first);
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keypad-20')));
    await tester.pumpAndSettle();

    final afterKill = MemoryGameStore()..running = store.running;
    await tester.pumpWidget(const SizedBox());
    await startX01(tester, await loaded(afterKill));
    await tester.tap(find.byKey(const ValueKey('end-interrupted')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('interrupted-game')), findsNothing);
    expect(afterKill.records, hasLength(1));
    expect(afterKill.running, isNull);
  });

  test('the running game is written beside the games file and removed when it ends', () async {
    final dir = await Directory.systemTemp.createTemp('dartpilot-running');
    addTearDown(() => dir.delete(recursive: true));
    final store = FileGameStore(File('${dir.path}/games.jsonl'));
    expect(await store.loadRunning(), isNull);
    final record = GameRecord(
      id: 'g1',
      mode: GameMode.x01,
      started: DateTime.utc(2026, 10, 26, 20),
      ended: DateTime.utc(2026, 10, 26, 20, 5),
      players: const ['Anna'],
      settings: const {'start_score': 501},
      throws: [DartThrow(const BoardPoint(0, 103), ThrowInput.keypad)],
    );
    await store.saveRunning(record);
    expect((await store.loadRunning())?.throws.single.point, const BoardPoint(0, 103));
    await store.saveRunning(null);
    expect(await store.loadRunning(), isNull);
  });
}
