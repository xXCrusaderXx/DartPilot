import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/engine_events.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';
import 'preview_test.dart' show hello, tinyJpeg;

/// As in docs/engine-api.md: camera usb-1 counted, usb-2 cut the dart at its image border
Map<String, dynamic> throwViewsJson(String throwId) => {
  'type': 'throw_views',
  'throw_id': throwId,
  'board_point': {'x_mm': 0.0, 'y_mm': 103.0, 'covariance_mm2': null},
  'cameras': [
    {
      'camera': 'usb-1',
      'used': true,
      'reason': '',
      'plane_distance_mm': 0.4,
      'crop_px': [512, 180, 240, 240],
      'image_size_px': [240, 240],
      'before_jpeg_base64': base64Encode(tinyJpeg),
      'after_jpeg_base64': base64Encode(tinyJpeg),
      'tip_px': [118.5, 131.0],
      'axis_px': [
        [118.5, 131.0],
        [201.0, 40.5],
      ],
      'located_px': [119.2, 130.1],
    },
    {
      'camera': 'usb-2',
      'used': false,
      'reason': 'cut',
      'plane_distance_mm': null,
      'crop_px': [0, 0, 240, 240],
      'image_size_px': [240, 240],
      'before_jpeg_base64': base64Encode(tinyJpeg),
      'after_jpeg_base64': base64Encode(tinyJpeg),
      'tip_px': null,
      'axis_px': null,
      'located_px': [10.0, 20.0],
    },
  ],
};

GameRecord recordWith(List<DartThrow> throws) => GameRecord(
  id: 'g1',
  mode: GameMode.x01,
  started: DateTime(2026, 10, 26, 20),
  ended: DateTime(2026, 10, 26, 20, 30),
  players: ['Anna'],
  settings: {'start_score': 301},
  throws: throws,
);

Future<void> openGameDarts(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.insights_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('stats-player-Anna')));
  await tester.pumpAndSettle();
  await tester.dragUntilVisible(find.byKey(const ValueKey('history-g1')), find.byType(ListView), const Offset(0, -300));
  await tester.tap(find.byKey(const ValueKey('history-g1')));
  await tester.pumpAndSettle();
}

void main() {
  test('throw views are read with their overlay in crop pixels', () {
    final views = EngineEvent.fromJson(throwViewsJson('s/1')) as ThrowViews;
    expect(views.throwId, 's/1');
    expect(views.point, const BoardPoint(0, 103));
    expect(views.cameras, hasLength(2));
    final used = views.cameras.first;
    expect(used.used, isTrue);
    expect(used.planeDistanceMm, 0.4);
    expect(used.imageSizePx, const Size(240, 240));
    expect(used.after, tinyJpeg);
    expect(used.tipPx, const Offset(118.5, 131));
    expect(used.axisPx, (const Offset(118.5, 131), const Offset(201, 40.5)));
    final cut = views.cameras.last;
    expect(cut.reason, 'cut');
    expect(cut.tipPx, isNull);
    expect(cut.axisPx, isNull);
  });

  testWidgets('a detected dart of a played game opens its camera views from the history', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    final statistics = Statistics(
      MemoryGameStore([
        recordWith([
          DartThrow(const BoardPoint(0, 103), ThrowInput.engine, engineThrowId: 's/1', confidence: 0.9),
          DartThrow(fieldCentre(Ring.outerSingle), ThrowInput.keypad),
        ]),
      ]),
      MemoryProfileStore(['Anna']),
    );
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine, statistics: statistics));
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpAndSettle();
    await openGameDarts(tester);

    // The keypad dart has no camera views.
    expect(tester.widget<ActionChip>(find.byKey(const ValueKey('game-dart-1'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('game-dart-0')));
    // The spinner never settles: a page transition's worth of frames instead
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(sent.where((m) => m['type'] == 'get_throw_views').single['throw_id'], 's/1');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    engine.receiveForTest(jsonEncode(throwViewsJson('s/1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('throw-view-usb-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('throw-view-overlay-usb-1')), findsOneWidget);
    expect(find.textContaining('gezählt'), findsWidgets);
    expect(find.textContaining('vom Bildrand abgeschnitten'), findsOneWidget);
    expect(find.textContaining('0,4 mm neben dem Punkt'), findsOneWidget);
    // From the history the dart is only shown, not corrected.
    expect(find.byKey(const ValueKey('throw-views-correct')), findsNothing);
  });

  testWidgets('without an engine the views say where they come from', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final statistics = Statistics(
      MemoryGameStore([
        recordWith([DartThrow(const BoardPoint(0, 103), ThrowInput.engine, engineThrowId: 's/1', confidence: 0.9)]),
      ]),
      MemoryProfileStore(['Anna']),
    );
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await openGameDarts(tester);
    await tester.tap(find.byKey(const ValueKey('game-dart-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('throw-views-message')), findsOneWidget);
    expect(find.textContaining('Verbinde dich mit der Engine'), findsOneWidget);
  });

  testWidgets('in a game, a detected dart opens its views and can be corrected from there', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine, statistics: statistics));
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpAndSettle();
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    await tester.tap(find.text('301'));
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    engine.receiveForTest(
      jsonEncode({
        'type': 'throw',
        'throw_id': 's/4',
        'accepted': true,
        'board_point': {'x_mm': 0.0, 'y_mm': 103.0, 'covariance_mm2': null},
        'confidence': 0.9,
      }),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recent-0')));
    await tester.pumpAndSettle();
    engine.receiveForTest(jsonEncode(throwViewsJson('s/4')));
    await tester.tap(find.byKey(const ValueKey('open-throw-views')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('throw-view-usb-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('throw-views-correct')));
    await tester.pumpAndSettle();
    // Back in the game, correcting that dart
    expect(find.byKey(const ValueKey('open-throw-views')), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('recent-0'))).selected, isTrue);
  });
}
