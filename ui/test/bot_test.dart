import 'dart:math' as math;

import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/bots/bot.dart';
import 'package:dartpilot/src/games/around_the_clock.dart';
import 'package:dartpilot/src/games/cricket.dart';
import 'package:dartpilot/src/games/x01.dart';
import 'package:flutter_test/flutter_test.dart';

DartThrow at(Ring ring, [int sector = 20]) => DartThrow(fieldCentre(ring, sector: sector), ThrowInput.keypad);

String aimed(BoardPoint aim) => DartThrow(aim, ThrowInput.keypad).score.label;

void main() {
  test('every level reaches its X01 average over many legs', () {
    for (final level in botLevels) {
      final bot = Bot(level, random: math.Random(level.level));
      var darts = 0, points = 0;
      for (var leg = 0; leg < 150; ++leg) {
        final game = X01Game(const X01Settings(players: ['Bot']));
        while (!game.isFinished) {
          game.add(bot.nextDart(game));
        }
        darts += game.players.single.dartsThrown;
        points += game.players.single.pointsScored;
      }
      expect(3 * points / darts, closeTo(level.average, 5), reason: 'level ${level.level}');
    }
  });

  test('a bot aims like a player', () {
    final game = X01Game(const X01Settings(players: ['Bot'], startScore: 101));
    // 101 is a two-dart finish: T17, bull
    expect(aimed(aimX01(game)), 'T17');
    expect(aimed(aimX01(X01Game(const X01Settings(players: ['Bot'])))), 'T20');
    // 101 − 61 = 40 left: the double
    game
      ..add(at(Ring.triple, 20))
      ..add(at(Ring.outerSingle, 1));
    expect(game.players.single.remaining, 40);
    expect(aimed(aimX01(game)), 'D20');
    // 41 with one dart left cannot be finished: a single that leaves D16
    final late = X01Game(const X01Settings(players: ['Bot'], startScore: 162));
    late
      ..add(at(Ring.triple, 20))
      ..add(at(Ring.triple, 20));
    late.add(at(Ring.outerSingle, 1));
    expect(late.players.single.remaining, 41);
    expect(aimed(aimX01(late)), anyOf('S9', 'T3', 'S1'));

    final cricket = CricketGame(['Bot']);
    expect(aimed(aimCricket(cricket)), 'T20');
    cricket.add(at(Ring.triple, 20));
    expect(aimed(aimCricket(cricket)), 'T19');

    final clock = AroundTheClockGame(['Bot'], endWithBull: true);
    expect(aimed(aimAroundTheClock(clock)), 'S1');
  });

  test('the same seed throws the same darts', () {
    final a = Bot(botLevel(5), random: math.Random(3)).throwAt(const BoardPoint(0, 103));
    final b = Bot(botLevel(5), random: math.Random(3)).throwAt(const BoardPoint(0, 103));
    expect(a.point, b.point);
    expect(botLevel(0).level, 1);
    expect(botLevel(42).level, 10);
  });
}
