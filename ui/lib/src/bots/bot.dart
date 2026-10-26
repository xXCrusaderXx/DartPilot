// Bots to play against (#158): a bot aims like a player at the board and its darts scatter around the aim with a
// spread that sets its level. Plain Dart without widgets, so its strength can be tested over many legs.
import 'dart:math' as math;

import '../board/dart_throw.dart';
import '../board/scoring.dart';
import '../games/around_the_clock.dart';
import '../games/cricket.dart';
import '../games/x01.dart';

/// A bot's strength. [spreadMm] is the standard deviation of its darts around the aim point, per axis; it is set so
/// that the level reaches about [average] (X01 three-dart average, 501 double out), checked in bot_test.dart.
class BotLevel {
  const BotLevel(this.level, this.average, this.spreadMm);

  final int level;
  final int average;
  final double spreadMm;
}

const List<BotLevel> botLevels = [
  BotLevel(1, 25, 34.4),
  BotLevel(2, 35, 24.1),
  BotLevel(3, 45, 18.3),
  BotLevel(4, 55, 14.8),
  BotLevel(5, 65, 12.4),
  BotLevel(6, 75, 10.0),
  BotLevel(7, 85, 8.4),
  BotLevel(8, 95, 7.0),
  BotLevel(9, 100, 6.4),
  BotLevel(10, 105, 5.8),
];

BotLevel botLevel(int level) => botLevels[(level.clamp(1, botLevels.length)) - 1];

class Bot {
  Bot(this.level, {math.Random? random}) : _random = random ?? math.Random();

  final BotLevel level;
  final math.Random _random;

  /// A dart aimed at [aim], landing with the bot's spread
  DartThrow throwAt(BoardPoint aim, {BoardGeometry geometry = const BoardGeometry()}) {
    // Box-Muller: two independent normal offsets
    final u = 1.0 - _random.nextDouble();
    final v = _random.nextDouble();
    final r = level.spreadMm * math.sqrt(-2.0 * math.log(u));
    final point = BoardPoint(aim.xMm + r * math.cos(2 * math.pi * v), aim.yMm + r * math.sin(2 * math.pi * v));
    return DartThrow(point, ThrowInput.keypad, geometry: geometry);
  }

  /// The next dart of the bot at the oche in [game]
  DartThrow nextDart(Object game) => throwAt(switch (game) {
    X01Game() => aimX01(game),
    CricketGame() => aimCricket(game),
    AroundTheClockGame() => aimAroundTheClock(game),
    _ => const BoardPoint(0, 0),
  });
}

/// Where a field is aimed at: the middle of its ring band in the middle of its sector
BoardPoint aimAt(String label) {
  if (label == '50') return const BoardPoint(0, 0);
  if (label == '25') return fieldCentre(Ring.outerBull);
  final sector = int.parse(label.substring(1));
  return switch (label[0]) {
    'T' => fieldCentre(Ring.triple, sector: sector),
    'D' => fieldCentre(Ring.double, sector: sector),
    _ => fieldCentre(Ring.outerSingle, sector: sector),
  };
}

BoardPoint aimX01(X01Game game) {
  final player = game.players[game.current];
  final dartsLeft = game.currentVisit.isComplete ? 3 : 3 - game.currentVisit.darts.length;
  if (game.settings.doubleIn && !player.isIn) return aimAt('D20');
  return aimAt(aimField(player.remaining, dartsLeft, doubleOut: game.settings.doubleOut));
}

/// The highest number the bot has not closed, on the triple; the bull last
BoardPoint aimCricket(CricketGame game) {
  final player = game.players[game.current];
  for (final target in cricketTargets) {
    if (!player.isClosed(target)) return target == 25 ? aimAt('50') : aimAt('T$target');
  }
  return aimAt('T20');
}

/// The big single of the current number, then the bull
BoardPoint aimAroundTheClock(AroundTheClockGame game) {
  final position = game.players[game.current].position;
  return position < 20 ? aimAt('S${position + 1}') : aimAt('50');
}
