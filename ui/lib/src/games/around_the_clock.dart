import '../board/dart_throw.dart';
import '../board/scoring.dart';
import 'dart_game.dart';

class AroundTheClockPlayerState {
  AroundTheClockPlayerState(this.name);

  final String name;

  /// Index into the target sequence: 0 is the 1, 19 the 20, 20 the bull if it is part of the game
  int position = 0;
  int dartsThrown = 0;
  int hits = 0;

  double get hitRate => dartsThrown == 0 ? 0 : hits / dartsThrown;
}

/// Hit 1 to 20 in order, optionally the bull at the end. Any ring of the target counts.
class AroundTheClockGame implements DartGame {
  AroundTheClockGame(List<String> names, {this.endWithBull = true}) : names = List.unmodifiable(names) {
    if (names.isEmpty) throw ArgumentError('at least one player');
    _replay();
  }

  final List<String> names;
  final bool endWithBull;
  final List<DartThrow> _throws = [];

  late List<AroundTheClockPlayerState> players;
  late int current;
  late List<(DartThrow, bool)> currentVisit;
  int? winner;

  int get targetCount => endWithBull ? 21 : 20;
  @override
  bool get isFinished => winner != null;
  bool get canUndo => _throws.isNotEmpty;

  @override
  List<DartThrow> get throws => List.unmodifiable(_throws);

  @override
  int get dartsInVisit => currentVisit.length % 3;

  @override
  void replace(int index, DartThrow dart) {
    _throws[index] = dart;
    _replay();
  }

  /// "1" … "20", or "Bull"
  String targetLabel(int position) => position < 20 ? '${position + 1}' : 'Bull';

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
    players = [for (final n in names) AroundTheClockPlayerState(n)];
    current = 0;
    currentVisit = [];
    winner = null;
    for (final dart in _throws) {
      _apply(dart);
    }
  }

  bool _hits(Score score, int position) =>
      position < 20 ? score.sector == position + 1 : score.ring == Ring.innerBull || score.ring == Ring.outerBull;

  void _apply(DartThrow dart) {
    if (currentVisit.length == 3) currentVisit = [];
    final player = players[current];
    player.dartsThrown++;
    final hit = _hits(dart.score, player.position);
    if (hit) {
      player.hits++;
      player.position++;
    }
    currentVisit.add((dart, hit));
    if (player.position >= targetCount) {
      winner = current;
      return;
    }
    if (currentVisit.length == 3) current = (current + 1) % players.length;
  }
}
