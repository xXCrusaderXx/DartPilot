import 'dart:convert';
import 'dart:io';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/engine_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';
import 'preview_test.dart' show hello;

/// A reference run as `dartpilot serve --simulate` plays it: the first target, a dart to pull, and the end
final Map<String, dynamic> fixtures =
    jsonDecode(File('test/fixtures/reference_run_simulator.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('parses the reference run', () {
    final done = EngineEvent.fromJson(fixtures['done'] as Map<String, dynamic>) as ReferenceRun;
    expect(done.step, 'done');
    expect(done.results, hasLength(10));
    expect(done.results.where((r) => r.locatedMm == null), hasLength(1));
    expect(done.summary!.located, 9);
    final remove = EngineEvent.fromJson(fixtures['remove'] as Map<String, dynamic>) as ReferenceRun;
    expect(remove.target!.wires, [20, 1]);
    expect(remove.target!.field, 'D20');
  });

  testWidgets('the reference run guides dart by dart and ends with a verdict', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('open-reference-run')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Zehn Darts dauern etwa fünf Minuten'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reference-start')));
    await tester.pump();
    expect(sent.last, {'type': 'start_reference_run'});

    engine.receiveForTest(jsonEncode(fixtures['first']));
    await tester.pump();
    expect(find.text('Dart 1 von 10'), findsOneWidget);
    expect(find.text('Steck einen Dart genau in die Mitte des Bulls und nimm die Hand weg.'), findsOneWidget);
    expect(find.byKey(const ValueKey('reference-zoom')), findsOneWidget);

    engine.receiveForTest(jsonEncode(fixtures['remove']));
    await tester.pump();
    expect(find.text('Zieh den Dart wieder heraus.'), findsOneWidget);
    expect(find.text('0,3 mm daneben'), findsOneWidget);

    engine.receiveForTest(jsonEncode(fixtures['done']));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reference-verdict')), findsOneWidget);
    expect(find.text('9 / 10'), findsOneWidget);
    expect(find.text('Nicht geortet'), findsOneWidget);
  });

  testWidgets('a corner target names its field and wires', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode(hello));
    final corner = Map<String, dynamic>.of(fixtures['remove'] as Map<String, dynamic>)..['step'] = 'insert_dart';
    engine.receiveForTest(jsonEncode(corner));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('open-reference-run')));
    await tester.pumpAndSettle();
    expect(
      find.text('Steck einen Dart in D20, in die Ecke am Draht zwischen 20 und 1, und nimm die Hand weg.'),
      findsOneWidget,
    );
    expect(find.text('Dart 2 von 10'), findsOneWidget);
  });
}
