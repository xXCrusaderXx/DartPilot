import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';
import 'preview_test.dart' show hello;

DartThrow at(Ring ring, [int sector = 20]) => DartThrow(fieldCentre(ring, sector: sector), ThrowInput.keypad);

void main() {
  testWidgets('the leading app shares its game after every dart and ends it when left', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(hello));
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine, statistics: statistics));
    await tester.pumpAndSettle();
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    await tester.tap(find.text('301'));
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Triple'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('keypad-20')));
    await tester.pumpAndSettle();

    final shares = sent.where((r) => r['type'] == 'share_game').toList();
    final record = GameRecord.fromJson(shares.last['game'] as Map<String, dynamic>)!;
    expect(record.players, ['Anna']);
    expect(record.x01Settings.startScore, 301);
    expect(record.throws.single.score.label, 'T20');

    Navigator.of(tester.element(find.text('Tastenfeld'))).pop();
    await tester.pumpAndSettle();
    expect(sent.last, {'type': 'end_shared_game'});
  });

  testWidgets('another display watches the shared game, with the same state and no input', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(hello));
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Ben']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine, statistics: statistics));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shared-game')), findsNothing);

    GameRecord game(List<DartThrow> throws) => GameRecord(
      id: 'g1',
      mode: GameMode.x01,
      started: DateTime(2026, 10, 25),
      ended: DateTime(2026, 10, 25),
      players: ['Anna', 'Ben'],
      settings: {'start_score': 301, 'double_out': true},
      throws: throws,
    );
    void share(GameRecord? record) =>
        engine.receiveForTest(jsonEncode({'type': 'shared_game', 'client': 'tablet', 'game': record?.toJson()}));

    share(game([at(Ring.triple)]));
    await tester.pumpAndSettle();
    expect(find.text('Laufendes Spiel ansehen: 301'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shared-game')));
    await tester.pumpAndSettle();
    String remaining(String player) => tester.widget<Text>(find.byKey(ValueKey('remaining-$player'))).data!;
    expect(remaining('Anna'), '241');
    expect(find.byKey(const ValueKey('watched-board')), findsOneWidget);
    expect(find.text('Tastenfeld'), findsNothing);

    share(game([at(Ring.triple), at(Ring.triple), at(Ring.triple)]));
    await tester.pumpAndSettle();
    expect(remaining('Anna'), '121');

    share(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shared-game-ended')), findsOneWidget);
    // Watching keeps nothing and shares nothing.
    expect(sent.where((r) => r['type'] == 'share_game' || r['type'] == 'end_shared_game'), isEmpty);
    expect(statistics.games, isEmpty);
  });
}
