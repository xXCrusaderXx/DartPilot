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
