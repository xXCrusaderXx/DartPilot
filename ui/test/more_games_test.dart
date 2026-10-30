import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/bots/bot.dart';
import 'package:dartpilot/src/games/checkout_trainer.dart';
import 'package:dartpilot/src/games/cricket.dart';
import 'package:dartpilot/src/games/killer.dart';
import 'package:dartpilot/src/games/x01.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:flutter_test/flutter_test.dart';

DartThrow at(Ring ring, [int sector = 20]) => DartThrow(fieldCentre(ring, sector: sector), ThrowInput.keypad);
DartThrow get miss => at(Ring.miss);
DartThrow field(String label) => DartThrow(aimAt(label), ThrowInput.keypad);

void main() {
  group('Killer', () {
    test('every player gets a different number from the seed', () {
      final numbers = killerNumbers(5, 8);
      expect(numbers.toSet(), hasLength(8));
      expect(numbers.every((n) => n >= 1 && n <= 20), isTrue);
      expect(killerNumbers(5, 8), numbers);
    });

    test('three hits on the own double make a killer, who then takes lives until one player is left', () {
      final game = KillerGame(['Anna', 'Ben'], [20, 3], lives: 2);
      // Anna: D20 twice, then a D3 that does not count before she is a killer
      game.add(at(Ring.double, 20));
      game.add(at(Ring.double, 20));
      game.add(at(Ring.double, 3));
      expect(game.players[0].marks, 2);
      expect(game.players[1].lives, 2);
      expect(game.current, 1);
      [miss, miss, miss].forEach(game.add);
      game.add(at(Ring.double, 20));
      expect(game.players[0].isKiller, isTrue);
      game.add(at(Ring.double, 3));
      expect(game.players[1].lives, 1);
      game.add(at(Ring.double, 3));
      expect(game.isFinished, isTrue);
      expect(game.winner, 0);
    });

    test('a killer who hits the own double loses a life, and a player who is out is skipped', () {
      final game = KillerGame(['Anna', 'Ben', 'Cleo'], [20, 3, 7], lives: 1);
      [at(Ring.double, 20), at(Ring.double, 20), at(Ring.double, 20)].forEach(game.add);
      [miss, miss, miss].forEach(game.add);
      [miss, miss, miss].forEach(game.add);
      // Anna takes Ben's last life, then hits her own double: out, and her visit ends at once.
      game.add(at(Ring.double, 3));
      expect(game.players[1].out, isTrue);
      game.add(at(Ring.double, 20));
      expect(game.players[0].out, isTrue);
      expect(game.isFinished, isTrue);
      expect(game.winner, 2);
    });

    test('a record replays with its numbers, and a bot goes for its own double first', () {
      final record = GameRecord(
        id: 'k',
        mode: GameMode.killer,
        started: DateTime(2026, 10, 26),
        ended: DateTime(2026, 10, 26),
        players: ['Anna', 'Ben'],
        settings: {
          'numbers': [11, 14],
          'lives': 3,
        },
        throws: [at(Ring.double, 11)],
      );
      final game = GameRecord.fromJson(record.toJson())!.killerGame;
      expect(game.numbers, [11, 14]);
      expect(score(aimKiller(game).xMm, aimKiller(game).yMm).label, 'D11');
    });
  });

  test('Cut-Throat Cricket: points go to the opponents who have not closed, and the lowest score wins', () {
    final game = CricketGame(['Anna', 'Ben', 'Cleo'], cutThroat: true);
    // Anna closes the 20 and scores one more triple: 60 for Ben and Cleo
    game.add(at(Ring.triple));
    game.add(at(Ring.triple));
    game.add(miss);
    expect(game.players.map((p) => p.points), [0, 60, 60]);
    // Ben closes the 20; Anna's next 20s only hit Cleo.
    [at(Ring.triple), miss, miss].forEach(game.add);
    [miss, miss, miss].forEach(game.add);
    [at(Ring.outerSingle), miss, miss].forEach(game.add);
    expect(game.players.map((p) => p.points), [0, 60, 80]);

    final record = GameRecord(
      id: 'c',
      mode: GameMode.cricket,
      started: DateTime(2026, 10, 26),
      ended: DateTime(2026, 10, 26),
      players: ['Anna', 'Ben', 'Cleo'],
      settings: {'cut_throat': true},
      throws: game.throws,
    );
    expect((record.replay().game as CricketGame).cutThroat, isTrue);
  });

  test('121: a checkout made moves up by one, a missed one steps down by one, never below 121', () {
    final starts = checkoutStarts(1, 3, CheckoutRange.ladder);
    expect(starts, [121, 121, 121]);
    final game = CheckoutTrainer(starts, dartsPerAttempt: 3, ladder: true);
    // 121 in three: T20, T11, D14
    expect(game.aim, suggestCheckout(121, 3)!.first);
    for (final label in suggestCheckout(121, 3)!) {
      game.add(field(label));
    }
    expect(game.attempts.first.checkedOut, isTrue);
    expect(game.current.start, 122);
    [miss, miss, miss].forEach(game.add);
    expect(game.current.start, 121);
    expect(game.attempts, hasLength(3));
    expect(game.bestCheckout, 121);
    expect(CheckoutTrainer.nextLadderStart(CheckoutAttempt(121)), 121);
    expect(CheckoutTrainer.nextLadderStart(CheckoutAttempt(170)..checkedOut = true), 170);
  });
}
