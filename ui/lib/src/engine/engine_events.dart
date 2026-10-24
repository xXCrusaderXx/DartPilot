// Messages of the engine API, protocol dartpilot/1.0 (docs/engine-api.md), as Dart objects.
import 'dart:convert';
import 'dart:typed_data';

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
    'engine_status' => EngineStatus(json['detection'] as String, json['message'] as String? ?? ''),
    _ => null,
  };
}

BoardPoint? _point(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  return BoardPoint((json['x_mm'] as num).toDouble(), (json['y_mm'] as num).toDouble());
}

class EngineHello extends EngineEvent {
  const EngineHello({required this.protocol, required this.mode, required this.geometry, required this.cameras});

  final String protocol;
  final String mode;
  final BoardGeometry geometry;
  final List<String> cameras;

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

class EngineStatus extends EngineEvent {
  const EngineStatus(this.detection, this.message);

  final String detection;
  final String message;
}
