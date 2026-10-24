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

/// Picks the players of a game setup in this order, creating profiles that do not exist yet
Future<void> pickPlayers(WidgetTester tester, List<String> names) async {
  for (final name in names) {
    final existing = find.byKey(ValueKey('pick-$name'));
    if (existing.evaluate().isEmpty) {
      await tester.tap(find.byKey(const ValueKey('pick-new-profile')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('new-profile-name')), name);
      await tester.tap(find.byKey(const ValueKey('new-profile-save')));
    } else {
      await tester.tap(existing);
    }
    await tester.pumpAndSettle();
  }
}
