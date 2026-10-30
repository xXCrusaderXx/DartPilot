// A training round compared with the player's earlier rounds of the same training (#125).
import 'dart:math' as math;

import '../games/checkout_trainer.dart';
import '../games/dart_game.dart';
import '../games/doubles.dart';
import '../games/grouping.dart';
import 'game_record.dart';
import 'precision.dart';

/// The figure a training round is judged by
typedef TrainingScore = ({double value, bool lowerIsBetter});

/// The figure of a training round played to its end: the group's spread, the doubles' hit rate, the share of
/// checkouts, or the 121 ladder's highest checkout; null for other games and for rounds left before their end
TrainingScore? trainingScore(GameRecord record) {
  final game = record.replay().game;
  if (game is! DartGame || !game.isFinished) return null;
  return switch (game) {
    GroupingGame(:final spread?) => (value: spread.spreadMm, lowerIsBetter: true),
    DoublesGame() => (value: game.hitRate, lowerIsBetter: false),
    CheckoutTrainer(ladder: true, :final bestCheckout?) => (value: bestCheckout.toDouble(), lowerIsBetter: false),
    CheckoutTrainer(ladder: false) => (value: game.checkoutRate, lowerIsBetter: false),
    _ => null,
  };
}

/// Rounds of one kind compare: the same target, the same doubles, the same range of finishes and darts for each.
String? trainingKind(GameRecord record) => switch (record.mode) {
  GameMode.grouping => 'grouping ${record.groupingTarget.label}',
  // The weakest five change as the player improves; their rounds compare with each other all the same.
  GameMode.doubles when record.settings['weakest'] == true => 'doubles weakest',
  GameMode.doubles => 'doubles ${[for (final t in record.doublesGame.targets) t.label].join(' ')}',
  GameMode.checkout => switch (record.checkoutTrainer) {
    final t when t.ladder => 'ladder ${t.dartsPerAttempt}',
    final t => 'checkout ${CheckoutRange.of(t.starts.first).name} ${t.dartsPerAttempt}',
  },
  _ => null,
};

/// The player's last and best round of the same training before this one
class TrainingComparison {
  const TrainingComparison({required this.last, required this.best, required this.lowerIsBetter});

  final double last;
  final double best;
  final bool lowerIsBetter;

  /// Whether [value] beats every earlier round
  bool isNewBest(double value) => lowerIsBetter ? value < best : value > best;
}

/// [current] against the rounds of the same training that [player] finished before it; null when there are none
TrainingComparison? compareWithEarlier(List<GameRecord> games, GameRecord current, String player) {
  final kind = trainingKind(current);
  if (kind == null) return null;
  final earlier = [
    for (final g in games)
      if (g.id != current.id &&
          g.players.contains(player) &&
          trainingKind(g) == kind &&
          !g.ended.isAfter(current.ended))
        g,
  ]..sort((a, b) => a.ended.compareTo(b.ended));
  TrainingScore? last;
  double? best;
  for (final g in earlier) {
    final score = trainingScore(g);
    if (score == null) continue;
    last = score;
    if (best == null || (score.lowerIsBetter ? score.value < best : score.value > best)) best = score.value;
  }
  if (last == null || best == null) return null;
  return TrainingComparison(last: last.value, best: best, lowerIsBetter: last.lowerIsBetter);
}

/// What the statistics follow over time: the doubles practice, the checkout trainer per range of finishes, the 121
/// ladder, and the grouping per target. Rounds of one track compare, whatever doubles or darts per attempt they had.
class TrainingTrack {
  const TrainingTrack._(this.mode, {this.range, this.target});

  final GameMode mode;

  /// The checkout trainer's range of finishes; [CheckoutRange.ladder] for the 121 ladder
  final CheckoutRange? range;

  /// The grouping's target
  final PrecisionTarget? target;

  /// The track of a training round; null for games that are not trainings
  static TrainingTrack? of(GameRecord record) => switch (record.mode) {
    GameMode.doubles => const TrainingTrack._(GameMode.doubles),
    GameMode.checkout => switch (record.checkoutTrainer) {
      final t when t.ladder => const TrainingTrack._(GameMode.checkout, range: CheckoutRange.ladder),
      final t => TrainingTrack._(GameMode.checkout, range: CheckoutRange.of(t.starts.first)),
    },
    GameMode.grouping => TrainingTrack._(GameMode.grouping, target: record.groupingTarget),
    _ => null,
  };

  bool get isLadder => range == CheckoutRange.ladder;

  /// Doubles first, then the checkout ranges from low to the ladder, then the grouping targets in the order offered
  int get order => switch (mode) {
    GameMode.doubles => 0,
    GameMode.checkout => 1 + range!.index,
    _ => 10 + math.max(0, trainingTargets.indexOf(target!)),
  };

  @override
  bool operator ==(Object other) =>
      other is TrainingTrack && other.mode == mode && other.range == range && other.target == target;

  @override
  int get hashCode => Object.hash(mode, range, target);
}

/// The finished rounds of one training track, oldest first
class TrainingProgress {
  TrainingProgress(this.track, {required this.lowerIsBetter});

  final TrainingTrack track;
  final bool lowerIsBetter;
  final List<({DateTime ended, double value})> rounds = [];

  double get last => rounds.last.value;

  double get best => rounds.map((r) => r.value).reduce((a, b) => (lowerIsBetter ? a <= b : a >= b) ? a : b);

  /// Whether the last round set the best figure, beating every round before it
  bool get lastIsBest {
    if (rounds.length < 2) return false;
    final before = rounds.sublist(0, rounds.length - 1).map((r) => r.value);
    return before.every((v) => lowerIsBetter ? last < v : last > v);
  }
}

/// The training rounds [player] finished, per track; rounds before [since] are left out.
List<TrainingProgress> computeTrainingProgress(List<GameRecord> games, String player, {DateTime? since}) {
  final byTrack = <TrainingTrack, TrainingProgress>{};
  final sorted = [
    for (final g in games)
      if (g.players.contains(player) && (since == null || !g.ended.isBefore(since))) g,
  ]..sort((a, b) => a.ended.compareTo(b.ended));
  for (final record in sorted) {
    final track = TrainingTrack.of(record);
    if (track == null) continue;
    final score = trainingScore(record);
    if (score == null) continue;
    byTrack.putIfAbsent(track, () => TrainingProgress(track, lowerIsBetter: score.lowerIsBetter)).rounds.add((
      ended: record.ended,
      value: score.value,
    ));
  }
  return byTrack.values.toList()..sort((a, b) => a.track.order.compareTo(b.track.order));
}
