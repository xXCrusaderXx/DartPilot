import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/engine_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 1x1 grey JPEG
final Uint8List tinyJpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/9oACAEBAAA/APvT/9k=',
);

Uint8List previewMessage(String camera, int sequence, Uint8List jpeg) {
  final header = utf8.encode(
    jsonEncode({'camera': camera, 'sequence': sequence, 'exposure_ns': 1, 'width': 1, 'height': 1}),
  );
  final length = ByteData(4)..setUint32(0, header.length, Endian.little);
  return Uint8List.fromList([...length.buffer.asUint8List(), ...header, ...jpeg]);
}

const hello = {
  'type': 'hello',
  'protocol': 'dartpilot/1.0',
  'mode': 'simulate',
  'board_geometry': {
    'bull_radius_mm': 6.35,
    'outer_bull_radius_mm': 15.9,
    'triple_inner_radius_mm': 99.0,
    'triple_outer_radius_mm': 107.0,
    'double_inner_radius_mm': 162.0,
    'double_outer_radius_mm': 170.0,
    'wire_rotation_deg': 0.0,
    'source': 'nominal',
  },
  'cameras': [
    {'id': 'usb-1', 'name': 'A', 'state': 'ok'},
    {'id': 'usb-2', 'name': 'B', 'state': 'ok'},
  ],
  'detection': 'running',
};

void main() {
  test('parses a preview message and rejects broken ones', () {
    final frame = PreviewFrame.parse(previewMessage('usb-1', 7, tinyJpeg))!;
    expect(frame.camera, 'usb-1');
    expect(frame.sequence, 7);
    expect(frame.jpeg, tinyJpeg);
    expect(PreviewFrame.parse(Uint8List.fromList([200, 0, 0, 0, 1, 2])), isNull);
    expect(PreviewFrame.parse(Uint8List(2)), isNull);
  });

  testWidgets('the camera page shows each camera with its image and state', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final engine = EngineConnection();
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(hello));

    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kameras'));
    await tester.pumpAndSettle();
    expect(find.text('Warte auf das erste Bild…'), findsNWidgets(2));

    engine.receiveForTest(previewMessage('usb-2', 1, tinyJpeg));
    // Stream events arrive in a microtask; the second pump builds with the frame.
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('preview-usb-2')), findsOneWidget);
    expect(find.text('Warte auf das erste Bild…'), findsOneWidget);

    engine.receiveForTest(jsonEncode({'type': 'camera_status', 'camera': 'usb-1', 'state': 'lost'}));
    await tester.pump();
    expect(find.text('usb-1 · Verloren'), findsOneWidget);
  });
}
