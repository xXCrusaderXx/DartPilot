import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/engine_events.dart';
import 'package:dartpilot/src/screens/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';
import 'preview_test.dart' show hello, previewMessage, tinyJpeg;

Map<String, dynamic> boardState(String state, {String reference = 'stored'}) => {
  'state': state,
  'cameras': [
    {
      'camera': 'usb-1',
      'state': state,
      'image_point_px': state == 'occupied' ? [640.0, 300.0] : null,
      'image_size_px': [1280, 720],
      'reason': state == 'occupied' ? 'object on the board' : '',
    },
    {
      'camera': 'usb-2',
      'state': 'empty',
      'image_point_px': null,
      'image_size_px': [1280, 720],
      'reason': '',
    },
  ],
  'reference': reference,
};

void main() {
  test('parses the board state from hello and its own message', () {
    final withBoard = EngineEvent.fromJson({...hello, 'board_state': boardState('occupied')}) as EngineHello;
    final camera = withBoard.boardState!.cameras.first;
    expect(withBoard.boardState!.occupied, isTrue);
    expect(camera.imagePointPx, const Offset(640, 300));
    expect(camera.imageSizePx, const Size(1280, 720));
    expect(withBoard.boardState!.referenceStored, isTrue);
    expect((EngineEvent.fromJson(hello) as EngineHello).boardState, isNull);

    final event = EngineEvent.fromJson({'type': 'board_state', ...boardState('empty', reference: 'missing')});
    expect((event as EngineBoardState).occupied, isFalse);
    expect(event.referenceStored, isFalse);
  });

  test('store_empty_reference completes with the error code of its result', () async {
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    final first = engine.storeEmptyReference();
    expect(sent.last['type'], 'store_empty_reference');
    engine.receiveForTest(
      jsonEncode({
        'type': 'result',
        'request_id': '1',
        'ok': false,
        'error': {'code': 'board_not_empty', 'message': ''},
      }),
    );
    expect(await first, 'board_not_empty');
    final second = engine.storeEmptyReference();
    engine.receiveForTest(jsonEncode({'type': 'result', 'request_id': '2', 'ok': true}));
    expect(await second, isNull);
  });

  testWidgets('warns before a game while darts are in the board and starts once it is empty', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode({...hello, 'board_state': boardState('occupied')}));

    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await tester.pumpAndSettle();
    expect(find.text('Darts in der Scheibe'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mode-Freies Werfen')));
    await tester.pumpAndSettle();
    expect(find.text('Darts aus der Scheibe ziehen'), findsOneWidget);
    // The engine's English reason is not shown in German; the marked image says where.
    expect(find.textContaining('object on the board'), findsNothing);
    expect(sent.any((r) => r['type'] == 'subscribe_preview' && r['camera'] == 'usb-1'), isTrue);
    engine.receiveForTest(previewMessage('usb-1', 1, tinyJpeg));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('board-preview-usb-1')), findsOneWidget);

    await tester.tap(find.text('Erneut prüfen'));
    expect(sent.last['type'], 'check_board');

    // The board becomes empty: the dialog closes and the game starts.
    engine.receiveForTest(jsonEncode({'type': 'board_state', ...boardState('empty')}));
    await tester.pumpAndSettle();
    expect(find.text('Darts aus der Scheibe ziehen'), findsNothing);
    expect(find.byType(TrainingScreen), findsOneWidget);
    expect(sent.last, {'type': 'unsubscribe_preview', 'camera': 'usb-1'});
  });

  testWidgets('a player who sees an empty board can store it again from the warning', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode({...hello, 'board_state': boardState('occupied')}));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mode-Freies Werfen')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Die Scheibe ist leer'));
    await tester.pumpAndSettle();
    expect(find.text('Leere Scheibe neu speichern?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Leere Scheibe speichern'));
    await tester.pump();
    expect(sent.last, {'type': 'store_empty_reference', 'force': true});

    // Every request so far had an id; the store request is the last one.
    engine.receiveForTest(jsonEncode({'type': 'result', 'request_id': '${sent.length}', 'ok': true}));
    engine.receiveForTest(jsonEncode({'type': 'board_state', ...boardState('empty')}));
    await tester.pumpAndSettle();
    expect(find.text('Leere Scheibe gespeichert'), findsOneWidget);
    expect(find.byType(TrainingScreen), findsOneWidget);
  });

  testWidgets('a board that becomes empty while the player is asked to store it stores nothing', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final engine = EngineConnection.forTest(sent.add);
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode({...hello, 'board_state': boardState('occupied')}));
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mode-Freies Werfen')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Die Scheibe ist leer'));
    await tester.pumpAndSettle();
    expect(find.text('Leere Scheibe neu speichern?'), findsOneWidget);

    engine.receiveForTest(jsonEncode({'type': 'board_state', ...boardState('empty')}));
    await tester.pumpAndSettle();
    expect(find.text('Leere Scheibe neu speichern?'), findsNothing);
    expect(find.text('Darts aus der Scheibe ziehen'), findsNothing);
    expect(find.byType(TrainingScreen), findsOneWidget);
    expect(sent.where((r) => r['type'] == 'store_empty_reference'), isEmpty);
  });

  testWidgets('a missing empty board is a step in the settings, which stores it', (tester) async {
    final engine = EngineConnection.forTest((_) {});
    addTearDown(engine.dispose);
    engine.receiveForTest(jsonEncode({...hello, 'board_state': boardState('unknown', reference: 'missing')}));

    await tester.pumpWidget(DartPilotApp(locale: const Locale('en'), engine: engine));
    await tester.pumpAndSettle();
    expect(find.text('No image of the empty board stored'), findsNothing);
    await openSettings(tester);
    expect(
      find.descendant(of: find.byKey(const ValueKey('settings-empty-board')), matching: find.text('To do')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('settings-empty-board')));
    engine.receiveForTest(jsonEncode({'type': 'result', 'request_id': '1', 'ok': true}));
    await tester.pumpAndSettle();
    expect(find.text('Empty board stored'), findsOneWidget);
  });
}
