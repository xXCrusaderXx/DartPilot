import 'dart:io';

import 'package:dartpilot/l10n/app_localizations_de.dart';
import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/games/checkout_trainer.dart';
import 'package:dartpilot/src/games/x01.dart';
import 'package:dartpilot/src/screens/game_throws_screen.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/player_stats.dart';
import 'package:dartpilot/src/stats/precision.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:dartpilot/src/stats/training_best.dart';
import 'package:dartpilot/src/widgets/precision_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

DartThrow field(String label, {double dxMm = 0}) {
  final c = PrecisionTarget.parse(label)!.centre();
  return DartThrow(BoardPoint(c.xMm + dxMm, c.yMm), ThrowInput.board);
}

GameRecord record(
  GameMode mode,
  List<DartThrow> throws,
  Map<String, Object?> settings, {
  String id = 'r',
  int day = 1,
}) => GameRecord(
  id: id,
  mode: mode,
  started: DateTime(2026, 10, day),
  ended: DateTime(2026, 10, day),
  players: ['Anna'],
  settings: settings,
  throws: throws,
);

void main() {
  group('checkout trainer busts', () {
    test('with three darts a bust ends the checkout, and what follows is the next one', () {
      final game = CheckoutTrainer([40, 32], dartsPerAttempt: 3);
      // T20 at 40 is a bust: the visit is over, so is the checkout.
      game.add(field('T20'));
      expect(game.attempts.first.checkedOut, isFalse);
      expect(game.attempts.first.busted, isTrue);
      expect(game.attemptsDone, 1);
      expect(game.current.start, 32);
      expect(game.aim, 'D16');
      // S20 and S1 belong to the 32; nothing counts as checked out.
      game.add(field('S20'));
      game.add(field('S1'));
      expect(game.checkouts, 0);
      expect(game.attempts[1].remaining, 11);
      expect(game.attempts[1].darts, hasLength(2));
    });

    test('with nine darts a bust uses up its visit: three visits in all, not a fourth', () {
      final game = CheckoutTrainer([40, 60], dartsPerAttempt: 9);
      game.add(field('T20'));
      // The bust ends the first visit after one dart; the next visit starts again at 40 with three darts.
      expect(game.dartsInVisit, 0);
      expect(game.current.start, 40);
      expect(game.current.visitsUsed, 1);
      expect(game.aim, 'D20');
      for (final label in ['S1', 'S1', 'S1', 'S1', 'S1', 'S1']) {
        game.add(field(label));
      }
      // 1 + 3 + 3 darts: three visits used, the checkout is over.
      expect(game.attempts.first.darts, hasLength(7));
      expect(game.attemptsDone, 1);
      expect(game.current.start, 60);
      expect(game.checkoutRate, 0);
    });

    test('a bust on the ladder steps down like any other miss', () {
      final game = CheckoutTrainer([125, 125], dartsPerAttempt: 3, ladder: true);
      game.add(field('T20'));
      game.add(field('T20'));
      game.add(field('T5'));
      expect(game.attempts.first.busted, isTrue);
      expect(game.current.start, 124);
    });
  });

  group('robust loading', () {
    test('a line with fields of the wrong type is skipped, the other games load', () async {
      final dir = await Directory.systemTemp.createTemp('dartpilot-robust');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/games.jsonl');
      final store = FileGameStore(file);
      await store.add(record(GameMode.x01, [field('T20')], {'start_score': 501}));
      await file.writeAsString('{"mode":"x01","id":1}\n', mode: FileMode.append);
      await store.add(record(GameMode.x01, [field('S20')], {'start_score': 501}, id: 'later'));
      final loaded = await FileGameStore(file).load();
      expect(loaded.map((g) => g.id), ['r', 'later']);
    });

    test('a profile made while the app starts keeps the stored profiles', () async {
      final profiles = MemoryProfileStore(['Anna', 'Ben']);
      final statistics = Statistics(MemoryGameStore(), profiles);
      final loading = statistics.load();
      final added = statistics.addProfile('Carl');
      await loading;
      expect(await added, isNull);
      expect(profiles.profiles, ['Anna', 'Ben', 'Carl']);
    });

    test('profiles that cannot be read are not saved over', () async {
      final profiles = _BrokenProfileStore();
      final statistics = Statistics(MemoryGameStore(), profiles);
      await statistics.load();
      expect(statistics.loaded, isTrue);
      await statistics.addProfile('Carl');
      expect(profiles.saved, isNull);
    });
  });

  test('trainings are neither won nor lost, solo games are not won, and training darts stay out of the board', () {
    final solo = record(GameMode.x01, [field('T20'), field('T20'), field('S1')], {'start_score': 501});
    final match = GameRecord(
      id: 'm',
      mode: GameMode.x01,
      started: DateTime(2026, 10, 2),
      ended: DateTime(2026, 10, 2),
      players: ['Anna', 'Ben'],
      settings: {'start_score': 101},
      throws: [field('T20'), field('S1'), field('D20')],
    );
    final grouping = record(GameMode.grouping, [field('T20'), field('T19')], {'target': 'T20', 'darts': 2});
    final stats = computePlayerStats([solo, match, grouping], 'Anna');
    expect(stats.games, 3);
    expect(stats.matches, 1);
    expect(stats.gamesWon, 1);
    expect(stats.trainings, 1);
    expect(stats.darts, 6);
    expect(stats.trainingDarts, 2);
    expect(stats.hits[(Ring.triple, 19)], isNull);
    expect(stats.history.where((g) => g.won).single.record.id, 'm');
    expect(stats.bestLegByStart, {101: 3});
    expect(stats.highestVisit, 121);
  });

  testWidgets('legs won are counted against the match legs, not the solo legs', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final solo = [
      for (var day = 1; day <= 2; ++day)
        record(GameMode.x01, [field('T20'), field('S1'), field('D20')], {'start_score': 101}, id: 's$day', day: day),
    ];
    final match = GameRecord(
      id: 'm',
      mode: GameMode.x01,
      started: DateTime(2026, 10, 3),
      ended: DateTime(2026, 10, 3),
      players: ['Anna', 'Ben'],
      settings: {'start_score': 101},
      throws: [field('T20'), field('S1'), field('D20')],
    );
    final stats = computePlayerStats([...solo, match], 'Anna');
    expect(stats.legs, 3);
    expect(stats.matchLegs, 1);
    expect(stats.legsWon, 1);
    final statistics = Statistics(MemoryGameStore([...solo, match]), MemoryProfileStore(['Anna', 'Ben']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stats-player-Anna')));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.text('Match-Legs'), find.byType(ListView).first, const Offset(0, -200));
    expect(find.text('Match-Legs'), findsOneWidget);
    expect(find.text('1 (1 gewonnen)'), findsWidgets);
    expect(find.text('3 (1 gewonnen)'), findsNothing);
  });

  test('a training round is compared with the earlier rounds of the same kind', () {
    grouping(int day, double dxMm) => record(
      GameMode.grouping,
      [field('T20'), field('T20', dxMm: dxMm), field('T20', dxMm: -dxMm)],
      {'target': 'T20', 'darts': 3},
      id: 'g$day',
      day: day,
    );
    final earlier = [grouping(1, 4), grouping(2, 8)];
    final bull = record(GameMode.grouping, [field('T19'), field('T19')], {'target': 'T19', 'darts': 2}, day: 3);
    final now = grouping(4, 2);
    final comparison = compareWithEarlier([...earlier, bull], now, 'Anna')!;
    expect(comparison.lowerIsBetter, isTrue);
    expect(comparison.last, trainingScore(earlier.last)!.value);
    expect(comparison.best, trainingScore(earlier.first)!.value);
    expect(comparison.isNewBest(trainingScore(now)!.value), isTrue);
    expect(compareWithEarlier([bull], now, 'Anna'), isNull);
  });

  test('the darts of a game are listed by visit, a bust ending its visit early', () {
    final game = record(
      GameMode.x01,
      [field('T20'), field('T20'), field('S1'), field('T20'), field('S1'), field('D20')],
      {'start_score': 161},
    );
    final visits = GameThrowsScreen(record: game).visits;
    // 161: T20 T20 S1 = 121 (40 left) | T20 bust | S1 D20 ... S1 leaves 39, D20 busts
    expect(visits.map((v) => v.darts.length), [3, 1, 2]);
    expect(visits.first.points, 121);
    expect(visits.first.left, 40);
    expect(visits[1].bust, isTrue);
    expect(visits[1].left, 40);
  });

  testWidgets('the 121 ladder is a training of its own and shows the level and the record', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // A round on the ladder with nine darts a checkout, the default, that checked out 121
    final earlier = record(
      GameMode.checkout,
      [for (final label in suggestCheckout(121, 3)!) field(label)],
      {
        'starts': [121],
        'darts': 9,
        'ladder': true,
      },
    );
    final statistics = Statistics(MemoryGameStore([earlier]), MemoryProfileStore(['Anna']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await tester.dragUntilVisible(find.text('Präzisionstraining'), find.byType(ListView).first, const Offset(0, -200));
    await tester.tap(find.text('Präzisionstraining'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('121-Leiter'));
    await tester.pumpAndSettle();
    expect(find.text('Versuche pro Runde'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    expect(find.text('121-Leiter'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('checkout-progress'))).data,
      'Stufe 121  ·  Versuch 1 von 10  ·  Rekord 121',
    );
  });

  testWidgets('a round played again is compared with the round just before it', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await tester.dragUntilVisible(find.text('Präzisionstraining'), find.byType(ListView).first, const Offset(0, -200));
    await tester.tap(find.text('Präzisionstraining'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gruppieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('target-T20')));
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();

    final c = PrecisionTarget.parse('T20')!.centre();
    Future<void> playRound(double stepMm) async {
      for (var i = 0; i < 9; ++i) {
        final board = tester.getRect(find.byKey(const ValueKey('dartboard')));
        final scale = board.shortestSide / (2 * (const BoardGeometry().doubleOuterRadiusMm + 30));
        final dx = (i % 3 - 1) * stepMm, dy = (i ~/ 3 - 1) * stepMm;
        await tester.tapAt(board.center + Offset((c.xMm + dx) * scale, -(c.yMm + dy) * scale));
        await tester.pumpAndSettle();
      }
    }

    // A tight first round, nothing to compare it with yet
    await playRound(1);
    expect(find.byKey(const ValueKey('grouping-result-spread')), findsOneWidget);
    expect(find.byKey(const ValueKey('training-last-best')), findsNothing);
    expect(find.byKey(const ValueKey('training-new-best')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('round-again')));
    await tester.pumpAndSettle();
    final first = statistics.games.single;

    // A wider second round: the first one is the last and the best so far.
    await playRound(3);
    final firstSpread = mmText(AppLocalizationsDe(), trainingScore(first)!.value);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('training-last-best'))).data,
      'Letztes Mal: $firstSpread  ·  Bestwert: $firstSpread',
    );
  });

  testWidgets('the players page without players offers to create one', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore());
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Neues Profil'), findsOneWidget);
  });
}

class _BrokenProfileStore extends MemoryProfileStore {
  List<String>? saved;

  @override
  Future<List<String>> load() async => throw const FormatException('broken');

  @override
  Future<void> save(List<String> profiles) async => saved = profiles;
}
