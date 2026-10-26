import 'dart:math' as math;

import '../board/dart_throw.dart';
import '../stats/precision.dart';
import 'dart_game.dart';

/// Grouping training (#125): a set number of darts at one target, scored by how tightly they group instead of by
/// points. Pure logic, no UI.
class GroupingGame implements DartGame {
  GroupingGame(this.target, {this.dartCount = 9});

  final PrecisionTarget target;
  final int dartCount;
  final List<DartThrow> _throws = [];

  @override
  List<DartThrow> get throws => List.unmodifiable(_throws);

  @override
  int get dartsInVisit => _throws.length % 3;

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

  /// The darts whose point was measured; only they count for the group.
  List<DartThrow> get measured => [
    for (final t in _throws)
      if (hasMeasuredPoint(t)) t,
  ];

  Spread? get spread => Spread.of([for (final t in measured) t.point], target.centre());

  /// How far a dart landed from the target, and where to: x right, y up
  ({double distanceMm, double dxMm, double dyMm}) miss(DartThrow dart) {
    final centre = target.centre();
    final dx = dart.point.xMm - centre.xMm, dy = dart.point.yMm - centre.yMm;
    return (distanceMm: math.sqrt(dx * dx + dy * dy), dxMm: dx, dyMm: dy);
  }

  /// Darts of the visit in progress; a full visit stays visible until the next dart starts a new one.
  List<DartThrow> get currentVisit {
    if (_throws.isEmpty) return const [];
    final start = (_throws.length - 1) ~/ 3 * 3;
    return List.unmodifiable(_throws.sublist(start));
  }
}
