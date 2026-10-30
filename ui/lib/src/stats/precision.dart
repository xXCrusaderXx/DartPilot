// Precision in millimetres (#125): how the darts aimed at one target scatter around it, from their board points.
import 'dart:math' as math;

import '../board/dart_throw.dart';
import '../board/scoring.dart';

/// A field a player aims at: the middle of a triple, a double, the big single, or a bull
class PrecisionTarget {
  const PrecisionTarget(this.ring, [this.sector = 0]);

  static const bull = PrecisionTarget(Ring.innerBull);
  static const outerBull = PrecisionTarget(Ring.outerBull);

  final Ring ring;

  /// 1 to 20; 0 for the bulls
  final int sector;

  /// T20, D16, S5, 25, BULL
  String get label => switch (ring) {
    Ring.innerBull => 'BULL',
    Ring.outerBull => '25',
    Ring.triple => 'T$sector',
    Ring.double => 'D$sector',
    _ => 'S$sector',
  };

  /// The point aimed at: the middle of the field, for a single the middle of the big single, for both bulls the
  /// middle of the board
  BoardPoint centre([BoardGeometry geometry = const BoardGeometry()]) => switch (ring) {
    Ring.innerBull || Ring.outerBull => const BoardPoint(0, 0),
    Ring.innerSingle => fieldCentre(Ring.outerSingle, sector: sector, geometry: geometry),
    _ => fieldCentre(ring, sector: sector, geometry: geometry),
  };

  /// Whether a dart scored in this field
  bool isHit(Score score) => switch (ring) {
    Ring.innerBull || Ring.outerBull => score.ring == ring,
    Ring.innerSingle ||
    Ring.outerSingle => (score.ring == Ring.innerSingle || score.ring == Ring.outerSingle) && score.sector == sector,
    _ => score.ring == ring && score.sector == sector,
  };

  /// A target from its [label], or from a field label of a checkout route (50 for the bull); null for anything else
  static PrecisionTarget? parse(String label) {
    if (label == 'BULL' || label == '50') return bull;
    if (label == '25') return outerBull;
    if (label.isEmpty) return null;
    final ring = switch (label[0]) {
      'T' => Ring.triple,
      'D' => Ring.double,
      'S' => Ring.outerSingle,
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

/// A game that knows what each dart was aimed at, so its darts count for the precision statistics
abstract interface class AimedGame {
  /// The target of the dart at [index] in the game's throws; null where the game does not know it
  PrecisionTarget? targetOf(int index);
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
    if (target.isHit(dart.score)) precision.hits++;
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

/// Darts at a target before its hit rate and spread say something about the player: a target with fewer is shown, but
/// not ranked or given its own card.
const int minRankedDarts = 6;

/// The doubles and the bull with at least [minDarts] measured darts, best first: the highest hit rate, then the
/// smallest spread; targets without a spread last
List<TargetPrecision> doublesRanking(List<TargetPrecision> precision, {int minDarts = 0}) {
  final doubles = [
    for (final p in precision)
      if ((p.target.ring == Ring.double || p.target.ring == Ring.innerBull) && p.points.length >= minDarts) p,
  ];
  return doubles..sort((a, b) {
    final byRate = b.hitRate.compareTo(a.hitRate);
    if (byRate != 0) return byRate;
    return (a.spread?.spreadMm ?? double.infinity).compareTo(b.spread?.spreadMm ?? double.infinity);
  });
}
