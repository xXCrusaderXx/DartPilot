// Messages of the engine API, protocol dartpilot/1.0 (docs/engine-api.md), as Dart objects.
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import '../board/dart_throw.dart';
import '../board/scoring.dart';

sealed class EngineEvent {
  const EngineEvent();

  /// Parses an engine message; unknown types give null, so newer engines stay compatible.
  static EngineEvent? fromJson(Map<String, dynamic> json) => switch (json['type']) {
    'hello' => EngineHello.fromJson(json),
    'throw' => EngineThrow.fromJson(json),
    'throw_corrected' => EngineThrowCorrected.fromJson(json),
    'takeout' => EngineTakeout(json['darts_removed'] as int? ?? 0),
    'camera_status' => EngineCameraStatus.fromJson(json),
    'board_state' => EngineBoardState.fromJson(json),
    'diagnosis' => EngineDiagnosis.fromJson(json),
    'engine_status' => EngineStatus(json['detection'] as String, json['message'] as String? ?? ''),
    _ => null,
  };
}

BoardPoint? _point(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  return BoardPoint((json['x_mm'] as num).toDouble(), (json['y_mm'] as num).toDouble());
}

class EngineHello extends EngineEvent {
  const EngineHello({
    required this.protocol,
    required this.mode,
    required this.geometry,
    required this.cameras,
    this.boardState,
  });

  final String protocol;
  final String mode;
  final BoardGeometry geometry;
  final List<String> cameras;

  /// Missing with engines before the board check
  final EngineBoardState? boardState;

  factory EngineHello.fromJson(Map<String, dynamic> json) {
    final g = json['board_geometry'] as Map<String, dynamic>;
    double r(String key) => (g[key] as num).toDouble();
    return EngineHello(
      protocol: json['protocol'] as String,
      mode: json['mode'] as String,
      geometry: BoardGeometry(
        bullRadiusMm: r('bull_radius_mm'),
        outerBullRadiusMm: r('outer_bull_radius_mm'),
        tripleInnerRadiusMm: r('triple_inner_radius_mm'),
        tripleOuterRadiusMm: r('triple_outer_radius_mm'),
        doubleInnerRadiusMm: r('double_inner_radius_mm'),
        doubleOuterRadiusMm: r('double_outer_radius_mm'),
        wireRotationDeg: r('wire_rotation_deg'),
      ),
      cameras: [for (final c in json['cameras'] as List<dynamic>) (c as Map<String, dynamic>)['id'] as String],
      boardState: json['board_state'] is Map<String, dynamic>
          ? EngineBoardState.fromJson(json['board_state'] as Map<String, dynamic>)
          : null,
    );
  }
}

class EngineThrow extends EngineEvent {
  const EngineThrow({
    required this.throwId,
    required this.accepted,
    required this.point,
    required this.confidence,
    this.reason = '',
  });

  final String throwId;

  /// false: the engine abstains; [point] is its best guess, if any
  final bool accepted;
  final BoardPoint? point;
  final double confidence;
  final String reason;

  factory EngineThrow.fromJson(Map<String, dynamic> json) => EngineThrow(
    throwId: json['throw_id'] as String,
    accepted: json['accepted'] as bool,
    point: _point(json['board_point']),
    confidence: (json['confidence'] as num? ?? 0).toDouble(),
    reason: json['reason'] as String? ?? '',
  );
}

class EngineThrowCorrected extends EngineEvent {
  const EngineThrowCorrected({required this.throwId, required this.action, required this.point, required this.client});

  final String throwId;

  /// corrected, rejected or added
  final String action;
  final BoardPoint? point;
  final String client;

  factory EngineThrowCorrected.fromJson(Map<String, dynamic> json) => EngineThrowCorrected(
    throwId: json['throw_id'] as String,
    action: json['action'] as String,
    point: _point(json['board_point']),
    client: json['client'] as String? ?? '',
  );
}

class EngineTakeout extends EngineEvent {
  const EngineTakeout(this.dartsRemoved);

  final int dartsRemoved;
}

class EngineCameraStatus extends EngineEvent {
  const EngineCameraStatus(
    this.camera,
    this.state, {
    this.effectiveFps,
    this.lostFrames,
    this.overflowDrops,
    this.brightness,
    this.latencyMs,
  });

  final String camera;

  /// ok, degraded or lost
  final String state;
  final double? effectiveFps;
  final int? lostFrames;
  final int? overflowDrops;

  /// Mean image brightness 0–255, if the engine measures it
  final double? brightness;

  /// Arrival minus exposure of the latest frame
  final double? latencyMs;

  factory EngineCameraStatus.fromJson(Map<String, dynamic> json) => EngineCameraStatus(
    json['camera'] as String,
    json['state'] as String,
    effectiveFps: (json['effective_fps'] as num?)?.toDouble(),
    lostFrames: json['lost_frames'] as int?,
    overflowDrops: json['overflow_drops'] as int?,
    brightness: (json['brightness'] as num?)?.toDouble(),
    latencyMs: (json['latency_ms'] as num?)?.toDouble(),
  );
}

/// A camera image from the engine (docs/engine-api.md, "Previews")
class PreviewFrame {
  const PreviewFrame({
    required this.camera,
    required this.sequence,
    required this.width,
    required this.height,
    required this.jpeg,
  });

  final String camera;
  final int sequence;
  final int width;
  final int height;
  final Uint8List jpeg;

  /// Binary message: header length as u32 little-endian, the header as JSON, then the JPEG; null if malformed.
  static PreviewFrame? parse(Uint8List bytes) {
    if (bytes.length < 4) return null;
    final length = ByteData.sublistView(bytes, 0, 4).getUint32(0, Endian.little);
    if (4 + length > bytes.length) return null;
    final header = jsonDecode(utf8.decode(bytes.sublist(4, 4 + length)));
    if (header is! Map<String, dynamic>) return null;
    return PreviewFrame(
      camera: header['camera'] as String,
      sequence: header['sequence'] as int,
      width: header['width'] as int,
      height: header['height'] as int,
      jpeg: Uint8List.sublistView(bytes, 4 + length),
    );
  }
}

/// Whether the board is empty, per camera and overall (docs/engine-api.md, "board_state")
class EngineBoardState extends EngineEvent {
  const EngineBoardState(this.state, {this.cameras = const [], this.referenceStored = false});

  /// empty, occupied or unknown
  final String state;
  final List<CameraBoardState> cameras;
  final bool referenceStored;

  bool get occupied => state == 'occupied';

  factory EngineBoardState.fromJson(Map<String, dynamic> json) => EngineBoardState(
    json['state'] as String? ?? 'unknown',
    cameras: [
      for (final c in json['cameras'] as List<dynamic>? ?? const [])
        CameraBoardState.fromJson(c as Map<String, dynamic>),
    ],
    referenceStored: json['reference'] == 'stored',
  );
}

class CameraBoardState {
  const CameraBoardState(this.camera, this.state, {this.imagePointPx, this.imageSizePx, this.reason = ''});

  final String camera;
  final String state;

  /// Where the camera sees the object, in an image of [imageSizePx]
  final Offset? imagePointPx;
  final Size? imageSizePx;
  final String reason;

  bool get occupied => state == 'occupied';

  factory CameraBoardState.fromJson(Map<String, dynamic> json) {
    final point = json['image_point_px'] as List<dynamic>?;
    final size = json['image_size_px'] as List<dynamic>?;
    return CameraBoardState(
      json['camera'] as String,
      json['state'] as String? ?? 'unknown',
      imagePointPx: point == null ? null : Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()),
      imageSizePx: size == null || (size[0] as num) <= 0
          ? null
          : Size((size[0] as num).toDouble(), (size[1] as num).toDouble()),
      reason: json['reason'] as String? ?? '',
    );
  }
}

double? _number(Object? json) => (json as num?)?.toDouble();

List<double>? _numbers(Object? json) => json is List ? [for (final v in json) (v as num).toDouble()] : null;

/// The live setup diagnosis (docs/engine-api.md, "diagnosis", #137): what the player should do next, and what is
/// wrong with the setup so far
class EngineDiagnosis extends EngineEvent {
  const EngineDiagnosis({
    required this.running,
    required this.step,
    required this.state,
    required this.elapsedS,
    this.cameras = const [],
    this.findings = const [],
    this.periods = const [],
  });

  final bool running;

  /// empty_board, remove_darts, insert_dart or remove_dart
  final String step;

  /// moving, settling, measuring, measured or stopped
  final String state;
  final double elapsedS;
  final List<String> cameras;

  /// Most severe first
  final List<DiagnosisFinding> findings;
  final List<DiagnosisPeriod> periods;

  factory EngineDiagnosis.fromJson(Map<String, dynamic> json) => EngineDiagnosis(
    running: json['running'] as bool? ?? false,
    step: json['step'] as String? ?? '',
    state: json['state'] as String? ?? '',
    elapsedS: _number(json['elapsed_s']) ?? 0,
    cameras: [for (final c in json['cameras'] as List<dynamic>? ?? const []) c as String],
    findings: [
      for (final f in json['findings'] as List<dynamic>? ?? const [])
        DiagnosisFinding.fromJson(f as Map<String, dynamic>),
    ],
    periods: [
      for (final p in json['periods'] as List<dynamic>? ?? const [])
        DiagnosisPeriod.fromJson(p as Map<String, dynamic>),
    ],
  );
}

class DiagnosisFinding {
  const DiagnosisFinding({
    required this.severity,
    required this.check,
    required this.code,
    this.camera,
    this.values = const {},
    this.message = '',
    this.hint = '',
  });

  /// problem, warning or info
  final String severity;
  final String check;
  final String code;

  /// null for findings about the whole setup
  final String? camera;
  final Map<String, double> values;

  /// English text from the engine, for codes the app does not know
  final String message;
  final String hint;

  factory DiagnosisFinding.fromJson(Map<String, dynamic> json) => DiagnosisFinding(
    severity: json['severity'] as String? ?? 'info',
    check: json['check'] as String? ?? '',
    code: json['code'] as String? ?? '',
    camera: (json['camera'] as String?)?.isEmpty ?? true ? null : json['camera'] as String,
    values: {
      for (final e in (json['values'] as Map<String, dynamic>? ?? const {}).entries) e.key: (e.value as num).toDouble(),
    },
    message: json['message'] as String? ?? '',
    hint: json['hint'] as String? ?? '',
  );
}

/// A still moment the diagnosis measured: an empty board, or a board with one dart
class DiagnosisPeriod {
  const DiagnosisPeriod({
    required this.startS,
    required this.endS,
    required this.empty,
    this.cameras = const [],
    this.boardMm,
    this.agreeingCameras = const [],
    this.worstPlaneMm,
  });

  final double startS;
  final double endS;
  final bool empty;

  /// In the order of [EngineDiagnosis.cameras]
  final List<DiagnosisPeriodCamera> cameras;

  /// Where the dart was located, if it was
  final List<double>? boardMm;
  final List<String> agreeingCameras;
  final double? worstPlaneMm;

  factory DiagnosisPeriod.fromJson(Map<String, dynamic> json) => DiagnosisPeriod(
    startS: _number(json['start_s']) ?? 0,
    endS: _number(json['end_s']) ?? 0,
    empty: json['empty'] as bool? ?? false,
    cameras: [
      for (final c in json['cameras'] as List<dynamic>? ?? const [])
        DiagnosisPeriodCamera.fromJson(c as Map<String, dynamic>),
    ],
    boardMm: _numbers(json['board_mm']),
    agreeingCameras: [for (final c in json['agreeing_cameras'] as List<dynamic>? ?? const []) c as String],
    worstPlaneMm: _number(json['worst_plane_mm']),
  );
}

class DiagnosisPeriodCamera {
  const DiagnosisPeriodCamera({this.brightness, this.calibrationMm, this.shiftPx, this.dart, this.axisLengthPx});

  final double? brightness;
  final double? calibrationMm;
  final List<double>? shiftPx;

  /// none, cut or seen; null on an empty board
  final String? dart;
  final double? axisLengthPx;

  factory DiagnosisPeriodCamera.fromJson(Map<String, dynamic> json) => DiagnosisPeriodCamera(
    brightness: _number(json['brightness']),
    calibrationMm: _number(json['calibration_mm']),
    shiftPx: _numbers(json['shift_px']),
    dart: json['dart'] as String?,
    axisLengthPx: _number(json['axis_length_px']),
  );
}

class EngineStatus extends EngineEvent {
  const EngineStatus(this.detection, this.message);

  final String detection;
  final String message;
}
