import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/engine_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const living = FoundEngine(
  id: 'ABC',
  name: 'Dartboard living room',
  host: '192.168.1.20',
  port: 8484,
  protocol: 'dartpilot/1.0',
  version: '0.2.0',
  mode: 'live',
);
const future = FoundEngine(id: 'XYZ', name: 'Basement', host: '192.168.1.30', port: 8484, protocol: 'dartpilot/2.0');

DiscoverySource fixed(List<FoundEngine> engines) =>
    (_) => Stream.fromIterable(engines);

void main() {
  test('reads broadcast replies and mDNS TXT records', () {
    final reply = FoundEngine.fromReply({
      'type': 'engine',
      'id': 'ABC',
      'name': 'Board',
      'port': 8484,
      'protocol': 'dartpilot/1.0',
      'version': '0.2.0',
      'mode': 'simulate',
    }, '192.168.1.20')!;
    expect(reply.url, 'ws://192.168.1.20:8484/');
    expect(reply.compatible, isTrue);
    expect(FoundEngine.fromReply({'type': 'discover'}, 'x'), isNull);
    expect(future.compatible, isFalse);

    final txt = parseTxt(['protocol=dartpilot/1.0\nname=Kitchen=left\nid=K1', 'mode=live']);
    expect(txt['name'], 'Kitchen=left');
    final engine = FoundEngine.fromTxt(txt, 'fe80::1', 9000);
    expect(engine.url, 'ws://[fe80::1]:9000/');
    expect(engine.key, 'K1');
    expect(FoundEngine.fromTxt(const {}, '10.0.0.2', 8484).key, '10.0.0.2:8484');
  });

  test('picks the engine address in this device\'s network, not a virtual bridge', () {
    final engine = [InternetAddress('192.168.122.1'), InternetAddress('192.168.1.20')];
    expect(pickAddress(engine, [InternetAddress('192.168.1.57')]), '192.168.1.20');
    expect(pickAddress(engine, [InternetAddress('10.0.0.3')]), '192.168.122.1');
  });

  test('a broadcast search gets the answer of an engine', () async {
    final engine = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(engine.close);
    final requests = <Map<String, dynamic>>[];
    engine.listen((event) {
      final datagram = engine.receive();
      if (datagram == null) return;
      requests.add(jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>);
      final reply = {'type': 'engine', 'id': 'E1', 'name': 'Test', 'port': 8484, 'protocol': 'dartpilot/1.0'};
      engine.send(utf8.encode(jsonEncode(reply)), datagram.address, datagram.port);
    });

    final search = broadcastSearch(target: InternetAddress.loopbackIPv4, port: engine.port);
    final found = await search(const Duration(milliseconds: 600)).toList();
    expect(requests.first, {'type': 'discover', 'protocol': 'dartpilot/1.0'});
    // Asked twice; both answers arrive, the discovery lists the engine once.
    expect(found.map((e) => e.id).toSet(), {'E1'});
    expect(found.first.host, '127.0.0.1');
  });

  test('merges sources, lists each engine once and survives a failing source', () async {
    Stream<FoundEngine> failing(Duration _) => Stream.error(const SocketException('port in use'));
    final discovery = EngineDiscovery([
      fixed([living]),
      failing,
      fixed([
        const FoundEngine(id: 'ABC', name: 'same', host: 'board.local', port: 8484, protocol: 'dartpilot/1.0'),
        future,
      ]),
    ]);
    final results = await discovery.search().toList();
    expect(results.last.map((e) => e.name), ['Dartboard living room', 'Basement']);
    expect(await EngineDiscovery(const []).search().toList(), isEmpty);
  });

  testWidgets('the engine card lists found engines and connects to one', (tester) async {
    final searches = StreamController<FoundEngine>();
    final connected = <Uri>[];
    final engine = EngineConnection(
      connector: (uri) {
        connected.add(uri);
        throw const SocketException('no engine in tests');
      },
      discovery: EngineDiscovery([(_) => searches.stream]),
    );
    addTearDown(engine.dispose);

    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await tester.tap(find.byKey(const ValueKey('engine-search')));
    await tester.pump();
    expect(find.text('Suche im Netzwerk…'), findsOneWidget);

    searches
      ..add(living)
      ..add(future);
    await tester.pump();
    expect(find.text('Engines im Netzwerk'), findsOneWidget);
    expect(find.textContaining('192.168.1.20:8484  ·  0.2.0'), findsOneWidget);
    expect(find.textContaining('inkompatibel (dartpilot/2.0)'), findsOneWidget);

    // An incompatible engine cannot be chosen.
    await tester.tap(find.byKey(const ValueKey('found-XYZ')));
    await tester.pump();
    expect(connected, isEmpty);

    await tester.tap(find.byKey(const ValueKey('found-ABC')));
    await tester.pump();
    expect(connected, [Uri.parse('ws://192.168.1.20:8484/')]);
    expect(engine.url, 'ws://192.168.1.20:8484/');

    await searches.close();
    await tester.pumpAndSettle();
  });

  testWidgets('an empty search says why it may find nothing', (tester) async {
    final engine = EngineConnection(
      connector: (uri) => WebSocketChannel.connect(uri),
      discovery: EngineDiscovery([fixed(const [])]),
    );
    addTearDown(engine.dispose);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('en'), engine: engine));
    await tester.tap(find.byKey(const ValueKey('engine-search')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No engine found'), findsOneWidget);
  });
}
