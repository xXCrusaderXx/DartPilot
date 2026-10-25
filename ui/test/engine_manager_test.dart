import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_choice.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/engine_discovery.dart';
import 'package:dartpilot/src/engine/engine_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A child process whose output the test writes
class FakeProcess implements Process {
  final StreamController<List<int>> _stdout = StreamController();
  final StreamController<List<int>> _stderr = StreamController();
  final Completer<int> _exit = Completer();
  final List<ProcessSignal> signals = [];

  void out(String line) => _stdout.add(utf8.encode('$line\n'));
  void err(String line) => _stderr.add(utf8.encode('$line\n'));

  void exit(int code) {
    if (_exit.isCompleted) return;
    _stdout.close();
    _stderr.close();
    _exit.complete(code);
  }

  @override
  Stream<List<int>> get stdout => _stdout.stream;
  @override
  Stream<List<int>> get stderr => _stderr.stream;
  @override
  Future<int> get exitCode => _exit.future;
  @override
  int get pid => 4242;
  @override
  IOSink get stdin => throw UnimplementedError();
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    signals.add(signal);
    exit(-15);
    return true;
  }
}

void main() {
  // Any existing file other than the app itself stands in for the engine program.
  late final String program;
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('dartpilot-engine');
    program = (await File('${dir.path}/dartpilot').writeAsString('… Usage: dartpilot serve --simulate …')).path;
  });

  test('starts the engine, reports its address once it listens, and stops it', () async {
    final process = FakeProcess();
    final calls = <List<String>>[];
    final manager = EngineManager(
      start: (exe, args) async {
        calls.add([exe, ...args]);
        return process;
      },
      findEngine: () => program,
      freePort: () async => 8500,
    );
    final started = manager.start();
    await Future<void>.delayed(Duration.zero);
    expect(manager.state, LocalEngineState.starting);
    // Live detection on the cameras by default
    expect(calls.single, [program, 'serve', '--cameras', '--port', '8500']);

    process.out('Engine API (simulated darts, real cameras) on ws://127.0.0.1:8500/ - Ctrl+C to stop');
    expect(await started, 'ws://127.0.0.1:8500/');
    expect(manager.state, LocalEngineState.running);
    expect(manager.log.last, contains('on ws://127.0.0.1:8500/'));

    await manager.stop();
    expect(process.signals, [ProcessSignal.sigterm]);
    expect(manager.state, LocalEngineState.stopped);
    expect(manager.error, isNull);
  });

  test('tells why the engine did not start', () async {
    final missing = EngineManager(findEngine: () => null);
    expect(await missing.start(), isNull);
    expect(missing.error, LocalEngineError.notFound);

    final process = FakeProcess();
    final manager = EngineManager(
      start: (_, args) async => process,
      findEngine: () => program,
      freePort: () async => 8484,
    );
    final started = manager.start(cameras: true);
    await Future<void>.delayed(Duration.zero);
    process.err('No camera could be started.');
    await Future<void>.delayed(Duration.zero);
    process.exit(1);
    expect(await started, isNull);
    expect(manager.state, LocalEngineState.failed);
    expect(manager.error, LocalEngineError.noCameras);
    expect(manager.log.last, 'Engine exited with code 1');
  });

  test(
    'simulated darts are an option, with or without the cameras; an engine without live detection says so',
    () async {
      final calls = <List<String>>[];
      final process = FakeProcess();
      final manager = EngineManager(
        start: (_, args) async {
          calls.add(args);
          return process;
        },
        findEngine: () => program,
        freePort: () async => 8484,
      );
      final first = manager.start(simulate: true, cameras: false);
      await Future<void>.delayed(Duration.zero);
      expect(calls.last, ['serve', '--simulate', '--port', '8484']);
      process.err('Live detection is not available yet; use --simulate.');
      await Future<void>.delayed(Duration.zero);
      process.exit(2);
      expect(await first, isNull);
      expect(manager.error, LocalEngineError.liveUnavailable);
    },
  );

  test('shared, the engine listens on the network and the app connects through the loopback address', () async {
    final calls = <List<String>>[];
    final process = FakeProcess();
    final manager = EngineManager(
      start: (_, args) async {
        calls.add(args);
        return process;
      },
      findEngine: () => program,
      freePort: () async => 8484,
    );
    final started = manager.start(share: true);
    await Future<void>.delayed(Duration.zero);
    expect(calls.single, ['serve', '--cameras', '--listen', '0.0.0.0', '--port', '8484']);
    process.out('Engine API (live) on ws://0.0.0.0:8484/ - Ctrl+C to stop');
    expect(await started, 'ws://127.0.0.1:8484/');
    expect(manager.port, 8484);
    await manager.stop();
  });

  test('never starts the app itself, which would start the app again and again', () async {
    var started = 0;
    final manager = EngineManager(
      start: (_, _) async {
        started++;
        return FakeProcess();
      },
      findEngine: () => Platform.resolvedExecutable,
      freePort: () async => 8484,
    );
    expect(await manager.start(), isNull);
    expect(started, 0);
    expect(manager.error, LocalEngineError.notFound);
    expect(manager.log.last, contains('Not the engine program'));
    expect(isOwnExecutable(Platform.resolvedExecutable), isTrue);
    expect(isOwnExecutable(program), isFalse);
    expect(looksLikeEngine(program), isTrue);
    expect(looksLikeEngine(Platform.resolvedExecutable), isFalse);
  });

  test('a program that never says it listens is stopped after the timeout', () async {
    final process = FakeProcess();
    final manager = EngineManager(
      start: (_, _) async => process,
      findEngine: () => program,
      freePort: () async => 8484,
      readyTimeout: const Duration(milliseconds: 50),
    );
    expect(await manager.start(), isNull);
    expect(process.signals, [ProcessSignal.sigkill]);
    expect(manager.state, LocalEngineState.failed);
    expect(manager.error, LocalEngineError.noAnswer);
  });

  test('a free port is 8484 when nobody uses it, another one otherwise', () async {
    final blocker = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      8484,
    ).then<ServerSocket?>((s) => s, onError: (_) => null);
    addTearDown(() => blocker?.close());
    final port = await findFreePort();
    expect(port, isNot(8484));
    expect(port, greaterThan(0));
  });

  testWidgets('the engine card starts the engine on this device and connects to it', (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final process = FakeProcess();
    final manager = EngineManager(
      start: (_, args) async => process,
      findEngine: () => program,
      freePort: () async => 8500,
    );
    final connected = <Uri>[];
    final engine = EngineConnection(
      connector: (uri) {
        connected.add(uri);
        throw const SocketException('no engine in tests');
      },
      discovery: EngineDiscovery(const []),
    );
    addTearDown(engine.dispose);
    addTearDown(manager.dispose);
    final settings = EngineSettings(mode: EngineMode.thisDevice);

    await tester.pumpWidget(
      DartPilotApp(locale: const Locale('de'), engine: engine, manager: manager, settings: settings),
    );
    expect(find.text('Die Engine auf diesem Gerät ist gestoppt.'), findsOneWidget);
    expect(find.text('Engine-Adresse'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('local-engine-start')));
    await tester.pump();
    expect(find.text('Engine startet…'), findsOneWidget);
    process.out('Engine API (simulated darts, real cameras) on ws://127.0.0.1:8500/ - Ctrl+C to stop');
    await tester.pump();
    await tester.pump();
    expect(find.text('Die Engine läuft auf diesem Gerät (ws://127.0.0.1:8500/).'), findsOneWidget);
    expect(connected, [Uri.parse('ws://127.0.0.1:8500/')]);

    // Switching to the network stops the engine this app started and offers the address again.
    await tester.tap(find.text('Im Netzwerk'));
    await tester.pumpAndSettle();
    expect(process.signals, [ProcessSignal.sigterm]);
    expect(find.text('Engine-Adresse'), findsOneWidget);
    expect(settings.mode, EngineMode.network);
    expect((await SharedPreferences.getInstance()).getString('engine.mode'), 'network');
  });

  test('the choice survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    await (EngineSettings(
      mode: EngineMode.thisDevice,
      url: 'ws://10.0.0.5:8484/',
      cameras: false,
    )..executable = '/opt/dartpilot/dartpilot').save();
    final loaded = await EngineSettings.load();
    expect(loaded.mode, EngineMode.thisDevice);
    expect(loaded.url, 'ws://10.0.0.5:8484/');
    expect(loaded.cameras, isFalse);
    expect(loaded.executable, '/opt/dartpilot/dartpilot');
  });
}
