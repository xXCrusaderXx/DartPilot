import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/display.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:dartpilot/src/theme.dart';
import 'package:dartpilot/src/widgets/player_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

void main() {
  test('automatic picks the scoreboard on phones and reads from afar on large screens', () {
    final display = DisplaySettings(store: false);
    expect(WindowClass.forWidth(412), WindowClass.compact);
    expect(WindowClass.forWidth(800), WindowClass.medium);
    expect(WindowClass.forWidth(1920), WindowClass.large);
    expect(display.styleFor(WindowClass.compact), DisplayStyle.scoreboard);
    expect(display.styleFor(WindowClass.large), DisplayStyle.clear);
    expect(display.farFor(WindowClass.medium), isFalse);
    expect(display.farFor(WindowClass.large), isTrue);

    display
      ..style = DisplayStyle.clear
      ..distance = ViewingDistance.far;
    expect(display.styleFor(WindowClass.compact), DisplayStyle.clear);
    expect(display.farFor(WindowClass.compact), isTrue);
  });

  Future<DisplaySettings> startX01(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna', 'Ben']));
    await statistics.load();
    final display = DisplaySettings(store: false);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics, display: display));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('play-offline'), skipOffstage: false));
    await tester.tap(find.byKey(const ValueKey('play-offline')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('X01', skipOffstage: false));
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna', 'Ben']);
    await tester.ensureVisible(find.byKey(const ValueKey('start-game'), skipOffstage: false));
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    return display;
  }

  Color? activeColour(WidgetTester tester) =>
      tester.widget<Container>(find.byKey(const ValueKey('active-player'))).color;

  testWidgets('a phone shows the scoreboard, a tablet the clear style, and the choice switches a running game', (
    tester,
  ) async {
    final display = await startX01(tester, const Size(412, 915));
    expect(activeColour(tester), AppColors.warning);

    await display.set(style: DisplayStyle.clear);
    await tester.pumpAndSettle();
    expect(activeColour(tester), isNull);
    expect(find.text('Ø 0,0'), findsWidgets);

    await display.set(distance: ViewingDistance.far);
    await tester.pumpAndSettle();
    // From afar only what is read from the oche: no averages
    expect(find.text('Ø 0,0'), findsNothing);
  });

  testWidgets('the display section in the settings changes the style', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final display = DisplaySettings(store: false);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), display: display));
    await playOffline(tester);
    await openSettingsPage(tester, 'display');
    await tester.ensureVisible(find.byKey(const ValueKey('display-style')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('display-style')), matching: find.text('Scoreboard')),
    );
    await tester.pumpAndSettle();
    expect(display.style, DisplayStyle.scoreboard);
    await tester.tap(find.text('Fern'));
    await tester.pumpAndSettle();
    expect(display.distance, ViewingDistance.far);
  });

  testWidgets('from afar the value of the player at the oche grows with the panel, and a long one still fits', (
    tester,
  ) async {
    Future<double> valueSize(double width, String value, ViewingDistance distance) async {
      final display = DisplaySettings(store: false)..distance = distance;
      await tester.pumpWidget(
        MaterialApp(
          home: DisplayScope(
            settings: display,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: PlayerRow(name: 'Anna', value: value, valueKey: const ValueKey('value'), active: true),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      return tester.getSize(find.byKey(const ValueKey('value'))).height;
    }

    final near = await valueSize(800, 'D20', ViewingDistance.near);
    final farNarrow = await valueSize(400, 'D20', ViewingDistance.far);
    final farWide = await valueSize(800, 'D20', ViewingDistance.far);
    expect(farNarrow, greaterThan(near));
    expect(farWide, greaterThan(farNarrow));
    // Killer's lives as hearts: shrunk into the row instead of overflowing it
    await valueSize(400, '♥♥♥♥♥♥♥♥♥♥', ViewingDistance.far);
  });
}
