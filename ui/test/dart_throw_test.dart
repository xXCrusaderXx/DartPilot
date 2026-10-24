import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/dartboard.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/games/training.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every keypad field scores as itself', () {
    for (final geometry in [const BoardGeometry(), const BoardGeometry(outerBullRadiusMm: 15.4, wireRotationDeg: 4)]) {
      for (var sector = 1; sector <= 20; ++sector) {
        for (final (ring, label) in [
          (Ring.innerSingle, 'S'),
          (Ring.outerSingle, 'S'),
          (Ring.triple, 'T'),
          (Ring.double, 'D'),
        ]) {
          final dart = DartThrow(
            fieldCentre(ring, sector: sector, geometry: geometry),
            ThrowInput.keypad,
            geometry: geometry,
          );
          expect(dart.score.label, '$label$sector');
        }
      }
      expect(
        DartThrow(fieldCentre(Ring.outerBull, geometry: geometry), ThrowInput.keypad, geometry: geometry).score.label,
        '25',
      );
      expect(
        DartThrow(fieldCentre(Ring.innerBull, geometry: geometry), ThrowInput.keypad, geometry: geometry).score.label,
        '50',
      );
      expect(
        DartThrow(fieldCentre(Ring.miss, geometry: geometry), ThrowInput.keypad, geometry: geometry).score.label,
        'miss',
      );
    }
  });

  test('a widget position maps to board coordinates with +y up', () {
    const size = Size(400, 400);
    final scale = Dartboard.scaleFor(size, const BoardGeometry());
    final top = Dartboard.toBoard(Offset(200, 200 - 103 * scale), size, const BoardGeometry());
    expect(top.xMm, closeTo(0, 1e-9));
    expect(top.yMm, closeTo(103, 1e-9));
    expect(DartThrow(top, ThrowInput.board).score.label, 'T20');
  });

  test('training counts visits, points and the average, and undoes', () {
    final training = Training();
    for (final ring in [Ring.triple, Ring.triple, Ring.innerSingle, Ring.double]) {
      training.add(DartThrow(fieldCentre(ring), ThrowInput.keypad));
    }
    expect(training.dartCount, 4);
    expect(training.totalPoints, 60 + 60 + 20 + 40);
    expect(training.visitNumber, 2);
    expect(training.currentVisit.map((d) => d.score.label), ['D20']);
    expect(training.threeDartAverage, closeTo(3 * 180 / 4, 1e-9));
    training.undo();
    expect(training.currentVisit.map((d) => d.score.label), ['T20', 'T20', 'S20']);
    expect(training.visitNumber, 1);
  });
}
