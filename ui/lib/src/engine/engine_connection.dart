import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../board/dart_throw.dart';
import '../board/scoring.dart';
import 'engine_discovery.dart';
import 'engine_events.dart';

enum EngineConnectionState { disconnected, connecting, connected, failed }

/// The app's connection to an engine (docs/engine-api.md). One per app; screens listen to [events].
class EngineConnection extends ChangeNotifier {
  EngineConnection({WebSocketChannel Function(Uri uri)? connector, EngineDiscovery? discovery})
    : _connector = connector ?? WebSocketChannel.connect,
      discovery = discovery ?? EngineDiscovery.network(),
      clientName = 'dartpilot-app-${math.Random().nextInt(0x7fffffff).toRadixString(16)}';

  /// For tests: requests go to `onSend` instead of a socket
  @visibleForTesting
  EngineConnection.forTest(void Function(Map<String, dynamic>) onSend, {EngineDiscovery? discovery})
    : _connector = WebSocketChannel.connect,
      discovery = discovery ?? EngineDiscovery(const []),
      clientName = 'test',
      _testSink = onSend;

  final WebSocketChannel Function(Uri uri) _connector;

  /// Finds engines in the network for the engine card
  final EngineDiscovery discovery;
  void Function(Map<String, dynamic>)? _testSink;

  /// Sent in hello, so the app recognises its own corrections in throw_corrected
  final String clientName;

  static const String defaultUrl = 'ws://localhost:8484/';

  String url = defaultUrl;
  EngineConnectionState state = EngineConnectionState.disconnected;
  EngineHello? hello;

  /// Latest board check of the engine; null when it has none
  EngineBoardState? boardState;

  /// Latest state of the setup diagnosis; null before it ran
  EngineDiagnosis? diagnosis;
  String? error;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final StreamController<EngineEvent> _events = StreamController.broadcast();
  final StreamController<PreviewFrame> _previews = StreamController.broadcast();

  /// Latest camera_status per camera
  final Map<String, EngineCameraStatus> cameraStatus = {};

  /// Latest state per camera: ok, degraded or lost
  Map<String, String> get cameraStates => {for (final e in cameraStatus.entries) e.key: e.value.state};

  final Map<String, List<PreviewHandle>> _previewHandles = {};
  int _statusSubscribers = 0;
  int _nextRequest = 1;
  final Map<String, Completer<String?>> _pending = {};

  Stream<EngineEvent> get events => _events.stream;

  Stream<PreviewFrame> get previews => _previews.stream;

  bool get isConnected => state == EngineConnectionState.connected;

  /// The board geometry the engine scores with, nominal without an engine
  BoardGeometry get geometry => hello?.geometry ?? const BoardGeometry();

  Future<void> connect(String newUrl) async {
    await disconnect();
    url = newUrl;
    state = EngineConnectionState.connecting;
    error = null;
    notifyListeners();
    try {
      final channel = _connector(Uri.parse(newUrl));
      _channel = channel;
      await channel.ready;
      _subscription = channel.stream.listen(
        _onMessage,
        onError: (Object e) => _fail('$e'),
        onDone: () {
          if (state != EngineConnectionState.failed) {
            state = EngineConnectionState.disconnected;
            notifyListeners();
          }
        },
      );
      _send({'type': 'hello', 'client': clientName});
    } catch (e) {
      _fail('$e');
    }
  }

  Future<void> disconnect() async {
    await _closeChannel();
    hello = null;
    boardState = null;
    diagnosis = null;
    if (state != EngineConnectionState.disconnected) {
      state = EngineConnectionState.disconnected;
      notifyListeners();
    }
  }

  void _fail(String message) {
    state = EngineConnectionState.failed;
    error = message;
    notifyListeners();
  }

  void _onMessage(dynamic message) {
    if (message is List<int>) {
      final frame = PreviewFrame.parse(message is Uint8List ? message : Uint8List.fromList(message));
      if (frame != null) _previews.add(frame);
      return;
    }
    if (message is! String) return;
    final json = jsonDecode(message);
    if (json is! Map<String, dynamic>) return;
    if (json['type'] == 'result') {
      final error = json['error'];
      _pending
          .remove(json['request_id'])
          ?.complete(
            json['ok'] == true ? null : (error is Map<String, dynamic> ? error['code'] as String? : null) ?? 'failed',
          );
      return;
    }
    final event = EngineEvent.fromJson(json);
    if (event is EngineHello) {
      hello = event;
      boardState = event.boardState;
      diagnosis = null;
      cameraStatus
        ..clear()
        ..addAll({for (final c in event.cameras) c: EngineCameraStatus(c, 'ok')});
      state = EngineConnectionState.connected;
      notifyListeners();
    }
    if (event is EngineDiagnosis) {
      diagnosis = event;
      notifyListeners();
    }
    if (event is EngineBoardState) {
      boardState = event;
      notifyListeners();
    }
    if (event is EngineCameraStatus) {
      cameraStatus[event.camera] = event;
      notifyListeners();
    }
    if (event != null) _events.add(event);
  }

  /// Returns the request id, which the engine's result carries
  String _send(Map<String, dynamic> request) {
    final id = '${_nextRequest++}';
    final testSink = _testSink;
    if (testSink != null) {
      testSink(request);
      return id;
    }
    _channel?.sink.add(jsonEncode({'request_id': id, ...request}));
    return id;
  }

  /// Sends a request and completes with the error code of its result, or null when it succeeded
  Future<String?> _request(Map<String, dynamic> request) {
    final completer = Completer<String?>();
    _pending[_send(request)] = completer;
    return completer.future;
  }

  static Map<String, dynamic> _pointJson(BoardPoint p) => {'x_mm': p.xMm, 'y_mm': p.yMm};

  void correctThrow(String throwId, BoardPoint point) =>
      _send({'type': 'correct_throw', 'throw_id': throwId, 'board_point': _pointJson(point)});

  void rejectThrow(String throwId, String reason) =>
      _send({'type': 'reject_throw', 'throw_id': throwId, 'reason': reason});

  /// Starts or changes the preview of a camera. Several widgets may watch the same camera; the engine gets the
  /// highest rate and width any of them asked for, and the preview stops when the last handle is released.
  PreviewHandle watchPreview(String camera, {double maxFps = 10, int maxWidth = 640}) {
    final handle = PreviewHandle._(this, camera, maxFps, maxWidth);
    _previewHandles.putIfAbsent(camera, () => []).add(handle);
    _updatePreview(camera);
    return handle;
  }

  void _releasePreview(PreviewHandle handle) {
    final handles = _previewHandles[handle.camera];
    if (handles == null || !handles.remove(handle)) return;
    _updatePreview(handle.camera);
  }

  void _updatePreview(String camera) {
    final handles = _previewHandles[camera] ?? const [];
    if (handles.isEmpty) {
      _previewHandles.remove(camera);
      _send({'type': 'unsubscribe_preview', 'camera': camera});
      return;
    }
    final fps = handles.map((h) => h.maxFps).reduce(math.max);
    final width = handles.map((h) => h.maxWidth).reduce(math.max);
    _send({'type': 'subscribe_preview', 'camera': camera, 'max_fps': fps, 'max_width': width});
  }

  /// Periodic camera_status while at least one caller watches; call [unwatchStatus] once for each call.
  void watchStatus() {
    if (_statusSubscribers++ == 0) _send({'type': 'subscribe_status'});
  }

  void unwatchStatus() {
    if (_statusSubscribers > 0 && --_statusSubscribers == 0) _send({'type': 'unsubscribe_status'});
  }

  /// Asks the engine to check the board now; the answer arrives as [boardState]
  void checkBoard() => _send({'type': 'check_board'});

  /// Stores the current images as the empty board; the error code if that failed, e.g. board_not_empty.
  /// [force] stores even while a camera reports an object, after the player confirmed the board is empty.
  Future<String?> storeEmptyReference({bool force = false}) =>
      _request({'type': 'store_empty_reference', if (force) 'force': true});

  /// Starts the setup diagnosis afresh; its state arrives as [diagnosis]. The error code if it cannot run.
  Future<String?> startDiagnosis() => _request({'type': 'start_diagnosis'});

  Future<String?> stopDiagnosis() => _request({'type': 'stop_diagnosis'});

  /// A dart the engine missed, entered by hand
  void addThrow(BoardPoint point) => _send({'type': 'add_throw', 'board_point': _pointJson(point)});

  /// For tests: feed a message as if the engine had sent it
  @visibleForTesting
  void receiveForTest(Object message) => _onMessage(message);

  Future<void> _closeChannel() async {
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    for (final pending in _pending.values) {
      pending.complete('disconnected');
    }
    _pending.clear();
    await subscription?.cancel();
    await channel?.sink.close();
  }

  @override
  void dispose() {
    // No notifications after dispose: close the channel without going through disconnect().
    _closeChannel();
    _events.close();
    _previews.close();
    super.dispose();
  }
}

/// Makes the connection available to all screens.
class EngineScope extends InheritedNotifier<EngineConnection> {
  const EngineScope({super.key, required EngineConnection connection, required super.child})
    : super(notifier: connection);

  static EngineConnection of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EngineScope>()!.notifier!;
}

/// A widget's interest in a camera preview; release it when the widget goes away.
class PreviewHandle {
  PreviewHandle._(this._connection, this.camera, this.maxFps, this.maxWidth);

  final EngineConnection _connection;
  final String camera;
  final double maxFps;
  final int maxWidth;

  void release() => _connection._releasePreview(this);
}
