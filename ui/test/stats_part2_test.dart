import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/stats/export.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/player_stats.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_screen_test.dart' show at;

GameRecord x01(DateTime ended, List<DartThrow> throws, {List<String> players = const ['Anna']}) => GameRecord(
  id: 'g-${ended.millisecondsSinceEpoch}',
  mode: GameMode.x01,
  started: ended,
  ended: ended,
  players: players,
  settings: {'start_score': 301, 'double_out': true},
  throws: throws,
);

void main() {
  final day = DateTime.utc(2026, 10, 20, 18);

  test('hits are counted per ring and sector, so inner and outer singles stay apart', () {
    final stats = computePlayerStats([
      x01(day, [
        at(Ring.innerSingle),
        at(Ring.outerSingle),
        at(Ring.outerSingle),
        at(Ring.triple, 19),
        at(Ring.innerBull),
      ]),
    ], 'Anna');
    expect(stats.hits[(Ring.innerSingle, 20)], 1);
    expect(stats.hits[(Ring.outerSingle, 20)], 2);
    expect(stats.hits[(Ring.triple, 19)], 1);
    expect(stats.hits[(Ring.innerBull, 0)], 1);
    // The field labels still count both singles together.
    expect(stats.fields['S20'], 3);
  });

  test('the CSV has one line per dart with its player, and the JSON the figures per player', () {
    final games = [
      x01(day, [at(Ring.triple), at(Ring.outerSingle), at(Ring.miss), at(Ring.double, 16)], players: ['Anna', 'Ben']),
    ];
    final lines = const LineSplitter().convert(dartsCsv(games));
    expect(lines.first, 'game_id,mode,ended_utc,player,dart,label,ring,sector,points,x_mm,y_mm,input,throw_id');
    expect(lines, hasLength(5));
    expect(lines[1], startsWith('${games.first.id},x01,2026-10-20T18:00:00.000Z,Anna,1,T20,triple,20,60,'));
    // The fourth dart starts Ben's visit.
    expect(lines[4], contains(',Ben,1,D16,double,16,32,'));

    final json = jsonDecode(gamesJson(games, ['Anna', 'Ben'], now: day)) as Map<String, dynamic>;
    expect(json['exported_utc'], '2026-10-20T18:00:00.000Z');
    expect((json['games'] as List).single['id'], games.first.id);
    final anna = (json['players'] as Map)['Anna'] as Map;
    expect(anna['darts'], 3);
    expect(anna['three_dart_average'], 80.0);
  });

  testWidgets('the player page shows the average over games and the hit board', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final statistics = Statistics(
      MemoryGameStore([
        x01(now.subtract(const Duration(days: 2)), [at(Ring.outerSingle), at(Ring.outerSingle), at(Ring.outerSingle)]),
        x01(now.subtract(const Duration(days: 1)), [at(Ring.triple), at(Ring.triple), at(Ring.triple)]),
      ]),
      MemoryProfileStore(['Anna']),
    );
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-offline')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stats-export')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stats-player-Anna')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('average-trend')), findsOneWidget);
    expect(find.byKey(const ValueKey('hit-heatmap')), findsOneWidget);
  });
}
