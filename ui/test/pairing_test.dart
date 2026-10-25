import 'dart:convert';

import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/engine/engine_connection.dart';
import 'package:dartpilot/src/engine/pairing_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'preview_test.dart' show hello;

Map<String, dynamic> helloWith(String pairing) => {
  ...hello,
  'engine': {'version': '0.3.0', 'id': 'engine-1'},
  'pairing': pairing,
  'pairing_pin_digits': 6,
};

void main() {
  test('a QR address carries the PIN, which is not part of the address', () {
    expect(splitPairingPin('ws://192.168.1.5:8484/?pin=123456'), ('ws://192.168.1.5:8484/', '123456'));
    expect(splitPairingPin('ws://192.168.1.5:8484/'), ('ws://192.168.1.5:8484/', null));
  });

  late List<Map<String, dynamic>> sent;
  late EngineConnection engine;
  late MemoryPairingTokens tokens;

  Future<void> start(WidgetTester tester) async {
    sent = [];
    tokens = MemoryPairingTokens();
    engine = EngineConnection.forTest(sent.add, tokens: tokens);
    addTearDown(engine.dispose);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), engine: engine));
  }

  void answer({String? error}) => engine.receiveForTest(
    jsonEncode({
      'type': 'result',
      'request_id': '${sent.length}',
      'ok': error == null,
      if (error != null) 'error': {'code': error, 'message': ''},
    }),
  );

  testWidgets('a network engine asks for its PIN once, then the app opens', (tester) async {
    await start(tester);
    engine.receiveForTest(jsonEncode(helloWith('required')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pairing-pin')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    // Nothing is stored for this engine yet, so nothing is tried.
    expect(sent.where((r) => r['type'] == 'pair'), isEmpty);

    // The sixth digit sends the PIN.
    await tester.enterText(find.byKey(const ValueKey('pairing-pin')), '123456');
    await tester.pump();
    expect(sent.last, {'type': 'pair', 'pin': '123456'});
    answer(error: 'wrong_pin');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pairing-error')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('pairing-pin')), '654321');
    await tester.pump();
    answer();
    engine.receiveForTest(jsonEncode({'type': 'paired', 'token': 'token-1', 'engine_id': 'engine-1'}));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pairing-pin')), findsNothing);
    expect(tokens.tokens, {'engine-1': 'token-1'});
  });

  testWidgets('with a stored token the app pairs by itself', (tester) async {
    await start(tester);
    tokens.tokens['engine-1'] = 'token-1';
    engine.receiveForTest(jsonEncode(helloWith('required')));
    await tester.pump();
    await tester.pump();
    expect(sent.last, {'type': 'pair', 'token': 'token-1'});
    answer();
    engine.receiveForTest(jsonEncode({'type': 'paired', 'token': 'token-1', 'engine_id': 'engine-1'}));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pairing-pin')), findsNothing);
  });

  testWidgets('a token the engine no longer knows is forgotten, and the PIN is asked again', (tester) async {
    await start(tester);
    tokens.tokens['engine-1'] = 'old';
    engine.receiveForTest(jsonEncode(helloWith('required')));
    await tester.pump();
    await tester.pump();
    answer(error: 'unknown_token');
    await tester.pumpAndSettle();
    expect(tokens.tokens, isEmpty);
    expect(find.byKey(const ValueKey('pairing-pin')), findsOneWidget);
  });

  testWidgets('engines on this device and engines before pairing open the app at once', (tester) async {
    await start(tester);
    engine.receiveForTest(jsonEncode(helloWith('local')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pairing-pin')), findsNothing);
    engine.receiveForTest(jsonEncode(hello));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pairing-pin')), findsNothing);
  });
}
