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
    'board_image' => BoardImage.fromJson(json),
    'reference_run' => ReferenceRun.fromJson(json),
    'diagnosis' => EngineDiagnosis.fromJson(json),
    'calibration_status' => CalibrationStatus.fromJson(json),
    'white_balance' => WhiteBalanceState.fromJson(json),
    'board_detection' => BoardDetection.fromJson(json),
    'board_plane' => BoardPlaneResult.fromJson(json),
    'refinement' => RefinementResult.fromJson(json),
    'calibration_check' => CalibrationCheck.fromJson(json),
    'camera_moved' => CameraMoved(json['camera'] as String),
    'engine_status' => EngineStatus(json['detection'] as String? ?? 'running', json['message'] as String? ?? ''),
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
    this.calibration,
    this.detection = 'running',
    this.detectionReason,
  });

  final String protocol;
  final String mode;
  final BoardGeometry geometry;
  final List<String> cameras;

  /// Missing with engines before the board check
  final EngineBoardState? boardState;

  /// Missing without cameras and with engines before the calibration wizard
  final CalibrationStatus? calibration;

  /// running, paused or unavailable; [detectionReason] says why: not_calibrated, no_empty_reference
  final String detection;
  final String? detectionReason;

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
      calibration: json['calibration_status'] is Map<String, dynamic>
          ? CalibrationStatus.fromJson(json['calibration_status'] as Map<String, dynamic>)
          : null,
      detection: json['detection'] as String? ?? 'running',
      detectionReason: json['detection_reason'] as String?,
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

Offset _offset(Object? json) {
  final p = json as List<dynamic>;
  return Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
}

Size? _size(Object? json) {
  if (json is! List || json.length < 2) return null;
  return Size((json[0] as num).toDouble(), (json[1] as num).toDouble());
}

/// What is calibrated, per camera (docs/engine-api.md, "Calibration")
class CalibrationStatus extends EngineEvent {
  const CalibrationStatus({this.cameras = const [], this.refinementStale = false, this.extrinsicsCreated});

  final List<CameraCalibration> cameras;

  /// A board was measured or a lens calibrated after the last refinement
  final bool refinementStale;
  final String? extrinsicsCreated;

  CameraCalibration? of(String camera) => cameras.where((c) => c.camera == camera).firstOrNull;

  factory CalibrationStatus.fromJson(Map<String, dynamic> json) => CalibrationStatus(
    cameras: [
      for (final c in json['cameras'] as List<dynamic>? ?? const [])
        CameraCalibration.fromJson(c as Map<String, dynamic>),
    ],
    refinementStale: json['refinement_stale'] == true,
    extrinsicsCreated: json['extrinsics_created'] as String?,
  );
}

class CameraCalibration {
  const CameraCalibration({
    required this.camera,
    this.intrinsics = 'none',
    this.boardPlaneMm,
    this.refined = false,
    this.whiteBalanceKelvin,
    this.check,
  });

  final String camera;

  /// valid, invalid or none
  final String intrinsics;
  final double? boardPlaneMm;
  final bool refined;
  final int? whiteBalanceKelvin;

  /// Latest background check against the calibration; null before the first one
  final CalibrationCheck? check;

  factory CameraCalibration.fromJson(Map<String, dynamic> json) => CameraCalibration(
    camera: json['camera'] as String,
    intrinsics: json['intrinsics'] as String? ?? 'none',
    boardPlaneMm: _number(json['board_plane_mm']),
    refined: json['refined'] == true,
    whiteBalanceKelvin: (json['white_balance_kelvin'] as num?)?.round(),
    check: json['check'] is Map<String, dynamic>
        ? CalibrationCheck.fromJson({'camera': json['camera'], ...json['check'] as Map<String, dynamic>})
        : null,
  );
}

/// The white balance sweep: where each camera found the board
class WhiteBalanceState extends EngineEvent {
  const WhiteBalanceState({required this.state, this.kelvinNow, this.settleS, this.cameras = const []});

  /// settling, sweeping, done or failed
  final String state;
  final int? kelvinNow;
  final double? settleS;
  final List<CameraWhiteBalance> cameras;

  bool get running => state == 'settling' || state == 'sweeping';

  factory WhiteBalanceState.fromJson(Map<String, dynamic> json) => WhiteBalanceState(
    state: json['state'] as String? ?? '',
    kelvinNow: (json['kelvin_now'] as num?)?.round(),
    settleS: _number(json['settle_s']),
    cameras: [
      for (final c in json['cameras'] as List<dynamic>? ?? const [])
        CameraWhiteBalance.fromJson(c as Map<String, dynamic>),
    ],
  );
}

class CameraWhiteBalance {
  const CameraWhiteBalance({required this.camera, this.foundAt = const {}, this.chosenKelvin, this.code});

  final String camera;

  /// Kelvin tried so far, and whether the board was found there
  final Map<int, bool> foundAt;
  final int? chosenKelvin;
  final String? code;

  factory CameraWhiteBalance.fromJson(Map<String, dynamic> json) => CameraWhiteBalance(
    camera: json['camera'] as String,
    foundAt: {
      for (final f in json['found_at'] as List<dynamic>? ?? const [])
        ((f as Map)['kelvin'] as num).round(): f['found'] == true,
    },
    chosenKelvin: (json['chosen_kelvin'] as num?)?.round(),
    code: json['code'] as String?,
  );
}

/// The board as one camera sees it: rings, wires and calibration points
class BoardDetection extends EngineEvent {
  const BoardDetection({
    required this.camera,
    required this.ok,
    this.imageSizePx,
    this.ellipses = const [],
    this.wiresPx = const [],
    this.pointsPx = const [],
  });

  final String camera;
  final bool ok;
  final Size? imageSizePx;
  final List<({Offset center, Size halfAxes, double angleDeg})> ellipses;
  final List<(Offset, Offset)> wiresPx;
  final List<Offset> pointsPx;

  factory BoardDetection.fromJson(Map<String, dynamic> json) => BoardDetection(
    camera: json['camera'] as String,
    ok: json['ok'] == true,
    imageSizePx: _size(json['image_size_px']),
    ellipses: [
      for (final e in json['ellipses'] as List<dynamic>? ?? const [])
        (
          center: _offset((e as Map)['center_px']),
          halfAxes: _size(e['axes_px']) ?? Size.zero,
          angleDeg: (e['angle_deg'] as num? ?? 0).toDouble(),
        ),
    ],
    wiresPx: [
      for (final w in json['wires_px'] as List<dynamic>? ?? const [])
        (
          Offset(((w as List)[0] as num).toDouble(), (w[1] as num).toDouble()),
          Offset((w[2] as num).toDouble(), (w[3] as num).toDouble()),
        ),
    ],
    pointsPx: [for (final p in json['points_px'] as List<dynamic>? ?? const []) _offset(p)],
  );
}

/// The stored board plane of a camera, with the sector numbers where the camera sees them
class BoardPlaneResult extends EngineEvent {
  const BoardPlaneResult({
    required this.camera,
    required this.fitMm,
    this.worstMm,
    this.lensCorrected = false,
    this.sectors = const {},
  });

  final String camera;
  final double fitMm;
  final double? worstMm;
  final bool lensCorrected;
  final Map<int, Offset> sectors;

  factory BoardPlaneResult.fromJson(Map<String, dynamic> json) => BoardPlaneResult(
    camera: json['camera'] as String,
    fitMm: _number(json['fit_mm']) ?? 0,
    worstMm: _number(json['worst_mm']),
    lensCorrected: json['lens_corrected'] == true,
    sectors: {
      for (final s in json['sectors'] as List<dynamic>? ?? const [])
        ((s as Map)['sector'] as num).round(): _offset(s['label_px']),
    },
  );
}

/// All cameras refined together: per camera how well, and what would help
class RefinementResult extends EngineEvent {
  const RefinementResult({
    required this.state,
    this.code,
    this.cameras = const [],
    this.outerBullMm,
    this.trebleCentreMm,
  });

  /// running, done or failed
  final String state;
  final String? code;
  final List<CameraRefinement> cameras;
  final double? outerBullMm;
  final double? trebleCentreMm;

  factory RefinementResult.fromJson(Map<String, dynamic> json) {
    final board = json['board'] as Map<String, dynamic>?;
    return RefinementResult(
      state: json['state'] as String? ?? '',
      code: json['code'] as String?,
      cameras: [
        for (final c in json['cameras'] as List<dynamic>? ?? const [])
          CameraRefinement.fromJson(c as Map<String, dynamic>),
      ],
      outerBullMm: _number(board?['outer_bull_mm']),
      trebleCentreMm: _number(board?['treble_centre_mm']),
    );
  }
}

class CameraRefinement {
  const CameraRefinement({
    required this.camera,
    required this.heldOutMm,
    required this.quality,
    this.uncertaintyMm,
    this.lensFrom,
    this.advice,
  });

  final String camera;
  final double heldOutMm;

  /// good, fair or poor
  final String quality;
  final double? uncertaintyMm;

  /// own, model or board
  final String? lensFrom;

  /// detect_again or lens_calibration
  final String? advice;

  factory CameraRefinement.fromJson(Map<String, dynamic> json) => CameraRefinement(
    camera: json['camera'] as String,
    heldOutMm: _number(json['held_out_mm']) ?? 0,
    quality: json['quality'] as String? ?? 'poor',
    uncertaintyMm: _number(json['uncertainty_mm']),
    lensFrom: json['lens_from'] as String?,
    advice: json['advice'] as String?,
  );
}

/// The real board seen from the front, in board coordinates (docs/engine-api.md, "Board image"): the point (x, y) mm
/// lies at column (x + radiusMm) / mmPerPx and row (radiusMm - y) / mmPerPx.
class BoardImage extends EngineEvent {
  const BoardImage({required this.jpeg, required this.radiusMm, required this.mmPerPx});

  final Uint8List jpeg;
  final double radiusMm;
  final double mmPerPx;

  factory BoardImage.fromJson(Map<String, dynamic> json) => BoardImage(
    jpeg: base64Decode(json['jpeg_base64'] as String),
    radiusMm: (json['radius_mm'] as num).toDouble(),
    mmPerPx: (json['mm_per_px'] as num).toDouble(),
  );
}

/// One camera against its calibration (docs/engine-api.md, "Calibration check"): has it moved? The background check
/// carries only [state] and [mm]; a subscription adds where the board is expected and where it is found.
class CalibrationCheck extends EngineEvent {
  const CalibrationCheck({
    required this.camera,
    required this.state,
    this.mm,
    this.shiftPx,
    this.count = 0,
    this.expectedPx = const [],
    this.foundPx = const [],
    this.imageSizePx,
    this.fitsCamera,
  });

  final String camera;

  /// checking, ok, off, moved, wrong_port, no_board or not_calibrated
  final String state;
  final double? mm;
  final Offset? shiftPx;
  final int count;

  /// Pairs in the same order: where the calibration expects a point, and where it is found now
  final List<Offset> expectedPx;
  final List<Offset> foundPx;
  final Size? imageSizePx;

  /// With wrong_port: the camera whose calibration fits this image
  final String? fitsCamera;

  /// The camera has to be measured again
  bool get needsCalibration => state == 'moved' || state == 'wrong_port';

  factory CalibrationCheck.fromJson(Map<String, dynamic> json) => CalibrationCheck(
    camera: json['camera'] as String,
    state: json['state'] as String? ?? 'checking',
    mm: _number(json['mm']),
    shiftPx: json['shift_px'] is List ? _offset(json['shift_px']) : null,
    count: (json['count'] as num? ?? 0).toInt(),
    expectedPx: [for (final p in json['expected_px'] as List<dynamic>? ?? const []) _offset(p)],
    foundPx: [for (final p in json['found_px'] as List<dynamic>? ?? const []) _offset(p)],
    imageSizePx: _size(json['image_size_px']),
    fitsCamera: json['fits_camera'] as String?,
  );
}

BoardPoint? _mmPoint(Object? json) =>
    json is List && json.length >= 2 ? BoardPoint((json[0] as num).toDouble(), (json[1] as num).toDouble()) : null;

/// The guided reference measurement (docs/engine-api.md, "reference_run"): darts pushed into known positions, and how
/// far the engine located them from there
class ReferenceRun extends EngineEvent {
  const ReferenceRun({required this.running, required this.step, this.target, this.results = const [], this.summary});

  final bool running;

  /// empty_board, insert_dart, remove_dart or done
  final String step;
  final ReferenceTarget? target;
  final List<ReferenceResult> results;
  final ReferenceSummary? summary;

  factory ReferenceRun.fromJson(Map<String, dynamic> json) {
    final target = json['target'] as Map<String, dynamic>?;
    final summary = json['summary'] as Map<String, dynamic>?;
    return ReferenceRun(
      running: json['running'] == true,
      step: json['step'] as String? ?? '',
      target: target == null
          ? null
          : ReferenceTarget(
              index: (target['index'] as num).toInt(),
              total: (target['total'] as num).toInt(),
              boardMm: _mmPoint(target['board_mm']) ?? const BoardPoint(0, 0),
              field: target['field'] as String? ?? '',
              wires: [for (final w in target['wires'] as List<dynamic>? ?? const []) (w as num).toInt()],
              hintCode: target['hint_code'] as String? ?? '',
            ),
      results: [
        for (final r in json['results'] as List<dynamic>? ?? const [])
          ReferenceResult(
            index: ((r as Map)['index'] as num).toInt(),
            boardMm: _mmPoint(r['board_mm']) ?? const BoardPoint(0, 0),
            locatedMm: _mmPoint(r['located_mm']),
            errorMm: _number(r['error_mm']),
            camerasUsed: (r['cameras_used'] as num? ?? 0).toInt(),
            reason: r['reason'] as String?,
          ),
      ],
      summary: summary == null
          ? null
          : ReferenceSummary(
              located: (summary['located'] as num? ?? 0).toInt(),
              abstained: (summary['abstained'] as num? ?? 0).toInt(),
              medianErrorMm: _number(summary['median_error_mm']),
              p90ErrorMm: _number(summary['p90_error_mm']),
              maxErrorMm: _number(summary['max_error_mm']),
            ),
    );
  }
}

class ReferenceTarget {
  const ReferenceTarget({
    required this.index,
    required this.total,
    required this.boardMm,
    required this.field,
    required this.wires,
    required this.hintCode,
  });

  final int index;
  final int total;
  final BoardPoint boardMm;

  /// D20, S6, Bull …
  final String field;

  /// The sector numbers on either side of the corner's radial wire; empty for the bull centre
  final List<int> wires;

  /// bull_centre or corner
  final String hintCode;
}

class ReferenceResult {
  const ReferenceResult({
    required this.index,
    required this.boardMm,
    this.locatedMm,
    this.errorMm,
    this.camerasUsed = 0,
    this.reason,
  });

  final int index;
  final BoardPoint boardMm;

  /// null when the engine abstained, with [reason]
  final BoardPoint? locatedMm;
  final double? errorMm;
  final int camerasUsed;
  final String? reason;
}

class ReferenceSummary {
  const ReferenceSummary({
    required this.located,
    required this.abstained,
    this.medianErrorMm,
    this.p90ErrorMm,
    this.maxErrorMm,
  });

  final int located;
  final int abstained;
  final double? medianErrorMm;
  final double? p90ErrorMm;
  final double? maxErrorMm;
}

/// A camera's whole image shifted, e.g. it was knocked; the engine checks its calibration next and sends no throw.
class CameraMoved extends EngineEvent {
  const CameraMoved(this.camera);

  final String camera;
}
