import '../board/dart_throw.dart';
import '../board/scoring.dart';
import 'dart_game.dart';

/// What a round is played at: which darts hit, what a hit is worth, and where a bot aims
class RoundTarget {
  const RoundTarget(this.label, this.aim, this._hits);

  /// The number, D for any double, T for any triple, or Bull, as shown to the players
  final String label;

  /// The field a bot aims at, as a checkout route names it (T20, D16, 50)
  final String aim;
  final bool Function(Score score) _hits;

  bool hits(Score score) => _hits(score);

  /// A number in any ring
  factory RoundTarget.number(int n) => RoundTarget('$n', 'T$n', (s) => s.sector == n);

  /// The double of a number; the inner bull for the bull
  factory RoundTarget.double(int n) => n == 25
      ? RoundTarget('D-Bull', '50', (s) => s.ring == Ring.innerBull)
      : RoundTarget('D$n', 'D$n', (s) => s.ring == Ring.double && s.sector == n);

  static final anyDouble = RoundTarget('D', 'D20', (s) => s.ring == Ring.double);
  static final anyTriple = RoundTarget('T', 'T20', (s) => s.ring == Ring.triple);
  static final bull = RoundTarget('Bull', '50', (s) => s.ring == Ring.innerBull || s.ring == Ring.outerBull);
}

class RoundPlayerState {
  RoundPlayerState(this.name, this.score);

  final String name;
  int score;
  int dartsThrown = 0;
  int hits = 0;

  /// Out of the game, as in Bob's 27 below zero; skipped from then on
  bool out = false;

  double get hitRate => dartsThrown == 0 ? 0 : hits / dartsThrown;
}

/// A game of rounds (#118): every player has one visit of three darts at the round's target, and the visit changes the
/// score by the mode's rule. After the last round the highest score wins; players level on it draw. A solo game has no
/// winner, only its score. Derived by replaying all darts, so undo and corrections are exact. Pure logic, no UI.
abstract class RoundGame implements DartGame {
  RoundGame(List<String> names, this.targets) : names = List.unmodifiable(names) {
    if (names.isEmpty) throw ArgumentError('at least one player');
    _replay();
  }

  final List<String> names;
  final List<RoundTarget> targets;
  final List<DartThrow> _throws = [];

  late List<RoundPlayerState> players;
  late int current;

  /// Index into [targets]; [targets.length] once the game is over
  late int round;
  late List<(DartThrow, bool)> currentVisit;

  /// The player and round of [currentVisit], which stays with them after it ends until the next dart
  late int visitPlayer;
  late int visitRound;

  /// The player who won against the others; null while the game runs, in a draw and in a solo game
  int? winner;

  /// Whether the game ended at once on a visit such as a Shanghai, rather than after the last round
  bool wonAtOnce = false;
  bool _over = false;

  int get startScore => 0;

  /// The score after a visit of [visit] at [target], from [score] before it
  int scoreAfter(int score, List<Score> visit, RoundTarget target);

  /// Whether the visit wins the game at once, as a Shanghai does
  bool winsAtOnce(List<Score> visit, RoundTarget target) => false;

  /// Whether the player is out after the visit, as in Bob's 27 below zero
  bool isOut(int score) => false;

  RoundTarget get target => targets[round.clamp(0, targets.length - 1)];

  @override
  bool get isFinished => _over;

  /// Two or more players level on the best score at the end
  bool get isDraw => _over && players.length > 1 && winner == null;

  /// The players with the best score at the end, or the one who won at once
  List<int> get leaders {
    if (wonAtOnce) return [visitPlayer];
    final best = players.map((p) => p.score).reduce((a, b) => a > b ? a : b);
    return [
      for (var i = 0; i < players.length; ++i)
        if (players[i].score == best) i,
    ];
  }

  bool get canUndo => _throws.isNotEmpty;

  @override
  List<DartThrow> get throws => List.unmodifiable(_throws);

  @override
  int get dartsInVisit => currentVisit.length % 3;

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

  @override
  void replace(int index, DartThrow dart) {
    _throws[index] = dart;
    _replay();
  }

  void _replay() {
    players = [for (final n in names) RoundPlayerState(n, startScore)];
    current = 0;
    round = 0;
    currentVisit = [];
    visitPlayer = 0;
    visitRound = 0;
    winner = null;
    wonAtOnce = false;
    _over = false;
    for (final dart in _throws) {
      _apply(dart);
    }
  }

  void _apply(DartThrow dart) {
    if (currentVisit.length == 3) currentVisit = [];
    if (currentVisit.isEmpty) {
      visitPlayer = current;
      visitRound = round;
    }
    final player = players[current];
    final hit = target.hits(dart.score);
    player.dartsThrown++;
    if (hit) player.hits++;
    currentVisit.add((dart, hit));
    if (currentVisit.length < 3) return;

    final visit = [for (final (d, _) in currentVisit) d.score];
    if (winsAtOnce(visit, target)) {
      player.score = scoreAfter(player.score, visit, target);
      wonAtOnce = true;
      _over = true;
      if (players.length > 1) winner = current;
      return;
    }
    player.score = scoreAfter(player.score, visit, target);
    if (isOut(player.score)) player.out = true;
    _nextPlayer();
  }

  /// The next player who is not out; a new round when the order starts over, the end after the last round or when
  /// everyone is out
  void _nextPlayer() {
    var index = current;
    var nextRound = round;
    for (var step = 0; step < players.length; ++step) {
      index++;
      if (index == players.length) {
        index = 0;
        nextRound++;
        if (nextRound >= targets.length) break;
      }
      if (!players[index].out) {
        current = index;
        round = nextRound;
        return;
      }
    }
    _end();
  }

  void _end() {
    round = targets.length;
    _over = true;
    final top = leaders;
    if (players.length > 1 && top.length == 1) winner = top.single;
  }
}

/// Shanghai: rounds 1 to 7 (or 20) at that number, every hit scores its points; single, double and triple of the
/// number in one visit win at once.
class ShanghaiGame extends RoundGame {
  ShanghaiGame(List<String> names, {int rounds = 7})
    : super(names, [for (var n = 1; n <= rounds; ++n) RoundTarget.number(n)]);

  @override
  int scoreAfter(int score, List<Score> visit, RoundTarget target) =>
      score + visit.where(target.hits).fold(0, (sum, s) => sum + s.points);

  @override
  bool winsAtOnce(List<Score> visit, RoundTarget target) {
    final rings = {
      for (final s in visit.where(target.hits))
        if (s.ring == Ring.innerSingle || s.ring == Ring.outerSingle) Ring.outerSingle else s.ring,
    };
    return rings.containsAll([Ring.outerSingle, Ring.double, Ring.triple]);
  }
}

/// Bob's 27: start with 27, then D1 to D20 and the double bull. Every hit adds the double's value; a visit without a hit
/// takes it away once. Below zero the player is out.
class Bobs27Game extends RoundGame {
  Bobs27Game(List<String> names)
    : super(names, [for (var n = 1; n <= 20; ++n) RoundTarget.double(n), RoundTarget.double(25)]);

  @override
  int get startScore => 27;

  int _value(RoundTarget target) => target.aim == '50' ? 50 : 2 * int.parse(target.aim.substring(1));

  @override
  int scoreAfter(int score, List<Score> visit, RoundTarget target) {
    final hits = visit.where(target.hits).length;
    return hits == 0 ? score - _value(target) : score + hits * _value(target);
  }

  @override
  bool isOut(int score) => score < 0;
}

/// Halve-It: start with 40; 15, 16, any double, 17, 18, any triple, 19, 20 and the bull. Hits on the target score their
/// points; a visit without a hit halves the score.
class HalveItGame extends RoundGame {
  HalveItGame(List<String> names)
    : super(names, [
        RoundTarget.number(15),
        RoundTarget.number(16),
        RoundTarget.anyDouble,
        RoundTarget.number(17),
        RoundTarget.number(18),
        RoundTarget.anyTriple,
        RoundTarget.number(19),
        RoundTarget.number(20),
        RoundTarget.bull,
      ]);

  @override
  int get startScore => 40;

  @override
  int scoreAfter(int score, List<Score> visit, RoundTarget target) {
    final points = visit.where(target.hits).fold(0, (sum, s) => sum + s.points);
    return points == 0 ? score ~/ 2 : score + points;
  }
}
