import 'package:dartpilot/l10n/app_localizations.dart';
import 'package:dartpilot/src/stats/game_record.dart';
import 'package:dartpilot/src/widgets/winner_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a rematch the board check holds back leaves the result open', (tester) async {
    var ready = false;
    var checks = 0;
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
                onUndo: () {},
                newGame: (_) => const Text('new game'),
                rematch: (_) => const Text('rematch'),
                readyForRematch: () async {
                  ++checks;
                  return ready;
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
    expect(find.text('Anna gewinnt!'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('result-rematch')));
    await tester.pumpAndSettle();
    expect(checks, 1);
    expect(find.text('Anna gewinnt!'), findsOneWidget);
    expect(find.text('rematch'), findsNothing);

    ready = true;
    await tester.tap(find.byKey(const ValueKey('result-rematch')));
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(find.text('Anna gewinnt!'), findsNothing);
    expect(find.text('rematch'), findsOneWidget);
  });
}
