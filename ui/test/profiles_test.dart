import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

GameRecord played(List<String> players, DateTime ended) => GameRecord(
  id: '$ended',
  mode: GameMode.cricket,
  started: ended,
  ended: ended,
  players: players,
  throws: [DartThrow(fieldCentre(Ring.triple), ThrowInput.keypad)],
);

void main() {
  test('profiles: unique names without case, players of old games become profiles, played ones first', () async {
    final profiles = MemoryProfileStore(['Carla']);
    final statistics = Statistics(
      MemoryGameStore([
        played(['Anna', 'Spieler 2'], DateTime(2026, 10, 1)),
        played(['Ben'], DateTime(2026, 10, 20)),
      ]),
      profiles,
    );
    await statistics.load();
    expect(statistics.profiles, ['Carla', 'Anna', 'Ben']);
    expect(profiles.profiles, ['Carla', 'Anna', 'Ben']);
    expect(statistics.players, ['Ben', 'Anna', 'Carla']);

    expect(await statistics.addProfile('  '), ProfileError.empty);
    expect(await statistics.addProfile('anna'), ProfileError.exists);
    expect(await statistics.addProfile(' Dora '), isNull);
    expect(statistics.players.last, 'Dora');

    await statistics.removeProfile('Ben');
    expect(statistics.players, ['Anna', 'Carla', 'Dora']);
    // Ben's game is still kept.
    expect(statistics.games, hasLength(2));
  });

  testWidgets('a game needs players: they are picked or created in the setup, in throwing order', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna', 'Ben']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();

    FilledButton start() => tester.widget<FilledButton>(find.byKey(const ValueKey('start-game')));
    expect(start().onPressed, isNull);
    expect(find.text('Tipp die Spieler in der Reihenfolge an, in der sie werfen.'), findsOneWidget);

    await pickPlayers(tester, ['Ben', 'Anna', 'Carla']);
    expect(find.text('Reihenfolge: Ben → Anna → Carla'), findsOneWidget);
    expect(statistics.profiles, ['Anna', 'Ben', 'Carla']);
    expect(start().onPressed, isNotNull);

    // Tapping a picked player takes them out again.
    await tester.tap(find.byKey(const ValueKey('pick-Anna')));
    await tester.pumpAndSettle();
    expect(find.text('Reihenfolge: Ben → Carla'), findsOneWidget);

    // A name that exists already is refused.
    await tester.tap(find.byKey(const ValueKey('pick-new-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('new-profile-name')), 'ben');
    await tester.tap(find.byKey(const ValueKey('new-profile-save')));
    await tester.pumpAndSettle();
    expect(find.text('Es gibt schon ein Profil mit diesem Namen.'), findsOneWidget);
  });

  testWidgets('home asks for a first profile; the players page creates and deletes profiles', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore());
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    expect(find.byKey(const ValueKey('first-profile')), findsOneWidget);

    // Created from home, the profile is confirmed and the card makes way for the games.
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('first-profile')), matching: find.byType(FilledButton)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('new-profile-name')), 'Marko');
    await tester.tap(find.byKey(const ValueKey('new-profile-save')));
    await tester.pumpAndSettle();
    expect(find.text('Marko ist angelegt – wähl ein Spiel'), findsOneWidget);
    expect(find.byKey(const ValueKey('first-profile')), findsNothing);
    await statistics.removeProfile('Marko');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('new-profile-name')), 'Anna');
    await tester.tap(find.byKey(const ValueKey('new-profile-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stats-player-Anna')), findsOneWidget);
    expect(find.text('Noch keine Spiele'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-menu-Anna')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stats-player-Anna')), findsNothing);
    expect(statistics.profiles, isEmpty);
  });
}
