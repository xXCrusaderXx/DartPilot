import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/widgets/window_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the slim title bar moves, maximises and closes the window', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('window_manager'), (call) async {
      calls.add(call.method);
      return call.method == 'isMaximized' ? false : null;
    });
    WindowFrame.enabled = true;
    addTearDown(() => WindowFrame.enabled = false);

    await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
    await tester.pumpAndSettle();
    expect(find.byType(TitleBar), findsOneWidget);
    expect(tester.getRect(find.byType(TitleBar)).top, 0);

    await tester.tap(find.byKey(const ValueKey('window-maximize')));
    await tester.tap(find.byKey(const ValueKey('window-minimize')));
    await tester.tap(find.byKey(const ValueKey('window-close')));
    await tester.pump();
    expect(calls, containsAllInOrder(['maximize', 'minimize', 'close']));
  });

  testWidgets('without a frame set up there is no title bar of the app', (tester) async {
    await tester.pumpWidget(const DartPilotApp(locale: Locale('de')));
    await tester.pumpAndSettle();
    expect(find.byType(TitleBar), findsNothing);
  });
}
