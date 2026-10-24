import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/engine_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'preview_test.dart' show hello;

const cameras = ['usb-1', 'usb-2'];

Map<String, dynamic> diagnosisJson({String step = 'insert_dart', String state = 'measured', bool running = true}) => {
  'type': 'diagnosis',
  'running': running,
  'step': step,
  'state': state,
  'elapsed_s': 74.2,
  'cameras': cameras,
  'findings': [
    {
      'severity': 'problem',
      'check': 'calibration',
      'camera': 'usb-2',
      'code': 'calibration_off',
      'values': {'mm': 1.234},
      'message': 'The board is 1.23 mm off this camera\'s calibration.',
      'hint': 'Calibrate again.',
    },
    {
      'severity': 'warning',
      'check': 'drift',
      'camera': 'usb-1',
      'code': 'drift',
      'values': {'px': 0.62, 'minutes': 1.6},
      'message': 'The image moved by 0.62 px within 1.6 min.',
      'hint': 'Let the cameras warm up.',
    },
    {
      'severity': 'info',
      'check': 'consistency',
      'camera': null,
      'code': 'planes_agree',
      'values': {'mm': 0.4},
      'message': 'Where three cameras saw a dart, they agreed within 0.40 mm (median).',
      'hint': '',
    },
    {
      'severity': 'info',
      'check': 'future',
      'camera': '',
      'code': 'something_new',
      'values': <String, dynamic>{},
      'message': 'A check this app does not know.',
      'hint': 'Its English hint.',
    },
  ],
  'periods': [
    {
      'start_s': 41.3,
      'end_s': 42.4,
      'empty': true,
      'cameras': [
        {
          'brightness': 112.4,
          'calibration_mm': 0.48,
          'shift_px': [0.02, -0.11],
        },
        {'brightness': 108.0, 'calibration_mm': 1.23},
      ],
    },
    {
      'start_s': 53.0,
      'end_s': 54.1,
      'empty': false,
      'cameras': [
        {'brightness': 110.0, 'dart': 'seen', 'axis_length_px': 240.0},
        {'brightness': 107.0, 'dart': 'cut'},
      ],
      'board_mm': [0.0, 103.0],
      'agreeing_cameras': cameras,
      'worst_plane_mm': 0.4,
    },
  ],
};

void main() {
  test('parses the diagnosis with findings and periods', () {
    final d = EngineEvent.fromJson(diagnosisJson()) as EngineDiagnosis;
    expect(d.step, 'insert_dart');
    expect(d.findings.first.values['mm'], 1.234);
    expect(d.findings[2].camera, isNull);
    expect(d.findings[3].camera, isNull);
    expect(d.periods.first.cameras.first.shiftPx, [0.02, -0.11]);
    expect(d.periods.last.boardMm, [0.0, 103.0]);
    expect(d.periods.last.cameras.last.dart, 'cut');
  });

  testWidgets('the diagnosis page guides the player and words the findings in the app\'s language', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-diagnosis')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Die Diagnose beobachtet die Kameras'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('diagnosis-start')));
    await tester.pump();
    expect(sent.last, {'type': 'start_diagnosis'});

    engine.receiveForTest(jsonEncode(diagnosisJson(step: 'empty_board', state: 'moving')));
    await tester.pump();
    expect(find.text('Lass die Scheibe leer und nimm die Hand aus dem Bild.'), findsOneWidget);
    expect(find.text('Bild bewegt sich – ruhig halten'), findsOneWidget);

    engine.receiveForTest(jsonEncode(diagnosisJson()));
    await tester.pump();
    expect(find.text('Steck einen Dart in die Scheibe und nimm die Hand weg.'), findsOneWidget);
    expect(find.text('1:14 · 1 leere Scheiben · 1 Darts'), findsOneWidget);
    expect(find.text('Kamera 2: Die Scheibe liegt 1,23 mm neben der Kalibrierung dieser Kamera.'), findsOneWidget);
    expect(find.text('Kamera 1: Das Bild hat sich um 0,62 px in 1,6 min bewegt.'), findsOneWidget);
    expect(find.text('Wo drei Kameras einen Dart sahen, stimmten sie auf 0,40 mm überein (Median).'), findsOneWidget);
    // An info finding that needs nothing done has no hint.
    expect(find.textContaining('Verfeinere alle Kameras erneut'), findsNothing);
    // A code the app does not know keeps the engine's English text.
    expect(find.text('A check this app does not know.'), findsOneWidget);
    expect(find.text('Its English hint.'), findsOneWidget);

    await tester.tap(find.text('Gemessene Momente (2)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dart bei 0,0, 103,0 mm, 2 Kameras einig auf 0,4 mm'), findsOneWidget);
    expect(find.textContaining('Kamera 2: Dart am Rand abgeschnitten'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('diagnosis-stop')));
    await tester.pump();
    expect(sent.last, {'type': 'stop_diagnosis'});
  });

  testWidgets('says when the engine cannot run the diagnosis', (tester) async {
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('en'), engine: engine));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-diagnosis')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('diagnosis-start')));
    engine.receiveForTest(
      jsonEncode({
        'type': 'result',
        'request_id': '${sent.length}',
        'ok': false,
        'error': {'code': 'not_available', 'message': ''},
      }),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('This engine cannot run the diagnosis'), findsOneWidget);
  });
}
