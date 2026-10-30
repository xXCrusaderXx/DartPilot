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
  X01Visit(this.player, this.startRemaining, this.leg);

  final int player;
  final int startRemaining;

  /// Number of the leg the visit belongs to, from 1
  final int leg;
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
    visits = [X01Visit(0, settings.startScore, 1)];
    var applied = 0;
    for (final dart in _throws) {
      if (isFinished) break;
      _apply(dart);
      ++applied;
    }
    // A correction that wins the match earlier ends it there: the darts after the winning one were never part of it.
    _throws.removeRange(applied, _throws.length);
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
      visits.add(X01Visit(current, players[current].remaining, legNumber));
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
    visits.add(X01Visit(current, settings.startScore, legNumber));
  }

  /// Checkout route for the player at the oche with the darts left in this visit, as players read it ("T20 20 Bull"),
  /// or null if there is none.
  List<String>? get checkoutSuggestion {
    if (isFinished) return null;
    final player = players[current];
    if (settings.doubleIn && !player.isIn) return null;
    final route = suggestCheckout(player.remaining, 3 - currentVisit.darts.length, doubleOut: settings.doubleOut);
    return route == null ? null : [for (final field in route) routeText(field)];
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

// The routes of the usual checkout charts for double-out, where they differ from what the penalties above would pick:
// players learn these by heart, so the app suggests the same. Every route is the fewest darts for its score.
const Map<int, List<String>> _chartRoutes = {
  170: ['T20', 'T20', '50'],
  167: ['T20', 'T19', '50'],
  164: ['T20', 'T18', '50'],
  161: ['T20', 'T17', '50'],
  160: ['T20', 'T20', 'D20'],
  158: ['T20', 'T20', 'D19'],
  157: ['T20', 'T19', 'D20'],
  156: ['T20', 'T20', 'D18'],
  155: ['T20', 'T19', 'D19'],
  154: ['T20', 'T18', 'D20'],
  153: ['T20', 'T19', 'D18'],
  152: ['T20', 'T20', 'D16'],
  151: ['T20', 'T17', 'D20'],
  150: ['T20', 'T18', 'D18'],
  149: ['T20', 'T19', 'D16'],
  148: ['T20', 'T16', 'D20'],
  147: ['T20', 'T17', 'D18'],
  146: ['T20', 'T18', 'D16'],
  145: ['T20', 'T15', 'D20'],
  144: ['T20', 'T20', 'D12'],
  143: ['T20', 'T17', 'D16'],
  142: ['T20', 'T14', 'D20'],
  141: ['T20', 'T19', 'D12'],
  140: ['T20', 'T20', 'D10'],
  139: ['T19', 'T14', 'D20'],
  138: ['T20', 'T18', 'D12'],
  137: ['T20', 'T19', 'D10'],
  136: ['T20', 'T20', 'D8'],
  135: ['T20', 'T17', 'D12'],
  134: ['T20', 'T14', 'D16'],
  133: ['T20', 'T19', 'D8'],
  132: ['T20', 'T16', 'D12'],
  131: ['T20', 'T13', 'D16'],
  130: ['T20', 'T20', 'D5'],
  129: ['T19', 'T16', 'D12'],
  128: ['T18', 'T14', 'D16'],
  127: ['T20', 'T17', 'D8'],
  126: ['T19', 'T19', 'D6'],
  125: ['25', 'T20', 'D20'],
  124: ['T20', 'T16', 'D8'],
  123: ['T19', 'T16', 'D9'],
  122: ['T18', 'T20', 'D4'],
  120: ['T20', 'S20', 'D20'],
  119: ['T19', 'T12', 'D13'],
  118: ['T20', 'S18', 'D20'],
  117: ['T20', 'S17', 'D20'],
  116: ['T20', 'S16', 'D20'],
  115: ['T20', 'S15', 'D20'],
  114: ['T20', 'S14', 'D20'],
  113: ['T20', 'S13', 'D20'],
  112: ['T20', 'S12', 'D20'],
  111: ['T20', 'S11', 'D20'],
  109: ['T20', 'S9', 'D20'],
  108: ['T20', 'S16', 'D16'],
  106: ['T20', 'S10', 'D18'],
  105: ['T20', 'S13', 'D16'],
  103: ['T19', 'S6', 'D20'],
  102: ['T20', 'S10', 'D16'],
  99: ['T19', 'S10', 'D16'],
  98: ['T20', 'D19'],
  97: ['T19', 'D20'],
  96: ['T20', 'D18'],
  95: ['T19', 'D19'],
  94: ['T18', 'D20'],
  93: ['T19', 'D18'],
  92: ['T20', 'D16'],
  91: ['T17', 'D20'],
  90: ['T20', 'D15'],
  89: ['T19', 'D16'],
  88: ['T16', 'D20'],
  87: ['T17', 'D18'],
  86: ['T18', 'D16'],
  85: ['T15', 'D20'],
  84: ['T20', 'D12'],
  83: ['T17', 'D16'],
  82: ['50', 'D16'],
  81: ['T19', 'D12'],
  80: ['T20', 'D10'],
  79: ['T19', 'D11'],
  78: ['T18', 'D12'],
  77: ['T19', 'D10'],
  76: ['T20', 'D8'],
  75: ['T17', 'D12'],
  74: ['T14', 'D16'],
  73: ['T19', 'D8'],
  72: ['T16', 'D12'],
  71: ['T13', 'D16'],
  70: ['T18', 'D8'],
  69: ['T19', 'D6'],
  68: ['T20', 'D4'],
  67: ['T17', 'D8'],
  66: ['T10', 'D18'],
  65: ['T19', 'D4'],
  64: ['T16', 'D8'],
  63: ['T13', 'D12'],
  62: ['T10', 'D16'],
  61: ['T15', 'D8'],
};

/// Fewest-dart route to finish `remaining` with at most `dartsLeft` darts, ending on a double if `doubleOut`.
/// Among routes with the same number of darts, the chart route or else the one with the most usual fields wins; the
/// result is deterministic.
List<String>? suggestCheckout(int remaining, int dartsLeft, {bool doubleOut = true}) {
  if (remaining <= 0 || dartsLeft <= 0) return null;
  if (doubleOut) {
    final chart = _chartRoutes[remaining];
    if (chart != null && chart.length <= dartsLeft) return chart;
  }
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
    if (best == null) continue;
    // Without a double to finish on, any dart may come last: the big ones first, as players throw them.
    if (!doubleOut) best.sort((a, b) => _order(a).compareTo(_order(b)));
    return [for (final f in best) f.label];
  }
  return null;
}

int _order(_Field field) {
  final i = _setupFields.indexWhere((f) => f.label == field.label);
  return i < 0 ? _setupFields.length : i;
}

/// A field of a checkout route as players read it: "Bull" for the bull, the bare number for a single
String routeText(String field) => switch (field) {
  '50' => 'Bull',
  _ when field.startsWith('S') => field.substring(1),
  _ => field,
};

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
