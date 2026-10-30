import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/display.dart';
import 'package:dartpilot/src/input/game_input.dart';
import 'package:dartpilot/src/screens/x01_panel.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'navigation.dart';

/// Starts a 301 between Anna and Ben on a window of [size] and switches to the keypad
Future<void> _startX01(WidgetTester tester, DisplaySettings display, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna', 'Ben']));
  await statistics.load();
  await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics, display: display));
  await playOffline(tester);
  await tester.tap(find.text('X01'));
  await tester.pumpAndSettle();
  await pickPlayers(tester, ['Anna', 'Ben']);
  // A phone on its side scrolls the setup.
  await tester.scrollUntilVisible(find.text('301'), 100, scrollable: find.byType(Scrollable).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('301'));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('start-game')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tastenfeld'));
  await tester.pumpAndSettle();
}

Future<void> _dart(WidgetTester tester, String modifier, String key) async {
  if (modifier.isNotEmpty) {
    await tester.tap(find.text(modifier));
    await tester.pump();
  }
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pump();
}

void main() {
  test('the game screen settings are kept per device and survive a preset', () async {
    SharedPreferences.setMockInitialValues({});
    final display = DisplaySettings();
    await display.set(boardSide: BoardSide.right, boardSize: BoardSize.small, celebration: Celebration.subtle);
    await display.showDetail(PanelDetail.checkout, false);
    await display.showDetail(PanelDetail.dartsThrown, true);
    await display.applyPreset(AppearancePreset.light);

    final loaded = DisplaySettings();
    await loaded.load();
    expect(loaded.boardSide, BoardSide.right);
    expect(loaded.boardSize, BoardSize.small);
    expect(loaded.celebration, Celebration.subtle);
    expect(loaded.panelDetails, {PanelDetail.visitDarts, PanelDetail.average, PanelDetail.dartsThrown});
  });

  test('a device without saved game screen settings gets the defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final loaded = DisplaySettings();
    await loaded.load();
    expect(loaded.boardSide, BoardSide.left);
    expect(loaded.boardSize, BoardSize.medium);
    expect(loaded.celebration, Celebration.full);
    expect(loaded.panelDetails, DisplaySettings.defaultPanelDetails);
  });

  for (final width in [915.0, 1600.0]) {
    testWidgets('the board takes the chosen side and size in a window ${width.round()} wide', (tester) async {
      final display = DisplaySettings(store: false);
      await _startX01(tester, display, Size(width, 700));
      Rect board() => tester.getRect(find.byType(GameInput));
      Rect panel() => tester.getRect(find.byType(X01Panel));

      expect(board().center.dx, lessThan(panel().center.dx));
      final medium = board().width;

      await display.set(boardSide: BoardSide.right);
      await tester.pumpAndSettle();
      expect(board().center.dx, greaterThan(panel().center.dx));

      await display.set(boardSize: BoardSize.small);
      await tester.pumpAndSettle();
      expect(board().width, lessThan(medium));
      expect(tester.takeException(), isNull);

      await display.set(boardSize: BoardSize.large);
      await tester.pumpAndSettle();
      expect(board().width, greaterThanOrEqualTo(medium));
      // The panel never gets narrower than it needs to stay readable.
      expect(panel().width, greaterThanOrEqualTo(340));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a phone upright gives the board more or less of the height', (tester) async {
    final display = DisplaySettings(store: false)..boardSize = BoardSize.small;
    await _startX01(tester, display, const Size(412, 915));
    final small = tester.getRect(find.byType(GameInput)).height;
    await display.set(boardSize: BoardSize.large);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(GameInput)).height, greaterThan(small));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the score panel shows only the details the player chose', (tester) async {
    final display = DisplaySettings(store: false);
    await _startX01(tester, display, const Size(1100, 800));
    await _dart(tester, 'Triple', 'keypad-20');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('visit-dart-0')), findsOneWidget);
    expect(find.textContaining('Ø'), findsWidgets);
    expect(find.text('1 Dart'), findsNothing);

    await display.showDetail(PanelDetail.visitDarts, false);
    await display.showDetail(PanelDetail.average, false);
    await display.showDetail(PanelDetail.dartsThrown, true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('visit-dart-0')), findsNothing);
    expect(find.textContaining('Ø'), findsNothing);
    expect(find.text('1 Dart'), findsOneWidget);
    expect(find.text('0 Darts'), findsOneWidget);

    // Anna leaves 121 and Ben scores nothing: at the start of her next visit Anna has a route.
    await _dart(tester, 'Triple', 'keypad-20');
    await _dart(tester, 'Triple', 'keypad-20');
    for (var i = 0; i < 3; ++i) {
      await _dart(tester, '', 'keypad-miss');
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('checkout')), findsOneWidget);
    await display.showDetail(PanelDetail.checkout, false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('checkout')), findsNothing);
  });

  for (final celebration in Celebration.values) {
    testWidgets('a 180 and a checkout are celebrated ${celebration.name}', (tester) async {
      final display = DisplaySettings(store: false)..celebration = celebration;
      await _startX01(tester, display, const Size(1100, 800));
      for (var i = 0; i < 3; ++i) {
        await _dart(tester, 'Triple', 'keypad-20');
      }
      await tester.pump(const Duration(milliseconds: 600));
      final banner = find.byKey(const ValueKey('celebration'));
      if (celebration == Celebration.off) {
        expect(banner, findsNothing);
      } else {
        expect(find.descendant(of: banner, matching: find.text('180')), findsOneWidget);
      }
      await tester.pumpAndSettle();
      expect(banner, findsNothing);

      for (var i = 0; i < 3; ++i) {
        await _dart(tester, '', 'keypad-miss');
      }
      await _dart(tester, 'Triple', 'keypad-20');
      await _dart(tester, 'Triple', 'keypad-15');
      await _dart(tester, 'Double', 'keypad-8');
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.descendant(of: banner, matching: find.text('Checkout 121')),
        celebration == Celebration.off ? findsNothing : findsOneWidget,
      );
      await tester.pumpAndSettle();
    });
  }

  testWidgets('with less motion in the system the banner shows without moving', (tester) async {
    final display = DisplaySettings(store: false);
    await _startX01(tester, display, const Size(1100, 800));
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    for (var i = 0; i < 3; ++i) {
      await _dart(tester, 'Triple', 'keypad-20');
    }
    await tester.pump(const Duration(milliseconds: 50));
    final banner = find.byKey(const ValueKey('celebration'));
    expect(banner, findsOneWidget);
    final opacity = tester.widget<Opacity>(find.ancestor(of: banner, matching: find.byType(Opacity)).first);
    expect(opacity.opacity, 1);
    expect(
      tester.widget<Transform>(find.ancestor(of: banner, matching: find.byType(Transform)).first).transform,
      Matrix4.identity(),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('the settings page changes the game screen layout', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final display = DisplaySettings(store: false);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), display: display));
    await playOffline(tester);
    await openSettingsPage(tester, 'display');

    Future<void> tapIn(String key, String text) async {
      await showSettingsEntry(tester, key);
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text)));
      await tester.pumpAndSettle();
    }

    await tapIn('board-side', 'Rechts');
    expect(display.boardSide, BoardSide.right);
    await tapIn('board-size', 'Groß');
    expect(display.boardSize, BoardSize.large);
    await tapIn('celebration', 'Dezent');
    expect(display.celebration, Celebration.subtle);
    await showSettingsEntry(tester, 'detail-dartsThrown');
    await tester.tap(find.byKey(const ValueKey('detail-dartsThrown')));
    await tester.pumpAndSettle();
    expect(display.shows(PanelDetail.dartsThrown), isTrue);

    // A preset leaves the layout alone.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('preset-light')),
      -200,
      scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preset-light')));
    await tester.pumpAndSettle();
    expect(display.boardSide, BoardSide.right);
    expect(display.boardSize, BoardSize.large);
  });

  testWidgets('a 180 shows on a dark plate, not in the yellow of the player at the oche, and over the score panel', (
    tester,
  ) async {
    final display = DisplaySettings(store: false)..style = DisplayStyle.scoreboard;
    await _startX01(tester, display, const Size(412, 915));
    for (var i = 0; i < 3; ++i) {
      await _dart(tester, 'Triple', 'keypad-20');
    }
    await tester.pump(const Duration(milliseconds: 600));
    final banner = find.byKey(const ValueKey('celebration'));
    final plate = tester.widget<Container>(banner).decoration! as BoxDecoration;
    final block = tester.widget<Container>(find.byKey(const ValueKey('active-player'))).color;
    expect(plate.color, isNot(block));
    // Never over the keypad the next dart goes in
    final keypad = tester.getRect(find.byKey(const ValueKey('keypad-20')));
    expect(tester.getRect(banner).top, greaterThan(keypad.bottom));
    await tester.pumpAndSettle();
  });

  testWidgets('a checkout under 100 gets the small banner even where celebrations are full', (tester) async {
    final display = DisplaySettings(store: false);
    await _startX01(tester, display, const Size(1100, 800));
    // 301 - 180 - 81 leaves 40 for Anna, Ben misses each time.
    for (final (modifier, key) in [('Triple', '20'), ('Triple', '20'), ('Triple', '20')]) {
      await _dart(tester, modifier, 'keypad-$key');
    }
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; ++i) {
      await _dart(tester, '', 'keypad-miss');
    }
    for (final (modifier, key) in [('Triple', '20'), ('Triple', '7'), ('', 'miss')]) {
      await _dart(tester, modifier, 'keypad-$key');
    }
    for (var i = 0; i < 3; ++i) {
      await _dart(tester, '', 'keypad-miss');
    }
    await _dart(tester, 'Double', 'keypad-20');
    await tester.pump(const Duration(milliseconds: 600));
    final banner = find.byKey(const ValueKey('celebration'));
    expect(find.descendant(of: banner, matching: find.text('Checkout 40')), findsOneWidget);
    final pill = tester.widget<Container>(banner).decoration! as BoxDecoration;
    expect(pill.borderRadius, BorderRadius.circular(999));
    await tester.pumpAndSettle();
  });

  testWidgets('on a phone on its side the other player and Undo are in view without scrolling', (tester) async {
    for (final style in [DisplayStyle.clear, DisplayStyle.scoreboard]) {
      final display = DisplaySettings(store: false)..style = style;
      await _startX01(tester, display, const Size(915, 412));
      await _dart(tester, 'Triple', 'keypad-20');
      await tester.pumpAndSettle();
      final screen = Offset.zero & const Size(915, 412);
      for (final finder in [
        find.byKey(const ValueKey('remaining-Ben')),
        find.byKey(const ValueKey('remaining-Anna')),
        find.byIcon(Icons.undo),
        find.byKey(const ValueKey('keypad-miss')),
      ]) {
        final rect = tester.getRect(finder);
        expect(screen.contains(rect.topLeft) && screen.contains(rect.bottomRight - const Offset(1, 1)), isTrue);
      }
      expect(tester.takeException(), isNull, reason: style.name);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('from afar on a TV the leg line and Undo grow', (tester) async {
    final display = DisplaySettings(store: false);
    await _startX01(tester, display, const Size(1920, 1080));
    expect(find.text('301 · Leg 1'), findsOneWidget);
    expect(
      tester.getSize(find.ancestor(of: find.byIcon(Icons.undo), matching: find.byType(OutlinedButton))).height,
      greaterThanOrEqualTo(64),
    );
  });

  testWidgets('the last darts show the visit that ended, whose it was and that it was bust, and keep it while the next '
      'one starts', (tester) async {
    await _startX01(tester, DisplaySettings(store: false), const Size(1100, 800));
    for (var i = 0; i < 3; ++i) {
      await _dart(tester, 'Triple', 'keypad-20');
    }
    for (var i = 0; i < 3; ++i) {
      await _dart(tester, '', 'keypad-miss');
    }
    // Anna on 121: T20 and S20 leave 41, then T20 is bust
    await _dart(tester, 'Triple', 'keypad-20');
    await _dart(tester, '', 'keypad-20');
    await tester.pumpAndSettle();
    expect(find.text('Ben · 0'), findsOneWidget);
    expect([for (var i = 2; i < 8; ++i) find.byKey(ValueKey('recent-$i')).evaluate().length], [0, 1, 1, 1, 1, 1]);
    expect(find.byKey(const ValueKey('recent-divider')), findsOneWidget);

    await _dart(tester, 'Triple', 'keypad-20');
    await tester.pumpAndSettle();
    expect(find.text('Anna · Überworfen'), findsOneWidget);
    expect([for (var i = 5; i < 9; ++i) find.byKey(ValueKey('recent-$i')).evaluate().length], [0, 1, 1, 1]);
    expect(find.byKey(const ValueKey('recent-divider')), findsNothing);

    // Ben's first dart is in, and Anna's last dart can still be corrected: it was a single 1, not a bust
    await _dart(tester, '', 'keypad-miss');
    await tester.pumpAndSettle();
    expect(find.text('Anna · Überworfen'), findsOneWidget);
    expect([for (var i = 5; i < 10; ++i) find.byKey(ValueKey('recent-$i')).evaluate().length], [0, 1, 1, 1, 1]);
    await tester.tap(find.byKey(const ValueKey('recent-8')));
    await tester.pumpAndSettle();
    await _dart(tester, '', 'keypad-1');
    await tester.pumpAndSettle();
    expect(find.text('Anna · 81'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('remaining-Anna'))).data, '40');
  });
}
