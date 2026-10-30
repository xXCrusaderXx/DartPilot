import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_choice.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/engine_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'navigation.dart';
import 'preview_test.dart' show hello;

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
    await openNetworkChoice(tester);
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
    expect(find.text('Verbindung zur Kamera-Erkennung verloren – verbinde neu…'), findsWidgets);
    expect(find.byKey(const ValueKey('engine-reconnecting')), findsOneWidget);
  });

  testWidgets('a drop keeps home open, and an engine that stays away can be left for darts by hand for now', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var attempts = 0;
    final incoming = StreamController<dynamic>();
    final engine = EngineConnection(
      connector: (_) {
        if (attempts++ > 0) throw const SocketException('Connection refused');
        return _FakeChannel(incoming.stream);
      },
      discovery: EngineDiscovery(const []),
    );
    addTearDown(engine.dispose);
    final settings = EngineSettings(store: false);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine, settings: settings));
    unawaited(engine.connect('ws://192.168.1.20:8484/'));
    await tester.pump();
    incoming.add(jsonEncode(hello));
    await tester.pumpAndSettle();
    expect(find.text('Kamera-Erkennung verbunden (simulierte Darts)'), findsOneWidget);

    // The engine goes away: home stays, and says it reconnects.
    await incoming.close();
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(engine.reconnecting, isTrue);
    expect(find.text('Verbindung zur Kamera-Erkennung verloren – verbinde neu…'), findsWidgets);

    // After a few tries the banner says to go on by hand. That is for now: home says calmly that darts go in by
    // hand, offers another try, and the engine stays the choice for the next start.
    for (final delay in [...EngineConnection.reconnectDelays, EngineConnection.reconnectDelays.last]) {
      await tester.pump(delay);
    }
    await tester.pump();
    expect(find.textContaining('trag die Darts von Hand ein, bis sie wieder da ist'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reconnect-stop')));
    await tester.pumpAndSettle();
    expect(engine.reconnecting, isFalse);
    expect(find.byKey(const ValueKey('engine-reconnecting')), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Kamera-Erkennung nicht erreichbar – trag die Darts von Hand ein'), findsNothing);
    expect(find.text('Darts von Hand – keine Kameras verbunden'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-retry')), findsOneWidget);
    expect(settings.chosen, isTrue);
    expect(settings.byHand, isFalse);
    expect(settings.pausedForNow, isTrue);

    // Trying again ends the pause; out of reach, home warns again.
    await tester.tap(find.byKey(const ValueKey('home-retry')));
    await tester.pumpAndSettle();
    expect(settings.pausedForNow, isFalse);
    expect(find.text('Kamera-Erkennung nicht erreichbar – trag die Darts von Hand ein'), findsOneWidget);
  });
}

/// An engine that answers with what the test feeds it, and goes away when that ends
class _FakeChannel implements WebSocketChannel {
  _FakeChannel(this.stream);

  @override
  final Stream<dynamic> stream;

  @override
  final WebSocketSink sink = _FakeSink();

  @override
  Future<void> get ready => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSink implements WebSocketSink {
  @override
  void add(dynamic data) {}

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
