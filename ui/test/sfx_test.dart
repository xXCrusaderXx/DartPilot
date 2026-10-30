import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/dart_throw.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/games/x01.dart';
import 'package:dartpilot/src/screens/settings_screen.dart';
import 'package:dartpilot/src/sound/caller.dart';
import 'package:dartpilot/src/sound/effects.dart';
import 'package:dartpilot/src/sound/sfx.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

DartThrow at(Ring ring, [int sector = 20, ThrowInput input = ThrowInput.keypad]) =>
    DartThrow(fieldCentre(ring, sector: sector), input);

void main() {
  /// The effect after `dart`, thrown into `game`
  Effect effectAfter(X01Game game, DartThrow dart) {
    final visits = game.visits.length;
    final leg = game.legNumber;
    game.add(dart);
    return x01Effect(game, dart, visitsBefore: visits, legBefore: leg);
  }

  test('an X01 dart sounds as what it decided: a dart, a visit, a 180, a bust, a leg and the match', () {
    final game = X01Game(const X01Settings(players: ['Anna', 'Ben'], startScore: 501));
    expect(effectAfter(game, at(Ring.triple)), Effect.dart);
    expect(effectAfter(game, at(Ring.miss)), Effect.miss);
    expect(effectAfter(game, at(Ring.triple)), Effect.visitHigh);
    expect(effectAfter(game, at(Ring.outerSingle)), Effect.dart);
    expect(effectAfter(game, at(Ring.outerSingle)), Effect.dart);
    expect(effectAfter(game, at(Ring.outerSingle)), Effect.visit);
    for (final effect in [Effect.dart, Effect.dart, Effect.oneEighty]) {
      expect(effectAfter(game, at(Ring.triple)), effect);
    }

    final short = X01Game(const X01Settings(players: ['Anna'], startScore: 40, legsToWin: 2));
    expect(effectAfter(short, at(Ring.triple)), Effect.bust);
    expect(effectAfter(short, at(Ring.double)), Effect.leg);
    expect(effectAfter(short, at(Ring.double)), Effect.match);
  });

  test('other games sound the end of a visit and the win; a training ends like a leg', () {
    expect(gameEffect(at(Ring.triple), finished: false), Effect.dart);
    expect(gameEffect(at(Ring.miss), finished: false), Effect.miss);
    expect(gameEffect(at(Ring.triple), finished: false, visitEnded: true), Effect.visit);
    expect(gameEffect(at(Ring.triple), finished: true, visitEnded: true), Effect.match);
    expect(gameEffect(at(Ring.double), finished: true, training: true), Effect.leg);
  });

  /// `dartFeedback` in an app with `sfx` and `caller`
  Future<BuildContext> host(WidgetTester tester, Sfx sfx, Caller caller) async {
    late BuildContext context;
    await tester.pumpWidget(
      CallerScope(
        caller: caller,
        child: SfxScope(
          sfx: sfx,
          child: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return context;
  }

  testWidgets('the caller has priority: what it says is not also played, and it speaks after the effect', (
    tester,
  ) async {
    final effects = RecordingEffects(canVibrate: true);
    final voice = RecordingVoice();
    final caller = Caller(voice, store: false)..enabled = true;
    final context = await host(tester, Sfx(effects, store: false), caller);

    dartFeedback(context, at(Ring.triple), effect: Effect.oneEighty, calls: const ['One hundred and eighty!']);
    expect(effects.effects, [Effect.dart]);
    expect(voice.spoken, isEmpty);
    await tester.pump(callerDelay);
    expect(voice.spoken, ['One hundred and eighty!']);

    // A bust is its own sound, with the caller after it
    dartFeedback(context, at(Ring.triple), effect: Effect.bust, calls: const ['No score']);
    expect(effects.effects.last, Effect.bust);
    expect(effects.felt.last, Haptic.medium);
    await tester.pump(callerDelay);
    expect(voice.spoken.last, 'No score');

    // With the caller off, the 180 is the effect's
    caller.enabled = false;
    dartFeedback(context, at(Ring.triple), effect: Effect.oneEighty, calls: const ['One hundred and eighty!']);
    expect(effects.effects.last, Effect.oneEighty);
    expect(voice.spoken, hasLength(2));
  });

  testWidgets('a bot is heard quieter and not felt; engine darts are not felt; effects off speak at once', (
    tester,
  ) async {
    final effects = RecordingEffects(canVibrate: true);
    final voice = RecordingVoice();
    final sfx = Sfx(effects, store: false);
    final context = await host(tester, sfx, Caller(voice, store: false)..enabled = true);

    dartFeedback(context, at(Ring.triple), effect: Effect.dart, bot: true);
    expect(effects.played.single, (Effect.dart, sfx.volume * Sfx.botGain));
    expect(effects.felt, isEmpty);
    dartFeedback(context, at(Ring.triple, 20, ThrowInput.engine), effect: Effect.dart);
    expect(effects.felt, isEmpty);
    dartFeedback(context, at(Ring.triple), effect: Effect.dart);
    expect(effects.felt, [Haptic.light]);

    await sfx.set(enabled: false, vibration: false);
    dartFeedback(context, at(Ring.triple), effect: Effect.visit, calls: const ['60']);
    expect(effects.played, hasLength(3));
    expect(effects.felt, hasLength(1));
    expect(voice.spoken, ['60']);
  });

  testWidgets('a game plays a thud per dart and the visit at its end, and vibrates for darts entered by hand', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final effects = RecordingEffects(canVibrate: true);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna']));
    await statistics.load();
    await tester.pumpWidget(
      DartPilotApp(locale: const Locale('de'), statistics: statistics, sfx: Sfx(effects, store: false)),
    );
    await playOffline(tester);
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    await tester.tap(find.text('301'));
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keypad-miss')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; ++i) {
      await tester.tap(find.byKey(const ValueKey('keypad-20')));
      await tester.pumpAndSettle();
    }
    expect(effects.effects, [Effect.miss, Effect.dart, Effect.visit]);
    expect(effects.felt, [Haptic.light, Haptic.light, Haptic.light]);
  });

  testWidgets('the sound page switches effects and vibration and plays a sample visit', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final effects = RecordingEffects(canVibrate: true);
    final sfx = Sfx(effects, store: false);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), sfx: sfx));
    await playOffline(tester);
    await openSettingsPage(tester, 'sound');
    expect(find.text('Soundeffekte'), findsOneWidget);
    expect(find.byKey(const ValueKey('sfx-volume')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sound-sample')));
    await tester.pump(SoundSettingsScreen.sampleDartTime * 3);
    expect(effects.effects, [Effect.dart, Effect.dart, Effect.oneEighty]);

    await tester.tap(find.byKey(const ValueKey('sfx-vibration')));
    await tester.pumpAndSettle();
    expect(sfx.vibration, isFalse);
    await tester.tap(find.byKey(const ValueKey('sfx-enabled')));
    await tester.pumpAndSettle();
    expect(sfx.enabled, isFalse);
    expect(find.byKey(const ValueKey('sfx-volume')), findsNothing);
  });

  testWidgets('a desktop has no vibration to switch', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), sfx: Sfx(RecordingEffects(), store: false)));
    await playOffline(tester);
    await openSettingsPage(tester, 'sound');
    expect(find.byKey(const ValueKey('sfx-enabled')), findsOneWidget);
    expect(find.byKey(const ValueKey('sfx-vibration')), findsNothing);
  });
}
