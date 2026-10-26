import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/games/around_the_clock.dart';
import 'package:dartpilot/src/games/cricket.dart';
import 'package:dartpilot/src/games/x01.dart';
import 'package:dartpilot/src/sound/caller.dart';
import 'package:dartpilot/src/sound/game_calls.dart';
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

  test('Cricket calls the marks of each visit, and the match', () {
    final game = CricketGame(['Anna', 'Ben']);
    game.add(at(Ring.triple));
    expect(cricketCalls(game), isEmpty);
    game.add(at(Ring.double, 19));
    game.add(at(Ring.outerSingle, 5));
    expect(cricketCalls(game), ['5 marks']);
    for (var i = 0; i < 3; ++i) {
      game.add(at(Ring.miss));
    }
    expect(cricketCalls(game), ['No score']);
    game.add(at(Ring.outerBull));
    game.add(at(Ring.miss));
    game.add(at(Ring.miss));
    expect(cricketCalls(game), ['One mark']);
  });

  test('Around the Clock calls who is next and at what', () {
    final game = AroundTheClockGame(['Anna', 'Ben']);
    game.add(at(Ring.outerSingle, 1));
    game.add(at(Ring.outerSingle, 2));
    expect(aroundTheClockCalls(game), isEmpty);
    game.add(at(Ring.miss));
    expect(aroundTheClockCalls(game), ['Ben, 1']);
    for (var i = 0; i < 3; ++i) {
      game.add(at(Ring.miss));
    }
    expect(aroundTheClockCalls(game), ['Anna, 3']);
  });

  test('a checkout route is read as a caller says it', () {
    expect(callRoute(['T20', 'T19', 'D12']), 'Treble 20, treble 19, double 12');
    expect(callRoute(['S10', '50']), '10, bull');
    expect(callRoute(['25', 'D20']), '25, double 20');
  });

  testWidgets('the checkout route is said on request, also with the caller off', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final voice = RecordingVoice();
    final caller = Caller(voice, store: false);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics, caller: caller));
    await playOffline(tester);
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    await tester.tap(find.text('301'));
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    // 301 - 180 = 121, a finish
    for (var i = 0; i < 3; ++i) {
      await tester.tap(find.text('Triple'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('keypad-20')));
      await tester.pumpAndSettle();
    }
    expect(caller.enabled, isFalse);
    expect(voice.spoken, isEmpty);
    await tester.tap(find.byKey(const ValueKey('call-checkout')));
    expect(voice.spoken.single, callRoute(suggestCheckout(121, 3)!));
  });
}
