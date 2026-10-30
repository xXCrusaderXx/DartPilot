import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/games/around_the_clock.dart';
import 'package:dartpilot/src/games/cricket.dart';
import 'package:dartpilot/src/games/killer.dart';
import 'package:dartpilot/src/games/round_games.dart';
import 'package:dartpilot/src/sound/game_calls.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/personal_best.dart';
import 'package:dartpilot/src/stats/player_stats.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DartThrow at(Ring ring, [int sector = 20]) => DartThrow(fieldCentre(ring, sector: sector), ThrowInput.keypad);
DartThrow get miss => at(Ring.miss);

GameRecord recordOf(GameMode mode, List<String> players, List<DartThrow> throws, {Map<String, Object?>? settings}) =>
    GameRecord(
      id: '$mode-${throws.length}',
      mode: mode,
      started: DateTime(2026, 10, 30),
      ended: DateTime(2026, 10, 30),
      players: players,
      settings: settings ?? const {},
      throws: throws,
    );

void main() {
  group('round games end in a win, a draw or, alone, only a score', () {
    test('players level on the best score draw, and nobody gets a win in the statistics', () {
      final game = ShanghaiGame(['Anna', 'Ben'], rounds: 2);
      for (var i = 0; i < 12; ++i) {
        game.add(miss);
      }
      expect(game.isFinished, isTrue);
      expect(game.isDraw, isTrue);
      expect(game.winner, isNull);
      expect(game.leaders, [0, 1]);
      expect(game.wonAtOnce, isFalse);
      final record = recordOf(GameMode.shanghai, ['Anna', 'Ben'], game.throws, settings: {'rounds': 2});
      expect(computePlayerStats([record], 'Anna').gamesWon, 0);
      expect(computePlayerStats([record], 'Ben').gamesWon, 0);
    });

    test('a draw among the best leaves the others out of it', () {
      HalveItGame play({required bool cleoHits}) {
        final game = HalveItGame(['Anna', 'Ben', 'Cleo']);
        for (var round = 0; round < 9; ++round) {
          // Round 6 is any triple: Ben, and Cleo if she [cleoHits], score 60 there.
          final triple = at(Ring.triple, 20);
          [miss, miss, miss].forEach(game.add);
          [round == 5 ? triple : miss, miss, miss].forEach(game.add);
          [round == 5 && cleoHits ? triple : miss, miss, miss].forEach(game.add);
        }
        return game;
      }

      final level = play(cleoHits: true);
      expect(level.leaders, [1, 2]);
      expect(level.isDraw, isTrue);
      final won = play(cleoHits: false);
      expect(won.isDraw, isFalse);
      expect(won.winner, 1);
    });

    test('a solo game has no winner, also not when the player goes below zero, and counts no win', () {
      final bobs = Bobs27Game(['Anna']);
      for (var i = 0; i < 15; ++i) {
        bobs.add(miss);
      }
      expect(bobs.isFinished, isTrue);
      expect(bobs.players.single.out, isTrue);
      expect(bobs.winner, isNull);
      expect(bobs.isDraw, isFalse);
      final cricket = CricketGame(['Anna']);
      for (final n in [20, 19, 18, 17, 16, 15]) {
        cricket.add(at(Ring.triple, n));
      }
      cricket.add(at(Ring.innerBull));
      cricket.add(at(Ring.outerBull));
      expect(cricket.isFinished, isTrue);
      final record = recordOf(GameMode.cricket, ['Anna'], cricket.throws);
      expect(computePlayerStats([record], 'Anna').gamesWon, 0);
    });

    test('the visit that ended keeps its player and round until the next dart', () {
      final game = ShanghaiGame(['Anna', 'Ben']);
      [miss, miss, miss].forEach(game.add);
      expect(game.current, 1);
      expect(game.visitPlayer, 0);
      game.add(miss);
      expect(game.visitPlayer, 1);
      [miss, miss].forEach(game.add);
      expect(game.round, 1);
      expect(game.visitRound, 0);
    });

    test('the best so far is the highest score in games of the same rules', () {
      final shanghai = ShanghaiGame(['Anna'], rounds: 7);
      [at(Ring.triple, 1), miss, miss].forEach(shanghai.add);
      final seven = recordOf(GameMode.shanghai, ['Anna'], shanghai.throws, settings: {'rounds': 7});
      final twenty = recordOf(
        GameMode.shanghai,
        ['Anna'],
        [at(Ring.triple, 1), at(Ring.triple, 1), at(Ring.triple, 1)],
        settings: {'rounds': 20},
      );
      final history = computePlayerStats([seven, twenty], 'Anna').history;
      expect(personalBest(history, recordOf(GameMode.shanghai, ['Anna'], const [], settings: {'rounds': 7})), 3);
      expect(personalBest(history, recordOf(GameMode.shanghai, ['Anna'], const [], settings: {'rounds': 20})), 9);
      expect(personalBest(history, recordOf(GameMode.halveIt, ['Anna'], const [])), isNull);
    });
  });

  group('the caller says what fits the game', () {
    List<String> visit(RoundGame game, List<DartThrow> darts) {
      var calls = <String>[];
      for (final d in darts) {
        final player = game.current;
        final before = game.players[player].score;
        game.add(d);
        calls = roundCalls(game, player: player, scoreBefore: before);
      }
      return calls;
    }

    test('Shanghai! only for single, double and triple in one visit, never for a game won on points', () {
      final solo = ShanghaiGame(['Anna']);
      for (var round = 0; round < 6; ++round) {
        visit(solo, [miss, miss, miss]);
      }
      expect(visit(solo, [miss, miss, at(Ring.outerSingle, 7)]), ['7', 'Final score, 7']);

      final duel = ShanghaiGame(['Anna', 'Ben'], rounds: 1);
      visit(duel, [miss, miss, miss]);
      expect(visit(duel, [at(Ring.triple, 1), miss, miss]), ['3', 'Ben wins']);

      final level = ShanghaiGame(['Anna', 'Ben'], rounds: 1);
      visit(level, [miss, miss, miss]);
      expect(visit(level, [miss, miss, miss]), ['No score', "It's a draw"]);
    });

    test('no X01 lines at the end of Cricket, Around the Clock or Killer', () {
      final cricket = CricketGame(['Anna']);
      for (final n in [20, 19, 18, 17, 16, 15]) {
        cricket.add(at(Ring.triple, n));
      }
      cricket.add(at(Ring.innerBull));
      cricket.add(at(Ring.outerBull));
      expect(cricketCalls(cricket), ['All closed in 8 darts']);

      final clock = AroundTheClockGame(['Anna', 'Ben'], endWithBull: false);
      for (var n = 1; n <= 20; ++n) {
        clock.add(at(Ring.outerSingle, n));
        if (n % 3 == 0) [miss, miss, miss].forEach(clock.add);
      }
      expect(aroundTheClockCalls(clock), ['Anna wins']);

      final killer = KillerGame(['Anna', 'Ben'], [20, 3], lives: 1);
      [at(Ring.double, 20), at(Ring.double, 20), at(Ring.double, 20)].forEach(killer.add);
      [miss, miss, miss].forEach(killer.add);
      final lives = [for (final p in killer.players) p.lives];
      final killers = [for (final p in killer.players) p.isKiller];
      killer.add(at(Ring.double, 3));
      expect(killerCalls(killer, livesBefore: lives, killersBefore: killers), ['Ben is out', 'Anna wins']);
    });
  });

  Future<void> resume(WidgetTester tester, GameRecord running, {List<GameRecord> kept = const [], Size? size}) async {
    tester.view.physicalSize = size ?? const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = MemoryGameStore([...kept])..running = running;
    final statistics = Statistics(store, MemoryProfileStore(running.players));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await tester.pumpAndSettle();
    for (final key in ['play-offline', 'resume-interrupted']) {
      final step = find.byKey(ValueKey(key), skipOffstage: false);
      await tester.ensureVisible(step);
      await tester.pumpAndSettle();
      await tester.tap(step);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
  }

  Future<void> tapMiss(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('keypad-miss')));
    await tester.pumpAndSettle();
  }

  testWidgets('a level Shanghai ends as a draw, not as a win of the first player', (tester) async {
    await resume(tester, recordOf(GameMode.shanghai, ['Anna', 'Ben'], List.filled(41, miss), settings: {'rounds': 7}));
    await tapMiss(tester);
    expect(find.text('Unentschieden'), findsOneWidget);
    expect(find.text('Anna, Ben: je 0 Punkte'), findsOneWidget);
    expect(find.textContaining('gewinnt'), findsNothing);
  });

  testWidgets('a solo Bob\'s 27 ends on its result and the best so far, not on a win', (tester) async {
    final earlier = recordOf(GameMode.bobs27, ['Anna'], [at(Ring.double, 1), miss, miss, ...List.filled(12, miss)]);
    // 27 - 2 - 4 - 6 - 8 - 10 is below zero at the D5.
    await resume(tester, recordOf(GameMode.bobs27, ['Anna'], List.filled(14, miss)), kept: [earlier]);
    await tapMiss(tester);
    expect(find.text('Spiel beendet'), findsOneWidget);
    expect(find.text('Unter null bei D5'), findsOneWidget);
    expect(find.byKey(const ValueKey('personal-best')), findsOneWidget);
    expect(find.textContaining('gewinnt'), findsNothing);
  });

  testWidgets('the round\'s target stands out, and a new visit starts without the last one\'s darts', (tester) async {
    await resume(tester, recordOf(GameMode.halveIt, ['Anna', 'Ben'], [miss, miss]));
    expect(tester.widget<Text>(find.byKey(const ValueKey('round-target'))).data, '15');
    expect(find.text('ZIEL'), findsOneWidget);
    await tapMiss(tester);
    expect(tester.widget<Text>(find.byKey(const ValueKey('visit-dart-0'))).data, '–');
  });

  testWidgets('Killer draws the lives as hearts and offers five lives', (tester) async {
    final semantics = tester.ensureSemantics();
    await resume(
      tester,
      recordOf(
        GameMode.killer,
        ['Anna', 'Ben'],
        const [],
        settings: {
          'numbers': [20, 3],
          'lives': 5,
        },
      ),
    );
    expect(
      find.descendant(of: find.byKey(const ValueKey('lives-Anna')), matching: find.byIcon(Icons.favorite)),
      findsNWidgets(5),
    );
    expect(find.bySemanticsLabel(RegExp('5 Leben')), findsWidgets);
    semantics.dispose();
  });

  testWidgets('with eight players on a phone on its side the player at the oche, the darts and Undo stay in view', (
    tester,
  ) async {
    const players = ['Anna', 'Ben', 'Cleo', 'Dora', 'Emil', 'Fritz', 'Gina', 'Hugo'];
    for (final mode in [GameMode.shanghai, GameMode.killer, GameMode.aroundTheClock]) {
      await resume(
        tester,
        recordOf(
          mode,
          players,
          List.filled(18, miss),
          settings: mode == GameMode.killer
              ? {
                  'numbers': [1, 2, 3, 4, 5, 6, 7, 8],
                }
              : {'rounds': 7},
        ),
        size: const Size(915, 412),
      );
      expect(tester.takeException(), isNull);
      final key = switch (mode) {
        GameMode.killer => 'lives-Gina',
        GameMode.aroundTheClock => 'target-Gina',
        _ => 'score-Gina',
      };
      final active = tester.getRect(find.byKey(ValueKey(key)));
      expect(active.top, greaterThanOrEqualTo(0));
      expect(active.bottom, lessThanOrEqualTo(412));
      final undo = tester.getRect(find.widgetWithText(OutlinedButton, 'Rückgängig'));
      expect(undo.bottom, lessThanOrEqualTo(412));
      expect(tester.getRect(find.byKey(const ValueKey('visit-dart-0'))).bottom, lessThanOrEqualTo(412));
      await tester.pumpWidget(const SizedBox());
    }
  });
}
