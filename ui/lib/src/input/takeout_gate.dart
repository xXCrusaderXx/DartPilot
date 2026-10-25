import '../board/dart_throw.dart';
import '../games/dart_game.dart';

/// After a player's visit the darts are still in the board: the next visit waits until the engine reports the
/// takeout or the player says the darts are out. The game screen owns it, so its bots wait as well.
class TakeoutGate {
  int? _closedAt;
  int _visitDarts = 0;

  /// Whether the next visit of `game` waits for the takeout. An undo reopens the visit and so the gate.
  bool isClosed(DartGame game) => _closedAt == game.throws.length;

  /// The darts of the finished visit, still in the board while the gate is closed
  List<DartThrow> darts(DartGame game) =>
      isClosed(game) ? game.throws.sublist(game.throws.length - _visitDarts) : const [];

  /// The visit that just ended with `visitDarts` darts waits for its takeout
  void close(DartGame game, int visitDarts) {
    _closedAt = game.throws.length;
    _visitDarts = visitDarts;
  }

  void open() => _closedAt = null;
}
