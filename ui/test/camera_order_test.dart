import 'dart:convert';

import 'package:dartpilot/l10n/app_localizations_de.dart';
import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/camera_order.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';
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

    // New cameras are a setup step: the settings show it, home does not.
    expect(find.byKey(const ValueKey('assign-cameras-prompt')), findsNothing);
    await openSettingsPage(tester, 'cameras');
    expect(
      find.descendant(of: find.byKey(const ValueKey('settings-assign-cameras')), matching: find.text('Fehlt')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('settings-assign-cameras')));
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
    expect(
      find.descendant(of: find.byKey(const ValueKey('settings-assign-cameras')), matching: find.text('Erledigt')),
      findsOneWidget,
    );
  });

  testWidgets('the assignment page follows cameras that come and asks before dropping changes', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    final order = CameraOrder(MemoryCameraOrderStore());
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine, cameraOrder: order));
    engine.receiveForTest(jsonEncode(hello));
    await openSettingsPage(tester, 'cameras');
    await tester.tap(find.byKey(const ValueKey('settings-assign-cameras')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-down-usb-1')));
    await tester.pumpAndSettle();

    // A third camera appears; the player's order of the first two stays.
    final cameras = [
      ...hello['cameras']! as List<Object?>,
      {'id': 'usb-3', 'name': 'Camera 3', 'state': 'ok'},
    ];
    engine.receiveForTest(jsonEncode({...hello, 'cameras': cameras}));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('assign-number-usb-2'))).data, '1');
    expect(tester.widget<Text>(find.byKey(const ValueKey('assign-number-usb-3'))).data, '3');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Geänderte Reihenfolge und Namen verwerfen?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assign-save')), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verwerfen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assign-save')), findsNothing);
  });

  testWidgets('an engine that keeps the assignment is the source on every display', (tester) async {
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    // This device assigned the cameras before the engine kept them: that assignment goes to the engine once.
    final order = CameraOrder(MemoryCameraOrderStore(['usb-2', 'usb-1'], {'usb-2': 'Links'}));
    await order.load();
    order.attach(engine);
    engine.receiveForTest(jsonEncode(hello));
    engine.receiveForTest(
      jsonEncode({
        'type': 'camera_assignment',
        'cameras': [
          {'id': 'usb-1', 'order': null, 'label': null},
          {'id': 'usb-2', 'order': null, 'label': null},
        ],
      }),
    );
    expect(sent.last['type'], 'set_camera_assignment');
    expect(
      sent.last['cameras'],
      containsAll([
        {'id': 'usb-2', 'order': 1, 'label': 'Links'},
        {'id': 'usb-1', 'order': 2, 'label': null},
      ]),
    );

    // What the engine then keeps counts, also for names this device never had.
    engine.receiveForTest(
      jsonEncode({
        'type': 'camera_assignment',
        'cameras': [
          {'id': 'usb-1', 'order': 1, 'label': 'Oben'},
          {'id': 'usb-2', 'order': 2, 'label': 'Links'},
        ],
      }),
    );
    expect(order.sorted(['usb-1', 'usb-2']), ['usb-1', 'usb-2']);
    expect(order.label(l10n, ['usb-1', 'usb-2'], 'usb-1'), 'Oben');
    expect(order.needsAssignment(['usb-1', 'usb-2']), isFalse);

    // A swap from this display goes to the engine, not into the device's store.
    order.assign(['usb-2', 'usb-1'], {});
    expect(sent.last['type'], 'set_camera_assignment');
    expect(
      sent.last['cameras'],
      containsAll([
        {'id': 'usb-2', 'order': 1, 'label': 'Links'},
        {'id': 'usb-1', 'order': 2, 'label': 'Oben'},
      ]),
    );
  });
}
