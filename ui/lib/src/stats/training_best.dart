// A training round compared with the player's earlier rounds of the same training (#125).
import '../games/checkout_trainer.dart';
import '../games/dart_game.dart';
import '../games/doubles.dart';
import '../games/grouping.dart';
import 'game_record.dart';

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
