import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/stats/dart_links.dart';
import 'package:dartpilot/src/stats/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';
import 'preview_test.dart' show hello;

Map<String, dynamic> dartSets({String? active, bool withSet = true}) => {
  'type': 'dart_sets',
  'sets': [
    if (withSet)
      {
        'id': 'set-1',
        'name': 'Annas Darts',
        'dims': {'barrel_mm': 50.5, 'barrel_diameter_mm': 7.1, 'total_mm': 151.0, 'flight_mm': 38.0},
        'images': [
          {'camera': 'usb-1'},
          {'camera': 'usb-2'},
        ],
      },
  ],
  'active': active,
};

void main() {
  late List<Map<String, dynamic>> sent;
  late EngineConnection engine;
  late MemoryDartLinksStore linkStore;

  Future<void> start(WidgetTester tester, {Map<String, dynamic>? sets}) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    sent = [];
    engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    linkStore = MemoryDartLinksStore();
    final statistics = Statistics(MemoryGameStore(), MemoryProfileStore(['Anna', 'Ben']));
    await statistics.load();
    await tester.pumpWidget(
      DartPilotApp(locale: const Locale('de'), engine: engine, statistics: statistics, dartLinks: DartLinks(linkStore)),
    );
    engine.receiveForTest(jsonEncode(hello));
    if (sets != null) engine.receiveForTest(jsonEncode(sets));
    await tester.pumpAndSettle();
  }

  Future<void> openMyDarts(WidgetTester tester) async {
    await openSettings(tester);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('open-my-darts')), 200);
    await tester.tap(find.byKey(const ValueKey('open-my-darts')));
    await tester.pumpAndSettle();
  }

  testWidgets('an engine without dart sets says so, and offers no measuring', (tester) async {
    await start(tester);
    await openMyDarts(tester);
    expect(find.byKey(const ValueKey('dart-sets-unavailable')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-dart-set')), findsNothing);
  });

  testWidgets('a set shows its dimensions and reference images, is linked to players and deleted', (tester) async {
    await start(tester, sets: dartSets());
    await openMyDarts(tester);
    expect(find.text('Annas Darts'), findsOneWidget);
    expect(find.textContaining('Gesamt 151.0 mm'), findsOneWidget);
    // The point length is not measured yet and not shown.
    expect(tester.widget<Text>(find.textContaining('Gesamt 151.0 mm')).data, isNot(contains('Spitze')));
    expect(sent.where((r) => r['type'] == 'get_dart_set_image').map((r) => r['camera']).toSet(), {'usb-1', 'usb-2'});

    await tester.tap(find.byKey(const ValueKey('link-set-1-Anna')));
    await tester.pumpAndSettle();
    expect(linkStore.links, {'anna': 'set-1'});

    await tester.tap(find.byKey(const ValueKey('dart-set-menu-set-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-dart-set-set-1')));
    await tester.pumpAndSettle();
    expect(sent.last, {'type': 'delete_dart_set', 'id': 'set-1'});
  });

  testWidgets('a new set is measured step by step', (tester) async {
    await start(tester, sets: dartSets(withSet: false));
    await openMyDarts(tester);
    await tester.tap(find.byKey(const ValueKey('add-dart-set')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('dart-set-name')), 'Bens Darts');
    await tester.tap(find.byKey(const ValueKey('dart-set-name-ok')));
    await tester.pumpAndSettle();
    expect(sent.last, {'type': 'start_dart_set', 'name': 'Bens Darts'});
    String step() => tester.widget<Text>(find.byKey(const ValueKey('dart-set-step'))).data!;
    expect(step(), startsWith('Steck einen Dart'));

    engine.receiveForTest(jsonEncode({'type': 'dart_set_capture', 'state': 'measuring', 'placed': 0, 'needed': 4}));
    await tester.pump();
    expect(step(), 'Wird vermessen …');
    engine.receiveForTest(
      jsonEncode({
        'type': 'dart_set_capture',
        'state': 'placed',
        'placed': 1,
        'needed': 4,
        'camera_states': [
          {'camera': 'usb-1', 'state': 'seen'},
          {'camera': 'usb-2', 'state': 'cut'},
        ],
      }),
    );
    await tester.pump();
    expect(find.text('Kamera 2: Dart am Rand abgeschnitten'), findsOneWidget);
    expect(step(), startsWith('Gemessen.'));
    expect(find.text('1 von 4 Stellen'), findsOneWidget);
    engine.receiveForTest(jsonEncode({'type': 'dart_set_capture', 'state': 'done', 'placed': 4, 'needed': 4}));
    await tester.pump();
    expect(step(), startsWith('Fertig'));
    await tester.tap(find.byKey(const ValueKey('dart-set-close')));
    await tester.pumpAndSettle();
    // A finished measurement is not cancelled on leaving.
    expect(sent.where((r) => r['type'] == 'cancel_dart_set'), isEmpty);
  });

  testWidgets('during a game the engine detects with the darts of the player at the board', (tester) async {
    await start(tester, sets: dartSets());
    await linkStore.save({'anna': 'set-1'});
    await DartLinks(linkStore).load();
    // The app's links come from the scope; link through it as the player would.
    final links = tester.element(find.byType(Scaffold).first);
    await DartLinksScope.of(links).link('Anna', 'set-1');
    await tester.tap(find.text('X01'));
    await tester.pumpAndSettle();
    await pickPlayers(tester, ['Anna', 'Ben']);
    await tester.tap(find.text('301'));
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    expect(sent.where((r) => r['type'] == 'set_active_darts').last, {'type': 'set_active_darts', 'id': 'set-1'});

    for (var i = 1; i <= 3; ++i) {
      engine.receiveForTest(
        jsonEncode({
          'type': 'throw',
          'throw_id': 's/$i',
          'accepted': true,
          'board_point': {'x_mm': 0, 'y_mm': 103},
          'confidence': 0.9,
        }),
      );
      await tester.pumpAndSettle();
    }
    // Ben has no set: generic detection.
    expect(sent.where((r) => r['type'] == 'set_active_darts').last, {'type': 'set_active_darts', 'id': null});
  });
}
