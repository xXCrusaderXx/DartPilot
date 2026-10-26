// Precision in millimetres (#125): how the darts aimed at one target scatter around it, from their board points.
import 'dart:math' as math;

import '../board/dart_throw.dart';
import '../board/scoring.dart';

/// A field a player aims at: a triple, a double or the bull
class PrecisionTarget {
  const PrecisionTarget(this.ring, [this.sector = 0]);

  static const bull = PrecisionTarget(Ring.innerBull);

  final Ring ring;

  /// 1 to 20; 0 for the bull
  final int sector;

  /// T20, D16, BULL
  String get label => switch (ring) {
    Ring.innerBull => 'BULL',
    Ring.triple => 'T$sector',
    Ring.double => 'D$sector',
    _ => 'S$sector',
  };

  /// The point aimed at: the middle of the field
  BoardPoint centre([BoardGeometry geometry = const BoardGeometry()]) =>
      fieldCentre(ring, sector: sector, geometry: geometry);

  static PrecisionTarget? parse(String label) {
    if (label == 'BULL') return bull;
    if (label.isEmpty) return null;
    final ring = switch (label[0]) {
      'T' => Ring.triple,
      'D' => Ring.double,
      _ => null,
    };
    final sector = int.tryParse(label.substring(1));
    if (ring == null || sector == null || sector < 1 || sector > 20) return null;
    return PrecisionTarget(ring, sector);
  }

  @override
  bool operator ==(Object other) => other is PrecisionTarget && other.ring == ring && other.sector == sector;

  @override
  int get hashCode => Object.hash(ring, sector);
}

/// The targets offered for training, most played first
const List<PrecisionTarget> trainingTargets = [
  PrecisionTarget(Ring.triple, 20),
  PrecisionTarget(Ring.triple, 19),
  PrecisionTarget(Ring.triple, 18),
  PrecisionTarget.bull,
  PrecisionTarget(Ring.double, 20),
  PrecisionTarget(Ring.double, 16),
  PrecisionTarget(Ring.double, 8),
  PrecisionTarget(Ring.double, 10),
  PrecisionTarget(Ring.double, 12),
  PrecisionTarget(Ring.double, 18),
];

/// Engine darts below this confidence were uncertain, even when the player confirmed them.
const double minPrecisionConfidence = 0.5;

/// Whether a dart's board point says where it landed: a tap on the board, or an engine dart accepted with confidence.
/// Keypad darts sit in the middle of their field and corrected engine darts carry the correction's point, so both are
/// left out rather than counted as perfect.
bool hasMeasuredPoint(DartThrow dart) => switch (dart.input) {
  ThrowInput.board => true,
  ThrowInput.engine => (dart.confidence ?? 0) >= minPrecisionConfidence,
  ThrowInput.keypad => false,
};

/// How a group of darts scatters around a target, in board coordinates (+x right, +y up)
class Spread {
  Spread._(this.count, this.offsetXMm, this.offsetYMm, this._sxx, this._syy, this._sxy);

  /// The spread of [points] aimed at [target]; null for fewer than two points, which have no spread.
  static Spread? of(List<BoardPoint> points, BoardPoint target) {
    final n = points.length;
    if (n < 2) return null;
    var mx = 0.0, my = 0.0;
    for (final p in points) {
      mx += p.xMm;
      my += p.yMm;
    }
    mx /= n;
    my /= n;
    var sxx = 0.0, syy = 0.0, sxy = 0.0;
    for (final p in points) {
      final dx = p.xMm - mx, dy = p.yMm - my;
      sxx += dx * dx;
      syy += dy * dy;
      sxy += dx * dy;
    }
    return Spread._(n, mx - target.xMm, my - target.yMm, sxx / (n - 1), syy / (n - 1), sxy / (n - 1));
  }

  final int count;

  /// Mean of the darts minus the target: the systematic offset
  final double offsetXMm;
  final double offsetYMm;

  // Sample covariance of the points around their mean, mm²
  final double _sxx;
  final double _syy;
  final double _sxy;

  double get offsetMm => math.sqrt(offsetXMm * offsetXMm + offsetYMm * offsetYMm);

  /// Root mean square distance of the darts from their own mean: the size of the group, without the offset
  double get spreadMm => math.sqrt(_sxx + _syy);

  ({double majorMm, double minorMm, double angleDeg}) get ellipse {
    final mean = (_sxx + _syy) / 2;
    final root = math.sqrt(math.pow((_sxx - _syy) / 2, 2) + _sxy * _sxy);
    return (
      majorMm: math.sqrt(mean + root),
      minorMm: math.sqrt(math.max(0, mean - root)),
      angleDeg: 0.5 * math.atan2(2 * _sxy, _sxx - _syy) * 180 / math.pi,
    );
  }
}

/// The darts one player aimed at one target, and how they scatter
class TargetPrecision {
  TargetPrecision(this.target);

  final PrecisionTarget target;
  final List<BoardPoint> points = [];

  /// Spread per week, oldest first, for the trend
  final List<({DateTime week, Spread spread})> weeks = [];

  /// Darts that hit the target field
  int hits = 0;

  Spread? get spread => Spread.of(points, target.centre());

  double get hitRate => points.isEmpty ? 0 : hits / points.length;
}

/// The Monday a date's week starts on
DateTime weekOf(DateTime date) => DateTime(date.year, date.month, date.day - (date.weekday - 1));

/// A dart aimed at a target, with the time it was thrown, for the precision statistics
typedef AimedDart = ({PrecisionTarget target, DartThrow dart, DateTime thrown});

/// The precision per target from [darts], the most thrown at first; darts without a measured point are left out.
List<TargetPrecision> computePrecision(Iterable<AimedDart> darts) {
  final byTarget = <PrecisionTarget, TargetPrecision>{};
  final byWeek = <PrecisionTarget, Map<DateTime, List<BoardPoint>>>{};
  for (final (:target, :dart, :thrown) in darts) {
    if (!hasMeasuredPoint(dart)) continue;
    final precision = byTarget.putIfAbsent(target, () => TargetPrecision(target));
    precision.points.add(dart.point);
    if (_hits(dart.score, target)) precision.hits++;
    byWeek.putIfAbsent(target, () => {}).putIfAbsent(weekOf(thrown), () => []).add(dart.point);
  }
  for (final precision in byTarget.values) {
    final weeks = byWeek[precision.target]!.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    for (final week in weeks) {
      final spread = Spread.of(week.value, precision.target.centre());
      if (spread != null) precision.weeks.add((week: week.key, spread: spread));
    }
  }
  return byTarget.values.toList()..sort((a, b) => b.points.length.compareTo(a.points.length));
}

bool _hits(Score score, PrecisionTarget target) =>
    score.ring == target.ring && (target.ring == Ring.innerBull || score.sector == target.sector);
