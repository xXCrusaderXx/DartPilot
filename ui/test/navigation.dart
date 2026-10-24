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
