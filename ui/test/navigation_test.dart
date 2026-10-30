import 'dart:convert';
import 'dart:io';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_choice.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/engine_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'navigation.dart';
import 'preview_test.dart' show hello;

void main() {
  testWidgets('the first page asks how darts are counted, then home and settings; disconnecting keeps home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);

    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await tester.pumpAndSettle();
    expect(find.text('Wie werden die Darts gezählt?'), findsOneWidget);
    expect(find.text('Von Hand'), findsOneWidget);
    expect(find.text('Mit Kameras über das Netzwerk'), findsOneWidget);
    // The search and its caveats wait until the network is picked.
    expect(find.text('Suche im Netzwerk…'), findsNothing);
    expect(find.text('Spielen'), findsNothing);

    // An engine says hello: the main view with the navigation bar of a phone.
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Kamera-Erkennung verbunden (simulierte Darts)'), findsOneWidget);
    expect(find.text('Statistik'), findsOneWidget);
    // Without a profile, home asks for one first; online play is not offered before it exists.
    expect(find.text('Wer spielt?'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Spielen'), 200);
    expect(find.text('Zusammen spielen'), findsNothing);

    // A missing calibration is a setup step: one line on home leads to it, not the detection state.
    engine.receiveForTest(
      jsonEncode({'type': 'engine_status', 'detection': 'unavailable', 'message': 'not_calibrated'}),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detection-state'), skipOffstage: false), findsNothing);
    engine.receiveForTest(jsonEncode({'type': 'engine_status', 'detection': 'running', 'message': ''}));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detection-state')), findsNothing);

    await openSettings(tester);
    expect(find.byKey(const ValueKey('settings-page-display')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-page-sound')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-page-cameras')));
    await tester.pumpAndSettle();
    expect(find.text('Verbunden mit einer Engine im Netzwerk'), findsOneWidget);
    await showSettingsEntry(tester, 'settings-cameras');
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('settings-cameras'))).enabled, isTrue);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('settings-disconnect')), -200);
    await tester.tap(find.byKey(const ValueKey('settings-disconnect')));
    await tester.pumpAndSettle();
    // Darts go in by hand now; the camera rows give way to one line.
    expect(find.text('Wie werden die Darts gezählt?'), findsNothing);
    expect(find.byKey(const ValueKey('settings-cameras'), skipOffstage: false), findsNothing);
    expect(find.byKey(const ValueKey('settings-cameras-optional'), skipOffstage: false), findsOneWidget);
  });

  testWidgets('by hand, home says so, the settings show what a hand player uses, and cameras can be connected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DartPilotApp(locale: Locale('en')));
    await playOffline(tester);
    // Wide screens get a rail at the side.
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Darts by hand – no cameras connected'), findsOneWidget);
    expect(find.byKey(const ValueKey('lobby')), findsNothing);

    await openSettings(tester);
    expect(find.text('Darts by hand – cameras are optional'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-page-cameras')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-diagnosis')), findsNothing);
    expect(find.byKey(const ValueKey('settings-cameras-optional')), findsOneWidget);

    // Connecting leads to the choice, which can be left again unchanged.
    await tester.tap(find.byKey(const ValueKey('settings-connect')));
    await tester.pumpAndSettle();
    expect(find.text('How are the darts counted?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('connect-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  test('the choice of how darts are counted survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await EngineSettings.load();
    expect(first.chosen, isFalse);
    first.choose(byHand: true);
    await Future<void>.delayed(Duration.zero);
    final byHand = await EngineSettings.load();
    expect((byHand.chosen, byHand.byHand), (true, true));

    // Whoever stored a mode before chose already.
    SharedPreferences.setMockInitialValues({'engine.mode': 'network', 'engine.url': 'ws://10.0.0.5:8484/'});
    final network = await EngineSettings.load();
    expect((network.chosen, network.byHand, network.mode), (true, false, EngineMode.network));

    // Where the engine program is at hand, this device is the first offer.
    SharedPreferences.setMockInitialValues({});
    expect((await EngineSettings.load(localEngine: true)).mode, EngineMode.thisDevice);
  });

  testWidgets('a remembered network engine opens on home and is reached in the background', (tester) async {
    final network = EngineSettings(chosen: true, url: 'ws://10.0.0.5:8484/', store: false);
    // On start, home opens at once and the remembered engine is reached in the background.
    final connected = <Uri>[];
    final engine = EngineConnection(
      connector: (uri) {
        connected.add(uri);
        throw const SocketException('no engine in tests');
      },
      discovery: EngineDiscovery(const []),
    );
    addTearDown(engine.dispose);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), settings: network, engine: engine));
    await tester.pumpAndSettle();
    expect(find.text('Wie werden die Darts gezählt?'), findsNothing);
    expect(connected, [Uri.parse('ws://10.0.0.5:8484/')]);
    // Out of reach: home says darts go in by hand meanwhile, and offers another try.
    expect(find.text('Kamera-Erkennung nicht erreichbar – trag die Darts von Hand ein'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-retry')));
    await tester.pumpAndSettle();
    expect(connected, hasLength(2));
  });

  testWidgets('back leads home and never out of the app', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await openSettings(tester);
    expect(find.byKey(const ValueKey('settings-page-cameras')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(find.text('Wie werden die Darts gezählt?'), findsNothing);
  });

  testWidgets('the open tab stays open when the connection drops and comes back', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await openSettings(tester);

    await engine.disconnect();
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);
  });
}
