import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// From the connection page to the games, without an engine
Future<void> playOffline(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('play-offline')));
  await tester.pumpAndSettle();
}

/// The settings page of the main view, in either language
Future<void> openSettings(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

/// Scrolls the settings to an entry, which the list builds only once it comes near the screen
Future<void> showSettingsEntry(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    200,
    scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last,
  );
  await tester.pumpAndSettle();
}

/// Picks the players of a game setup in this order, creating profiles that do not exist yet
Future<void> pickPlayers(WidgetTester tester, List<String> names) async {
  for (final name in names) {
    final existing = find.byKey(ValueKey('pick-$name'));
    if (existing.evaluate().isEmpty) {
      await tester.tap(find.byKey(const ValueKey('pick-new-profile')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('new-profile-name')), name);
      await tester.tap(find.byKey(const ValueKey('new-profile-save')));
    } else if (!_picked(tester, existing)) {
      // On a low screen the profiles may be below the rules
      await tester.ensureVisible(existing);
      await tester.pumpAndSettle();
      await tester.tap(existing);
    }
    await tester.pumpAndSettle();
  }
}

/// A page of the settings: 'display', 'sound' or 'cameras'
Future<void> openSettingsPage(WidgetTester tester, String page) async {
  await openSettings(tester);
  await tester.tap(find.byKey(ValueKey('settings-page-$page')));
  await tester.pumpAndSettle();
}

/// Opens the way with cameras in the network on the first page, where the search and the address field are
Future<void> openNetworkChoice(WidgetTester tester) async {
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('count-network')));
  await tester.pump();
}

/// Whether a player's chip is picked already, such as the only profile or one of the last line-up
bool _picked(WidgetTester tester, Finder chip) => switch (tester.widget(chip)) {
  final FilterChip c => c.selected,
  final ChoiceChip c => c.selected,
  _ => false,
};
