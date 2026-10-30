import 'dart:convert';
import 'dart:io';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/camera_order.dart';
import 'package:dartpilot/src/engine/engine_events.dart';
import 'package:dartpilot/src/engine/setup_status.dart';
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

  testWidgets('a moved camera marks the settings tab and the check entry, and home has one line that leads there', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(fixtures['hello']));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await tester.pumpAndSettle();
    expect(find.textContaining('hat sich bewegt'), findsNothing);
    expect(find.byKey(const ValueKey('setup-hint')), findsOneWidget);
    expect(find.text('Die Kameras sind noch nicht fertig eingerichtet'), findsOneWidget);
    expect(tester.widgetList<Badge>(find.byKey(const ValueKey('settings-attention'))).first.isLabelVisible, isTrue);

    await openSettingsPage(tester, 'cameras');
    expect(
      find.descendant(of: find.byKey(const ValueKey('settings-calibration-check')), matching: find.text('Prüfen')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(const ValueKey('settings-calibration')), matching: find.text('Erledigt')),
      findsOneWidget,
    );
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
    await openSettingsPage(tester, 'cameras');
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

  testWidgets('a knocked camera is announced at once, on any page', (tester) async {
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(fixtures['hello']));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await tester.pumpAndSettle();
    engine.receiveForTest(
      jsonEncode({
        'type': 'camera_moved',
        'camera': 'sim-3',
        'shift_px': [5.0, 1.0],
      }),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    expect(find.text('Kamera 3 wurde verschoben – die Kalibrierung wird geprüft.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 9));
  });

  testWidgets('a knocked rig moves all cameras and back: one notice', (tester) async {
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(fixtures['hello']));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await tester.pumpAndSettle();
    void moved(double dx) {
      for (final camera in ['sim-1', 'sim-2', 'sim-3']) {
        engine.receiveForTest(
          jsonEncode({
            'type': 'camera_moved',
            'camera': camera,
            'shift_px': [dx, 1.0],
          }),
        );
      }
    }

    moved(2);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    expect(find.text('Das Gestell wurde angestoßen – die Kalibrierung wird geprüft.'), findsOneWidget);
    // A snack bar's time starts once it has slid in.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('camera-moved')), findsNothing);
    // Swaying back a few seconds later gives no second notice.
    moved(-2);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    expect(find.byKey(const ValueKey('camera-moved')), findsNothing);
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('the setup line on home opens the first open step and can be hidden', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(fixtures['hello']));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await tester.pumpAndSettle();
    final status = SetupStatus.of(engine, CameraOrder());
    expect(status.firstOpen, isNotNull);
    await tester.tap(find.byKey(const ValueKey('setup-hint-hide')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setup-hint')), findsNothing);
  });

  test('the first open setup step follows the order the player takes them', () {
    const status = SetupStatus(
      assignment: SetupState.done,
      calibration: SetupState.stale,
      check: SetupState.none,
      emptyBoard: SetupState.missing,
    );
    expect(status.firstOpen, SetupStep.calibration);
    expect(SetupStatus.offline.firstOpen, isNull);
    expect(SetupStatus.offline.needsAttention, isFalse);
  });
}
