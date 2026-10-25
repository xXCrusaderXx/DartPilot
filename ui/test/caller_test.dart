import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/games/x01.dart';
import 'package:dartpilot/src/sound/caller.dart';
import 'package:dartpilot/src/sound/x01_calls.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

DartThrow at(Ring ring, [int sector = 20]) => DartThrow(fieldCentre(ring, sector: sector), ThrowInput.keypad);

void main() {
  /// The calls after `dart`, thrown into `game`
  List<String> callsAfter(X01Game game, DartThrow dart) {
    final visits = game.visits.length;
    final leg = game.legNumber;
    game.add(dart);
    return x01Calls(game, visitsBefore: visits, legBefore: leg);
  }

  test('a visit is called when it ends, with 180, no score and bust by name', () {
    final game = X01Game(const X01Settings(players: ['Anna', 'Ben'], startScore: 301));
    expect(callsAfter(game, at(Ring.triple)), isEmpty);
    expect(callsAfter(game, at(Ring.triple)), isEmpty);
    expect(callsAfter(game, at(Ring.triple)), ['One hundred and eighty!']);
    for (var i = 0; i < 2; ++i) {
      callsAfter(game, at(Ring.miss));
    }
    // Anna has 121 left, a finish: her turn is called with it.
    expect(callsAfter(game, at(Ring.miss)), ['No score', 'Anna, you require 121']);
    callsAfter(game, at(Ring.outerSingle));
    callsAfter(game, at(Ring.outerSingle));
    // Ben's 301 is no finish, so only the score is called.
    expect(callsAfter(game, at(Ring.outerSingle)), ['60']);
  });

  test('bust, game shot and the match', () {
    final game = X01Game(const X01Settings(players: ['Anna'], startScore: 40, legsToWin: 2));
    expect(callsAfter(game, at(Ring.triple)), ['Bust', 'Anna, you require 40']);
    expect(callsAfter(game, at(Ring.double)), ['Game shot!']);
    expect(callsAfter(game, at(Ring.double)), ['Game shot, and the match!']);
  });

  testWidgets('a game calls each visit when the caller is on', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final voice = RecordingVoice();
    final caller = Caller(voice, store: false);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics, caller: caller));
    await playOffline(tester);

    // Switched on in the settings
    await openSettings(tester);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('caller-enabled')), 200);
    await tester.tap(find.byKey(const ValueKey('caller-enabled')));
    await tester.pumpAndSettle();
    expect(caller.enabled, isTrue);
    await tester.tap(find.byKey(const ValueKey('caller-test')));
    expect(voice.spoken.last, 'One hundred and eighty!');

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    await tester.tap(find.text('301'));
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; ++i) {
      await tester.tap(find.byKey(const ValueKey('keypad-20')));
      await tester.pumpAndSettle();
    }
    expect(voice.spoken.last, '60');
  });
}
