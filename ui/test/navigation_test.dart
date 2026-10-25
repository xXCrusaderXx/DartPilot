import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';
import 'preview_test.dart' show hello;

void main() {
  testWidgets('connection page first, then home and settings; disconnecting leads back', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);

    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await tester.pumpAndSettle();
    expect(find.text('Engine verbinden'), findsOneWidget);
    expect(find.text('Lokal oder solo spielen'), findsNothing);

    // An engine says hello: the main view with the navigation bar of a phone.
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Verbunden (simuliert)'), findsOneWidget);
    // Without a profile, home asks for one first.
    expect(find.text('Wer spielt?'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Lokal oder solo spielen'), 200);
    expect(find.text('Lokal oder solo spielen'), findsOneWidget);

    // A live engine that is not calibrated says so on home.
    engine.receiveForTest(
      jsonEncode({'type': 'engine_status', 'detection': 'unavailable', 'message': 'not_calibrated'}),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('detection-state')), -200);
    expect(find.textContaining('Noch nicht kalibriert'), findsOneWidget);
    engine.receiveForTest(jsonEncode({'type': 'engine_status', 'detection': 'running', 'message': ''}));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detection-state')), findsNothing);

    await openSettings(tester);
    expect(find.text('Verbunden mit einer Engine im Netzwerk'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('settings-cameras'))).enabled, isTrue);
    await tester.tap(find.byKey(const ValueKey('settings-disconnect')));
    await tester.pumpAndSettle();
    expect(find.text('Engine verbinden'), findsOneWidget);
  });

  testWidgets('without an engine the games work and the engine tools are off', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DartPilotApp(locale: Locale('en')));
    await playOffline(tester);
    // Wide screens get a rail at the side.
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Without an engine – darts are entered by hand'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('lobby'))).enabled, isFalse);

    await openSettings(tester);
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('settings-cameras'))).enabled, isFalse);
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('open-diagnosis'))).enabled, isFalse);

    // Connect leads back to the connection page.
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Connect an engine'), findsOneWidget);
  });

  testWidgets('back leads home while connected, and from home to the connection page only without an engine', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await openSettings(tester);
    expect(find.byKey(const ValueKey('settings-connection')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    // Home with an engine: back stays on home.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(find.text('Engine verbinden'), findsNothing);
  });

  testWidgets('without an engine, back from home leads to the connection page', (tester) async {
    await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
    await playOffline(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Engine verbinden'), findsOneWidget);
  });
}
