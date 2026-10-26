import 'dart:math' as math;

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/games/checkout_trainer.dart';
import 'package:dartpilot/src/games/doubles.dart';
import 'package:dartpilot/src/games/grouping.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/player_stats.dart';
import 'package:dartpilot/src/stats/precision.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

const t20 = PrecisionTarget(Ring.triple, 20);
const t20d = PrecisionTarget(Ring.double, 20);

/// A tapped dart [dx] mm right and [dy] mm up of the middle of T20
DartThrow nearT20(double dx, double dy, {ThrowInput input = ThrowInput.board, double? confidence}) {
  final c = t20.centre();
  return DartThrow(BoardPoint(c.xMm + dx, c.yMm + dy), input, confidence: confidence);
}

/// Taps the drawn board where [point] is; the board is measured each time, as its size follows the panel.
Future<void> tapBoard(WidgetTester tester, BoardPoint point) async {
  final board = tester.getRect(find.byKey(const ValueKey('dartboard')));
  final scale = board.shortestSide / (2 * (const BoardGeometry().doubleOuterRadiusMm + 30));
  await tester.tapAt(board.center + Offset(point.xMm * scale, -point.yMm * scale));
  await tester.pumpAndSettle();
}

Future<void> openTraining(WidgetTester tester, String title) async {
  await tester.dragUntilVisible(find.text('Präzisionstraining'), find.byType(ListView).first, const Offset(0, -200));
  await tester.tap(find.text('Präzisionstraining'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Future<Statistics> startApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna']));
  await statistics.load();
  await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
  await playOffline(tester);
  return statistics;
}

void main() {
  group('Spread', () {
    test('offset is the mean minus the target, spread the RMS distance from the mean', () {
      final target = const BoardPoint(0, 0);
      // A square of side 4 around (6, -4): every point 2√2 mm from the mean
      final points = [
        const BoardPoint(4, -6),
        const BoardPoint(8, -6),
        const BoardPoint(4, -2),
        const BoardPoint(8, -2),
      ];
      final s = Spread.of(points, target)!;
      expect(s.count, 4);
      expect(s.offsetXMm, closeTo(6, 1e-9));
      expect(s.offsetYMm, closeTo(-4, 1e-9));
      expect(s.offsetMm, closeTo(math.sqrt(52), 1e-9));
      // Sample variance 16/3 on each axis
      expect(s.spreadMm, closeTo(math.sqrt(32 / 3), 1e-9));
      expect(s.ellipse.majorMm, closeTo(math.sqrt(16 / 3), 1e-9));
      expect(s.ellipse.minorMm, closeTo(math.sqrt(16 / 3), 1e-9));
    });

    test('the ellipse lies along a diagonal group', () {
      final points = [for (var i = -3; i <= 3; ++i) BoardPoint(i.toDouble(), i.toDouble())];
      final e = Spread.of(points, const BoardPoint(0, 0))!.ellipse;
      expect(e.angleDeg, closeTo(45, 1e-9));
      expect(e.minorMm, closeTo(0, 1e-9));
      expect(e.majorMm, greaterThan(0));
    });

    test('a single dart has no spread', () {
      expect(Spread.of([const BoardPoint(1, 1)], const BoardPoint(0, 0)), isNull);
    });
  });

  test('only darts with a measured point count', () {
    expect(hasMeasuredPoint(nearT20(0, 0)), isTrue);
    expect(hasMeasuredPoint(nearT20(0, 0, input: ThrowInput.keypad)), isFalse);
    expect(hasMeasuredPoint(nearT20(0, 0, input: ThrowInput.engine, confidence: 0.9)), isTrue);
    expect(hasMeasuredPoint(nearT20(0, 0, input: ThrowInput.engine, confidence: 0.3)), isFalse);
    // A correction carries no confidence: its point is the player's, not a measurement.
    expect(hasMeasuredPoint(nearT20(0, 0, input: ThrowInput.engine)), isFalse);
  });

  test('targets have labels that parse back, and their centre is the middle of the field', () {
    for (final target in [...trainingTargets, ...allDoubles, PrecisionTarget.outerBull, PrecisionTarget.parse('S5')!]) {
      expect(PrecisionTarget.parse(target.label), target);
      if (target == PrecisionTarget.outerBull) continue;
      final s = score(target.centre().xMm, target.centre().yMm);
      expect(s.ring, target.ring);
      expect(target.isHit(s), isTrue);
    }
    expect(PrecisionTarget.parse('50'), PrecisionTarget.bull);
    expect(PrecisionTarget.outerBull.centre(), const BoardPoint(0, 0));
    expect(PrecisionTarget.outerBull.isHit(score(0, 10)), isTrue);
    expect(PrecisionTarget.parse('S5')!.isHit(score(0, 50)), isFalse);
    expect(PrecisionTarget.parse('X5'), isNull);
    expect(PrecisionTarget.parse('T21'), isNull);
    expect(PrecisionTarget.parse(''), isNull);
  });

  test('precision per target, week by week, without unmeasured darts', () {
    final monday = DateTime(2026, 10, 19, 20);
    final nextWeek = DateTime(2026, 10, 27, 20);
    final darts = <AimedDart>[
      (target: t20, dart: nearT20(-2, 0), thrown: monday),
      (target: t20, dart: nearT20(2, 0), thrown: monday),
      (target: t20, dart: nearT20(0, 30, input: ThrowInput.keypad), thrown: monday),
      (target: t20, dart: nearT20(-1, 0), thrown: nextWeek),
      (target: t20, dart: nearT20(1, 0), thrown: nextWeek),
      (target: PrecisionTarget.bull, dart: DartThrow(const BoardPoint(1, 1), ThrowInput.board), thrown: monday),
    ];
    final result = computePrecision(darts);
    expect(result.map((p) => p.target.label), ['T20', 'BULL']);
    final p = result.first;
    expect(p.points, hasLength(4));
    expect(p.hits, 4);
    expect(p.weeks.map((w) => w.week), [DateTime(2026, 10, 19), DateTime(2026, 10, 26)]);
    expect(p.weeks.first.spread.spreadMm, greaterThan(p.weeks.last.spread.spreadMm));
    expect(result.last.spread, isNull);
  });

  test('a grouping game ends after its darts and is kept with its target', () {
    final game = GroupingGame(t20, dartCount: 3);
    game.add(nearT20(-6, -4));
    game.add(nearT20(-6, -4, input: ThrowInput.keypad));
    game.add(nearT20(-4, -6, input: ThrowInput.engine, confidence: 0.95));
    expect(game.isFinished, isTrue);
    game.add(nearT20(0, 0));
    expect(game.throws, hasLength(3));
    expect(game.measured, hasLength(2));
    expect(game.miss(game.throws.first).distanceMm, closeTo(math.sqrt(52), 1e-9));
    expect(game.spread!.offsetXMm, closeTo(-5, 1e-9));

    final record = GameRecord(
      id: 'g',
      mode: GameMode.grouping,
      started: DateTime(2026, 10, 26),
      ended: DateTime(2026, 10, 26),
      players: ['Anna'],
      settings: {'target': 'T20', 'darts': 3},
      throws: game.throws,
    );
    final back = GameRecord.fromJson(record.toJson())!;
    expect(back.groupingTarget, t20);
    expect(back.throws.last.confidence, 0.95);
    final precision = computePlayerPrecision([back], 'Anna').single;
    expect(precision.points, hasLength(2));
    final stats = computePlayerStats([back], 'Anna');
    expect(stats.history.single.spreadMm, closeTo(game.spread!.spreadMm, 1e-9));
  });

  test('doubles practice: one visit per double, ranked by hit rate, then spread', () {
    final d16 = const PrecisionTarget(Ring.double, 16), d8 = const PrecisionTarget(Ring.double, 8);
    final game = DoublesGame([t20d, d16, d8]);
    DartThrow at(PrecisionTarget t, double dx) =>
        DartThrow(BoardPoint(t.centre().xMm + dx, t.centre().yMm), ThrowInput.board);
    // D20: one hit; D16: one hit in a tighter group; D8: three hits
    for (final dx in [-30.0, 0.0, 30.0]) {
      game.add(at(t20d, dx));
    }
    expect(game.current, d16);
    for (final dx in [-12.0, 0.0, 12.0]) {
      game.add(at(d16, dx));
    }
    for (final dx in [-1.0, 0.0, 1.0]) {
      game.add(at(d8, dx));
    }
    expect(game.isFinished, isTrue);
    expect(game.hits, 5);
    expect(game.dartsAt(d16), hasLength(3));
    final record = GameRecord(
      id: 'd',
      mode: GameMode.doubles,
      started: DateTime(2026, 10, 26),
      ended: DateTime(2026, 10, 26),
      players: ['Anna'],
      settings: {
        'targets': ['D20', 'D16', 'D8'],
        'darts_per_target': 3,
      },
      throws: game.throws,
    );
    final back = GameRecord.fromJson(record.toJson())!;
    final ranking = doublesRanking(computePlayerPrecision([back], 'Anna'));
    expect(ranking.map((p) => p.target.label), ['D8', 'D16', 'D20']);
    expect(computePlayerStats([back], 'Anna').history.single.hitRate, closeTo(5 / 9, 1e-9));
  });

  test('checkout starts come from the seed and can all be finished with three darts', () {
    expect(checkoutStarts(7, 20, CheckoutRange.high), checkoutStarts(7, 20, CheckoutRange.high));
    for (final n in checkoutStarts(3, 200, CheckoutRange.high)) {
      expect(n, inInclusiveRange(101, 170));
      expect([159, 162, 163, 165, 166, 168, 169], isNot(contains(n)));
    }
  });

  test('checkout trainer names the field before every dart and measures the miss against it', () {
    DartThrow field(String label, {double dx = 0}) {
      final c = PrecisionTarget.parse(label)!.centre();
      return DartThrow(BoardPoint(c.xMm + dx, c.yMm), ThrowInput.board);
    }

    final game = CheckoutTrainer([40, 81], dartsPerAttempt: 3);
    expect(game.aim, 'D20');
    // 40: a miss into S20, then D10 to finish
    game.add(field('S20', dx: 1));
    expect(game.aim, 'D10');
    game.add(field('D10'));
    expect(game.attempts.first.checkedOut, isTrue);
    expect(game.current.start, 81);
    expect(game.aim, 'T19');
    // 81: three darts that do not finish
    game.add(field('S19'));
    game.add(field('S20'));
    game.add(field('S1'));
    expect(game.isFinished, isTrue);
    expect(game.checkouts, 1);
    expect(game.checkoutRate, 0.5);
    expect([for (var i = 0; i < 5; ++i) game.targetOf(i)?.label], ['D20', 'D10', 'T19', 'T10', 'S10']);

    final record = GameRecord(
      id: 'c',
      mode: GameMode.checkout,
      started: DateTime(2026, 10, 26),
      ended: DateTime(2026, 10, 26),
      players: ['Anna'],
      settings: {
        'starts': [40, 81],
        'darts': 3,
      },
      throws: game.throws,
    );
    final precision = computePlayerPrecision([GameRecord.fromJson(record.toJson())!], 'Anna');
    expect(precision.map((p) => p.target.label).toSet(), {'D20', 'D10', 'T19', 'T10', 'S10'});
    expect(computePlayerStats([record], 'Anna').history.single.checkoutRate, 0.5);
  });

  testWidgets('a grouping round on the board shows every miss and ends with the spread on the player page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await openTraining(tester, 'Gruppieren');
    await tester.tap(find.byKey(const ValueKey('target-T20')));
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('grouping-target')), findsOneWidget);

    final c = t20.centre();
    // Nine darts in a group left of and below the middle of T20; the board shrinks once the darts are listed above it.
    for (var i = 0; i < 9; ++i) {
      final board = tester.getRect(find.byKey(const ValueKey('dartboard')));
      final scale = board.shortestSide / (2 * (const BoardGeometry().doubleOuterRadiusMm + 30));
      final dx = -6.0 + (i % 3 - 1) * 2, dy = -2.0 + (i ~/ 3 - 1) * 2;
      await tester.tapAt(board.center + Offset((c.xMm + dx) * scale, -(c.yMm + dy) * scale));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('grouping-dart-8')), findsOneWidget);
    expect(find.byKey(const ValueKey('grouping-result-spread')), findsOneWidget);
    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();

    final record = statistics.games.single;
    expect(record.mode, GameMode.grouping);
    expect(record.groupingTarget, t20);
    expect(record.throws, hasLength(9));
    final spread = computePlayerPrecision(statistics.games, 'Anna').single.spread!;
    expect(spread.offsetXMm, closeTo(-6, 1));
    expect(spread.offsetYMm, closeTo(-2, 1));

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stats-player-Anna')));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('precision-offset-T20')),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.byKey(const ValueKey('precision-plot-T20')), findsOneWidget);
    expect(find.textContaining('6 mm links, 2 mm tief'), findsOneWidget);
  });

  testWidgets('doubles practice goes round the doubles and ranks them on its setup page afterwards', (tester) async {
    final statistics = await startApp(tester);
    await openTraining(tester, 'Doppel-Training');
    expect(find.byKey(const ValueKey('doubles-set-weakest')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 30; ++i) {
      final next = find.byKey(const ValueKey('doubles-next'));
      final shown = next.evaluate().isEmpty ? find.byKey(const ValueKey('doubles-target')) : next;
      final centre = PrecisionTarget.parse(tester.widget<Text>(shown).data!.split(' ').last)!.centre();
      // Every second dart a little high, still in the double
      await tapBoard(tester, BoardPoint(centre.xMm, centre.yMm + (i.isEven ? 0 : 2)));
    }
    expect(find.byKey(const ValueKey('doubles-result-rate')), findsOneWidget);
    expect(find.text('Trefferquote: 100\u00a0%'), findsOneWidget);
    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();
    expect(statistics.games.single.mode, GameMode.doubles);
    expect(doublesRanking(computePlayerPrecision(statistics.games, 'Anna')), hasLength(10));

    await openTraining(tester, 'Doppel-Training');
    expect(find.text('Deine Doppel, die besten zuerst'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('doubles-set-weakest')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('doubles-targets'))).data!.split('  '), hasLength(5));
  });

  testWidgets('the checkout trainer shows the field to aim at and counts the checkouts', (tester) async {
    final statistics = await startApp(tester);
    await openTraining(tester, 'Checkout-Trainer');
    await tester.tap(find.text('5'));
    await tester.tap(find.text('3'));
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    // Always hitting the field shown checks every finish out.
    for (var i = 0; i < 15 && find.byKey(const ValueKey('checkout-result')).evaluate().isEmpty; ++i) {
      final label = tester.widget<Text>(find.byKey(const ValueKey('checkout-aim'))).data!.split(' ').last;
      await tapBoard(tester, PrecisionTarget.parse(label)!.centre());
    }
    expect(find.text('Checkout-Quote: 5 / 5'), findsOneWidget);
    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();
    final record = statistics.games.single;
    expect(record.mode, GameMode.checkout);
    expect(computePlayerStats([record], 'Anna').history.single.checkoutRate, 1.0);
    expect(computePlayerPrecision([record], 'Anna'), isNotEmpty);
  });
}
