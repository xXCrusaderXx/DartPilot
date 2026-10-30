import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/screens/x01_panel.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:dartpilot/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'navigation.dart';

void main() {
  test('every player colour keeps 3:1 on the surfaces of every palette', () {
    for (final palette in [
      AppPalette.dark,
      AppPalette.light,
      AppPalette.highContrastDark,
      AppPalette.highContrastLight,
    ]) {
      for (final colour in playerColours) {
        for (final ground in palette.grounds) {
          expect(contrastRatio(colour, ground), greaterThanOrEqualTo(3), reason: '$colour on $ground');
        }
      }
    }
  });

  test('profiles get colours by their order until a player chooses one; guests have none', () async {
    final profiles = MemoryProfileStore(['Anna', 'Ben']);
    final statistics = Statistics(MemoryGameStore(), profiles);
    await statistics.load();
    expect(statistics.colourOf('Anna'), playerColours[0]);
    expect(statistics.colourOf('ben'), playerColours[1]);
    expect(statistics.colourOf('Gast 1'), isNull);
    expect(statistics.hasOwnColour('Anna'), isFalse);

    await statistics.setColour('anna', playerColours[5]);
    expect(statistics.colourOf('Anna'), playerColours[5]);

    final again = Statistics(MemoryGameStore(), profiles);
    await again.load();
    expect(again.colourOf('Anna'), playerColours[5]);
    expect(again.hasOwnColour('Anna'), isTrue);

    await again.setColour('Anna', null);
    expect(again.colourOf('Anna'), playerColours[0]);

    await again.setColour('Ben', playerColours[3]);
    await again.removeProfile('Ben');
    expect(profiles.colours, isEmpty);
  });

  test('the device keeps the colours, whatever the name', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PrefsProfileStore();
    await store.saveColours({'anna': 0xFF2F7FE0, 'a=b': 0xFFD9480F});
    expect(await store.loadColours(), {'anna': 0xFF2F7FE0, 'a=b': 0xFFD9480F});
  });

  testWidgets('a player picks a colour in the statistics, and the game shows it', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna', 'Ben']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-offline')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bar_chart_outlined).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-menu-Ben')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-colour-Ben')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-colour-6')));
    await tester.pumpAndSettle();
    expect(statistics.colourOf('Ben'), playerColours[6]);
    final avatar = tester.widget<CircleAvatar>(
      find.descendant(of: find.byKey(const ValueKey('stats-player-Ben')), matching: find.byType(CircleAvatar)),
    );
    expect(avatar.backgroundColor, playerColours[6]);

    await tester.tap(find.byKey(const ValueKey('profile-menu-Ben')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-colour-Ben')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-colour-reset')));
    await tester.pumpAndSettle();
    expect(statistics.hasOwnColour('Ben'), isFalse);

    // In a game each profile's dot shows beside its name.
    await statistics.setColour('Ben', playerColours[6]);
    await tester.tap(find.byIcon(Icons.home_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna', 'Ben']);
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    final dots = tester.widgetList<PlayerDot>(
      find.descendant(of: find.byType(X01Panel), matching: find.byType(PlayerDot)),
    );
    expect([for (final d in dots) d.colour], [playerColours[0], playerColours[6]]);
  });
}
