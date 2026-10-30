import 'dart:math' as math;

import '../board/dart_throw.dart';
import '../board/scoring.dart';
import 'dart_game.dart';

/// A different number from 1 to 20 for each player, drawn from [seed] so a kept game replays the same
List<int> killerNumbers(int seed, int players) {
  final numbers = [for (var n = 1; n <= 20; ++n) n]..shuffle(math.Random(seed));
  return numbers.take(players).toList();
}

class KillerPlayerState {
  KillerPlayerState(this.name, this.number, this.lives);

  final String name;
  final int number;
  int lives;

  /// Hits on the own double; three make a killer
  int marks = 0;
  int dartsThrown = 0;

  bool get isKiller => marks >= KillerGame.marksToKill;
  bool get out => lives <= 0;
}

/// Killer (#118): every player has a number. Three hits on the own double make a killer; a killer's hits on another
/// player's double take a life, a hit on the own double takes one of the killer's. The last player with lives wins.
/// Pure logic, no UI.
class KillerGame implements DartGame {
  KillerGame(List<String> names, this.numbers, {this.lives = 3}) : names = List.unmodifiable(names) {
    if (names.length < 2 || numbers.length != names.length) throw ArgumentError('two players or more, each a number');
    _replay();
  }

  static const int marksToKill = 3;

  final List<String> names;
  final List<int> numbers;
  final int lives;
  final List<DartThrow> _throws = [];

  late List<KillerPlayerState> players;
  late int current;
  late List<DartThrow> currentVisit;

  /// The player of [currentVisit], which stays with them after it ends until the next dart
  late int visitPlayer;

  /// Set when the player at the oche went out during the visit: the visit ends at once.
  late bool _visitOver;
  int? winner;

  @override
  bool get isFinished => winner != null;
  bool get canUndo => _throws.isNotEmpty;

  @override
  List<DartThrow> get throws => List.unmodifiable(_throws);

  @override
  int get dartsInVisit => _visitOver ? 0 : currentVisit.length % 3;

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
    players = [for (var i = 0; i < names.length; ++i) KillerPlayerState(names[i], numbers[i], lives)];
    current = 0;
    currentVisit = [];
    visitPlayer = 0;
    _visitOver = false;
    winner = null;
    for (final dart in _throws) {
      _apply(dart);
    }
  }

  void _apply(DartThrow dart) {
    if (currentVisit.length == 3 || _visitOver) {
      currentVisit = [];
      _visitOver = false;
    }
    if (currentVisit.isEmpty) visitPlayer = current;
    final player = players[current];
    player.dartsThrown++;
    currentVisit.add(dart);
    final score = dart.score;
    if (score.ring == Ring.double) {
      if (!player.isKiller) {
        if (score.sector == player.number) player.marks++;
      } else {
        for (final p in players) {
          if (p.number == score.sector && !p.out) p.lives--;
        }
      }
    }
    final alive = [
      for (var i = 0; i < players.length; ++i)
        if (!players[i].out) i,
    ];
    if (alive.length <= 1) {
      winner = alive.isEmpty ? current : alive.single;
      return;
    }
    if (player.out) {
      _visitOver = true;
    } else if (currentVisit.length < 3) {
      return;
    }
    do {
      current = (current + 1) % players.length;
    } while (players[current].out);
  }
}
