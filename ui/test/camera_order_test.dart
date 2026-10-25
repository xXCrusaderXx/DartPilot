import 'dart:convert';

import 'package:dartpilot/l10n/app_localizations_de.dart';
import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/camera_order.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'preview_test.dart' show hello;

void main() {
  final l10n = AppLocalizationsDe();

  test('the player order comes first, new cameras follow, and names replace the number', () async {
    final store = MemoryCameraOrderStore(['usb-3', 'usb-1'], {'usb-3': 'Links'});
    final order = CameraOrder(store);
    await order.load();
    const cameras = ['usb-1', 'usb-2', 'usb-3'];
    expect(order.sorted(cameras), ['usb-3', 'usb-1', 'usb-2']);
    expect(order.needsAssignment(cameras), isTrue);
    expect(order.label(l10n, cameras, 'usb-3'), 'Links');
    expect(order.label(l10n, cameras, 'usb-1'), 'Kamera 2');
    expect(order.label(l10n, cameras, 'usb-2'), 'Kamera 3');

    // A swap of the two connected cameras; usb-3, not connected now, keeps its place behind them.
    await order.assign(['usb-2', 'usb-1'], {'usb-1': '  ', 'usb-2': 'Oben'});
    expect(store.order, ['usb-2', 'usb-1', 'usb-3']);
    expect(store.names, {'usb-3': 'Links', 'usb-2': 'Oben'});
    expect(order.needsAssignment(['usb-1', 'usb-2']), isFalse);
  });

  testWidgets('new cameras are assigned from home, swapped and named', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    final store = MemoryCameraOrderStore();
    final order = CameraOrder(store);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine, cameraOrder: order));
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('assign-cameras-prompt')), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('assign-cameras-prompt')), matching: find.byType(FilledButton)),
    );
    await tester.pumpAndSettle();
    // Every camera shows its live image.
    expect(sent.where((r) => r['type'] == 'subscribe_preview').map((r) => r['camera']).toSet(), {'usb-1', 'usb-2'});
    expect(tester.widget<Text>(find.byKey(const ValueKey('assign-number-usb-1'))).data, '1');

    await tester.tap(find.byKey(const ValueKey('assign-down-usb-1')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('assign-number-usb-2'))).data, '1');
    await tester.enterText(find.byKey(const ValueKey('assign-name-usb-1')), 'Links');
    await tester.tap(find.byKey(const ValueKey('assign-save')));
    await tester.pumpAndSettle();

    expect(store.order, ['usb-2', 'usb-1']);
    expect(store.names, {'usb-1': 'Links'});
    expect(find.byKey(const ValueKey('assign-cameras-prompt')), findsNothing);
  });
}
