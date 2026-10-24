import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

String throwJson(String id, double x, double y, {bool accepted = true, double confidence = 0.9}) => jsonEncode({
  'type': 'throw',
  'throw_id': id,
  'accepted': accepted,
  'board_point': {'x_mm': x, 'y_mm': y, 'covariance_mm2': null},
  'confidence': confidence,
});

void main() {
  testWidgets('engine darts, an uncertain dart, a correction and a takeout in X01', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final engine = EngineConnection();
    addTearDown(engine.dispose);

    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await playOffline(tester);
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Spieler entfernen').last);
    await tester.tap(find.text('301'));
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    String remaining() => tester.widget<Text>(find.byKey(const ValueKey('remaining-Spieler 1'))).data!;

    // A detected T20 counts at once.
    engine.receiveForTest(throwJson('s/1', 0, 103));
    await tester.pumpAndSettle();
    expect(remaining(), '241');

    // An uncertain dart waits for confirmation.
    engine.receiveForTest(throwJson('s/2', 0, 103, accepted: false, confidence: 0.4));
    await tester.pumpAndSettle();
    expect(find.text('Unsicher: T20 (40 %)'), findsOneWidget);
    expect(remaining(), '241');
    await tester.tap(find.text('Bestätigen'));
    await tester.pumpAndSettle();
    expect(remaining(), '181');

    // Correct the first dart: it was an S20.
    await tester.tap(find.byKey(const ValueKey('recent-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keypad-20')));
    await tester.pumpAndSettle();
    expect(remaining(), '221');

    // Takeout after two darts: the third counts as a miss.
    engine.receiveForTest(jsonEncode({'type': 'takeout', 'event_ns': 1, 'darts_removed': 2}));
    await tester.pumpAndSettle();
    expect(find.text('1 Dart fehlt'), findsOneWidget);
    await tester.tap(find.text('Als Daneben zählen'));
    await tester.pumpAndSettle();
    expect(remaining(), '221');
    expect(tester.widget<Text>(find.byKey(const ValueKey('visit-dart-0'))).data, '–');
  });
}
