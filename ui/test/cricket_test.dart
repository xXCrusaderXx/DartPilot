import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/games/around_the_clock.dart';
import 'package:dartpilot/src/games/cricket.dart';
import 'package:flutter_test/flutter_test.dart';

DartThrow d(String label) {
  if (label == 'miss') return DartThrow(fieldCentre(Ring.miss), ThrowInput.keypad);
  if (label == '25') return DartThrow(fieldCentre(Ring.outerBull), ThrowInput.keypad);
  if (label == '50') return DartThrow(fieldCentre(Ring.innerBull), ThrowInput.keypad);
  final ring = switch (label[0]) {
    'T' => Ring.triple,
    'D' => Ring.double,
    _ => Ring.innerSingle,
  };
  return DartThrow(fieldCentre(ring, sector: int.parse(label.substring(1))), ThrowInput.keypad);
}

void play(dynamic game, List<String> labels) {
  for (final label in labels) {
    game.add(d(label));
  }
}

void main() {
  group('cricket', () {
    test('marks close a number, extra marks score while an opponent is open', () {
      final g = CricketGame(['A', 'B']);
      play(g, ['T20', 'D20', 'S1']);
      expect(g.players[0].marks[20], 5);
      expect(g.players[0].points, 40);
      expect(g.current, 1);
      play(g, ['T20', 'miss', 'miss']);
      play(g, ['S20', 'miss', 'miss']);
      expect(g.players[0].points, 40, reason: 'B has closed 20 now');
      expect(g.players[0].totalMarks, 5);
    });

    test('bull: outer one mark, inner two marks, 25 points each', () {
      final g = CricketGame(['A', 'B']);
      play(g, ['50', '25', '50']);
      expect(g.players[0].marks[25], 5);
      expect(g.players[0].points, 50);
    });

    test('numbers below 15 do not count', () {
      final g = CricketGame(['A']);
      play(g, ['T14', 'D1', 'S12']);
      expect(g.players[0].marks.values.every((m) => m == 0), isTrue);
      expect(g.currentVisit.map((x) => x.target), [null, null, null]);
    });

    test('closing everything wins only with at least as many points', () {
      final g = CricketGame(['A', 'B']);
      // B scores 60 on 20 first, then A closes everything with fewer points.
      play(g, ['miss', 'miss', 'miss']);
      play(g, ['T20', 'T20', 'miss']);
      expect(g.players[1].points, 60);
      play(g, ['T20', 'T19', 'T18']);
      play(g, ['miss', 'miss', 'miss']);
      play(g, ['T17', 'T16', 'T15']);
      play(g, ['miss', 'miss', 'miss']);
      play(g, ['50', '25']);
      expect(g.players[0].allClosed, isTrue);
      expect(g.isFinished, isFalse);
      // A scores on the still open 19 of B until ahead.
      play(g, ['miss']);
      play(g, ['miss', 'miss', 'miss']);
      play(g, ['T19', 'S19']);
      expect(g.players[0].points, 76);
      expect(g.winner, 0);
    });

    test('one player wins by closing everything', () {
      final g = CricketGame(['Solo']);
      play(g, ['T20', 'T19', 'T18', 'T17', 'T16', 'T15', '50', '25']);
      expect(g.winner, 0);
      expect(g.players[0].marksPerRound, closeTo(3 * 21 / 8, 1e-9));
    });

    test('undo replays exactly', () {
      final g = CricketGame(['A', 'B']);
      play(g, ['T20', 'T20', 'T20']);
      g.undo();
      expect(g.players[0].points, 60);
      expect(g.current, 0);
      expect(g.currentVisit.length, 2);
    });
  });

  group('around the clock', () {
    test('any ring of the target advances, other numbers do not', () {
      final g = AroundTheClockGame(['A', 'B']);
      play(g, ['S1', 'T2', 'S20']);
      expect(g.players[0].position, 2);
      expect(g.targetLabel(g.players[0].position), '3');
      expect(g.current, 1);
      expect(g.players[0].hitRate, closeTo(2 / 3, 1e-9));
    });

    test('ends with the bull, inner or outer', () {
      final g = AroundTheClockGame(['A']);
      play(g, [for (var n = 1; n <= 20; ++n) 'D$n']);
      expect(g.isFinished, isFalse);
      expect(g.targetLabel(g.players[0].position), 'Bull');
      play(g, ['25']);
      expect(g.winner, 0);
    });

    test('without the bull the 20 finishes', () {
      final g = AroundTheClockGame(['A'], endWithBull: false);
      play(g, [for (var n = 1; n <= 20; ++n) 'S$n']);
      expect(g.winner, 0);
      expect(g.players[0].dartsThrown, 20);
    });

    test('undo', () {
      final g = AroundTheClockGame(['A', 'B']);
      play(g, ['S1', 'S2', 'S3', 'S1']);
      g.undo();
      g.undo();
      expect(g.current, 0);
      expect(g.players[0].position, 2);
    });
  });
}
