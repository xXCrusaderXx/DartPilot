import '../board/dart_throw.dart';
import '../board/scoring.dart';
import '../stats/precision.dart';
import 'dart_game.dart';

/// The doubles in the order players finish on them most, then the bull
final List<PrecisionTarget> allDoubles = List.unmodifiable([
  for (final n in [20, 16, 8, 18, 12, 10, 4, 14, 6, 2, 19, 17, 15, 13, 11, 9, 7, 5, 3, 1])
    PrecisionTarget(Ring.double, n),
  PrecisionTarget.bull,
]);

/// Doubles practice (#125): one visit at each double in turn, every dart measured against the middle of the double.
/// Pure logic, no UI.
class DoublesGame implements DartGame, AimedGame {
  DoublesGame(this.targets, {this.dartsPerTarget = 3}) : assert(targets.isNotEmpty);

  final List<PrecisionTarget> targets;
  final int dartsPerTarget;
  final List<DartThrow> _throws = [];

  @override
  List<DartThrow> get throws => List.unmodifiable(_throws);

  @override
  int get dartsInVisit => _throws.length % 3;

  int get dartCount => targets.length * dartsPerTarget;

  @override
  bool get isFinished => _throws.length >= dartCount;

  @override
  void add(DartThrow dart) {
    if (!isFinished) _throws.add(dart);
  }

  @override
  void undo() {
    if (_throws.isNotEmpty) _throws.removeLast();
  }

  @override
  void replace(int index, DartThrow dart) => _throws[index] = dart;

  @override
  PrecisionTarget targetOf(int index) => targets[(index ~/ dartsPerTarget).clamp(0, targets.length - 1)];

  /// The double at the oche; the last one once the round is over
  PrecisionTarget get current => targetOf(_throws.length);

  /// The darts at [target] so far
  List<DartThrow> dartsAt(PrecisionTarget target) => [
    for (var i = 0; i < _throws.length; ++i)
      if (targetOf(i) == target) _throws[i],
  ];

  int get hits => [for (var i = 0; i < _throws.length; ++i) targetOf(i).isHit(_throws[i].score)].where((h) => h).length;

  double get hitRate => _throws.isEmpty ? 0 : hits / _throws.length;
}
