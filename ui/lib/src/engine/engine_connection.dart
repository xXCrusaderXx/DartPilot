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
import 'pairing_tokens.dart';

enum EngineConnectionState { disconnected, connecting, connected, failed }

/// The app's connection to an engine (docs/engine-api.md). One per app; screens listen to [events].
class EngineConnection extends ChangeNotifier {
  EngineConnection({WebSocketChannel Function(Uri uri)? connector, EngineDiscovery? discovery, PairingTokens? tokens})
    : _connector = connector ?? WebSocketChannel.connect,
      discovery = discovery ?? EngineDiscovery.network(),
      tokens = tokens ?? MemoryPairingTokens(),
      requestTimeout = defaultRequestTimeout,
      clientName = 'dartpilot-app-${math.Random().nextInt(0x7fffffff).toRadixString(16)}';

  /// For tests: requests go to `onSend` instead of a socket; without [requestTimeout] they wait for their result for
  /// ever.
  @visibleForTesting
  EngineConnection.forTest(
    void Function(Map<String, dynamic>) onSend, {
    EngineDiscovery? discovery,
    PairingTokens? tokens,
    this.requestTimeout,
  }) : _connector = WebSocketChannel.connect,
       discovery = discovery ?? EngineDiscovery(const []),
       tokens = tokens ?? MemoryPairingTokens(),
       clientName = 'test',
       _testSink = onSend;

  final WebSocketChannel Function(Uri uri) _connector;

  /// Finds engines in the network for the engine card
  final EngineDiscovery discovery;

  /// Tokens from pairing with network engines (#110)
  final PairingTokens tokens;

  /// The engine asks this device to pair before anything else; the app asks for the PIN
  bool pairingRequired = false;

  /// A PIN that came with the address (QR code), tried as soon as the engine asks for pairing
  String? _pendingPin;

  /// The PIN of the engine on this device, for other devices to pair with; null until asked for
  PairingPin? pairingPin;

  /// The devices paired with the engine on this device; null until asked for
  PairedClients? pairedClients;
  void Function(Map<String, dynamic>)? _testSink;

  /// Sent in hello, so the app recognises its own corrections in throw_corrected
  final String clientName;

  static const String defaultUrl = 'ws://localhost:8484/';

  /// How long connecting and each request may take before they count as failed
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration defaultRequestTimeout = Duration(seconds: 15);
  final Duration? requestTimeout;

  /// Pauses before each new try after the engine went away
  static const List<Duration> reconnectDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];

  /// The engine went away by itself, and the app tries to reach it again
  bool reconnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  /// Tries since the engine went away
  int get reconnectAttempts => _reconnectAttempts;

  String url = defaultUrl;
  EngineConnectionState state = EngineConnectionState.disconnected;
  EngineHello? hello;

  /// Latest board check of the engine; null when it has none
  EngineBoardState? boardState;

  /// The real board from the front, shown instead of the drawn one; null where the engine has none (simulator, not
  /// calibrated)
  BoardImage? boardImage;

  /// The camera views of throws this client asked for (#129), by throw ID
  final Map<String, ThrowViews> throwViews = {};

  /// Latest state of the reference measurement; null before it ran
  ReferenceRun? referenceRun;

  /// The measured dart sets and the active one (#120); null with engines that have none
  DartSets? dartSets;

  /// Progress of measuring a new dart set; null when none is measured
  DartSetCapture? dartSetCapture;

  /// Reference images by set id and camera, as far as asked for
  final Map<(String, String), DartSetImage> dartSetImages = {};

  /// The cameras' order and names as the engine keeps them; null with engines that keep none
  CameraAssignment? cameraAssignment;

  /// The game an app shares through the engine, this app's own included; null when none is shared
  SharedGame? sharedGame;

  /// Latest state of the setup diagnosis; null before it ran
  EngineDiagnosis? diagnosis;

  /// What is calibrated; null without cameras
  CalibrationStatus? calibration;

  /// Latest results of the calibration steps, for the wizard
  WhiteBalanceState? whiteBalance;
  final Map<String, BoardDetection> boardDetections = {};
  final Map<String, BoardPlaneResult> boardPlanes = {};
  RefinementResult? refinement;

  /// Detailed checks while someone watches them, per camera
  final Map<String, CalibrationCheck> calibrationChecks = {};
  int _checkWatchers = 0;

  /// Whether the engine detects darts now (running, paused, unavailable), and why not (not_calibrated, …)
  String detection = 'running';
  String? detectionReason;
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

  /// Connects to `newUrl`. A `pin` in its query (from a QR code) pairs this device right away.
  Future<void> connect(String newUrl) async {
    _stopReconnecting();
    await _open(newUrl);
  }

  Future<void> _open(String newUrl) async {
    await _close();
    final (address, pin) = splitPairingPin(newUrl);
    _pendingPin = pin;
    url = newUrl = address;
    state = EngineConnectionState.connecting;
    error = null;
    notifyListeners();
    try {
      final channel = _connector(Uri.parse(newUrl));
      _channel = channel;
      await channel.ready.timeout(connectTimeout);
      _subscription = channel.stream.listen(
        _onMessage,
        onError: (Object e) => _fail('$e'),
        onDone: () {
          // The engine went away: nothing it sent before still holds, and no result will come.
          final wasConnected = isConnected;
          _closeChannel();
          _clearEngineState();
          if (state != EngineConnectionState.failed) {
            state = EngineConnectionState.disconnected;
            notifyListeners();
          }
          if (wasConnected || reconnecting) _scheduleReconnect();
        },
      );
      _send({'type': 'hello', 'client': clientName});
    } catch (e) {
      _fail('$e');
    }
  }

  Future<void> disconnect() async {
    _stopReconnecting();
    await _close();
  }

  Future<void> _close() async {
    await _closeChannel();
    _clearEngineState();
    if (state != EngineConnectionState.disconnected) {
      state = EngineConnectionState.disconnected;
      notifyListeners();
    }
  }

  void _clearEngineState() {
    hello = null;
    boardState = null;
    cameraAssignment = null;
    dartSets = null;
    dartSetCapture = null;
    dartSetImages.clear();
    pairingRequired = false;
    pairingPin = null;
    pairedClients = null;
    boardImage = null;
    referenceRun = null;
    sharedGame = null;
    diagnosis = null;
    cameraStatus.clear();
    _clearCalibration();
  }

  void _fail(String message) {
    _closeChannel();
    state = EngineConnectionState.failed;
    error = message;
    notifyListeners();
    if (reconnecting) _scheduleReconnect();
  }

  /// Tries the same engine again after a growing pause, until it answers or the player connects elsewhere.
  void _scheduleReconnect() {
    reconnecting = true;
    notifyListeners();
    final delay = reconnectDelays[math.min(_reconnectAttempts++, reconnectDelays.length - 1)];
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () => _open(url));
  }

  void _stopReconnecting() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    if (reconnecting) {
      reconnecting = false;
      notifyListeners();
    }
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
      // Taken from the current frames, so only from an empty board
      if (boardState?.state == 'empty') requestBoardImage();
      detection = event.detection;
      detectionReason = event.detectionReason;
      diagnosis = null;
      _clearCalibration();
      calibration = event.calibration;
      cameraStatus
        ..clear()
        ..addAll({for (final c in event.cameras) c: EngineCameraStatus(c, 'ok')});
      state = EngineConnectionState.connected;
      _reconnectAttempts = 0;
      reconnecting = false;
      pairingRequired = event.pairing == 'required';
      if (pairingRequired) _pairOnConnect(event.engineId);
      notifyListeners();
    }
    if (event is Paired) {
      pairingRequired = false;
      _pendingPin = null;
      final id = event.engineId.isNotEmpty ? event.engineId : hello?.engineId;
      if (id != null) tokens.store(id, event.token);
      if (boardState?.state == 'empty') requestBoardImage();
      notifyListeners();
    }
    if (event is PairingPin) {
      pairingPin = event;
      notifyListeners();
    }
    if (event is PairedClients) {
      pairedClients = event;
      notifyListeners();
    }
    switch (event) {
      case CalibrationStatus():
        calibration = event;
      case WhiteBalanceState():
        whiteBalance = event;
      case BoardDetection():
        boardDetections[event.camera] = event;
        boardPlanes.remove(event.camera);
      case BoardPlaneResult():
        boardPlanes[event.camera] = event;
      case RefinementResult():
        refinement = event;
      case CalibrationCheck():
        calibrationChecks[event.camera] = event;
      default:
        break;
    }
    if (event is CalibrationStatus ||
        event is WhiteBalanceState ||
        event is BoardDetection ||
        event is BoardPlaneResult ||
        event is RefinementResult ||
        event is CalibrationCheck) {
      notifyListeners();
    }
    if (event is SharedGame) {
      sharedGame = event.game == null ? null : event;
      notifyListeners();
    }
    if (event is ReferenceRun) {
      referenceRun = event;
      notifyListeners();
    }
    if (event is BoardImage) {
      boardImage = event;
      notifyListeners();
    }
    if (event is ThrowViews) {
      throwViews[event.throwId] = event;
      notifyListeners();
    }
    // After a takeout the board is empty: the image follows changes of light without a dart in it.
    if (event is EngineTakeout) requestBoardImage();
    if (event is EngineStatus) {
      detection = event.detection;
      // The message carries the reason code (docs/engine-api.md, engine_status).
      detectionReason = event.message.isEmpty ? null : event.message;
      notifyListeners();
    }
    if (event is CameraAssignment) {
      cameraAssignment = event;
      notifyListeners();
    }
    if (event is DartSets) {
      dartSets = event;
      notifyListeners();
    }
    if (event is DartSetCapture) {
      dartSetCapture = event;
      notifyListeners();
    }
    if (event is DartSetImage) {
      dartSetImages[(event.id, event.camera)] = event;
      notifyListeners();
    }
    if (event is EngineDiagnosis) {
      diagnosis = event;
      notifyListeners();
    }
    if (event is EngineBoardState) {
      if (event.state == 'empty' && boardState?.state != 'empty' && boardImage == null) requestBoardImage();
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
    if (_testSink == null && _channel == null) return Future.value('disconnected');
    final completer = Completer<String?>();
    final id = _send(request);
    _pending[id] = completer;
    final timeout = requestTimeout;
    if (timeout == null) return completer.future;
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(id);
        return 'timeout';
      },
    );
  }

  static Map<String, dynamic> _pointJson(BoardPoint p) => {'x_mm': p.xMm, 'y_mm': p.yMm};

  /// [candidate] is the index of the throw's candidate the player picked, kept by the engine as a labelled example.
  void correctThrow(String throwId, BoardPoint point, {int? candidate}) =>
      _send({'type': 'correct_throw', 'throw_id': throwId, 'board_point': _pointJson(point), 'candidate': ?candidate});

  void rejectThrow(String throwId, String reason) =>
      _send({'type': 'reject_throw', 'throw_id': throwId, 'reason': reason});

  /// Stores the cameras' order and names in the engine; every client gets them as [cameraAssignment].
  Future<String?> setCameraAssignment(List<AssignedCamera> cameras) => _request({
    'type': 'set_camera_assignment',
    'cameras': [for (final c in cameras) c.toJson()],
  });

  /// Starts measuring a new dart set; progress arrives as [dartSetCapture], the new set in [dartSets].
  Future<String?> startDartSet(String name) => _request({'type': 'start_dart_set', 'name': name});

  void cancelDartSet() => _send({'type': 'cancel_dart_set'});

  /// A set from dimensions the player typed in, e.g. from the packaging, without measuring
  Future<String?> createDartSet(String name, Map<String, double> dims) =>
      _request({'type': 'create_dart_set', 'name': name, 'dims': dims});

  /// Measures a set's dart on a photo of the printed dart sheet (#120); the result arrives as the set's photo
  /// dimensions in [dartSets]
  Future<String?> measureDartPhoto(String id, Uint8List jpeg) =>
      _request({'type': 'measure_dart_photo', 'id': id, 'jpeg_base64': base64Encode(jpeg)});

  /// Enters or corrects dimensions of a set; null removes an entered value, so the measured one counts again
  Future<String?> updateDartSet(String id, Map<String, double?> dims) =>
      _request({'type': 'update_dart_set', 'id': id, 'dims': dims});

  Future<String?> renameDartSet(String id, String name) =>
      _request({'type': 'rename_dart_set', 'id': id, 'name': name});

  Future<String?> deleteDartSet(String id) => _request({'type': 'delete_dart_set', 'id': id});

  /// Asks for a set's reference image from one camera; it arrives in [dartSetImages].
  void requestDartSetImage(String id, String camera) =>
      _send({'type': 'get_dart_set_image', 'id': id, 'camera': camera});

  /// The darts the player at the board throws; null for generic detection. Sent only when it changes.
  void useDarts(String? id) {
    final sets = dartSets;
    if (sets == null || sets.active == id) return;
    if (id != null && !sets.sets.any((s) => s.id == id)) return;
    dartSets = DartSets(sets.sets, id);
    _send({'type': 'set_active_darts', 'id': id});
  }

  /// After an engine's hello that asks for pairing: the stored token, else the PIN from the QR code
  Future<void> _pairOnConnect(String? engineId) async {
    final token = engineId == null ? null : await tokens.tokenFor(engineId);
    if (token != null) {
      final error = await _request({'type': 'pair', 'token': token});
      if (error == null) return;
      // The engine forgot this device (unpaired, or reinstalled): the PIN is needed again.
      if (error == 'unknown_token') await tokens.forget(engineId!);
    }
    final pin = _pendingPin;
    if (pin != null) await pairWithPin(pin);
  }

  /// Pairs this device with the PIN the engine shows; completes with the error code (wrong_pin, too_many_attempts)
  /// or null. The token arrives as `paired` and is stored for later connections.
  Future<String?> pairWithPin(String pin) {
    _pendingPin = null;
    return _request({'type': 'pair', 'pin': pin});
  }

  /// For the engine on this device: its PIN arrives as [pairingPin].
  void requestPairingPin() => _send({'type': 'get_pairing_pin'});

  /// For the engine on this device: the paired devices arrive as [pairedClients].
  void requestPairedClients() => _send({'type': 'list_paired_clients'});

  Future<String?> unpair(String id) async {
    final error = await _request({'type': 'unpair', 'id': id});
    if (error == null) requestPairedClients();
    return error;
  }

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

  void _clearCalibration() {
    calibration = null;
    whiteBalance = null;
    boardDetections.clear();
    boardPlanes.clear();
    refinement = null;
    calibrationChecks.clear();
  }

  /// The calibration steps (docs/engine-api.md, "Calibration"); each completes with an error code, or null. Their
  /// results arrive as events, possibly before the result.
  Future<String?> tuneWhiteBalance() => _request({'type': 'tune_white_balance'});

  Future<String?> detectBoard(String camera) => _request({'type': 'detect_board', 'camera': camera});

  Future<String?> setSector20(String camera, Offset pointPx) => _request({
    'type': 'set_sector_20',
    'camera': camera,
    'point_px': [pointPx.dx, pointPx.dy],
  });

  Future<String?> refineCameras() => _request({'type': 'refine_cameras'});

  /// Detailed calibration checks every 2 s while at least one caller watches; the engine counts subscribers, so call
  /// [unwatchCalibrationCheck] once for every call.
  void watchCalibrationCheck() {
    if (_checkWatchers++ == 0) _send({'type': 'subscribe_calibration_check'});
  }

  void unwatchCalibrationCheck() {
    if (_checkWatchers > 0 && --_checkWatchers == 0) _send({'type': 'unsubscribe_calibration_check'});
  }

  /// Shares the game this app leads, for other displays to follow (#116)
  void shareGame(Map<String, dynamic> game) => _send({'type': 'share_game', 'game': game});

  void endSharedGame() => _send({'type': 'end_shared_game'});

  /// Starts the reference measurement afresh, or stops it; its state arrives as [referenceRun].
  Future<String?> startReferenceRun() => _request({'type': 'start_reference_run'});

  Future<String?> stopReferenceRun() => _request({'type': 'stop_reference_run'});

  /// Asks for the real board's image; it arrives as [boardImage]. Engines without one answer with an error.
  void requestBoardImage() => _send({'type': 'get_board_image'});

  /// Asks for the camera views of a throw; they arrive in [throwViews]. Completes with the error code, e.g.
  /// not_available for a throw without frames, or null.
  Future<String?> requestThrowViews(String throwId) =>
      _request({'type': 'get_throw_views', 'throw_id': throwId, 'max_width': 320});

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
    _reconnectTimer?.cancel();
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

  /// The connection, rebuilding the caller on every engine event; prefer [read] or [EngineSelect] where a widget
  /// needs only some of its values.
  static EngineConnection of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EngineScope>()!.notifier!;

  /// The connection without rebuilding the caller when it changes, for requests and event streams
  static EngineConnection read(BuildContext context) => context.getInheritedWidgetOfExactType<EngineScope>()!.notifier!;
}

/// Builds from a value of the connection and rebuilds only when that value changes, not on every engine event.
/// [select] should return values that compare equal while nothing shown changed, e.g. a record of fields.
class EngineSelect<T> extends StatefulWidget {
  const EngineSelect({super.key, required this.select, required this.builder});

  final T Function(EngineConnection engine) select;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<EngineSelect<T>> createState() => _EngineSelectState<T>();
}

class _EngineSelectState<T> extends State<EngineSelect<T>> {
  EngineConnection? _engine;
  late T _value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = EngineScope.read(context);
    if (identical(engine, _engine)) return;
    _engine?.removeListener(_changed);
    _engine = engine..addListener(_changed);
    _value = widget.select(engine);
  }

  @override
  void didUpdateWidget(EngineSelect<T> old) {
    super.didUpdateWidget(old);
    _value = widget.select(_engine!);
  }

  @override
  void dispose() {
    _engine?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final value = widget.select(_engine!);
    if (value != _value) setState(() => _value = value);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
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

/// The engine address and the PIN that a QR code adds to it (`ws://host:8484/?pin=123456`); the PIN is null without one
(String, String?) splitPairingPin(String url) {
  final uri = Uri.tryParse(url);
  final pin = uri?.queryParameters['pin'];
  if (uri == null || pin == null) return (url, null);
  final rest = Map.of(uri.queryParameters)..remove('pin');
  final address = Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
    queryParameters: rest.isEmpty ? null : rest,
  );
  return (address.toString(), pin);
}
