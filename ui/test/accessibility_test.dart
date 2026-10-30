import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

void main() {
  testWidgets('an X01 game meets the tap target and label guidelines, and the board reads its darts', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna']));
    await statistics.load();
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), statistics: statistics));
    await playOffline(tester);
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna']);
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    // A tap on the board straight above the bull, in the single 20
    final board = tester.getRect(find.byKey(const ValueKey('dartboard')));
    await tester.tapAt(Offset(board.center.dx, board.center.dy - board.height * 0.235));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(const ValueKey('dartboard'))),
      matchesSemantics(
        label: 'Dartscheibe',
        value: '20',
        hint: 'Tippe dorthin, wo der Dart steckt',
        hasTapAction: true,
      ),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });
}
