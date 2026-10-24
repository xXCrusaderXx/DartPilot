// Board point in mm to sector and ring, a port of engine/scoring (docs/board-coordinates.md).
// The C++ scorer is authoritative for the engine; this one scores manual input in the app and must give the same
// result for every point (test/scoring_test.dart mirrors tests/ScoringTest.cpp).
import 'dart:math' as math;

/// Sector numbers clockwise from the top; the middle of sector 20 is the +y axis.
const List<int> sectorsClockwiseFromTop = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];

const double _sectorWidthDeg = 18.0;
const double _halfSectorWidthDeg = _sectorWidthDeg / 2.0;

/// Ring boundaries and wire rotation of one board. The defaults are the nominal tournament dimensions; the measured
/// board model of the calibration replaces them.
class BoardGeometry {
  const BoardGeometry({
    this.bullRadiusMm = 6.35,
    this.outerBullRadiusMm = 15.9,
    this.tripleInnerRadiusMm = 99.0,
    this.tripleOuterRadiusMm = 107.0,
    this.doubleInnerRadiusMm = 162.0,
    this.doubleOuterRadiusMm = 170.0,
    this.wireRotationDeg = 0.0,
  });

  final double bullRadiusMm;
  final double outerBullRadiusMm;
  final double tripleInnerRadiusMm;
  final double tripleOuterRadiusMm;
  final double doubleInnerRadiusMm;
  final double doubleOuterRadiusMm;

  /// Counter-clockwise rotation of the radial wires from their nominal angles 9 + k * 18 degrees
  final double wireRotationDeg;

  List<double> get boundaries => [
    bullRadiusMm,
    outerBullRadiusMm,
    tripleInnerRadiusMm,
    tripleOuterRadiusMm,
    doubleInnerRadiusMm,
    doubleOuterRadiusMm,
  ];

  /// Radii are positive and strictly increasing, and the rotation is finite.
  bool get isValid {
    final radii = boundaries;
    if (!(radii.first > 0.0) || !wireRotationDeg.isFinite || !radii.last.isFinite) return false;
    for (var i = 1; i < radii.length; ++i) {
      if (!(radii[i - 1] < radii[i])) return false;
    }
    return true;
  }
}

enum Ring { innerBull, outerBull, innerSingle, triple, outerSingle, double, miss }

class Score {
  const Score({
    required this.ring,
    required this.sector,
    required this.multiplier,
    required this.points,
    required this.ringBoundaryDistanceMm,
    required this.sectorBoundaryDistanceMm,
  });

  final Ring ring;

  /// 1 to 20; 0 for the bulls and a miss
  final int sector;

  /// 0 for a miss
  final int multiplier;
  final int points;
  final double ringBoundaryDistanceMm;

  /// Distance to the nearest radial wire; infinite inside the outer bull and outside the double ring
  final double sectorBoundaryDistanceMm;

  /// How far the point may move before its score can change
  double get boundaryDistanceMm => math.min(ringBoundaryDistanceMm, sectorBoundaryDistanceMm);

  bool get isDouble => ring == Ring.double || ring == Ring.innerBull;

  /// "T20", "D16", "S5", "25", "50" or "miss"
  String get label => switch (ring) {
    Ring.innerBull => '50',
    Ring.outerBull => '25',
    Ring.innerSingle || Ring.outerSingle => 'S$sector',
    Ring.triple => 'T$sector',
    Ring.double => 'D$sector',
    Ring.miss => 'miss',
  };
}

double _normalised(double angleDeg) {
  final wrapped = angleDeg % 360.0;
  return wrapped < 0.0 ? wrapped + 360.0 : wrapped;
}

double _degrees(double radians) => radians * 180.0 / math.pi;

double _radians(double degrees) => degrees * math.pi / 180.0;

/// Deterministic: the same point and geometry always give the same score. A point exactly on a ring boundary belongs
/// to the region further out, a point exactly on a radial wire to the sector counter-clockwise from it.
Score score(double xMm, double yMm, [BoardGeometry geometry = const BoardGeometry()]) {
  final rMm = math.sqrt(xMm * xMm + yMm * yMm);
  final boundaries = geometry.boundaries;

  // Half-open rings [inner, outer): a point on a boundary counts as further out.
  var ringIndex = 0;
  while (ringIndex < boundaries.length && boundaries[ringIndex] <= rMm) {
    ++ringIndex;
  }
  const rings = [
    Ring.innerBull,
    Ring.outerBull,
    Ring.innerSingle,
    Ring.triple,
    Ring.outerSingle,
    Ring.double,
    Ring.miss,
  ];
  final ring = rings[ringIndex];

  var ringDistance = double.infinity;
  for (final boundary in boundaries) {
    ringDistance = math.min(ringDistance, (rMm - boundary).abs());
  }

  // Angle relative to the wires, so that sector 6 spans [-9, 9) degrees and each next sector counter-clockwise starts
  // where the previous one ends.
  final phiDeg = _normalised(_degrees(math.atan2(yMm, xMm)) - geometry.wireRotationDeg);
  final fromBoundaryDeg = _normalised(phiDeg + _halfSectorWidthDeg);
  final counterClockwiseIndex = math.min((fromBoundaryDeg / _sectorWidthDeg).floor(), 19);
  // The middle of sector 6 (index 5 clockwise from the top) lies at 0 degrees.
  final clockwiseIndex = ((5 - counterClockwiseIndex) % 20 + 20) % 20;
  final sectorNumber = sectorsClockwiseFromTop[clockwiseIndex];

  final hasRadialWires = ring != Ring.innerBull && ring != Ring.outerBull && ring != Ring.miss;
  var sectorDistance = double.infinity;
  if (hasRadialWires) {
    final intoSectorDeg = fromBoundaryDeg - counterClockwiseIndex * _sectorWidthDeg;
    final toWireDeg = math.min(intoSectorDeg, _sectorWidthDeg - intoSectorDeg);
    sectorDistance = rMm * math.sin(_radians(toWireDeg));
  }

  final (sector, multiplier, points) = switch (ring) {
    Ring.innerBull => (0, 2, 50),
    Ring.outerBull => (0, 1, 25),
    Ring.innerSingle || Ring.outerSingle => (sectorNumber, 1, sectorNumber),
    Ring.triple => (sectorNumber, 3, 3 * sectorNumber),
    Ring.double => (sectorNumber, 2, 2 * sectorNumber),
    Ring.miss => (0, 0, 0),
  };
  return Score(
    ring: ring,
    sector: sector,
    multiplier: multiplier,
    points: points,
    ringBoundaryDistanceMm: ringDistance,
    sectorBoundaryDistanceMm: sectorDistance,
  );
}

/// Angle in degrees (counter-clockwise from the +x axis) of the middle of a sector on this board.
double sectorMiddleDeg(int sector, [BoardGeometry geometry = const BoardGeometry()]) {
  final index = sectorsClockwiseFromTop.indexOf(sector);
  if (index < 0) throw ArgumentError.value(sector, 'sector', 'not 1 to 20');
  return 90.0 - _sectorWidthDeg * index + geometry.wireRotationDeg;
}
