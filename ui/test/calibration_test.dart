import 'dart:convert';
import 'dart:io';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/engine_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';
import 'preview_test.dart' show previewMessage, tinyJpeg;

/// What `dartpilot serve --simulate` answered to every calibration step (docs/engine-api.md, "Calibration")
final Map<String, dynamic> fixtures =
    jsonDecode(File('test/fixtures/calibration_simulator.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('parses the engine\'s calibration messages', () {
    final hello = EngineEvent.fromJson(fixtures['hello'] as Map<String, dynamic>) as EngineHello;
    expect(hello.calibration!.cameras, hasLength(3));
    expect(hello.calibration!.of('sim-1')!.whiteBalanceKelvin, 3000);

    final light = EngineEvent.fromJson(fixtures['white_balance_done'] as Map<String, dynamic>) as WhiteBalanceState;
    expect(light.state, 'done');
    expect(light.cameras.first.chosenKelvin, 3000);
    expect(light.cameras.first.foundAt[2800], isTrue);
    expect(light.cameras.first.foundAt[6400], isFalse);

    final detection = EngineEvent.fromJson(fixtures['board_detection'] as Map<String, dynamic>) as BoardDetection;
    expect(detection.imageSizePx, const Size(640, 360));
    expect(detection.ellipses, hasLength(3));
    expect(detection.wiresPx, hasLength(20));

    final plane = EngineEvent.fromJson(fixtures['board_plane'] as Map<String, dynamic>) as BoardPlaneResult;
    expect(plane.sectors, hasLength(20));
    expect(plane.sectors[20]!.dx, 320);
    expect(plane.sectors[20]!.dy, closeTo(113.67, 1e-6));

    final refinement = EngineEvent.fromJson(fixtures['refinement'] as Map<String, dynamic>) as RefinementResult;
    expect(refinement.cameras.map((c) => c.advice), [null, 'detect_again', 'lens_calibration']);
  });

  testWidgets('the wizard: light, board with a tap into the 20, refinement, done', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    void receive(String fixture) => engine.receiveForTest(jsonEncode(fixtures[fixture]));
    receive('hello');

    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await openSettingsPage(tester, 'cameras');
    await tester.tap(find.byKey(const ValueKey('settings-calibration')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('calib-overview-sim-2')), findsOneWidget);
    expect(find.textContaining('Scheibe 0,62 mm'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calib-start')));
    await tester.pumpAndSettle();

    // 1. Light
    await tester.tap(find.byKey(const ValueKey('calib-light-tune')));
    await tester.pump();
    expect(sent.last, {'type': 'tune_white_balance'});
    receive('white_balance_sweeping');
    await tester.pump();
    expect(find.byKey(const ValueKey('calib-light-state')), findsOneWidget);
    receive('white_balance_done');
    engine.receiveForTest(jsonEncode({'type': 'result', 'request_id': '${sent.length}', 'ok': true}));
    await tester.pumpAndSettle();
    expect(find.text('Licht für jede Kamera eingestellt.'), findsOneWidget);
    expect(find.text('3000 K'), findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('calib-next')));
    await tester.pumpAndSettle();

    // 2. Board of camera 1: detect, tap into the 20, check the numbers
    expect(find.text('Kamera 1 von 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calib-detect')));
    await tester.pump();
    expect(sent.last, {'type': 'detect_board', 'camera': 'sim-1'});
    receive('board_detection');
    engine.receiveForTest(jsonEncode({'type': 'result', 'request_id': '${sent.length}', 'ok': true}));
    engine.receiveForTest(previewMessage('sim-1', 1, tinyJpeg));
    await tester.pump();
    await tester.pump();
    expect(find.text('Tippe in das Feld der 20.'), findsOneWidget);

    // The preview shows the 640×360 image; a tap above the bull lands in the 20.
    final preview = find.byKey(const ValueKey('overlay-preview-sim-1'));
    final box = tester.getRect(preview);
    await tester.tapAt(box.topLeft + Offset(box.width / 2, box.height * 140 / 360));
    await tester.pump();
    final tap = sent.last;
    expect(tap['type'], 'set_sector_20');
    expect((tap['point_px'] as List)[0], closeTo(320, 1));
    expect((tap['point_px'] as List)[1], closeTo(140, 1));
    receive('board_plane');
    engine.receiveForTest(jsonEncode({'type': 'result', 'request_id': '${sent.length}', 'ok': true}));
    await tester.pumpAndSettle();
    expect(find.text('Stimmen die Zahlen mit der Scheibe überein?'), findsOneWidget);
    expect(find.byKey(const ValueKey('calib-board-fit')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calib-next')));
    await tester.pumpAndSettle();
    expect(find.text('Kamera 2 von 3'), findsOneWidget);

    // 3. Refinement, reached through the step chips
    await tester.tap(find.byKey(const ValueKey('calib-step-refine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calib-refine')));
    await tester.pump();
    expect(sent.last, {'type': 'refine_cameras'});
    receive('refinement');
    engine.receiveForTest(jsonEncode({'type': 'result', 'request_id': '${sent.length}', 'ok': true}));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kamera 1 · 0,42 mm  ·  gut'), findsOneWidget);
    expect(find.textContaining('Kamera 3 · 0,71 mm  ·  brauchbar'), findsOneWidget);
    expect(find.textContaining('Linsenkalibrierung dieser Kamera'), findsOneWidget);

    // Measure again leads back to the board of that camera.
    await tester.tap(find.text('Neu einmessen'));
    await tester.pumpAndSettle();
    expect(find.text('Kamera 2 von 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calib-step-refine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calib-next')));
    await tester.pumpAndSettle();
    expect(find.text('Die Kameras sind kalibriert.'), findsOneWidget);
  });

  testWidgets('errors from the engine are worded for the player', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(fixtures['hello']));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await openSettingsPage(tester, 'cameras');
    await tester.tap(find.byKey(const ValueKey('settings-calibration')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calib-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calib-step-board')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calib-detect')));
    engine.receiveForTest(
      jsonEncode({
        'type': 'result',
        'request_id': '${sent.length}',
        'ok': false,
        'error': {'code': 'busy', 'message': ''},
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Die Engine ist noch mit einem anderen Schritt beschäftigt.'), findsOneWidget);
  });
}
