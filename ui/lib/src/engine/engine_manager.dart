// Runs the engine on this device (#105, ADR 0008): the app starts `dartpilot serve` as a child process on Linux and
// Windows, waits until it listens, keeps its log, and stops it again.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum LocalEngineState { stopped, starting, running, failed }

/// Why the engine could not start or stopped; the log has the details.
enum LocalEngineError { notFound, noCameras, portInUse, crashed, noAnswer, liveUnavailable }

typedef ProcessStarter = Future<Process> Function(String executable, List<String> arguments);

class EngineManager extends ChangeNotifier {
  EngineManager({
    ProcessStarter? start,
    String? Function()? findEngine,
    Future<int> Function()? freePort,
    bool Function(String path)? isEngine,
    this.readyTimeout = const Duration(seconds: 20),
  }) : _start = start ?? Process.start,
       _isEngine = isEngine ?? looksLikeEngine,
       _findEngine = findEngine ?? findEngineExecutable,
       _freePort = freePort ?? findFreePort;

  final ProcessStarter _start;
  final String? Function() _findEngine;
  final Future<int> Function() _freePort;
  final bool Function(String path) _isEngine;

  /// A program that has not said it listens by then is not the engine, or hangs: it is stopped.
  final Duration readyTimeout;

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
  Timer? _readyTimer;
  Completer<String?>? _ready;

  /// The options the running engine was started with, so a change can ask for a restart
  ({bool simulate, bool cameras, bool share})? startedWith;

  /// Port of the running engine, from [url]
  int? get port => url == null ? null : Uri.tryParse(url!)?.port;

  String? get resolvedExecutable => executable ?? _findEngine();

  /// Starts the engine and completes with its address, or null if it could not start ([error] says why).
  /// Live detection on the cameras; [simulate] plays generated darts instead, for trying the app without detection,
  /// where [cameras] still streams the real cameras for previews, status and the board check.
  /// [share] makes the engine listen on the network, for other devices to connect to (#109).
  Future<String?> start({bool simulate = false, bool cameras = true, bool share = false}) async {
    await stop();
    startedWith = (simulate: simulate, cameras: simulate ? cameras : true, share: share);
    final program = resolvedExecutable;
    if (program == null || !File(program).existsSync()) {
      return _failed(LocalEngineError.notFound, 'Engine program not found: ${program ?? 'dartpilot'}');
    }
    // Starting the app itself would start the app again and again.
    if (isOwnExecutable(program) || !_isEngine(program)) {
      return _failed(LocalEngineError.notFound, 'Not the engine program (the app itself, or an older app): $program');
    }
    final port = await _freePort();
    state = LocalEngineState.starting;
    error = null;
    url = null;
    log.clear();
    notifyListeners();
    final arguments = [
      'serve',
      if (simulate) '--simulate',
      if (!simulate || cameras) '--cameras',
      if (share) ...['--listen', '0.0.0.0'],
      '--port',
      '$port',
    ];
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
    _readyTimer?.cancel();
    _readyTimer = Timer(readyTimeout, () {
      if (!identical(process, _process) || state != LocalEngineState.starting) return;
      _process = null;
      process.kill(ProcessSignal.sigkill);
      _failed(LocalEngineError.noAnswer, 'No answer within ${readyTimeout.inSeconds} s; stopped.');
    });
    return ready.future;
  }

  static final RegExp _listening = RegExp(r'on (ws://\S+/)');

  void _onLine(String line) {
    _addLog(line);
    final match = _listening.firstMatch(line);
    if (match != null && state == LocalEngineState.starting) {
      state = LocalEngineState.running;
      _readyTimer?.cancel();
      // The app itself connects through the loopback address also when the engine listens on all of them.
      url = match.group(1)!.replaceFirst('://0.0.0.0:', '://127.0.0.1:');
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
    final reason = text.contains('Live detection is not available')
        ? LocalEngineError.liveUnavailable
        : text.contains('No camera could be started')
        ? LocalEngineError.noCameras
        : text.contains('Address already in use') || text.contains('address in use')
        ? LocalEngineError.portInUse
        : LocalEngineError.crashed;
    _failed(reason, null);
  }

  String? _failed(LocalEngineError reason, String? message) {
    _readyTimer?.cancel();
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
    _readyTimer?.cancel();
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
    _readyTimer?.cancel();
    _process?.kill(ProcessSignal.sigterm);
    _process = null;
    super.dispose();
  }
}

/// Whether [path] is the engine: its program carries the usage text of `dartpilot serve`. A program of the same name
/// may be an app of an older version, which would start itself again.
bool looksLikeEngine(String path) {
  try {
    return latin1.decode(File(path).readAsBytesSync(), allowInvalid: true).contains('Usage: dartpilot serve');
  } on FileSystemException {
    return false;
  }
}

/// Whether [path] is this app's own program, also through a link
bool isOwnExecutable(String path) {
  try {
    return File(path).resolveSymbolicLinksSync() == File(Platform.resolvedExecutable).resolveSymbolicLinksSync();
  } on FileSystemException {
    return false;
  }
}

/// The engine program: $DARTPILOT_ENGINE, the one shipped with the app (engine/ next to it), next to the app, or on
/// the PATH.
String? findEngineExecutable() {
  final name = Platform.isWindows ? 'dartpilot.exe' : 'dartpilot';
  final configured = Platform.environment['DARTPILOT_ENGINE'];
  if (configured != null && configured.isNotEmpty) return configured;
  final appDirectory = File(Platform.resolvedExecutable).parent.path;
  for (final directory in [
    // The engine shipped with the app comes first.
    '$appDirectory${Platform.pathSeparator}engine',
    appDirectory,
    '$appDirectory/lib',
    ...?Platform.environment['PATH']?.split(Platform.isWindows ? ';' : ':'),
  ]) {
    final candidate = File('$directory${Platform.pathSeparator}$name');
    if (candidate.existsSync() && !isOwnExecutable(candidate.path) && looksLikeEngine(candidate.path)) {
      return candidate.path;
    }
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
