// Runs the engine on this device (#105, ADR 0008): the app starts `dartpilot serve` as a child process on Linux and
// Windows, waits until it listens, keeps its log, and stops it again.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum LocalEngineState { stopped, starting, running, failed }

/// Why the engine could not start or stopped; the log has the details.
enum LocalEngineError { notFound, noCameras, portInUse, crashed }

typedef ProcessStarter = Future<Process> Function(String executable, List<String> arguments);

class EngineManager extends ChangeNotifier {
  EngineManager({ProcessStarter? start, String? Function()? findEngine, Future<int> Function()? freePort})
    : _start = start ?? Process.start,
      _findEngine = findEngine ?? findEngineExecutable,
      _freePort = freePort ?? findFreePort;

  final ProcessStarter _start;
  final String? Function() _findEngine;
  final Future<int> Function() _freePort;

  /// A child process works on desktop systems; Android runs the engine as a library (#106).
  static bool get supported => !kIsWeb && (Platform.isLinux || Platform.isWindows);

  static const int maxLogLines = 500;

  LocalEngineState state = LocalEngineState.stopped;
  LocalEngineError? error;

  /// Address the engine listens on, once it is running
  String? url;

  /// Program to run; found automatically when null
  String? executable;
  final List<String> log = [];

  Process? _process;
  Completer<String?>? _ready;

  String? get resolvedExecutable => executable ?? _findEngine();

  /// Starts the engine and completes with its address, or null if it could not start ([error] says why).
  /// Live detection does not exist yet (milestones 0.3 to 0.6), so darts are simulated; [cameras] streams the real
  /// cameras for previews, status and the board check.
  Future<String?> start({bool cameras = true}) async {
    await stop();
    final program = resolvedExecutable;
    if (program == null || !File(program).existsSync()) {
      return _failed(LocalEngineError.notFound, 'Engine program not found: ${program ?? 'dartpilot'}');
    }
    final port = await _freePort();
    state = LocalEngineState.starting;
    error = null;
    url = null;
    log.clear();
    notifyListeners();
    final arguments = ['serve', '--simulate', if (cameras) '--cameras', '--port', '$port'];
    _addLog('\$ $program ${arguments.join(' ')}');
    final ready = _ready = Completer<String?>();
    final Process process;
    try {
      process = await _start(program, arguments);
    } on ProcessException catch (e) {
      return _failed(LocalEngineError.notFound, e.message);
    }
    _process = process;
    for (final stream in [process.stdout, process.stderr]) {
      stream.transform(utf8.decoder).transform(const LineSplitter()).listen(_onLine);
    }
    unawaited(process.exitCode.then((code) => _onExit(process, code)));
    return ready.future;
  }

  static final RegExp _listening = RegExp(r'on (ws://\S+/)');

  void _onLine(String line) {
    _addLog(line);
    final match = _listening.firstMatch(line);
    if (match != null && state == LocalEngineState.starting) {
      state = LocalEngineState.running;
      url = match.group(1);
      _ready?.complete(url);
      _ready = null;
    }
    notifyListeners();
  }

  void _onExit(Process process, int code) {
    if (!identical(process, _process)) return;
    _process = null;
    if (state == LocalEngineState.stopped) return;
    _addLog('Engine exited with code $code');
    final text = log.join('\n');
    final reason = text.contains('No camera could be started')
        ? LocalEngineError.noCameras
        : text.contains('Address already in use') || text.contains('address in use')
        ? LocalEngineError.portInUse
        : LocalEngineError.crashed;
    _failed(reason, null);
  }

  String? _failed(LocalEngineError reason, String? message) {
    if (message != null) _addLog(message);
    state = LocalEngineState.failed;
    error = reason;
    url = null;
    _ready?.complete(null);
    _ready = null;
    notifyListeners();
    return null;
  }

  void _addLog(String line) {
    log.add(line);
    if (log.length > maxLogLines) log.removeRange(0, log.length - maxLogLines);
  }

  /// Stops the engine; it gets a moment to close its session before it is killed.
  Future<void> stop() async {
    final process = _process;
    _process = null;
    if (state != LocalEngineState.stopped) {
      state = LocalEngineState.stopped;
      url = null;
      _ready?.complete(null);
      _ready = null;
      notifyListeners();
    }
    if (process == null) return;
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
    }
  }

  @override
  void dispose() {
    _process?.kill(ProcessSignal.sigterm);
    _process = null;
    super.dispose();
  }
}

/// The engine program: $DARTPILOT_ENGINE, next to the app (installed together), or on the PATH.
String? findEngineExecutable() {
  final name = Platform.isWindows ? 'dartpilot.exe' : 'dartpilot';
  final configured = Platform.environment['DARTPILOT_ENGINE'];
  if (configured != null && configured.isNotEmpty) return configured;
  final appDirectory = File(Platform.resolvedExecutable).parent.path;
  for (final directory in [
    appDirectory,
    '$appDirectory/lib',
    ...?Platform.environment['PATH']?.split(Platform.isWindows ? ';' : ':'),
  ]) {
    final candidate = File('$directory${Platform.pathSeparator}$name');
    if (candidate.existsSync()) return candidate.path;
  }
  return null;
}

/// A port nobody listens on right now; 8484 when it is free, so the usual address keeps working.
Future<int> findFreePort() async {
  for (final port in [8484, 0]) {
    try {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      final free = socket.port;
      await socket.close();
      return free;
    } on SocketException {
      continue;
    }
  }
  return 8484;
}
