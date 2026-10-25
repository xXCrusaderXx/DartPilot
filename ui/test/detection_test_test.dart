import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/engine_events.dart';
import 'package:dartpilot/src/stats/detection_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'navigation.dart';

EngineThrow detection(String id, BoardPoint? point, {bool accepted = true, double? latencyMs}) =>
    EngineThrow(throwId: id, accepted: accepted, point: point, confidence: 0.9, detectionLatencyMs: latencyMs);

const t20 = BoardPoint(0, 103);
const s20 = BoardPoint(0, 130);
const s1 = BoardPoint(30, 125);

void main() {
  test('the log counts right, wrong, unsure, missed and false darts, and the latencies', () {
    final log = DetectionLog();
    log.detected(detection('s/1', t20, latencyMs: 400));
    log.detected(detection('s/2', t20, latencyMs: 600));
    log.detected(detection('s/3', null, accepted: false, latencyMs: 2000));
    // Corrected within the same field the dart stays right; into another field it is wrong.
    log.correct(log.current.darts[0], const BoardPoint(1, 104));
    log.correct(log.current.darts[1], s20);
    expect(log.current.darts[2].open, isTrue);
    log.correct(log.current.darts[2], s1);
    log.takeout(const EngineTakeout(3, detectionLatencyMs: 700));

    log.detected(detection('s/4', t20));
    log.reject(log.current.darts.single);
    log.missed(s20);
    log.takeout(const EngineTakeout(2));

    expect(log.count(DartOutcome.right), 1);
    expect(log.count(DartOutcome.wrong), 1);
    expect(log.count(DartOutcome.abstained), 1);
    expect(log.count(DartOutcome.missed), 1);
    expect(log.count(DartOutcome.falseAlarm), 1);
    expect(log.realDarts, 4);
    expect(log.placedRight, 0.5);
    expect(median(log.detectionLatenciesMs), 600);
    expect(log.takeoutLatenciesMs, [700]);
    expect(log.errorsMm.single, closeTo(27, 1e-9));
    // The second pull reported two darts with one in the board.
    expect(log.takeoutMismatches, 1);
    expect(log.rounds, hasLength(3));
  });

  testWidgets('darts are rated on the screen and sent to the engine; values change through sliders', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await playOffline(tester);
    expect(find.byKey(const ValueKey('detection-test')), findsNothing);
    engine.state = EngineConnectionState.connected;
    engine.receiveForTest(jsonEncode({'type': 'engine_status', 'detection': 'running', 'message': ''}));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('detection-test')));
    await tester.pumpAndSettle();
    expect(sent.last['type'], 'get_detection_params');
    expect(find.text('Diese Engine kann ihre Werte nicht im laufenden Betrieb ändern.'), findsOneWidget);

    engine.receiveForTest(
      jsonEncode({
        'type': 'throw',
        'throw_id': 's/1',
        'accepted': true,
        'board_point': {'x_mm': 0, 'y_mm': 103},
        'confidence': 0.93,
        'detection_latency_ms': 420.0,
        'cameras': [
          {'camera': 'usb-1', 'used': true},
          {'camera': 'usb-2', 'used': false, 'reason': 'not_seen'},
        ],
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('T20'), findsWidgets);
    expect(find.textContaining('richtig · 93 % · 420 ms · usb-2: not_seen'), findsOneWidget);

    // It really is an S20: select it, then give the field on the keypad.
    await tester.tap(find.byKey(const ValueKey('logged-dart-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keypad-20')));
    await tester.pumpAndSettle();
    expect(sent.last['type'], 'correct_throw');
    expect(sent.last['throw_id'], 's/1');
    expect(find.text('T20 → S20'), findsOneWidget);

    // A dart the engine did not report.
    await tester.tap(find.byKey(const ValueKey('keypad-5')));
    await tester.pumpAndSettle();
    expect(sent.last['type'], 'add_throw');
    expect(find.text('verpasst'), findsOneWidget);

    // One added by mistake: deleted again, also in the engine.
    await tester.tap(find.byKey(const ValueKey('keypad-1')));
    await tester.pumpAndSettle();
    final added = sent.last['board_point'] as Map<String, dynamic>;
    engine.receiveForTest(
      jsonEncode({
        'type': 'throw_corrected',
        'throw_id': 's/3',
        'action': 'added',
        'board_point': added,
        'client': 'test',
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('verpasst'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('remove-dart-2')));
    await tester.pumpAndSettle();
    expect(sent.last['type'], 'reject_throw');
    expect(sent.last['throw_id'], 's/3');
    expect(find.text('verpasst'), findsOneWidget);

    engine.receiveForTest(jsonEncode({'type': 'takeout', 'darts_removed': 2, 'detection_latency_ms': 650.0}));
    await tester.pumpAndSettle();
    expect(find.text('Runde 2'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('stat-Richtig platziert'))).data, '0 % (0/1)');
    expect(tester.widget<Text>(find.byKey(const ValueKey('stat-Verpasst'))).data, '1');

    engine.receiveForTest(
      jsonEncode({
        'type': 'detection_params',
        'params': {'settle_ms': 1500},
        'ranges': {
          'settle_ms': {'min': 0, 'max': 2000, 'step': 50, 'unit': 'ms'},
        },
      }),
    );
    await tester.pumpAndSettle();
    final slider = find.byKey(const ValueKey('param-settle_ms'));
    await tester.dragUntilVisible(slider, find.byKey(const ValueKey('detection-stats')), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('1500 ms'), findsOneWidget);
    await tester.tapAt(tester.getTopLeft(slider) + Offset(tester.getSize(slider).width * 0.1, 10));
    await tester.pumpAndSettle();
    expect(sent.last['type'], 'set_detection_params');
    expect((sent.last['params'] as Map)['settle_ms'], lessThan(1500));
  });

  testWidgets('values are grouped, explained, reset to their default and kept as profiles', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await playOffline(tester);
    engine.state = EngineConnectionState.connected;
    engine.receiveForTest(jsonEncode({'type': 'engine_status', 'detection': 'running', 'message': ''}));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('detection-test')));
    await tester.pumpAndSettle();
    Map<String, dynamic> params(double settle) => {
      'type': 'detection_params',
      'params': {'settle_samples': settle, 'still_motion': 2.5},
      'ranges': {
        'settle_samples': {'min': 1, 'max': 30, 'step': 1, 'unit': ''},
        'still_motion': {'min': 0.5, 'max': 10, 'step': 0.1, 'unit': 'grey'},
      },
      'info': {
        'settle_samples': {'group': 'event_detection', 'description': 'Still samples before averaging', 'default': 6},
        'still_motion': {
          'group': 'event_detection',
          'description': 'Mean change that still counts as still',
          'default': 2.5,
        },
      },
    };
    engine.receiveForTest(jsonEncode(params(3)));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('param-still_motion')),
      find.byKey(const ValueKey('detection-stats')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(find.text('event_detection'), findsOneWidget);
    expect(find.text('Still samples before averaging'), findsOneWidget);
    // Only the changed value can be reset, to its default.
    expect(find.byKey(const ValueKey('param-reset-still_motion')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('param-reset-settle_samples')));
    await tester.pumpAndSettle();
    expect(sent.last['type'], 'set_detection_params');
    expect(sent.last['params'], {'settle_samples': 6.0});

    // A profile keeps the values and sets them again.
    await tester.tap(find.byKey(const ValueKey('param-profile-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('param-profile-name')), 'schnell');
    await tester.tap(find.byKey(const ValueKey('param-profile-save')));
    await tester.pumpAndSettle();
    engine.receiveForTest(jsonEncode(params(6)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('param-profile-schnell')));
    await tester.pumpAndSettle();
    expect(sent.last['params'], {'settle_samples': 3.0, 'still_motion': 2.5});
  });
}
