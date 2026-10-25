import 'dart:math' as math;

import '../board/dart_throw.dart';
import '../board/scoring.dart';
import '../engine/engine_events.dart';

/// What the player said about a dart of the detection test
enum DartOutcome {
  /// Placed by the engine in the right field
  right,

  /// Placed by the engine in another field than the player's
  wrong,

  /// The engine was unsure; the player gave the field or confirmed its guess
  abstained,

  /// Not reported by the engine; the player added it
  missed,

  /// Reported by the engine although no dart landed
  falseAlarm,
}

/// One dart of the detection test, as the engine reported it and as the player rated it
class LoggedDart {
  LoggedDart._(this.detection, this.outcome, this.truth);

  /// null for a dart the engine missed
  final EngineThrow? detection;
  DartOutcome outcome;

  /// Where the dart really is; for a dart rated right, the engine's own point
  BoardPoint? truth;

  String? get throwId => detection?.throwId;

  /// Waits for the player: an abstention without a given field
  bool get open => outcome == DartOutcome.abstained && truth == null;

  /// Distance between the engine's point and the real one, for darts the player corrected
  double? get errorMm {
    final detected = detection?.point;
    final t = truth;
    if (detected == null || t == null || outcome == DartOutcome.right) return null;
    return math.sqrt(math.pow(detected.xMm - t.xMm, 2) + math.pow(detected.yMm - t.yMm, 2));
  }
}

/// A visit of the detection test: the darts until the takeout
class LoggedRound {
  final List<LoggedDart> darts = [];

  /// Set by the takeout that ended it
  int? dartsRemoved;
  double? takeoutLatencyMs;
}

/// The detection test (throw, see the result, pull, again): the engine's results rated by the player, with counts
/// and latencies over all rounds. Plain Dart, so the counting can be tested without widgets.
class DetectionLog {
  DetectionLog({this.geometry = const BoardGeometry()});

  final BoardGeometry geometry;
  final List<LoggedRound> rounds = [LoggedRound()];

  LoggedRound get current => rounds.last;
  Iterable<LoggedDart> get darts => rounds.expand((r) => r.darts);

  Score scoreOf(BoardPoint point) => score(point.xMm, point.yMm, geometry);

  /// A dart the engine reported: right until the player says otherwise, an abstention until the player gives its
  /// field
  void detected(EngineThrow detection) {
    final point = detection.point;
    current.darts.add(
      detection.accepted
          ? LoggedDart._(detection, DartOutcome.right, point ?? fieldCentre(Ring.miss, geometry: geometry))
          : LoggedDart._(detection, DartOutcome.abstained, null),
    );
  }

  /// The player puts `dart` where it really is. Within the same field an accepted dart stays right: the test rates
  /// fields, the replay benchmark measures millimetres.
  void correct(LoggedDart dart, BoardPoint truth) {
    dart.truth = truth;
    if (dart.outcome == DartOutcome.right || dart.outcome == DartOutcome.wrong) {
      final detected = dart.detection?.point;
      final same = detected != null && scoreOf(detected).label == scoreOf(truth).label;
      dart.outcome = same ? DartOutcome.right : DartOutcome.wrong;
    }
  }

  /// The player confirms the engine's guess of an abstention
  void confirm(LoggedDart dart) {
    final guess = dart.detection?.point;
    if (dart.open && guess != null) dart.truth = guess;
  }

  /// No dart landed where the engine reported one
  void reject(LoggedDart dart) {
    dart.outcome = DartOutcome.falseAlarm;
    dart.truth = null;
  }

  /// A dart the engine did not report
  LoggedDart missed(BoardPoint truth) {
    final dart = LoggedDart._(null, DartOutcome.missed, truth);
    current.darts.add(dart);
    return dart;
  }

  /// The darts were pulled: the round ends, and the next starts
  void takeout(EngineTakeout event) {
    current
      ..dartsRemoved = event.dartsRemoved
      ..takeoutLatencyMs = event.detectionLatencyMs;
    rounds.add(LoggedRound());
  }

  int count(DartOutcome outcome) => darts.where((d) => d.outcome == outcome).length;

  /// Darts that really landed: everything but false alarms
  int get realDarts => darts.where((d) => d.outcome != DartOutcome.falseAlarm).length;

  /// Of the darts the engine placed, the share in the right field; null before the first
  double? get placedRight {
    final placed = count(DartOutcome.right) + count(DartOutcome.wrong);
    return placed == 0 ? null : count(DartOutcome.right) / placed;
  }

  List<double> get detectionLatenciesMs => [for (final d in darts) ?d.detection?.detectionLatencyMs];

  List<double> get processingLatenciesMs => [for (final d in darts) ?d.detection?.processingLatencyMs];

  List<double> get takeoutLatenciesMs => [for (final r in rounds) ?r.takeoutLatencyMs];

  List<double> get errorsMm => [for (final d in darts) ?d.errorMm];

  /// Takeouts whose dart count differs from the darts the player had in the board
  int get takeoutMismatches => rounds
      .where(
        (r) =>
            r.dartsRemoved != null &&
            r.dartsRemoved != r.darts.where((d) => d.outcome != DartOutcome.falseAlarm).length,
      )
      .length;
}

/// Median of `values`; null when empty
double? median(List<double> values) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}
