import 'dart:convert';
import 'dart:io';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/engine_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

/// What `dartpilot serve --simulate` sends: sim-2 has moved by 4.2 mm, the others are fine
final Map<String, dynamic> fixtures =
    jsonDecode(File('test/fixtures/calibration_check_simulator.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('parses the background check and the detailed one', () {
    final hello = EngineEvent.fromJson(fixtures['hello'] as Map<String, dynamic>) as EngineHello;
    final moved = hello.calibration!.of('sim-2')!.check!;
    expect(moved.state, 'moved');
    expect(moved.mm, 4.2);
    expect(moved.needsCalibration, isTrue);
    expect(hello.calibration!.of('sim-1')!.check!.needsCalibration, isFalse);

    final detail = EngineEvent.fromJson(fixtures['check_sim-2'] as Map<String, dynamic>) as CalibrationCheck;
    expect(detail.expectedPx, hasLength(detail.foundPx.length));
    expect(detail.shiftPx, const Offset(6, -3));
  });

  testWidgets('home warns about a moved camera and leads into the wizard at that camera', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(fixtures['hello']));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('calibration-warning-sim-2')), findsOneWidget);
    expect(find.text('Kamera 2 hat sich bewegt – miss sie neu ein.'), findsOneWidget);
    expect(find.byKey(const ValueKey('calibration-warning-sim-1')), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('calibration-warning-sim-2')),
        matching: find.text('Neu einmessen'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kamera 2 von 3'), findsOneWidget);
  });

  testWidgets('the check page subscribes while open and shows a verdict per camera', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(fixtures['hello']));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('settings-calibration-check')));
    await tester.pumpAndSettle();
    expect(sent.where((r) => r['type'] == 'subscribe_calibration_check'), hasLength(1));

    for (final camera in ['sim-1', 'sim-2', 'sim-3']) {
      engine.receiveForTest(jsonEncode(fixtures['check_$camera']));
    }
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('check-text-sim-2'))).data,
      'Kamera oder Scheibe hat sich bewegt (4,2 mm). Miss diese Kamera neu ein.',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('check-text-sim-1'))).data,
      'Passt zur Kalibrierung (0,6 mm).',
    );
    expect(find.byKey(const ValueKey('check-recalibrate-sim-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('check-recalibrate-sim-1')), findsNothing);

    // Leaving the page ends the engine's 2 s checks.
    Navigator.of(tester.element(find.byKey(const ValueKey('check-sim-1')))).pop();
    await tester.pumpAndSettle();
    expect(sent.last, {'type': 'unsubscribe_calibration_check'});
  });
}
