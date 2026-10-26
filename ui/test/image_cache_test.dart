import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';
import 'preview_test.dart' show hello, previewMessage, tinyJpeg;

void main() {
  testWidgets('live camera frames do not pile up in the image cache', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final cache = PaintingBinding.instance.imageCache..clear();
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('settings-cameras')));
    await tester.pumpAndSettle();

    for (var i = 1; i <= 30; ++i) {
      engine.receiveForTest(previewMessage('usb-1', i, tinyJpeg));
      await tester.pump();
      await tester.pump();
    }
    final held = cache.currentSize + cache.pendingImageCount + cache.liveImageCount;
    debugPrint(
      'IMAGES held $held (cached ${cache.currentSize}, pending ${cache.pendingImageCount}, live ${cache.liveImageCount})',
    );
    // The frame on screen and the one being decoded, not every frame since the page opened
    expect(held, lessThanOrEqualTo(2));
  });
}
