import 'dart:convert';

import 'package:dartpilot/l10n/app_localizations.dart';
import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/board/scoring.dart';
import 'package:dartpilot/src/display.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/input/key_entry.dart';
import 'package:dartpilot/src/screens/x01_screen.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:dartpilot/src/widgets/winner_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_input_test.dart' show throwJson;
import 'input_robustness_test.dart' show correctionJson;
import 'navigation.dart';
import 'preview_test.dart' show hello;

/// X01 301 for Anna and Ben, best of three legs, darts by hand on the keypad
Future<void> startHandGame(WidgetTester tester, Size size, {DisplaySettings? display}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna', 'Ben']));
  await statistics.load();
  await tester.pumpWidget(
    DartPilotApp(locale: const Locale('de'), statistics: statistics, display: display ?? DisplaySettings(store: false)),
  );
  await playOffline(tester);
  await tester.scrollUntilVisible(find.byKey(const ValueKey('mode-X01')), 200);
  await tester.tap(find.byKey(const ValueKey('mode-X01')));
  await tester.pumpAndSettle();
  await pickPlayers(tester, ['Anna', 'Ben']);
  await tester.scrollUntilVisible(find.text('301'), 100, scrollable: find.byType(Scrollable).last);
  await tester.tap(find.text('301'));
  await tester.pump();
  await tester.ensureVisible(find.byTooltip('Ein Leg mehr'));
  await tester.tap(find.byTooltip('Ein Leg mehr'));
  await tester.pump();
  await tester.ensureVisible(find.byKey(const ValueKey('start-game')));
  await tester.tap(find.byKey(const ValueKey('start-game')));
  await tester.pumpAndSettle();
  if (find.byKey(const ValueKey('keypad-20')).evaluate().isEmpty) {
    await tester.tap(find.text('Tastenfeld'));
    await tester.pumpAndSettle();
  }
}

Future<void> keypad(WidgetTester tester, String key, {String modifier = ''}) async {
  if (modifier.isNotEmpty) {
    await tester.tap(find.byKey(ValueKey('keypad-modifier-$modifier')));
    await tester.pump();
  }
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pump();
}

/// Whether the whole of [finder] is on screen above Undo
void expectAboveUndo(WidgetTester tester, Finder finder) {
  final undo = tester.getRect(find.widgetWithText(OutlinedButton, 'Rückgängig'));
  final rect = tester.getRect(finder);
  expect(rect.bottom, lessThanOrEqualTo(undo.top), reason: '$finder at $rect, Undo at $undo');
  expect(rect.top, greaterThanOrEqualTo(0));
}

void main() {
  for (final (device, size) in [('a phone upright', Size(412, 915)), ('a phone on its side', Size(915, 412))]) {
    testWidgets('on $device the keypad keeps its place in a visit, and route and visit stay above Undo', (
      tester,
    ) async {
      await startHandGame(tester, size);
      Offset key20() => tester.getCenter(find.byKey(const ValueKey('keypad-20')));
      final before = key20();
      // A whole visit and the next one's first dart: the strip of last darts never moves the keys.
      for (var i = 0; i < 3; ++i) {
        await keypad(tester, 'keypad-20', modifier: 'triple');
        expect(key20(), before, reason: 'after dart ${i + 1}');
      }
      await tester.pump(X01Screen.holdTime);
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; ++i) {
        await keypad(tester, 'keypad-miss');
        expect(key20(), before);
      }
      await tester.pump(X01Screen.holdTime);
      await tester.pumpAndSettle();

      // Anna on 121 after one dart at 61: the route and the visit are in view, not under Undo.
      await keypad(tester, 'keypad-20', modifier: 'triple');
      await tester.pumpAndSettle();
      expect(key20(), before);
      // Whose visit ended stays readable beside the darts, however many of them the strip holds
      final strip = tester.getRect(find.byKey(const ValueKey('recent-strip')));
      final owner = tester.getRect(find.byKey(const ValueKey('recent-visit')));
      expect(owner.left, greaterThanOrEqualTo(strip.left));
      expect(owner.right, lessThanOrEqualTo(strip.right));
      expect(tester.widget<Text>(find.byKey(const ValueKey('recent-visit'))).data, 'Ben · 0');
      expect(tester.takeException(), isNull);
      expectAboveUndo(tester, find.byKey(const ValueKey('checkout')));
      expectAboveUndo(tester, find.byKey(const ValueKey('visit-total')));

      // The won leg is said in the leg line's place, and the visit stays in view.
      await keypad(tester, 'keypad-15', modifier: 'triple');
      await keypad(tester, 'keypad-8', modifier: 'double');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('leg-won')), findsOneWidget);
      expectAboveUndo(tester, find.byKey(const ValueKey('leg-won')));
      expectAboveUndo(tester, find.byKey(const ValueKey('visit-total')));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the remaining score is spoken with what it is, and a won leg shows its checkout, not 0', (tester) async {
    await startHandGame(tester, const Size(1400, 1000));
    expect(find.bySemanticsLabel('301 Rest'), findsWidgets);
    await keypad(tester, 'keypad-20', modifier: 'triple');
    await keypad(tester, 'keypad-20', modifier: 'triple');
    await keypad(tester, 'keypad-20', modifier: 'triple');
    await tester.pump(X01Screen.holdTime);
    for (var i = 0; i < 3; ++i) {
      await keypad(tester, 'keypad-miss');
    }
    await tester.pump(X01Screen.holdTime);
    await keypad(tester, 'keypad-20', modifier: 'triple');
    await keypad(tester, 'keypad-15', modifier: 'triple');
    await keypad(tester, 'keypad-8', modifier: 'double');
    // While the leg's last visit is on show
    expect(tester.widget<Text>(find.byKey(const ValueKey('remaining-Anna')).first).data, 'Checkout 121');
  });

  testWidgets('board or keypad is kept for the next game on this device', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final display = DisplaySettings();
    await display.load();
    expect(display.keypadInput, isFalse);
    await startHandGame(tester, const Size(1400, 1000), display: display);
    expect(display.keypadInput, isTrue);
    final again = DisplaySettings();
    await again.load();
    expect(again.keypadInput, isTrue);
    // A shared appearance leaves it to each device
    expect(
      utf8.decode(base64Url.decode(base64Url.normalize(again.toCode().split(':').last))),
      isNot(contains('keypad')),
    );

    await tester.pumpWidget(const SizedBox());
    await startHandGame(tester, const Size(1400, 1000), display: again);
    expect(find.byKey(const ValueKey('dartboard')), findsNothing);
    expect(find.byKey(const ValueKey('keypad-20')), findsOneWidget);
  });

  testWidgets('a single reads as the bare number in the visit and the last darts', (tester) async {
    await startHandGame(tester, const Size(1400, 1000));
    await keypad(tester, 'keypad-20');
    expect(tester.widget<Text>(find.byKey(const ValueKey('visit-dart-0'))).data, '20');
    expect(find.descendant(of: find.byKey(const ValueKey('recent-0')), matching: find.text('20')), findsOneWidget);
    // By hand only: no mark of where each dart came from
    expect(
      find.descendant(of: find.byKey(const ValueKey('recent-0')), matching: find.byIcon(Icons.touch_app)),
      findsNothing,
    );
  });

  testWidgets('the keypad modifiers tell a screen reader which one is chosen', (tester) async {
    await startHandGame(tester, const Size(1400, 1000));
    final handle = tester.ensureSemantics();
    await tester.tap(find.byKey(const ValueKey('keypad-modifier-triple')));
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(const ValueKey('keypad-modifier-triple'))),
      matchesSemantics(
        label: 'Triple',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  group('darts typed on a keyboard', () {
    TypedField? typeAll(KeyEntry entry, String text) {
      TypedField? last;
      for (final c in text.split('')) {
        last = entry.type(c) ?? last;
      }
      return last;
    }

    test('the number ends the dart as soon as it cannot go on', () {
      final entry = KeyEntry();
      expect(typeAll(entry, 't20'), (ring: Ring.triple, sector: 20));
      expect(entry.pending, '');
      expect(entry.type('5'), (ring: Ring.innerSingle, sector: 5));
      expect(typeAll(entry, 'd16'), (ring: Ring.double, sector: 16));
      expect(entry.type('1'), isNull);
      expect(entry.pending, '1');
      expect(entry.enter(), (ring: Ring.innerSingle, sector: 1));
      expect(typeAll(entry, '25'), (ring: Ring.outerBull, sector: 20));
      expect(typeAll(entry, 'd25'), (ring: Ring.innerBull, sector: 20));
      expect(entry.type('b'), (ring: Ring.innerBull, sector: 20));
      expect(entry.type('0'), (ring: Ring.miss, sector: 20));
      expect(entry.type('m'), (ring: Ring.miss, sector: 20));
      // A modifier after an open number ends that number first
      entry.type('2');
      expect(entry.type('t'), (ring: Ring.innerSingle, sector: 2));
      expect(entry.pending, 'T');
      expect(entry.clear(), isTrue);
      // No field 27 or T25
      expect(typeAll(entry, '27'), isNull);
      expect(typeAll(entry, 't25'), isNull);
    });

    testWidgets('on the game screen, with Backspace as undo', (tester) async {
      await startHandGame(tester, const Size(1400, 1000));
      String remaining() => tester.widget<Text>(find.byKey(const ValueKey('remaining-Anna'))).data!;
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      expect(find.text('T2…'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pumpAndSettle();
      expect(remaining(), '241');
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(remaining(), '240');
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(remaining(), '241');
    });
  });

  testWidgets('home does not give the all-clear while the engine is connected but not detecting', (tester) async {
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine, statistics: statistics));
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpAndSettle();
    expect(find.text('Kamera-Erkennung verbunden – erkennt noch keine Darts'), findsNothing);
    engine.receiveForTest(jsonEncode({'type': 'engine_status', 'detection': 'paused', 'message': ''}));
    await tester.pumpAndSettle();
    expect(find.text('Kamera-Erkennung verbunden – erkennt noch keine Darts'), findsOneWidget);
  });

  group('with cameras', () {
    /// X01 301 for Anna and Ben with a connected engine, at TV size unless [size] says otherwise; what the app sends
    /// lands in `sent`
    Future<EngineConnection> startEngineGame(
      WidgetTester tester,
      List<Map<String, dynamic>> sent, {
      Size size = const Size(1920, 1080),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final engine = EngineConnection.forTest(sent.add);
      addTearDown(engine.dispose);
      final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna', 'Ben']));
      await statistics.load();
      await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine, statistics: statistics));
      engine.receiveForTest(jsonEncode(hello));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('mode-X01')), 200);
      await tester.ensureVisible(find.byKey(const ValueKey('mode-X01')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mode-X01')));
      await tester.pumpAndSettle();
      await pickPlayers(tester, ['Anna', 'Ben']);
      await tester.scrollUntilVisible(find.text('301'), 100, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('301'));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('start-game')));
      await tester.tap(find.byKey(const ValueKey('start-game')));
      await tester.pumpAndSettle();
      return engine;
    }

    Future<void> receive(WidgetTester tester, EngineConnection engine, Object message) async {
      engine.receiveForTest(message is String ? message : jsonEncode(message));
      await tester.pumpAndSettle();
    }

    String remaining(WidgetTester tester, String player) =>
        tester.widget<Text>(find.byKey(ValueKey('remaining-$player'))).data!;

    testWidgets('a game says when the cameras do not count and offers the keypad', (tester) async {
      final engine = await startEngineGame(tester, []);
      expect(find.byKey(const ValueKey('engine-not-counting')), findsNothing);
      await receive(tester, engine, {'type': 'engine_status', 'detection': 'paused', 'message': ''});
      expect(find.text('Kameras zählen gerade nicht – trag die Darts von Hand ein'), findsOneWidget);
      // Read from the oche: as large as the panel's headings
      final title = tester.widget<Text>(find.text('Kameras zählen gerade nicht – trag die Darts von Hand ein'));
      expect(title.style!.fontSize, greaterThanOrEqualTo(24));
      await tester.tap(find.byKey(const ValueKey('health-keypad')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('keypad-20')), findsOneWidget);

      await receive(tester, engine, {'type': 'engine_status', 'detection': 'running', 'message': ''});
      expect(find.byKey(const ValueKey('engine-not-counting')), findsNothing);
      await receive(tester, engine, {'type': 'camera_status', 'camera': 'usb-1', 'state': 'lost'});
      expect(find.text('Eine Kamera liefert keine Bilder.'), findsOneWidget);
    });

    testWidgets('after a drop the game says so, corrections wait, and the return says darts may be missing', (
      tester,
    ) async {
      final sent = <Map<String, dynamic>>[];
      final engine = await startEngineGame(tester, sent);
      await receive(tester, engine, throwJson('s/1', 0, 103));
      engine
        ..state = EngineConnectionState.disconnected
        ..reconnecting = true
        ..notifyListeners();
      // The strip at the top turns while the app tries again: frames, not settling
      Future<void> settle() async {
        for (var i = 0; i < 5; ++i) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await settle();
      expect(find.byKey(const ValueKey('engine-dropped')), findsOneWidget);

      // A correction while away is kept, not lost
      await tester.tap(find.byKey(const ValueKey('recent-0')));
      await settle();
      await tester.tap(find.byKey(const ValueKey('health-keypad')));
      await settle();
      await tester.tap(find.byKey(const ValueKey('keypad-20')));
      await settle();
      expect(sent.where((m) => m['type'] == 'correct_throw'), isEmpty);

      await receive(tester, engine, hello);
      expect(sent.where((m) => m['type'] == 'correct_throw'), hasLength(1));
      expect(find.byKey(const ValueKey('engine-dropped')), findsNothing);
      expect(find.byKey(const ValueKey('engine-back')), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      await tester.pump();
      expect(find.byKey(const ValueKey('engine-back')), findsNothing);
    });

    testWidgets('a correction with the keypad goes back to the board, and the dart is framed meanwhile', (
      tester,
    ) async {
      final engine = await startEngineGame(tester, []);
      await receive(tester, engine, throwJson('s/1', 0, 103));
      await receive(tester, engine, throwJson('s/2', 0, 103));
      await tester.tap(find.byKey(const ValueKey('recent-1')));
      await tester.pumpAndSettle();
      expect(find.text('T20 korrigieren – tipp das richtige Feld an'), findsOneWidget);
      final cell = tester.widget<Container>(find.byKey(const ValueKey('visit-cell-1')));
      expect((cell.decoration! as BoxDecoration).border!.top.color, isNot(Colors.transparent));
      await tester.tap(find.text('Tastenfeld'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('keypad-20')));
      await tester.pumpAndSettle();
      expect(remaining(tester, 'Anna'), '221');
      expect(find.byKey(const ValueKey('dartboard')), findsOneWidget);
    });

    testWidgets('a correction on another device is said and its dart framed for a while', (tester) async {
      final engine = await startEngineGame(tester, []);
      await receive(tester, engine, throwJson('s/1', 0, 103));
      await receive(tester, engine, correctionJson('s/1', 'corrected', y: 57));
      expect(remaining(tester, 'Anna'), '281');
      expect(find.text('Auf einem anderen Gerät korrigiert: T20 → 20'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      await tester.pump();
      expect(find.byKey(const ValueKey('corrected-elsewhere')), findsNothing);
    });

    testWidgets('missing darts entered by hand hold the next player\'s darts until the visit is complete', (
      tester,
    ) async {
      final engine = await startEngineGame(tester, []);
      await receive(tester, engine, throwJson('s/1', 0, 103));
      await receive(tester, engine, {'type': 'takeout', 'event_ns': 1, 'darts_removed': 1});
      expect(find.text('2 Darts fehlen'), findsOneWidget);
      // A tap beside the question does not close it
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('2 Darts fehlen'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('missing-enter')));
      await tester.pumpAndSettle();
      expect(find.text('Noch 2 Darts von Hand eingeben'), findsOneWidget);

      // Ben's first dart arrives before Anna's are in: it waits.
      await receive(tester, engine, throwJson('s/2', 0, 103));
      expect(remaining(tester, 'Anna'), '241');
      expect(remaining(tester, 'Ben'), '301');
      await tester.tap(find.byKey(const ValueKey('missing-keypad')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('keypad-miss')));
      await tester.pumpAndSettle();
      expect(find.text('Noch 1 Dart von Hand eingeben'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('keypad-miss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('enter-missing')), findsNothing);
      // Now Ben's dart counts as his, with no takeout asked for Anna's visit
      expect(remaining(tester, 'Ben'), '241');
      expect(find.byKey(const ValueKey('remove-darts')), findsNothing);
    });

    testWidgets('a takeout of the next visit while missing darts are typed in follows its darts', (tester) async {
      final engine = await startEngineGame(tester, []);
      await receive(tester, engine, throwJson('s/1', 0, 103));
      await receive(tester, engine, {'type': 'takeout', 'event_ns': 1, 'darts_removed': 1});
      await tester.tap(find.byKey(const ValueKey('missing-enter')));
      await tester.pumpAndSettle();
      // Ben throws his whole visit and pulls it before Anna's darts are in
      for (final id in ['s/2', 's/3', 's/4']) {
        await receive(tester, engine, throwJson(id, 0, 103));
      }
      await receive(tester, engine, {'type': 'takeout', 'event_ns': 2, 'darts_removed': 3});
      expect(remaining(tester, 'Ben'), '301');
      await tester.tap(find.byKey(const ValueKey('missing-keypad')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('keypad-miss')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('keypad-miss')));
      await tester.pumpAndSettle();
      // Ben's visit counts, and its takeout already passed the turn on to Anna
      expect(remaining(tester, 'Ben'), '121');
      expect(find.byKey(const ValueKey('remove-darts')), findsNothing);
    });

    for (final (device, size) in [('a phone upright', Size(412, 915)), ('a phone on its side', Size(915, 412))]) {
      testWidgets('on $device the camera warning and the missing darts leave Undo and the visit in view', (
        tester,
      ) async {
        final engine = await startEngineGame(tester, [], size: size);
        await receive(tester, engine, throwJson('s/1', 0, 103));
        await receive(tester, engine, {'type': 'engine_status', 'detection': 'paused', 'message': ''});
        expect(find.byKey(const ValueKey('engine-not-counting')), findsOneWidget);
        void expectUndoWhole() {
          final undo = tester.getRect(find.widgetWithText(OutlinedButton, 'Rückgängig'));
          expect(undo.bottom, lessThanOrEqualTo(size.height), reason: 'Undo at $undo');
          expect(undo.height, greaterThanOrEqualTo(40));
        }

        expectUndoWhole();
        expectAboveUndo(tester, find.byKey(const ValueKey('visit-total')));
        await receive(tester, engine, {'type': 'takeout', 'event_ns': 1, 'darts_removed': 1});
        await tester.tap(find.byKey(const ValueKey('missing-enter')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('enter-missing')), findsOneWidget);
        expectUndoWhole();
        expectAboveUndo(tester, find.byKey(const ValueKey('visit-total')));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('an undo while missing darts are typed in keeps the next player\'s dart waiting for him', (
      tester,
    ) async {
      final sent = <Map<String, dynamic>>[];
      final engine = await startEngineGame(tester, sent);
      await receive(tester, engine, throwJson('s/1', 0, 103));
      await receive(tester, engine, {'type': 'takeout', 'event_ns': 1, 'darts_removed': 1});
      await tester.tap(find.byKey(const ValueKey('missing-enter')));
      await tester.pumpAndSettle();
      await receive(tester, engine, throwJson('s/2', 0, 103));

      // Anna takes her T20 back: her visit is still owed, and Ben's dart is not counted for her.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Rückgängig'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(remaining(tester, 'Anna'), '301');
      expect(remaining(tester, 'Ben'), '301');
      expect(find.text('Noch 3 Darts von Hand eingeben'), findsOneWidget);
      expect(sent.where((m) => m['type'] == 'reject_throw').map((m) => m['throw_id']), ['s/1']);

      await tester.tap(find.byKey(const ValueKey('missing-keypad')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; ++i) {
        await tester.tap(find.byKey(const ValueKey('keypad-miss')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('enter-missing')), findsNothing);
      expect(remaining(tester, 'Anna'), '301');
      expect(remaining(tester, 'Ben'), '241');
    });
  });

  testWidgets('the result focuses the rematch and keeps it whole on a phone on its side', (tester) async {
    tester.view.physicalSize = const Size(915, 412);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var rematch = false;
    final record = GameRecord(
      id: 'g',
      mode: GameMode.x01,
      started: DateTime(2026, 10, 30),
      ended: DateTime(2026, 10, 30),
      players: ['Anna', 'Ben'],
      throws: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showWinnerDialog(
                context,
                winner: 'Anna',
                record: record,
                result: 'Checkout 141',
                lines: const [
                  ResultLine('Anna', figures: 'Ø 80,0'),
                  ResultLine('Ben', figures: 'Ø 60,0'),
                ],
                onUndo: () {},
                newGame: (_) => const Text('new game'),
                rematch: (_) {
                  rematch = true;
                  return const Text('rematch');
                },
              ),
              child: const Text('end'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('end'));
    await tester.pumpAndSettle();
    final button = tester.getRect(find.byKey(const ValueKey('result-rematch')));
    expect(button.bottom, lessThanOrEqualTo(412));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(rematch, isTrue);
  });

  testWidgets('the app\'s larger text on the system\'s largest stops at twice the size', (tester) async {
    await startHandGame(
      tester,
      const Size(412, 915),
      display: DisplaySettings(store: false)..textSize = TextSize.larger,
    );
    // The system's largest text, set once the game is open
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(MediaQuery.textScalerOf(tester.element(find.byKey(const ValueKey('keypad-20')))).scale(1), 2.0);
    await keypad(tester, 'keypad-20', modifier: 'triple');
    await keypad(tester, 'keypad-20', modifier: 'triple');
    expect(tester.takeException(), isNull);
    // Every key still in reach after two darts
    for (final key in ['keypad-20', 'keypad-25', 'keypad-bull', 'keypad-miss']) {
      expect(tester.getRect(find.byKey(ValueKey(key))).bottom, lessThan(915), reason: key);
    }
    await keypad(tester, 'keypad-20', modifier: 'triple');
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('remaining-Anna'))).data, '121');
  });
}
