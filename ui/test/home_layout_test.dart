import 'package:dartpilot/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

void main() {
  for (final (window, size, columns) in [
    ('a phone', const Size(412, 915), 1),
    ('a tablet upright', const Size(800, 1280), 2),
    ('a monitor', const Size(1920, 1080), 3),
  ]) {
    testWidgets('home lists the games in $columns column(s) on $window', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const DartPilotApp(locale: Locale('en')));
      await playOffline(tester);

      double top(String mode) => tester.getTopLeft(find.byKey(ValueKey('mode-$mode'))).dy;
      const games = ['X01', 'Cricket', 'Around the Clock'];
      // The first row holds as many games as there are columns; the next game starts a row below it.
      for (var i = 1; i < columns; ++i) {
        expect(top(games[i]), top(games[0]));
      }
      expect(top(games[columns.clamp(1, 2)]), columns == 3 ? top(games[0]) : greaterThan(top(games[0])));
      expect(tester.takeException(), isNull);
    });
  }
}
