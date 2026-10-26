import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'preview_test.dart' show hello;

void main() {
  testWidgets('engine events during a game do not rebuild the pages behind it', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Freies Werfen'));
    await tester.pumpAndSettle();

    final rebuilt = <String, int>{};
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      final name = element.widget.runtimeType.toString();
      rebuilt[name] = (rebuilt[name] ?? 0) + 1;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    for (var i = 0; i < 20; ++i) {
      engine.receiveForTest(
        jsonEncode({'type': 'camera_status', 'camera': 'usb-1', 'state': 'ok', 'effective_fps': 30.0 - i / 10}),
      );
      await tester.pump();
    }
    debugPrint('REBUILDS total ${rebuilt.values.fold(0, (a, b) => a + b)}: $rebuilt');
    for (final page in ['RootScreen', 'MainShell', 'HomeScreen', 'SettingsScreen', 'StatisticsScreen']) {
      expect(rebuilt[page] ?? 0, 0, reason: page);
    }
  });
}
