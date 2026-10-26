import 'dart:io';

import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/player_stats.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter_test/flutter_test.dart';

DartThrow at(Ring ring, [int sector = 20]) => DartThrow(fieldCentre(ring, sector: sector), ThrowInput.keypad);

final t20 = at(Ring.triple), s20 = at(Ring.outerSingle), s1 = at(Ring.outerSingle, 1), miss = at(Ring.miss);

GameRecord x01(List<String> players, List<DartThrow> throws, {int start = 101, DateTime? ended}) => GameRecord(
  id: 'g',
  mode: GameMode.x01,
  started: DateTime(2026, 10, 24, 20),
  ended: ended ?? DateTime(2026, 10, 24, 21),
  players: players,
  settings: {'start_score': start, 'double_in': false, 'double_out': true, 'legs_to_win': 1},
  throws: throws,
);

void main() {
  test('a hand-checked 101 game: averages, first 9, checkout rate, finish and best leg', () {
    // Anna: T20 S20 S1 (81, 20 left) | D10 (checkout, 1 dart)            -> 4 darts, 101 points
    // Ben:  S1 S1 S1 (3)                                                 -> 3 darts, 3 points
    final game = x01(['Anna', 'Ben'], [t20, s20, s1, s1, s1, s1, at(Ring.double, 10)]);
    final anna = computePlayerStats([game], 'Anna');
    expect(anna.games, 1);
    expect(anna.gamesWon, 1);
    expect(anna.darts, 4);
    expect(anna.threeDartAverage, closeTo(3 * 101 / 4, 1e-9));
    expect(anna.first9Average, closeTo(3 * 101 / 4, 1e-9));
    expect(anna.legs, 1);
    expect(anna.legsWon, 1);
    expect(anna.bestLegDarts, 4);
    expect(anna.highestFinish, 20);
    // One dart at a finishing double (20 left), and it went in.
    expect(anna.checkoutAttempts, 1);
    expect(anna.checkoutRate, 1.0);
    expect(anna.favouriteDoubles.single.key, 'D10');
    expect(anna.rings[Ring.triple], 1);
    expect(anna.fields['S20'], 1);
    expect(anna.visits100, 0);

    final ben = computePlayerStats([game], 'Ben');
    expect(ben.gamesWon, 0);
    expect(ben.threeDartAverage, 3.0);
    expect(ben.legs, 1);
    expect(ben.legsWon, 0);
    expect(ben.bestLegDarts, isNull);
  });

  test('missed doubles count as attempts, a bust visit scores nothing, and 140+ visits are counted', () {
    // 181 start: T20 T20 S20 = 140 (41 left) | S1 (40) miss miss | D20 checkout
    final game = x01(['Anna'], [t20, t20, s20, s1, miss, miss, at(Ring.double)], start: 181);
    final anna = computePlayerStats([game], 'Anna');
    expect(anna.visits140, 1);
    expect(anna.checkoutAttempts, 3);
    expect(anna.checkouts, 1);
    expect(anna.checkoutRate, closeTo(1 / 3, 1e-9));
    expect(anna.first9Average, closeTo(3 * 181 / 7, 1e-9));
    expect(anna.rings[Ring.miss], 2);
  });

  test('cricket marks per round, around the clock hit rate, the period and guests', () {
    final cricket = GameRecord(
      id: 'c',
      mode: GameMode.cricket,
      started: DateTime(2026, 10, 1),
      ended: DateTime(2026, 10, 1),
      players: ['Anna'],
      throws: [t20, s20, miss],
    );
    final clock = GameRecord(
      id: 'a',
      mode: GameMode.aroundTheClock,
      started: DateTime(2026, 10, 24),
      ended: DateTime(2026, 10, 24),
      players: ['Anna', 'Spieler 2'],
      throws: [s1, miss, miss],
    );
    final all = computePlayerStats([cricket, clock], 'Anna');
    expect(all.games, 2);
    // As the game counts them: the T20 closes the 20; the S20 after it scores nothing alone at the board.
    expect(all.marksPerRound, 3.0);
    expect(all.clockHitRate, closeTo(1 / 3, 1e-9));
    expect(all.history.first.record.id, 'a');

    final recent = computePlayerStats([cricket, clock], 'Anna', since: DateTime(2026, 10, 20));
    expect(recent.games, 1);
    expect(recent.marksPerRound, isNull);

    final stats = Statistics(MemoryGameStore([cricket, clock]));
    expect(isGuestName('Spieler 2'), isTrue);
    expect(isGuestName('Player 12'), isTrue);
    expect(isGuestName('Spieler Anna'), isFalse);
    return stats.load().then((_) => expect(stats.players, ['Anna']));
  });

  test('games survive a restart in the file store, and unknown lines are skipped', () async {
    final dir = await Directory.systemTemp.createTemp('dartpilot-stats');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/games.jsonl');
    final store = FileGameStore(file);
    await store.add(x01(['Anna'], [t20, s20]));
    await file.writeAsString('{"mode":"future_mode","id":"later"}\nnot json\n', mode: FileMode.append);
    final loaded = await FileGameStore(file).load();
    expect(loaded.single.players, ['Anna']);
    expect(loaded.single.throws.first.score.label, 'T20');
    expect(loaded.single.x01Settings.startScore, 101);
  });
}
