import 'dart:convert';
import 'dart:io';

import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/engine_events.dart';
import 'package:flutter_test/flutter_test.dart';

const helloJson = {
  'type': 'hello',
  'protocol': 'dartpilot/1.0',
  'mode': 'simulate',
  'board_geometry': {
    'bull_radius_mm': 6.35,
    'outer_bull_radius_mm': 15.4,
    'triple_inner_radius_mm': 99.0,
    'triple_outer_radius_mm': 107.0,
    'double_inner_radius_mm': 162.0,
    'double_outer_radius_mm': 170.0,
    'wire_rotation_deg': 0.0,
    'source': 'measured',
  },
  'cameras': [
    {'id': 'sim-1', 'name': 'Simulated camera 1', 'state': 'ok'},
  ],
  'detection': 'running',
};

void main() {
  test('parses engine messages and ignores unknown ones', () {
    final hello = EngineEvent.fromJson(helloJson) as EngineHello;
    expect(hello.geometry.outerBullRadiusMm, 15.4);
    expect(hello.cameras, ['sim-1']);

    final abstain = EngineEvent.fromJson({
      'type': 'throw',
      'throw_id': 's/4',
      'accepted': false,
      'board_point': null,
      'confidence': 0.4,
      'reason': 'occluded',
    }) as EngineThrow;
    expect(abstain.accepted, isFalse);
    expect(abstain.point, isNull);
    expect(abstain.reason, 'occluded');
    expect(EngineEvent.fromJson({'type': 'something_new'}), isNull);
    expect((EngineEvent.fromJson({'type': 'takeout', 'darts_removed': 3}) as EngineTakeout).dartsRemoved, 3);
  });

  test('talks to an engine over a real WebSocket', () async {
    final received = <Map<String, dynamic>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.transform(WebSocketTransformer()).listen((socket) {
      socket.add(jsonEncode(helloJson));
      socket.listen((message) {
        received.add(jsonDecode(message as String) as Map<String, dynamic>);
        socket.add(
          jsonEncode({
            'type': 'throw',
            'throw_id': 's/1',
            'accepted': true,
            'board_point': {'x_mm': 0.0, 'y_mm': 103.0, 'covariance_mm2': null},
            'confidence': 0.9,
          }),
        );
      });
    });

    final engine = EngineConnection();
    final events = <EngineEvent>[];
    engine.events.listen(events.add);
    await engine.connect('ws://127.0.0.1:${server.port}/');
    await Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return events.whereType<EngineThrow>().isEmpty;
    }).timeout(const Duration(seconds: 5));

    expect(engine.isConnected, isTrue);
    expect(engine.geometry.outerBullRadiusMm, 15.4);
    expect(received.first['type'], 'hello');
    expect(received.first['client'], engine.clientName);
    expect(events.whereType<EngineThrow>().single.point!.yMm, 103.0);

    engine.correctThrow('s/1', const BoardPoint(1, 2));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received.last['type'], 'correct_throw');
    expect(received.last['board_point'], {'x_mm': 1.0, 'y_mm': 2.0});

    await engine.disconnect();
    expect(engine.state, EngineConnectionState.disconnected);
    await server.close(force: true);
  });

  test('a request fails with disconnected when the engine goes away, and its state is dropped', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    WebSocket? engineSide;
    server.transform(WebSocketTransformer()).listen((socket) {
      engineSide = socket;
      socket.add(jsonEncode(helloJson));
      socket.listen((_) {});
    });

    final engine = EngineConnection();
    await engine.connect('ws://127.0.0.1:${server.port}/');
    await Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return !engine.isConnected;
    }).timeout(const Duration(seconds: 5));
    expect(engine.hello, isNotNull);

    final result = engine.startDiagnosis();
    await engineSide!.close();
    expect(await result.timeout(const Duration(seconds: 5)), 'disconnected');
    expect(engine.state, EngineConnectionState.disconnected);
    expect(engine.hello, isNull);
    expect(engine.cameraStatus, isEmpty);

    expect(await engine.startDiagnosis(), 'disconnected');
    await engine.disconnect();
    await server.close(force: true);
  });

  testWidgets('a request without a result times out', (tester) async {
    final engine = EngineConnection.forTest((_) {}, requestTimeout: EngineConnection.defaultRequestTimeout);
    String? code;
    engine.startDiagnosis().then((c) => code = c);
    await tester.pump(EngineConnection.defaultRequestTimeout - const Duration(seconds: 1));
    expect(code, isNull);
    await tester.pump(const Duration(seconds: 2));
    expect(code, 'timeout');
  });

  test('after the engine went away the app connects again by itself, until the player disconnects', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    server.transform(WebSocketTransformer()).listen((socket) {
      sockets.add(socket);
      socket.add(jsonEncode(helloJson));
      socket.listen((_) {});
    });
    Future<void> until(bool Function() condition) => Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return !condition();
    }).timeout(const Duration(seconds: 5));

    final engine = EngineConnection();
    await engine.connect('ws://127.0.0.1:${server.port}/');
    await until(() => engine.isConnected);

    await sockets.single.close();
    await until(() => engine.reconnecting);
    expect(engine.isConnected, isFalse);
    await until(() => engine.isConnected);
    expect(engine.reconnecting, isFalse);
    expect(sockets, hasLength(2));

    await engine.disconnect();
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(sockets, hasLength(2));
    expect(engine.reconnecting, isFalse);
    await server.close(force: true);
  });
}
