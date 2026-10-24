// Mirrors tests/ScoringTest.cpp, so the Dart scorer gives the same result as the engine for every point.
import 'dart:math' as math;

import 'package:dartpilot/src/board/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

Score scoreAt(double rMm, double phiDeg, [BoardGeometry geometry = const BoardGeometry()]) {
  final phi = phiDeg * math.pi / 180;
  return score(rMm * math.cos(phi), rMm * math.sin(phi), geometry);
}

double sectorMiddleOf(int i) => 90.0 - 18.0 * i;

/// Independent reference: the sector whose middle is angularly closest to the point
int referenceSector(double x, double y) {
  final phi = math.atan2(y, x) * 180 / math.pi;
  var best = 0;
  var bestDifference = 1e9;
  for (var i = 0; i < 20; ++i) {
    var difference = (phi - sectorMiddleOf(i)) % 360.0;
    if (difference > 180) difference = 360 - difference;
    if (difference < bestDifference) {
      bestDifference = difference;
      best = sectorsClockwiseFromTop[i];
    }
  }
  return best;
}

void main() {
  test('every sector in every ring', () {
    for (var i = 0; i < 20; ++i) {
      final sector = sectorsClockwiseFromTop[i];
      final phi = sectorMiddleOf(i);
      expect(scoreAt(50, phi).points, sector);
      expect(scoreAt(103, phi).points, 3 * sector);
      expect(scoreAt(130, phi).points, sector);
      expect(scoreAt(166, phi).points, 2 * sector);
      expect(scoreAt(103, phi).ring, Ring.triple);
      expect(scoreAt(166, phi).ring, Ring.double);
    }
  });

  test('bulls', () {
    expect(score(0, 0).points, 50);
    expect(score(0, 0).ring, Ring.innerBull);
    expect(score(3, -4).points, 50);
    expect(score(10, 0).points, 25);
    expect(score(10, 0).sector, 0);
    expect(score(-7, 7).ring, Ring.outerBull);
  });

  test('miss', () {
    final miss = score(0, 200);
    expect(miss.ring, Ring.miss);
    expect(miss.points, 0);
    expect(miss.sector, 0);
    expect(miss.multiplier, 0);
    expect(miss.boundaryDistanceMm, 30.0);
  });

  test('ring boundaries belong to the region further out', () {
    expect(score(6.35, 0).ring, Ring.outerBull);
    expect(score(15.9, 0).ring, Ring.innerSingle);
    expect(score(99.0, 0).ring, Ring.triple);
    expect(score(107.0, 0).ring, Ring.outerSingle);
    expect(score(162.0, 0).ring, Ring.double);
    expect(score(170.0, 0).ring, Ring.miss);
    expect(score(6.35 - 1e-12, 0).ring, Ring.innerBull);
    expect(score(99.0 - 1e-12, 0).ring, Ring.innerSingle);
    expect(score(170.0 - 1e-12, 0).ring, Ring.double);
  });

  test('radial wires split neighbouring sectors', () {
    expect(scoreAt(50, 9.0 - 1e-6).sector, 6);
    expect(scoreAt(50, 9.0 + 1e-6).sector, 13);
    expect(score(-50, 1e-6).sector, 11);
    expect(score(-50, -1e-6).sector, 11);
    expect(scoreAt(50, 189.0 + 1e-6).sector, 8);
    expect(scoreAt(50, 189.0 - 1e-6).sector, 11);
  });

  test('boundary distances', () {
    final s6 = score(50, 0);
    expect(s6.sectorBoundaryDistanceMm, closeTo(50 * math.sin(9 * math.pi / 180), 1e-9));
    expect(s6.ringBoundaryDistanceMm, closeTo(50 - 15.9, 1e-9));
    expect(score(99.5, 0).boundaryDistanceMm, closeTo(0.5, 1e-9));
    expect(score(10, 0).sectorBoundaryDistanceMm, double.infinity);
    expect(score(10, 0).boundaryDistanceMm, closeTo(3.65, 1e-9));
    expect(scoreAt(120, 9.0 - 0.1).sectorBoundaryDistanceMm, lessThan(0.21));
  });

  test('measured geometry', () {
    const rotated = BoardGeometry(wireRotationDeg: 18);
    expect(scoreAt(50, 108, rotated).sector, 20);
    expect(scoreAt(50, 90, rotated).sector, 1);
    const wide = BoardGeometry(doubleOuterRadiusMm: 171);
    expect(score(170.5, 0).ring, Ring.miss);
    expect(score(170.5, 0, wide).ring, Ring.double);
  });

  test('geometry validation', () {
    expect(const BoardGeometry().isValid, isTrue);
    expect(const BoardGeometry(tripleInnerRadiusMm: 110).isValid, isFalse);
    expect(const BoardGeometry(wireRotationDeg: double.nan).isValid, isFalse);
  });

  test('labels', () {
    expect(scoreAt(103, 90).label, 'T20');
    expect(scoreAt(166, sectorMiddleOf(18)).label, 'D12');
    expect(scoreAt(50, sectorMiddleOf(1)).label, 'S1');
    expect(score(0, 0).label, '50');
    expect(score(10, 0).label, '25');
    expect(score(0, 180).label, 'miss');
  });

  test('matches the reference on a 0.5 mm grid', () {
    var checked = 0;
    for (var y = -175.0; y <= 175.0; y += 0.5) {
      for (var x = -175.0; x <= 175.0; x += 0.5) {
        final r = math.sqrt(x * x + y * y);
        if (r < 15.9 || r >= 170.0) continue;
        final result = score(x, y);
        expect(result.sector, referenceSector(x, y), reason: 'at ($x, $y)');
        final multiplier = (r >= 99.0 && r < 107.0) ? 3 : (r >= 162.0 ? 2 : 1);
        expect(result.multiplier, multiplier, reason: 'at ($x, $y)');
        ++checked;
      }
    }
    expect(checked, greaterThan(350000));
  });
}
