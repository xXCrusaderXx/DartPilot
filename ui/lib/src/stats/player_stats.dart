// The figures of one player over a set of games (#117), computed by replaying the games.
import '../board/scoring.dart';
import '../games/around_the_clock.dart';
import '../games/checkout_trainer.dart';
import '../games/cricket.dart';
import '../games/doubles.dart';
import '../games/grouping.dart';
import '../games/killer.dart';
import '../games/round_games.dart';
import '../games/x01.dart';
import 'game_record.dart';
import 'precision.dart';

/// One game of the player, for the history
class PlayedGame {
  const PlayedGame(
    this.record, {
    required this.won,
    required this.darts,
    this.average,
    this.marksPerRound,
    this.hitRate,
    this.spreadMm,
    this.checkoutRate,
    this.points,
  });

  final GameRecord record;
  final bool won;
  final int darts;

  /// X01 three-dart average, Cricket marks per round, Around the Clock and doubles practice share of darts on the
  /// target
  final double? average;
  final double? marksPerRound;
  final double? hitRate;

  /// Grouping training: the size of the group in mm
  final double? spreadMm;

  /// Checkout trainer: share of the checkouts finished
  final double? checkoutRate;

  /// Shanghai, Bob's 27, Halve-It: the final score
  final int? points;
}

class PlayerStats {
  int games = 0;
  int gamesWon = 0;
  int darts = 0;

  /// Rings hit, over all modes
  final Map<Ring, int> rings = {for (final r in Ring.values) r: 0};

  /// Darts per field label (T20, S5, D16, 25, BULL, MISS), over all modes
  final Map<String, int> fields = {};

  /// Darts per ring and sector, for the hit board; bulls and misses have sector 0
  final Map<(Ring, int), int> hits = {};

  // X01
  int x01Darts = 0;
  int x01Points = 0;
  int first9Darts = 0;
  int first9Points = 0;
  int legs = 0;
  int legsWon = 0;
  int? bestLegDarts;
  int checkoutAttempts = 0;
  int checkouts = 0;
  int? highestFinish;

  /// The double each leg was finished on
  final Map<String, int> finishingDoubles = {};
  int visits100 = 0;
  int visits140 = 0;
  int visits180 = 0;

  // Cricket
  int cricketDarts = 0;
  int cricketMarks = 0;

  // Around the Clock
  int clockDarts = 0;
  int clockHits = 0;

  final List<PlayedGame> history = [];

  double? get threeDartAverage => x01Darts == 0 ? null : 3 * x01Points / x01Darts;
  double? get first9Average => first9Darts == 0 ? null : 3 * first9Points / first9Darts;
  double? get checkoutRate => checkoutAttempts == 0 ? null : checkouts / checkoutAttempts;
  double? get marksPerRound => cricketDarts == 0 ? null : 3 * cricketMarks / cricketDarts;
  double? get clockHitRate => clockDarts == 0 ? null : clockHits / clockDarts;

  /// Share of darts in a ring, 0 to 1
  double ringShare(Ring ring) => darts == 0 ? 0 : rings[ring]! / darts;

  /// Most often hit finishing doubles first
  List<MapEntry<String, int>> get favouriteDoubles =>
      finishingDoubles.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

/// A dart can finish a double-out leg when what is left is a double or the bull.
bool isOneDartFinish(int remaining) => remaining == 50 || (remaining >= 2 && remaining <= 40 && remaining.isEven);

/// The figures of [player] over [games], newest game first in the history; games before [since] are left out.
PlayerStats computePlayerStats(List<GameRecord> games, String player, {DateTime? since}) {
  final stats = PlayerStats();
  for (final record in games) {
    if (since != null && record.ended.isBefore(since)) continue;
    final index = record.players.indexOf(player);
    if (index < 0) continue;
    final (:game, :playerOf) = record.replay();
    final mine = [
      for (var i = 0; i < record.throws.length; ++i)
        if (playerOf[i] == index) record.throws[i],
    ];
    stats.games++;
    stats.darts += mine.length;
    for (final t in mine) {
      stats.rings[t.score.ring] = stats.rings[t.score.ring]! + 1;
      stats.fields[t.score.label] = (stats.fields[t.score.label] ?? 0) + 1;
      final key = (t.score.ring, _hasSector(t.score.ring) ? t.score.sector : 0);
      stats.hits[key] = (stats.hits[key] ?? 0) + 1;
    }
    final PlayedGame played;
    switch (game) {
      case X01Game():
        played = _addX01(stats, record, game, index, mine.length);
      case CricketGame():
        final state = game.players[index];
        stats.cricketDarts += state.dartsThrown;
        stats.cricketMarks += state.totalMarks;
        played = PlayedGame(record, won: game.winner == index, darts: mine.length, marksPerRound: state.marksPerRound);
      case AroundTheClockGame():
        final state = game.players[index];
        stats.clockDarts += state.dartsThrown;
        stats.clockHits += state.hits;
        played = PlayedGame(record, won: game.winner == index, darts: mine.length, hitRate: state.hitRate);
      case GroupingGame():
        played = PlayedGame(record, won: false, darts: mine.length, spreadMm: game.spread?.spreadMm);
      case DoublesGame():
        played = PlayedGame(record, won: false, darts: mine.length, hitRate: game.hitRate);
      case KillerGame():
        played = PlayedGame(record, won: game.winner == index, darts: mine.length);
      case RoundGame():
        played = PlayedGame(record, won: game.winner == index, darts: mine.length, points: game.players[index].score);
      case CheckoutTrainer():
        played = PlayedGame(record, won: false, darts: mine.length, checkoutRate: game.checkoutRate);
      default:
        continue;
    }
    if (played.won) stats.gamesWon++;
    stats.history.add(played);
  }
  stats.history.sort((a, b) => b.record.ended.compareTo(a.record.ended));
  return stats;
}

PlayedGame _addX01(PlayerStats stats, GameRecord record, X01Game game, int index, int darts) {
  final state = game.players[index];
  stats.x01Darts += state.dartsThrown;
  stats.x01Points += state.pointsScored;
  final doubleOut = game.settings.doubleOut;

  // Walk the visits leg by leg: a leg ends with a checkout.
  var visitsInLeg = 0;
  var legDarts = 0;
  var played = false;
  for (final visit in game.visits) {
    if (visit.player == index && visit.darts.isNotEmpty) {
      played = true;
      visitsInLeg++;
      legDarts += visit.darts.length;
      if (visitsInLeg <= 3) {
        stats.first9Darts += visit.darts.length;
        stats.first9Points += visit.points;
      }
      if (visit.points >= 180) {
        stats.visits180++;
      } else if (visit.points >= 140) {
        stats.visits140++;
      } else if (visit.points >= 100) {
        stats.visits100++;
      }
      var remaining = visit.startRemaining;
      for (final d in visit.darts) {
        if (doubleOut && isOneDartFinish(remaining)) {
          stats.checkoutAttempts++;
          if (d.result == DartResult.checkout) stats.checkouts++;
        }
        remaining -= d.pointsCounted;
      }
      if (visit.isCheckout) {
        stats.legsWon++;
        final best = stats.bestLegDarts;
        if (best == null || legDarts < best) stats.bestLegDarts = legDarts;
        if (stats.highestFinish == null || visit.startRemaining > stats.highestFinish!) {
          stats.highestFinish = visit.startRemaining;
        }
        final last = visit.darts.last.dart.score.label;
        stats.finishingDoubles[last] = (stats.finishingDoubles[last] ?? 0) + 1;
      }
    }
    if (visit.isCheckout) {
      if (played) stats.legs++;
      visitsInLeg = 0;
      legDarts = 0;
      played = false;
    }
  }
  // A leg left unfinished still counts as played.
  if (played) stats.legs++;
  return PlayedGame(record, won: game.winner == index, darts: darts, average: state.threeDartAverage);
}

bool _hasSector(Ring ring) => ring != Ring.innerBull && ring != Ring.outerBull && ring != Ring.miss;

/// The precision per target of [player] from the games that know what each dart was aimed at; games before [since]
/// are left out.
List<TargetPrecision> computePlayerPrecision(List<GameRecord> games, String player, {DateTime? since}) {
  final darts = <AimedDart>[];
  for (final record in games) {
    if (since != null && record.ended.isBefore(since)) continue;
    final index = record.players.indexOf(player);
    if (index < 0) continue;
    final (:game, :playerOf) = record.replay();
    if (game is! AimedGame) continue;
    for (var i = 0; i < record.throws.length; ++i) {
      final target = game.targetOf(i);
      if (playerOf[i] == index && target != null) {
        darts.add((target: target, dart: record.throws[i], thrown: record.ended));
      }
    }
  }
  return computePrecision(darts);
}
