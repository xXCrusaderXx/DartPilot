import 'dart:convert';
import 'dart:io';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/stats/backup.dart';
import 'package:dartpilot/src/stats/export.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/player_stats.dart';
import 'package:dartpilot/src/stats/precision.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:dartpilot/src/stats/training_best.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

DartThrow key(String label) => DartThrow(PrecisionTarget.parse(label)!.centre(), ThrowInput.keypad);
DartThrow board(String label) => DartThrow(PrecisionTarget.parse(label)!.centre(), ThrowInput.board);
final miss = DartThrow(const BoardPoint(0, 200), ThrowInput.keypad);

GameRecord game(
  String id,
  GameMode mode,
  List<String> players,
  List<DartThrow> throws, {
  Map<String, Object?> settings = const {},
  int day = 1,
}) => GameRecord(
  id: id,
  mode: mode,
  started: DateTime(2026, 10, day),
  ended: DateTime(2026, 10, day, 20),
  players: players,
  settings: settings,
  throws: throws,
);

/// 101 double out: T20 S1 D20 checks out in one visit.
List<DartThrow> get leg101 => [key('T20'), key('S1'), key('D20')];

void main() {
  group('data hygiene', () {
    test('a game the player threw no dart in is not theirs', () {
      // Ben threw one visit of a rematch, then the players left.
      final rematch = game('r', GameMode.x01, ['Ben', 'Anna'], [key('T20'), key('T20'), key('T20')]);
      final stats = computePlayerStats([rematch], 'Anna');
      expect(stats.games, 0);
      expect(stats.history, isEmpty);
    });

    test('an unfinished game is no match and no win and stays out of the trend, but its darts count', () {
      final won = game('w', GameMode.x01, ['Anna', 'Ben'], [...leg101], settings: {'start_score': 101}, day: 1);
      final left = game('l', GameMode.x01, ['Anna', 'Ben'], [key('S20'), key('S20'), key('S20')], day: 2);
      final stats = computePlayerStats([won, left], 'Anna');
      expect(stats.games, 2);
      expect(stats.matches, 1);
      expect(stats.gamesWon, 1);
      expect(stats.darts, 6);
      expect(stats.history.first.finished, isFalse);
      expect(stats.history.last.finished, isTrue);
    });
  });

  test('keypad darts count for the hit rate per double, only measured ones for the spread', () {
    final precision = computePrecision([
      for (final d in [key('D16'), miss, key('D16'), board('D16')])
        (target: const PrecisionTarget(Ring.double, 16), dart: d, thrown: DateTime(2026, 10, 1)),
    ]);
    expect(precision.single.darts, 4);
    expect(precision.single.hits, 3);
    expect(precision.single.hitRate, 0.75);
    expect(precision.single.points, hasLength(1));
    expect(doublesRanking(precision, minDarts: 4), hasLength(1));
  });

  test('training progress follows each track over the rounds, with its best', () {
    GameRecord doubles(String id, int day, int hits) => game(
      id,
      GameMode.doubles,
      ['Anna'],
      [for (var i = 0; i < 3; ++i) i < hits ? key('D20') : miss],
      settings: {
        'targets': ['D20'],
        'darts_per_target': 3,
      },
      day: day,
    );
    GameRecord ladder(String id, int day) => game(
      id,
      GameMode.checkout,
      ['Anna'],
      // 121: T20 T11 D14 checks out, then 122 is missed with nine darts.
      [key('T20'), key('T11'), key('D14'), for (var i = 0; i < 9; ++i) miss],
      settings: {
        'starts': [121, 121],
        'darts': 9,
        'ladder': true,
      },
      day: day,
    );
    final progress = computeTrainingProgress([
      doubles('d2', 2, 2),
      doubles('d1', 1, 1),
      doubles('d3', 3, 3),
      ladder('l1', 4),
      // Not finished: no figure to follow
      game(
        'd4',
        GameMode.doubles,
        ['Anna'],
        [key('D20')],
        settings: {
          'targets': ['D20'],
        },
        day: 5,
      ),
    ], 'Anna');
    expect(progress, hasLength(2));
    final d = progress.first;
    expect(d.track.mode, GameMode.doubles);
    expect([for (final r in d.rounds) r.value], [1 / 3, 2 / 3, 1.0]);
    expect(d.best, 1.0);
    expect(d.lastIsBest, isTrue);
    expect(progress.last.track.isLadder, isTrue);
    expect(progress.last.last, 121);
  });

  test('the history names a 121 ladder round as such, with its highest checkout', () {
    final round = game(
      'l',
      GameMode.checkout,
      ['Anna'],
      [key('T20'), key('T11'), key('D14')],
      settings: {
        'starts': [121],
        'darts': 9,
        'ladder': true,
      },
    );
    final played = computePlayerStats([round], 'Anna').history.single;
    expect(played.ladderBest, 121);
    expect(played.checkoutRate, isNull);
  });

  group('player data care', () {
    test('a renamed profile takes its games and colour along', () async {
      final store = MemoryGameStore([
        game('a', GameMode.x01, ['Ana', 'Ben'], leg101, settings: {'start_score': 101}),
      ]);
      final profiles = MemoryProfileStore(['Ana', 'Ben'])..colours = {'ana': 0xff00ff00};
      final statistics = Statistics(store, profiles);
      await statistics.load();
      expect(await statistics.renameProfile('Ana', 'ben'), ProfileError.exists);
      expect(await statistics.renameProfile('Ana', ' '), ProfileError.empty);
      expect(await statistics.renameProfile('Ana', 'Anna'), isNull);
      expect(statistics.profiles, ['Anna', 'Ben']);
      expect(store.records.single.players, ['Anna', 'Ben']);
      expect(profiles.colours, {'anna': 0xff00ff00});
      expect(statistics.statsOf('Anna').gamesWon, 1);
      // Only the case changes: the same player
      expect(await statistics.renameProfile('Anna', 'ANNA'), isNull);
      expect(statistics.profiles.first, 'ANNA');
    });

    test('one game can be deleted; the file keeps lines this version cannot read', () async {
      final dir = await Directory.systemTemp.createTemp('dartpilot-care');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/games.jsonl');
      final store = FileGameStore(file);
      await store.add(game('a', GameMode.x01, ['Anna'], leg101));
      await file.writeAsString('{"mode":"future_mode","id":"later"}\n', mode: FileMode.append);
      await store.add(game('b', GameMode.x01, ['Anna'], leg101));
      final statistics = Statistics(store);
      await statistics.load();
      await statistics.removeGame('a');
      expect([for (final g in statistics.games) g.id], ['b']);
      expect([for (final g in await FileGameStore(file).load()) g.id], ['b']);
      expect(await file.readAsString(), contains('future_mode'));
    });

    test('a backup adds only what is new and refuses a file that is no backup', () async {
      final mine = game('a', GameMode.x01, ['Anna'], leg101);
      final theirs = game('b', GameMode.x01, ['Ben'], leg101);
      final text = gamesJson([mine, theirs], ['Anna', 'Ben', 'Cleo'], colours: {'ben': 0xff112233});
      final backup = Backup.parse(text);
      expect(backup.games, hasLength(2));

      final statistics = Statistics(MemoryGameStore([mine]), MemoryProfileStore(['Anna']));
      await statistics.load();
      final added = await statistics.importBackup(backup);
      expect(added, (games: 1, profiles: 2));
      expect([for (final g in statistics.games) g.id], ['a', 'b']);
      expect(statistics.profiles, ['Anna', 'Ben', 'Cleo']);
      expect(statistics.hasOwnColour('Ben'), isTrue);
      // Read again, nothing is doubled.
      expect(await statistics.importBackup(backup), (games: 0, profiles: 0));

      expect(() => Backup.parse('not json'), throwsFormatException);
      expect(() => Backup.parse(jsonEncode({'hello': 1})), throwsFormatException);
      expect(
        () => Backup.parse(
          jsonEncode({
            'games': [
              {'mode': 'future_mode'},
            ],
          }),
        ),
        throwsFormatException,
      );
    });
  });

  test('the figures of a period are kept between rebuilds and the cache stays bounded', () async {
    final statistics = Statistics(
      MemoryGameStore([
        game('a', GameMode.x01, ['Anna'], leg101),
      ]),
    );
    await statistics.load();
    final since = DateTime(2026, 9, 1);
    expect(identical(statistics.statsOf('Anna', since: since), statistics.statsOf('Anna', since: since)), isTrue);
    final first = statistics.statsOf('Anna', since: DateTime(2000));
    for (var day = 1; day <= 40; ++day) {
      statistics.statsOf('Anna', since: DateTime(2001, 1, day));
    }
    expect(identical(statistics.statsOf('Anna', since: DateTime(2000)), first), isFalse);
  });

  testWidgets('the player page has a training section, and a game is deleted from its throws page', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = MemoryGameStore([
      for (var day = 1; day <= 3; ++day)
        game(
          'd$day',
          GameMode.doubles,
          ['Anna'],
          [key('D20'), miss, if (day > 1) key('D20') else miss],
          settings: {
            'targets': ['D20'],
          },
          day: day,
        ),
      game('x', GameMode.x01, ['Anna', 'Ben'], leg101, settings: {'start_score': 101}, day: 4),
    ]);
    final statistics = Statistics(store, MemoryProfileStore(['Anna', 'Ben']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stats-player-Anna')));
    await tester.pumpAndSettle();

    expect(find.text('Training'), findsOneWidget);
    expect(find.text('Doppelquote'), findsOneWidget);
    expect(find.text('67 %'), findsOneWidget);
    expect(find.textContaining('Bestwert 67\u00a0%  ·  3 Runden'), findsOneWidget);
    // One match, won: games and legs are one figure each, darts say where they were thrown.
    String figure(String label) => tester.widget<Text>(find.byKey(ValueKey('figure-$label'))).data!;
    expect(figure('Spiele'), '1 (1 gewonnen)');
    expect(figure('Legs'), '1 (1 gewonnen)');
    expect(figure('Darts in Spielen'), '3');
    expect(find.byKey(const ValueKey('figure-Matches')), findsNothing);
    expect(find.byKey(const ValueKey('figure-180')), findsNothing);
    expect(find.textContaining('gegen Ben'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('history-x')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-game')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-game-confirm')));
    await tester.pumpAndSettle();
    expect(store.records.map((g) => g.id), isNot(contains('x')));
    expect(find.byKey(const ValueKey('history-x')), findsNothing);
    expect(find.text('Spiel gelöscht'), findsOneWidget);
  });

  testWidgets('a profile is renamed from its menu', (tester) async {
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Ana']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-menu-Ana')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-rename-Ana')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('rename-profile-name')), 'Anna');
    await tester.tap(find.byKey(const ValueKey('rename-profile-save')));
    await tester.pumpAndSettle();
    expect(statistics.profiles, ['Anna']);
    expect(find.byKey(const ValueKey('stats-player-Anna')), findsOneWidget);
  });
}
