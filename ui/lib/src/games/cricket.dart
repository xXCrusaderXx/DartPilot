import '../board/dart_throw.dart';
import '../board/scoring.dart';

/// Numbers to close, the bull as 25
const List<int> cricketTargets = [20, 19, 18, 17, 16, 15, 25];

class CricketPlayerState {
  CricketPlayerState(this.name);

  final String name;
  final Map<int, int> marks = {for (final t in cricketTargets) t: 0};
  int points = 0;
  int dartsThrown = 0;
  int totalMarks = 0;

  bool isClosed(int target) => marks[target]! >= 3;
  bool get allClosed => cricketTargets.every(isClosed);

  /// Marks per three darts, the usual Cricket average
  double get marksPerRound => dartsThrown == 0 ? 0 : 3 * totalMarks / dartsThrown;
}

class CricketDart {
  const CricketDart(this.dart, this.target, this.marks, this.points);

  final DartThrow dart;

  /// 15–20 or 25, null for a dart off the targets
  final int? target;
  final int marks;
  final int points;
}

/// Standard Cricket, replayed from all darts so undo is exact.
class CricketGame {
  CricketGame(List<String> names) : names = List.unmodifiable(names) {
    if (names.isEmpty) throw ArgumentError('at least one player');
    _replay();
  }

  final List<String> names;
  final List<DartThrow> _throws = [];

  late List<CricketPlayerState> players;
  late int current;
  late List<CricketDart> currentVisit;
  int? winner;

  bool get isFinished => winner != null;
  bool get canUndo => _throws.isNotEmpty;

  void add(DartThrow dart) {
    if (isFinished) return;
    _throws.add(dart);
    _apply(dart);
  }

  void undo() {
    if (_throws.isEmpty) return;
    _throws.removeLast();
    _replay();
  }

  void _replay() {
    players = [for (final n in names) CricketPlayerState(n)];
    current = 0;
    currentVisit = [];
    winner = null;
    for (final dart in _throws) {
      _apply(dart);
    }
  }

  /// Target and number of marks of a dart: single 1, double 2, triple 3; outer bull 1, bull 2
  static (int?, int) marksOf(Score score) => switch (score.ring) {
    Ring.innerBull => (25, 2),
    Ring.outerBull => (25, 1),
    Ring.miss => (null, 0),
    _ => cricketTargets.contains(score.sector) ? (score.sector, score.multiplier) : (null, 0),
  };

  void _apply(DartThrow dart) {
    if (currentVisit.length == 3) currentVisit = [];
    final player = players[current];
    player.dartsThrown++;
    final (target, marks) = marksOf(dart.score);
    var points = 0;
    var counted = 0;
    if (target != null) {
      final before = player.marks[target]!;
      final toClose = (3 - before).clamp(0, 3);
      final extra = marks - toClose;
      player.marks[target] = before + marks;
      final opponentOpen = players.any((p) => !identical(p, player) && !p.isClosed(target));
      if (extra > 0 && opponentOpen) points = extra * target;
      // Marks beyond closing only count when they score.
      counted = extra > 0 && !opponentOpen ? toClose : marks;
      player.points += points;
      player.totalMarks += counted;
    }
    currentVisit.add(CricketDart(dart, target, counted, points));

    if (player.allClosed && players.every((p) => identical(p, player) || p.points <= player.points)) {
      winner = current;
      return;
    }
    if (currentVisit.length == 3) current = (current + 1) % players.length;
  }
}
