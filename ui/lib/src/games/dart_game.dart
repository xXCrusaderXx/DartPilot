import '../board/dart_throw.dart';

/// What every game offers to the input: darts in, undo, and replacing a dart for corrections. Games keep all darts
/// and replay them, so replacing a dart anywhere gives the same state as if it had been thrown that way.
abstract interface class DartGame {
  /// All darts of the game in the order they were thrown
  List<DartThrow> get throws;

  /// Darts of the visit in progress; 0 when the next dart starts a new visit
  int get dartsInVisit;

  bool get isFinished;

  void add(DartThrow dart);
  void undo();

  /// Replaces the dart at `index` in [throws] and replays the game
  void replace(int index, DartThrow dart);
}

/// [game] with [throws] added, for a game rebuilt from a shared or stored record
G replayed<G extends DartGame>(G game, List<DartThrow> throws) {
  for (final t in throws) {
    game.add(t);
  }
  return game;
}

/// A visit that ended, as the input's strip of last darts names it: whose darts they were and what they came to
class VisitResult {
  const VisitResult({required this.player, required this.darts, this.points, this.bust = false});

  final String player;

  /// How many darts it had: the last ones in [DartGame.throws] while the next visit has none yet
  final int darts;

  /// What it scored, in games that count points per visit
  final int? points;
  final bool bust;
}

/// A game whose visits do not always have three darts, or that names their result
abstract interface class TellsVisits {
  /// The visit that ended last, or null before the first one ended
  VisitResult? get lastVisit;
}
