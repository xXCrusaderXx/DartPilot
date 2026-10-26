import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/bots/bot.dart';
import 'package:dartpilot/src/games/round_games.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/player_stats.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

DartThrow at(Ring ring, [int sector = 20]) => DartThrow(fieldCentre(ring, sector: sector), ThrowInput.keypad);
DartThrow get miss => at(Ring.miss);

void visit(RoundGame game, List<DartThrow> darts) => darts.forEach(game.add);

void main() {
  group('Shanghai', () {
    test('every hit on the round\'s number scores its points; after the last round the highest score wins', () {
      final game = ShanghaiGame(['Anna', 'Ben'], rounds: 2);
      visit(game, [at(Ring.triple, 1), at(Ring.outerSingle, 1), at(Ring.triple, 20)]);
      expect(game.players[0].score, 4);
      expect(game.players[0].hits, 2);
      expect(game.current, 1);
      visit(game, [at(Ring.double, 1), miss, miss]);
      expect(game.round, 1);
      expect(game.target.label, '2');
      visit(game, [miss, miss, miss]);
      visit(game, [at(Ring.triple, 2), at(Ring.triple, 2), miss]);
      expect(game.isFinished, isTrue);
      expect(game.players.map((p) => p.score), [4, 14]);
      expect(game.winner, 1);
    });

    test('single, double and triple of the number in one visit win at once', () {
      final game = ShanghaiGame(['Anna', 'Ben']);
      visit(game, [at(Ring.innerSingle, 1), at(Ring.triple, 1), at(Ring.double, 1)]);
      expect(game.isFinished, isTrue);
      expect(game.winner, 0);
      expect(game.players[0].score, 6);
    });
  });

  group("Bob's 27", () {
    test('a hit adds the double, a visit without one takes it away, below zero is out', () {
      final game = Bobs27Game(['Anna']);
      expect(game.players[0].score, 27);
      visit(game, [at(Ring.double, 1), at(Ring.double, 1), miss]);
      expect(game.players[0].score, 31);
      visit(game, [miss, miss, miss]);
      expect(game.players[0].score, 27);
      visit(game, [miss, miss, miss]);
      expect(game.players[0].score, 21);
      for (final n in [4, 5, 6]) {
        expect(game.target.label, 'D$n');
        visit(game, [miss, miss, miss]);
      }
      // 21 - 8 - 10 - 12 < 0
      expect(game.players[0].out, isTrue);
      expect(game.isFinished, isTrue);
    });

    test('the last round is the double bull, worth 50', () {
      final game = Bobs27Game(['Anna']);
      for (var n = 1; n <= 20; ++n) {
        visit(game, [at(Ring.double, n), miss, miss]);
      }
      expect(game.target.label, 'D-Bull');
      visit(game, [at(Ring.innerBull), at(Ring.outerBull), miss]);
      expect(game.isFinished, isTrue);
      expect(game.players[0].score, 27 + 420 + 50);
    });

    test('a player who is out is skipped, the others play on', () {
      final game = Bobs27Game(['Anna', 'Ben']);
      // Anna: 27 - 2 - 4 - 6 - 8 = 7, then - 10 is below zero
      for (var round = 0; round < 4; ++round) {
        visit(game, [miss, miss, miss]);
        visit(game, [at(Ring.double, round + 1), miss, miss]);
      }
      visit(game, [miss, miss, miss]);
      expect(game.players[0].out, isTrue);
      expect(game.current, 1);
      visit(game, [at(Ring.double, 5), miss, miss]);
      expect(game.current, 1);
      expect(game.target.label, 'D6');
    });
  });

  test('Halve-It: hits on the target add their points, a visit without one halves the score', () {
    final game = HalveItGame(['Anna']);
    expect(game.players[0].score, 40);
    visit(game, [at(Ring.triple, 15), miss, miss]);
    expect(game.players[0].score, 85);
    visit(game, [at(Ring.outerSingle, 15), miss, miss]);
    expect(game.players[0].score, 42);
    expect(game.target.label, 'D');
    visit(game, [at(Ring.double, 3), at(Ring.triple, 20), miss]);
    expect(game.players[0].score, 48);
    expect(game.targets.map((t) => t.label), ['15', '16', 'D', '17', '18', 'T', '19', '20', 'Bull']);
  });

  test('a record replays every mode, and the final score is in the statistics', () {
    final game = HalveItGame(['Anna', 'Ben']);
    visit(game, [at(Ring.triple, 15), miss, miss]);
    visit(game, [miss, miss, miss]);
    final record = GameRecord(
      id: 'h',
      mode: GameMode.halveIt,
      started: DateTime(2026, 10, 26),
      ended: DateTime(2026, 10, 26),
      players: ['Anna', 'Ben'],
      throws: game.throws,
    );
    final back = GameRecord.fromJson(record.toJson())!;
    final replayed = back.replay();
    final playerOf = replayed.playerOf;
    expect((replayed.game as HalveItGame).players.map((p) => p.score), [85, 20]);
    expect(playerOf, [0, 0, 0, 1, 1, 1]);
    expect(computePlayerStats([back], 'Ben').history.single.points, 20);
    final shanghai = GameRecord(
      id: 's',
      mode: GameMode.shanghai,
      started: DateTime(2026, 10, 26),
      ended: DateTime(2026, 10, 26),
      players: ['Anna'],
      settings: {'rounds': 20},
      throws: const [],
    );
    expect(shanghai.roundGame.targets, hasLength(20));
  });

  test('a bot aims at the round\'s target', () {
    final bot = Bot(botLevel(10));
    final game = Bobs27Game(['Bot']);
    var hits = 0;
    for (var i = 0; i < 200; ++i) {
      if (game.target.hits(bot.nextDart(game).score)) hits++;
    }
    expect(hits, greaterThan(40));
  });

  testWidgets('Shanghai is played from home with two players, and the scores follow the darts', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna', 'Ben']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await tester.dragUntilVisible(find.text('Weitere Spiele'), find.byType(ListView).first, const Offset(0, -200));
    await tester.tap(find.text('Weitere Spiele'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shanghai'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna', 'Ben']);
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('round-target'))).data, '1');

    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    Future<void> key(String ring, int n) async {
      await tester.tap(find.text(ring));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('keypad-$n')));
      await tester.pumpAndSettle();
    }

    await key('Triple', 1);
    await key('Double', 1);
    await key('Single', 1);
    // Single, double and triple of the 1 in one visit: a Shanghai
    expect(find.text('Anna gewinnt!'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('score-Anna'))).data, '6');
  });
}
