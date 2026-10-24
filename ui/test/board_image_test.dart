import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/dartboard.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/engine_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_check_test.dart' show boardState;
import 'preview_test.dart' show hello, tinyJpeg;

Map<String, dynamic> boardImageJson() => {
  'type': 'board_image',
  'image_size_px': [600, 600],
  'mm_per_px': 250 / 300,
  'radius_mm': 250.0,
  'jpeg_base64': base64Encode(tinyJpeg),
};

void main() {
  test('asks for the board image on an empty board at connect and after every takeout', () {
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode({...hello, 'board_state': boardState('occupied')}));
    expect(sent.where((r) => r['type'] == 'get_board_image'), isEmpty);
    engine.receiveForTest(jsonEncode({'type': 'board_state', ...boardState('empty')}));
    expect(sent.last, {'type': 'get_board_image'});

    engine.receiveForTest(jsonEncode(boardImageJson()));
    expect(engine.boardImage!.radiusMm, 250);
    expect(engine.boardImage!.jpeg, tinyJpeg);

    sent.clear();
    engine.receiveForTest(jsonEncode({'type': 'takeout', 'darts_removed': 3}));
    expect(sent.single, {'type': 'get_board_image'});
  });

  testWidgets('the board shows the real board under the throws; taps still give board points', (tester) async {
    final image = BoardImage.fromJson(boardImageJson());
    final taps = <BoardPoint>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            height: 400,
            child: Dartboard(image: image, onTap: taps.add),
          ),
        ),
      ),
    );
    final picture = tester.getRect(find.byKey(const ValueKey('board-image')));
    // 400 px for 2 × 200 mm: 1 px per mm, so the image of radius 250 mm is 500 px wide, centred.
    expect(picture.size, const Size(500, 500));
    expect(picture.center, tester.getCenter(find.byType(Dartboard)));
    await tester.tapAt(tester.getCenter(find.byType(Dartboard)) + const Offset(0, -103));
    expect(taps.single.yMm, closeTo(103, 0.01));
  });

  testWidgets('without an image the drawn board stays', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
    await tester.tap(find.byKey(const ValueKey('play-offline')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Freies Werfen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dartboard')), findsOneWidget);
    expect(find.byKey(const ValueKey('board-image')), findsNothing);
  });
}
