import 'dart:convert';

import 'package:dartpilot/l10n/app_localizations.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/widgets/overlay_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'preview_test.dart' show hello, previewMessage, tinyJpeg;

void main() {
  testWidgets('taps come back in the camera\'s full-image pixels, and drawings go the other way', (tester) async {
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(hello));
    final taps = <Offset>[];
    double? paintedScale;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EngineScope(
          connection: engine,
          child: Center(
            child: SizedBox(
              width: 320,
              child: OverlayPreview(
                camera: 'usb-1',
                imageSizePx: const Size(1280, 720),
                onTapImagePx: taps.add,
                paint: (canvas, size, scale) => paintedScale = scale,
              ),
            ),
          ),
        ),
      ),
    );
    // A 1×1 preview frame stands in for the camera's scaled JPEG.
    engine.receiveForTest(previewMessage('usb-1', 1, tinyJpeg));
    await tester.pump();
    await tester.pump();

    final box = find.byKey(const ValueKey('overlay-preview-usb-1'));
    expect(tester.getSize(box), const Size(320, 180));
    await tester.tapAt(tester.getCenter(box));
    await tester.tapAt(tester.getTopLeft(box) + const Offset(80, 45));
    expect(taps, [const Offset(640, 360), const Offset(320, 180)]);
    expect(paintedScale, 0.25);
  });
}
