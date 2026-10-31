import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/games/checkout_trainer.dart';
import 'package:dartpilot/src/games/doubles.dart';
import 'package:dartpilot/src/games/killer.dart';
import 'package:dartpilot/src/games/x01.dart';
import 'package:dartpilot/src/screens/game_flow.dart';
import 'package:dartpilot/src/sound/effects.dart';
import 'package:dartpilot/src/sound/game_calls.dart';
import 'package:dartpilot/src/sound/x01_calls.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:dartpilot/src/stats/training_best.dart';
import 'package:dartpilot/src/widgets/winner_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  group('the line-up of a game', () {
    test('a rematch lets the next player start, and the bots and switches go with their players', () {
      const lineUp = LineUp(['Anna', 'Bot · Stark', 'Ben'], bots: {1: 7}, options: [true]);
      final next = lineUp.rotated;
      expect(next.players, ['Bot · Stark', 'Ben', 'Anna']);
      expect(next.bots, {0: 7});
      expect(next.options, [true]);
      expect(next.rotated.rotated.players, lineUp.players);
    });

    test('is kept per game', () async {
      SharedPreferences.setMockInitialValues({});
      await const LineUp(['Anna', 'Bot · Stark'], bots: {1: 7}, options: [false]).save('killer');
      final kept = await LineUp.load('killer');
      expect(kept?.players, ['Anna', 'Bot · Stark']);
      expect(kept?.botsByName, {'Bot · Stark': 7});
      expect(kept?.options, [false]);
      expect(await LineUp.load('cricket'), isNull);
    });
  });

  test('places are shared by players level on what decides, in their order', () {
    final lines = rankedLines([
      (const ResultLine('Anna'), [1, -20]),
      (const ResultLine('Ben'), [0, -10]),
      (const ResultLine('Cleo'), [1, -20]),
      (const ResultLine('Dirk'), [1, -5]),
    ]);
    expect([for (final l in lines) l.name], ['Ben', 'Anna', 'Cleo', 'Dirk']);
    expect([for (final l in lines) l.place], [1, 2, 2, 4]);
  });

  test('Killer keeps the order players went out in', () {
    final game = KillerGame(['Anna', 'Ben', 'Cleo'], [20, 3, 5], lives: 1);
    [at(Ring.double, 20), at(Ring.double, 20), at(Ring.double, 20)].forEach(game.add);
    [miss, miss, miss, miss, miss, miss].forEach(game.add);
    game.add(at(Ring.double, 5));
    expect(game.outOrder, [2]);
    game.add(at(Ring.double, 3));
    expect(game.outOrder, [2, 1]);
    expect(game.winner, 0);
  });

  test('a 501 leg in nine darts is a nine-darter, and the caller says so', () {
    final game = X01Game(const X01Settings(players: ['Anna', 'Ben']));
    void visit(List<DartThrow> darts) => darts.forEach(game.add);
    visit([at(Ring.triple), at(Ring.triple), at(Ring.triple)]);
    visit([miss, miss, miss]);
    visit([at(Ring.triple), at(Ring.triple), at(Ring.triple)]);
    visit([miss, miss, miss]);
    final visitsBefore = game.visits.length;
    visit([at(Ring.triple), at(Ring.triple, 19)]);
    game.add(at(Ring.double, 12));
    expect(game.isFinished, isTrue);
    expect(game.isNineDarter(game.visits.lastWhere((v) => v.isCheckout)), isTrue);
    expect(x01Calls(game, visitsBefore: visitsBefore, legBefore: 1), [callMatchShot, callNineDarter]);
  });

  test('the caller says a bot\'s name without its separator', () {
    final game = KillerGame(['Anna', 'Bot · Stark'], [20, 3], lives: 1);
    [at(Ring.double, 20), at(Ring.double, 20), at(Ring.double, 20), miss, miss, miss].forEach(game.add);
    game.add(at(Ring.double, 3));
    final calls = killerCalls(game, livesBefore: [1, 1], killersBefore: [true, false]);
    expect(calls, ['Bot Stark is out', 'Anna wins']);
  });

  group('trainings sound what a dart did', () {
    test('a checkout made sounds like a leg, a bust like a bust', () {
      final trainer = CheckoutTrainer(const [40, 40], dartsPerAttempt: 3);
      trainer.add(at(Ring.double, 20));
      expect(checkoutTrainerEffect(trainer, at(Ring.double, 20), attemptsBefore: 1, bustsBefore: 0), Effect.leg);
      final busted = CheckoutTrainer(const [40, 40], dartsPerAttempt: 6);
      busted.add(at(Ring.outerSingle, 20));
      busted.add(at(Ring.outerSingle, 20));
      expect(checkoutTrainerEffect(busted, at(Ring.outerSingle, 20), attemptsBefore: 1, bustsBefore: 0), Effect.bust);
    });

    test('a double hit in doubles practice sounds apart from a miss', () {
      final game = DoublesGame(allDoubles.take(2).toList());
      game.add(at(Ring.double, 20));
      expect(doublesEffect(game, at(Ring.double, 20)), Effect.visit);
      game.add(at(Ring.outerSingle, 20));
      expect(doublesEffect(game, at(Ring.outerSingle, 20)), Effect.dart);
    });

    test('rounds at the weakest doubles compare with each other, whichever doubles they were', () {
      GameRecord weakest(List<int> doubles) => recordOf(
        GameMode.doubles,
        ['Anna'],
        const [],
        settings: {
          'targets': [for (final d in doubles) 'D$d'],
          'darts_per_target': 3,
          'weakest': true,
        },
      );
      expect(trainingKind(weakest([1, 3, 5, 7, 9])), trainingKind(weakest([2, 3, 5, 7, 9])));
    });
  });

  group('every game ends on the same result', () {
    Future<void> resume(WidgetTester tester, GameRecord running) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final store = MemoryGameStore()..running = running;
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

    Future<void> dart(WidgetTester tester, String key, {String? modifier}) async {
      if (modifier != null) {
        await tester.tap(find.text(modifier));
        await tester.pump();
      }
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    String? text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data;

    Future<void> rematch(WidgetTester tester, String game) async {
      await tester.tap(find.byKey(const ValueKey('result-rematch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('winner-title')), findsNothing);
      expect((await LineUp.load(game))?.players, ['Ben', 'Anna']);
    }

    testWidgets('Cricket: ranked by points, with a rematch that Ben starts', (tester) async {
      await resume(
        tester,
        recordOf(
          GameMode.cricket,
          ['Anna', 'Ben'],
          [
            at(Ring.triple, 20),
            at(Ring.triple, 20),
            at(Ring.triple, 19),
            miss,
            miss,
            miss,
            at(Ring.triple, 18),
            at(Ring.triple, 17),
            at(Ring.triple, 16),
            miss,
            miss,
            miss,
            at(Ring.triple, 15),
            at(Ring.innerBull),
          ],
        ),
      );
      await dart(tester, 'keypad-25');
      expect(find.text('Anna gewinnt!'), findsOneWidget);
      expect(text(tester, 'place-Anna'), '1.');
      expect(text(tester, 'place-Ben'), '2.');
      expect(text(tester, 'result-value-Anna'), '60');
      await rematch(tester, 'cricket');
    });

    testWidgets('Killer: the order players went out in, with a rematch', (tester) async {
      await resume(
        tester,
        recordOf(
          GameMode.killer,
          ['Anna', 'Ben'],
          [at(Ring.double, 20), at(Ring.double, 20), at(Ring.double, 20), miss, miss, miss, at(Ring.double, 3)],
          settings: {
            'numbers': [20, 3],
            'lives': 2,
          },
        ),
      );
      // Anna is a killer: the doubles she throws at now are the others'.
      expect(text(tester, 'round-target'), 'D3');
      await dart(tester, 'keypad-3', modifier: 'Double');
      expect(find.text('Anna gewinnt!'), findsOneWidget);
      expect(text(tester, 'place-Ben'), '2.');
      await rematch(tester, 'killer');
    });

    testWidgets('Around the Clock: by how far round each got, with a rematch', (tester) async {
      final throws = <DartThrow>[];
      for (var n = 1; n <= 20; n += 3) {
        throws.addAll([for (var i = n; i < n + 3; ++i) i <= 20 ? at(Ring.outerSingle, i) : miss]);
        throws.addAll([at(Ring.outerSingle, 1), miss, miss]);
      }
      // The last visit: 19 and 20 to go, 20 thrown at the end
      final running = throws.sublist(0, 18 * 2 + 1);
      await resume(
        tester,
        recordOf(GameMode.aroundTheClock, ['Anna', 'Ben'], running, settings: {'end_with_bull': false}),
      );
      await dart(tester, 'keypad-20');
      expect(find.text('Anna gewinnt!'), findsOneWidget);
      expect(text(tester, 'result-value-Anna'), '20/20');
      expect(text(tester, 'result-value-Ben'), '1/20');
      await rematch(tester, 'around_the_clock');
    });

    testWidgets('Shanghai: by points, with a rematch', (tester) async {
      final throws = [at(Ring.outerSingle, 1), ...List.filled(40, miss)];
      await resume(tester, recordOf(GameMode.shanghai, ['Anna', 'Ben'], throws, settings: {'rounds': 7}));
      await dart(tester, 'keypad-miss');
      expect(find.text('Anna gewinnt!'), findsOneWidget);
      expect(text(tester, 'result-value-Anna'), '1');
      await rematch(tester, 'shanghai');
    });

    testWidgets('a draw ends on the same result, with the tied players sharing first place and a rematch', (
      tester,
    ) async {
      await resume(
        tester,
        recordOf(GameMode.shanghai, ['Anna', 'Ben'], List.filled(41, miss), settings: {'rounds': 7}),
      );
      await dart(tester, 'keypad-miss');
      expect(text(tester, 'winner-title'), 'Unentschieden');
      expect(text(tester, 'place-Anna'), '1.');
      expect(text(tester, 'place-Ben'), '1.');
      await rematch(tester, 'shanghai');
    });

    testWidgets('cut-throat says so, and the fewest points lead', (tester) async {
      await resume(
        tester,
        recordOf(
          GameMode.cricket,
          ['Anna', 'Ben'],
          [at(Ring.triple, 20), at(Ring.triple, 20), miss],
          settings: {'cut_throat': true},
        ),
      );
      expect(find.text('Cricket · Cut-Throat'), findsOneWidget);
      expect(find.byKey(const ValueKey('cut-throat-note')), findsOneWidget);
      expect(text(tester, 'points-Ben'), '60');
      expect(find.byKey(const ValueKey('leader-Anna')), findsOneWidget);
      expect(find.byKey(const ValueKey('leader-Ben')), findsNothing);
    });

    for (final mode in [GameMode.cricket, GameMode.aroundTheClock, GameMode.killer]) {
      testWidgets('${mode.name}: without an engine a visit that ended stays on show for a moment', (tester) async {
        await resume(
          tester,
          recordOf(
            mode,
            ['Anna', 'Ben'],
            const [],
            settings: mode == GameMode.killer
                ? {
                    'numbers': [20, 3],
                    'lives': 3,
                  }
                : null,
          ),
        );
        for (var i = 0; i < 3; ++i) {
          await tester.tap(find.byKey(const ValueKey('keypad-miss')));
          await tester.pump();
        }
        expect(text(tester, 'visit-dart-2'), 'Daneben');
        await tester.pump(HoldsVisits.holdTime);
        await tester.pumpAndSettle();
        expect(text(tester, 'visit-dart-0'), '–');
      });
    }

    testWidgets('a party setup starts from the last line-up, bots and who starts included', (tester) async {
      SharedPreferences.setMockInitialValues({
        'lineup.cricket': '{"players":["Ben","Bot · Stark","Anna"],"bots":{"1":7},"options":[true]}',
      });
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna', 'Ben']));
      await statistics.load();
      await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play-offline')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cricket'));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('first-Ben'))).selected, isTrue);
      expect(find.byKey(const ValueKey('first-Bot · Stark')), findsOneWidget);
      // Bot · Stark starts now; the others follow in their order.
      await tester.tap(find.byKey(const ValueKey('first-Bot · Stark')));
      await tester.pumpAndSettle();
      expect(find.text('Reihenfolge: Bot · Stark → Anna → Ben'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    });
  });
}
