import 'dart:async';

import 'package:dartpilot/src/screens/game_scaffold.dart';

/// Runs before every test file: tests have no platform wake lock, so game screens keep the screen on through a keeper
/// that does nothing.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ScreenAwake.keepOn = (_) {};
  await testMain();
}
