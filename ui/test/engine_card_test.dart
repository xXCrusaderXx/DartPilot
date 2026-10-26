import 'dart:convert';
import 'dart:io';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/engine_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a failed connection says why and can be tried again', (tester) async {
    var attempts = 0;
    final engine = EngineConnection(
      connector: (_) {
        attempts++;
        throw const SocketException('Connection refused');
      },
      discovery: EngineDiscovery(const []),
    );
    addTearDown(engine.dispose);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await tester.runAsync(() => engine.connect('ws://127.0.0.1:1/'));
    await tester.pumpAndSettle();

    expect(engine.state, EngineConnectionState.failed);
    expect(find.text('Unter dieser Adresse antwortet nichts. Läuft die Engine?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('engine-retry')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(attempts, 2);
  });

  testWidgets('a banner over every page says while the app reaches a lost engine again', (tester) async {
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    expect(find.byKey(const ValueKey('engine-reconnecting')), findsNothing);

    engine.reconnecting = true;
    engine.receiveForTest(jsonEncode({'type': 'engine_status', 'detection': 'running', 'message': ''}));
    await tester.pump();
    expect(find.text('Verbindung zur Engine verloren – verbinde neu…'), findsWidgets);
    expect(find.byKey(const ValueKey('engine-reconnecting')), findsOneWidget);
  });
}
