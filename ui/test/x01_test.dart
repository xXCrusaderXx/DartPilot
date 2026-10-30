import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/games/x01.dart';
import 'package:flutter_test/flutter_test.dart';

DartThrow d(String label) {
  final sector = label.length > 1 && label != '25' && label != '50' ? int.parse(label.substring(1)) : 20;
  return DartThrow(fieldCentre(ringOf(label), sector: sector), ThrowInput.keypad);
}

X01Game game({int start = 501, bool doubleIn = false, bool doubleOut = true, int legs = 1, int players = 2}) => X01Game(
  X01Settings(
    players: [for (var i = 0; i < players; ++i) 'P${i + 1}'],
    startScore: start,
    doubleIn: doubleIn,
    doubleOut: doubleOut,
    legsToWin: legs,
  ),
);

void play(X01Game g, List<String> labels) {
  for (final label in labels) {
    g.add(d(label));
  }
}

void main() {
  test('three darts make a visit, then the next player throws', () {
    final g = game();
    play(g, ['T20', 'T20', 'T20']);
    expect(g.players[0].remaining, 321);
    expect(g.current, 1);
    expect(g.currentVisit.darts, isEmpty);
    expect(g.players[0].threeDartAverage, 180);
  });

  test('bust restores the score and ends the visit', () {
    final g = game(start: 101, players: 1);
    play(g, ['T20', 'S20']);
    expect(g.players[0].remaining, 21);
    play(g, ['T20']);
    expect(g.visits[0].isBust, isTrue);
    expect(g.players[0].remaining, 101);
    expect(g.players[0].pointsScored, 0);
    expect(g.players[0].dartsThrown, 3);
  });

  test('double out: leaving 1 or finishing on a single is a bust', () {
    final g = game(start: 41, players: 1);
    play(g, ['S20', 'S20']);
    expect(g.visits[0].isBust, isTrue);
    expect(g.players[0].remaining, 41);
    play(g, ['S1', 'S20', 'S20']);
    expect(g.visits[1].isBust, isTrue);
    play(g, ['S1', 'D20']);
    expect(g.isFinished, isTrue);
    expect(g.winner, 0);
    expect(g.players[0].checkouts, [41]);
  });

  test('bull counts as a double for the checkout', () {
    final g = game(start: 50, players: 1);
    play(g, ['50']);
    expect(g.isFinished, isTrue);
  });

  test('single out finishes on any dart', () {
    final g = game(start: 20, players: 1, doubleOut: false);
    play(g, ['S20']);
    expect(g.isFinished, isTrue);
  });

  test('double in: darts before the first double do not count', () {
    final g = game(start: 301, players: 1, doubleIn: true);
    play(g, ['T20', 'D10', 'T20']);
    expect(g.visits[0].darts.map((x) => x.result), [DartResult.notIn, DartResult.scored, DartResult.scored]);
    expect(g.players[0].remaining, 301 - 20 - 60);
  });

  test('a won leg starts the next one with the next player', () {
    final g = game(start: 40, legs: 2);
    play(g, ['D20']);
    expect(g.players[0].legsWon, 1);
    expect(g.isFinished, isFalse);
    expect(g.legNumber, 2);
    expect(g.current, 1);
    expect(g.players.map((p) => p.remaining), [40, 40]);
    play(g, ['D20']);
    expect(g.players[1].legsWon, 1);
    expect(g.current, 0);
    play(g, ['S20', 'D10']);
    expect(g.winner, 0);
  });

  test('undo replays to the same state, also across a bust and a leg', () {
    final g = game(start: 40, legs: 2);
    play(g, ['D20', 'S20', 'S19']);
    g.undo();
    expect(g.current, 1);
    expect(g.players[1].remaining, 20);
    g.undo();
    g.undo();
    expect(g.legNumber, 1);
    expect(g.players[0].remaining, 40);
    expect(g.players[0].legsWon, 0);
    expect(g.canUndo, isFalse);
  });

  test('no darts after the match is won', () {
    final g = game(start: 40, players: 1);
    play(g, ['D20', 'T20']);
    expect(g.players[0].dartsThrown, 1);
  });

  group('checkout suggestions', () {
    test('classic routes', () {
      expect(suggestCheckout(170, 3), ['T20', 'T20', '50']);
      expect(suggestCheckout(100, 2), ['T20', 'D20']);
      expect(suggestCheckout(40, 1), ['D20']);
      expect(suggestCheckout(32, 1), ['D16']);
      expect(suggestCheckout(41, 2), ['S9', 'D16']);
      expect(suggestCheckout(60, 2), ['S20', 'D20']);
      expect(suggestCheckout(141, 3), ['T20', 'T19', 'D12']);
      expect(suggestCheckout(50, 1), ['50']);
    });

    test('no route where none exists', () {
      for (final bogey in [169, 168, 166, 165, 163, 162, 159]) {
        expect(suggestCheckout(bogey, 3), isNull, reason: '$bogey');
      }
      expect(suggestCheckout(1, 3), isNull);
      expect(suggestCheckout(101, 1), isNull);
      expect(suggestCheckout(161, 2), isNull);
    });

    test('every suggested route finishes exactly on a double', () {
      for (var remaining = 2; remaining <= 170; ++remaining) {
        final route = suggestCheckout(remaining, 3);
        if (route == null) continue;
        final darts = [for (final label in route) d(label)];
        expect(darts.fold(0, (sum, x) => sum + x.score.points), remaining, reason: '$route');
        expect(darts.last.score.isDouble, isTrue, reason: '$route');
      }
    });

    test('three-dart routes follow the usual charts: T20 or T19 first, a plain single to set up', () {
      expect(suggestCheckout(99, 3), ['T19', 'S10', 'D16']);
      expect(suggestCheckout(102, 3), ['T20', 'S10', 'D16']);
      expect(suggestCheckout(103, 3), ['T19', 'S6', 'D20']);
      expect(suggestCheckout(106, 3), ['T20', 'S10', 'D18']);
      expect(suggestCheckout(113, 3), ['T20', 'S13', 'D20']);
      expect(suggestCheckout(114, 3), ['T20', 'S14', 'D20']);
      // With fewer darts left the chart's three-dart route does not apply.
      expect(suggestCheckout(113, 2), isNull);
      expect(suggestCheckout(82, 2), ['50', 'D16']);
    });

    test('in single-out the big darts come first', () {
      expect(suggestCheckout(170, 3, doubleOut: false), ['T20', 'T20', '50']);
      expect(suggestCheckout(110, 3, doubleOut: false), ['T20', '50']);
    });

    test('the game names the route as players read it: Bull and plain singles', () {
      expect(game(start: 170, players: 1).checkoutSuggestion, ['T20', 'T20', 'Bull']);
      expect(game(start: 60, players: 1).checkoutSuggestion, ['20', 'D20']);
      expect(game(start: 116, players: 1).checkoutSuggestion, ['T20', '16', 'D20']);
    });

    test('the game suggests with the darts left in the visit', () {
      final g = game(start: 141, players: 1);
      expect(g.checkoutSuggestion, ['T20', 'T19', 'D12']);
      play(g, ['T20']);
      expect(g.checkoutSuggestion, ['T19', 'D12']);
    });
  });

  test('a correction that wins the match earlier ends it there, as a replay of the record would', () {
    final g = game(start: 101, players: 1);
    play(g, ['T20', 'S1', 'S20', 'S20']);
    expect(g.isFinished, isFalse);
    // The third dart was a D20: 101 is out in three darts, and the dart after it was never part of the game.
    g.replace(2, d('D20'));
    expect(g.isFinished, isTrue);
    expect(g.throws, hasLength(3));
    expect(g.players[0].dartsThrown, 3);
  });

  test('every visit knows its leg', () {
    final g = game(start: 101, legs: 2, players: 1);
    play(g, ['T20', 'S1', 'D20']);
    expect(g.visits.first.leg, 1);
    expect(g.legNumber, 2);
    expect(g.currentVisit.leg, 2);
  });
}
