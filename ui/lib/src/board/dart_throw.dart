import 'dart:math' as math;

import 'scoring.dart';
import 'scoring.dart' as scoring show score;

/// Impact position in board coordinates (docs/board-coordinates.md)
class BoardPoint {
  const BoardPoint(this.xMm, this.yMm);

  final double xMm;
  final double yMm;

  factory BoardPoint.polar(double rMm, double phiDeg) {
    final phi = phiDeg * math.pi / 180.0;
    return BoardPoint(rMm * math.cos(phi), rMm * math.sin(phi));
  }

  @override
  bool operator ==(Object other) => other is BoardPoint && other.xMm == xMm && other.yMm == yMm;

  @override
  int get hashCode => Object.hash(xMm, yMm);
}

/// Where a throw came from
enum ThrowInput { board, keypad, engine }

/// One dart. The score is always derived from the board point (docs/board-coordinates.md), also for keypad input,
/// which places the point in the middle of the chosen field.
class DartThrow {
  DartThrow(
    this.point,
    this.input, {
    BoardGeometry geometry = const BoardGeometry(),
    this.engineThrowId,
    this.confidence,
  }) : score = scoring.score(point.xMm, point.yMm, geometry);

  final BoardPoint point;
  final ThrowInput input;
  final Score score;

  /// Throw ID of the engine for darts it detected or recorded, so corrections can refer to them
  final String? engineThrowId;

  /// Engine confidence, 0 to 1, for detected darts
  final double? confidence;
}

/// Middle of a field, for keypad input: the bull centre, the middle of a ring band in the middle of a sector, or a
/// point outside the board for a miss.
BoardPoint fieldCentre(Ring ring, {int sector = 20, BoardGeometry geometry = const BoardGeometry()}) {
  final g = geometry;
  if (ring == Ring.innerBull) return const BoardPoint(0, 0);
  final rMm = switch (ring) {
    Ring.innerBull => 0.0,
    Ring.outerBull => (g.bullRadiusMm + g.outerBullRadiusMm) / 2,
    Ring.innerSingle => (g.outerBullRadiusMm + g.tripleInnerRadiusMm) / 2,
    Ring.triple => (g.tripleInnerRadiusMm + g.tripleOuterRadiusMm) / 2,
    Ring.outerSingle => (g.tripleOuterRadiusMm + g.doubleInnerRadiusMm) / 2,
    Ring.double => (g.doubleInnerRadiusMm + g.doubleOuterRadiusMm) / 2,
    Ring.miss => g.doubleOuterRadiusMm + 15.0,
  };
  return BoardPoint.polar(rMm, sectorMiddleDeg(sector, geometry));
}
