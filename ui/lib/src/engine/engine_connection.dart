import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../board/dart_throw.dart';
import '../board/scoring.dart';
import 'engine_events.dart';

enum EngineConnectionState { disconnected, connecting, connected, failed }

/// The app's connection to an engine (docs/engine-api.md). One per app; screens listen to [events].
class EngineConnection extends ChangeNotifier {
  EngineConnection({WebSocketChannel Function(Uri uri)? connector})
    : _connector = connector ?? WebSocketChannel.connect,
      clientName = 'dartpilot-app-${math.Random().nextInt(0x7fffffff).toRadixString(16)}';

  final WebSocketChannel Function(Uri uri) _connector;

  /// Sent in hello, so the app recognises its own corrections in throw_corrected
  final String clientName;

  static const String defaultUrl = 'ws://localhost:8484/';

  String url = defaultUrl;
  EngineConnectionState state = EngineConnectionState.disconnected;
  EngineHello? hello;
  String? error;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final StreamController<EngineEvent> _events = StreamController.broadcast();
  final StreamController<PreviewFrame> _previews = StreamController.broadcast();

  /// Latest state per camera from camera_status
  final Map<String, String> cameraStates = {};
  int _nextRequest = 1;

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
    final event = EngineEvent.fromJson(json);
    if (event is EngineHello) {
      hello = event;
      cameraStates
        ..clear()
        ..addAll({for (final c in event.cameras) c: 'ok'});
      state = EngineConnectionState.connected;
      notifyListeners();
    }
    if (event is EngineCameraStatus && cameraStates[event.camera] != event.state) {
      cameraStates[event.camera] = event.state;
      notifyListeners();
    }
    if (event != null) _events.add(event);
  }

  void _send(Map<String, dynamic> request) {
    _channel?.sink.add(jsonEncode({'request_id': '${_nextRequest++}', ...request}));
  }

  static Map<String, dynamic> _pointJson(BoardPoint p) => {'x_mm': p.xMm, 'y_mm': p.yMm};

  void correctThrow(String throwId, BoardPoint point) =>
      _send({'type': 'correct_throw', 'throw_id': throwId, 'board_point': _pointJson(point)});

  void rejectThrow(String throwId, String reason) =>
      _send({'type': 'reject_throw', 'throw_id': throwId, 'reason': reason});

  void subscribePreview(String camera, {double maxFps = 10, int maxWidth = 640}) =>
      _send({'type': 'subscribe_preview', 'camera': camera, 'max_fps': maxFps, 'max_width': maxWidth});

  void unsubscribePreview(String camera) => _send({'type': 'unsubscribe_preview', 'camera': camera});

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
