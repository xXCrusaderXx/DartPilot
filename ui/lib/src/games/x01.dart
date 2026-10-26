import '../board/dart_throw.dart';
import '../board/scoring.dart';
import 'dart_game.dart';

class X01Settings {
  const X01Settings({
    required this.players,
    this.startScore = 501,
    this.doubleIn = false,
    this.doubleOut = true,
    this.legsToWin = 1,
  });

  final List<String> players;
  final int startScore;

  /// Darts only count from the first double (or bull) of a leg on
  final bool doubleIn;

  /// The leg has to be finished with a double (or bull)
  final bool doubleOut;

  /// First to this many legs wins the match
  final int legsToWin;
}

/// Outcome of one dart in the game
enum DartResult { scored, notIn, bust, checkout }

class X01Dart {
  const X01Dart(this.dart, this.result, this.pointsCounted);

  final DartThrow dart;
  final DartResult result;

  /// Points this dart took off the remaining score; 0 for a dart before double-in and for every dart of a bust
  final int pointsCounted;
}

class X01Visit {
  X01Visit(this.player, this.startRemaining);

  final int player;
  final int startRemaining;
  final List<X01Dart> darts = [];

  bool get isBust => darts.any((d) => d.result == DartResult.bust);
  bool get isCheckout => darts.any((d) => d.result == DartResult.checkout);
  bool get isComplete => darts.length == 3 || isBust || isCheckout;
  int get points => isBust ? 0 : darts.fold(0, (sum, d) => sum + d.pointsCounted);
}

class X01PlayerState {
  X01PlayerState(this.name, this.remaining);

  final String name;
  int remaining;
  bool isIn = false;
  int legsWon = 0;
  int dartsThrown = 0;
  int pointsScored = 0;
  int legDarts = 0;
  final List<int> checkouts = [];

  /// Points per three darts over the match; bust visits count their darts with 0 points
  double get threeDartAverage => dartsThrown == 0 ? 0 : 3 * pointsScored / dartsThrown;
}

/// X01 state, derived by replaying all darts from the settings. Undo removes the last dart and replays, so the state
/// can never drift from the throws.
class X01Game implements DartGame {
  X01Game(this.settings) {
    if (settings.players.isEmpty) throw ArgumentError('at least one player');
    _replay();
  }

  final X01Settings settings;
  final List<DartThrow> _throws = [];

  late List<X01PlayerState> players;
  late List<X01Visit> visits;
  late int legNumber;
  late int legStarter;
  late int current;
  int? winner;

  /// Visit of the player at the oche, possibly with no darts yet
  X01Visit get currentVisit => visits.last;

  @override
  bool get isFinished => winner != null;

  bool get canUndo => _throws.isNotEmpty;

  @override
  List<DartThrow> get throws => List.unmodifiable(_throws);

  @override
  int get dartsInVisit => currentVisit.isComplete ? 0 : currentVisit.darts.length;

  @override
  void replace(int index, DartThrow dart) {
    _throws[index] = dart;
    _replay();
  }

  @override
  void add(DartThrow dart) {
    if (isFinished) return;
    _throws.add(dart);
    _apply(dart);
  }

  @override
  void undo() {
    if (_throws.isEmpty) return;
    _throws.removeLast();
    _replay();
  }

  void _replay() {
    players = [for (final name in settings.players) X01PlayerState(name, settings.startScore)];
    legNumber = 1;
    legStarter = 0;
    current = 0;
    winner = null;
    visits = [X01Visit(0, settings.startScore)];
    for (final dart in _throws) {
      _apply(dart);
    }
  }

  void _apply(DartThrow dart) {
    final player = players[current];
    final visit = currentVisit;
    final score = dart.score;
    player.dartsThrown++;
    player.legDarts++;

    DartResult result;
    var counted = 0;
    if (settings.doubleIn && !player.isIn && !score.isDouble) {
      result = DartResult.notIn;
    } else {
      player.isIn = true;
      final after = player.remaining - score.points;
      final finishesOnDouble = !settings.doubleOut || score.isDouble;
      if (after < 0 || (after == 0 && !finishesOnDouble) || (after == 1 && settings.doubleOut)) {
        result = DartResult.bust;
      } else if (after == 0) {
        result = DartResult.checkout;
        counted = score.points;
      } else {
        result = DartResult.scored;
        counted = score.points;
      }
    }
    visit.darts.add(X01Dart(dart, result, counted));

    if (result == DartResult.bust) {
      // The whole visit is void: back to the score before it.
      for (final d in visit.darts) {
        player.pointsScored -= d.pointsCounted;
      }
      player.remaining = visit.startRemaining;
      if (settings.doubleIn && visit.startRemaining == settings.startScore) player.isIn = false;
    } else {
      player.remaining -= counted;
      player.pointsScored += counted;
    }

    if (result == DartResult.checkout) {
      player.legsWon++;
      player.checkouts.add(visit.startRemaining);
      if (player.legsWon >= settings.legsToWin) {
        winner = current;
        return;
      }
      _startNextLeg();
      return;
    }
    if (visit.isComplete) {
      current = (current + 1) % players.length;
      visits.add(X01Visit(current, players[current].remaining));
    }
  }

  void _startNextLeg() {
    legNumber++;
    legStarter = (legStarter + 1) % players.length;
    for (final p in players) {
      p.remaining = settings.startScore;
      p.isIn = false;
      p.legDarts = 0;
    }
    current = legStarter;
    visits.add(X01Visit(current, settings.startScore));
  }

  /// Checkout route for the player at the oche with the darts left in this visit, or null if there is none.
  List<String>? get checkoutSuggestion {
    if (isFinished) return null;
    final player = players[current];
    if (settings.doubleIn && !player.isIn) return null;
    return suggestCheckout(player.remaining, 3 - currentVisit.darts.length, doubleOut: settings.doubleOut);
  }
}

class _Field {
  const _Field(this.label, this.points, this.isDouble, this.penalty);

  final String label;
  final int points;
  final bool isDouble;

  /// How unusual it is to aim for this field; routes with the lowest total are suggested.
  final double penalty;
}

// Setup darts: big trebles and singles are the usual targets, the outer bull is a last resort.
final List<_Field> _setupFields = [
  for (var n = 20; n >= 1; --n) _Field('T$n', 3 * n, false, (20 - n).toDouble()),
  for (var n = 20; n >= 1; --n) _Field('S$n', n, false, 0.5 * (20 - n)),
  const _Field('25', 25, false, 15),
  const _Field('50', 50, true, 15),
];

// Finishing doubles in the order players prefer them: the ones that split well when missed come first. The rank
// weighs twice as much as a setup dart, so a route to D20 or D16 wins over a slightly simpler setup.
const List<int> _preferredDoubles = [20, 16, 8, 18, 12, 10, 4, 14, 6, 2, 19, 17, 15, 13, 11, 9, 7, 5, 3, 1];
final List<_Field> _finishFields = [
  for (var i = 0; i < _preferredDoubles.length; ++i)
    _Field('D${_preferredDoubles[i]}', 2 * _preferredDoubles[i], true, 2.0 * i),
  const _Field('50', 50, true, 20),
];

/// Fewest-dart route to finish `remaining` with at most `dartsLeft` darts, ending on a double if `doubleOut`.
/// Among routes with the same number of darts, the one with the most usual fields wins; the result is deterministic.
List<String>? suggestCheckout(int remaining, int dartsLeft, {bool doubleOut = true}) {
  if (remaining <= 0 || dartsLeft <= 0) return null;
  final finishes = doubleOut ? _finishFields : [..._setupFields, ..._finishFields];
  for (var darts = 1; darts <= dartsLeft; ++darts) {
    List<_Field>? best;
    var bestPenalty = double.infinity;
    for (final finish in finishes) {
      final rest = remaining - finish.points;
      if (rest < 0 || (darts == 1) != (rest == 0)) continue;
      for (final setup in _setups(rest, darts - 1, 0)) {
        final penalty = finish.penalty + setup.fold(0.0, (sum, f) => sum + f.penalty);
        if (penalty < bestPenalty) {
          bestPenalty = penalty;
          best = [...setup, finish];
        }
      }
    }
    if (best != null) return [for (final f in best) f.label];
  }
  return null;
}

// Setup combinations for `points` with exactly `darts` darts, each listed once in the order of _setupFields.
Iterable<List<_Field>> _setups(int points, int darts, int from) sync* {
  if (darts == 0) {
    if (points == 0) yield const [];
    return;
  }
  for (var i = from; i < _setupFields.length; ++i) {
    final field = _setupFields[i];
    if (field.points > points) continue;
    for (final more in _setups(points - field.points, darts - 1, i)) {
      yield [field, ...more];
    }
  }
}

/// What is left after a setup dart, best first: doubles a player likes to finish on
const List<int> _leaves = [32, 40, 16, 8, 24, 20, 36, 12, 4, 2];

/// The field to aim at with `remaining` and `dartsLeft` in the visit: the first of the checkout route, T20 when there
/// is none and more than 60 is left, else the single that leaves a good double.
String aimField(int remaining, int dartsLeft, {bool doubleOut = true}) {
  final route = suggestCheckout(remaining, dartsLeft, doubleOut: doubleOut);
  if (route != null) return route.first;
  if (remaining > 60) return 'T20';
  for (final leave in _leaves) {
    final single = remaining - leave;
    if (single >= 1 && single <= 20) return 'S$single';
  }
  return 'S1';
}

/// Score of a field label as the keypad would enter it, for tests and suggestions
Ring ringOf(String label) => switch (label[0]) {
  'T' => Ring.triple,
  'D' => Ring.double,
  'S' => Ring.innerSingle,
  _ => label == '50' ? Ring.innerBull : Ring.outerBull,
};
