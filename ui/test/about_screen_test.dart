import 'package:dartpilot/l10n/app_localizations.dart';
import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/app_info.dart';
import 'package:dartpilot/src/screens/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1000, 1600);
    view.devicePixelRatio = 1.0;
  });
  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset());

  testWidgets('shows the release version, the licence and the links', (tester) async {
    await tester.pumpWidget(_app(const AboutScreen(version: '1.2.3')));
    await tester.pumpAndSettle();
    expect(find.text('Version 1.2.3'), findsOneWidget);
    expect(find.textContaining('GPL-3.0-or-later'), findsWidgets);
    expect(find.text(sourceUrl), findsOneWidget);
    expect(find.text(userGuideUrl('en')), findsOneWidget);
    expect(find.textContaining('Material Icons'), findsOneWidget);
  });

  testWidgets('a build from source says so instead of a version', (tester) async {
    await tester.pumpWidget(_app(const AboutScreen(version: ''), locale: const Locale('de')));
    await tester.pumpAndSettle();
    expect(find.text('Entwicklungsversion'), findsOneWidget);
    expect(find.text(userGuideUrl('de')), findsOneWidget);
  });

  test('the guide follows the language', () {
    expect(userGuideUrl('de'), endsWith('docs/user-guide.de.md'));
    expect(userGuideUrl('en'), endsWith('docs/user-guide.md'));
    expect(userGuideUrl('fr'), endsWith('docs/user-guide.md'));
  });

  testWidgets('a link is copied', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(_app(const AboutScreen(version: '1.2.3')));
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('about-source')), matching: find.byIcon(Icons.copy)),
    );
    await tester.pumpAndSettle();
    expect(copied, sourceUrl);
    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets('the licences of included software open the licence page', (tester) async {
    await tester.pumpWidget(_app(const AboutScreen(version: '1.2.3')));
    await tester.tap(find.byKey(const ValueKey('about-third-party')));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('the settings lead to the About page', (tester) async {
    await tester.pumpWidget(const DartPilotApp(locale: Locale('en')));
    await playOffline(tester);
    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('settings-page-about')));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);
  });
}
