import 'dart:convert';
import 'dart:io';

import 'package:dartpilot/l10n/app_localizations.dart';
import 'package:dartpilot/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String language) =>
    jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('English and German have the same messages', () {
    Set<String> keys(String language) => _arb(language).keys.where((k) => !k.startsWith('@')).toSet();
    expect(keys('de').difference(keys('en')), isEmpty, reason: 'only in German');
    expect(keys('en').difference(keys('de')), isEmpty, reason: 'only in English');
  });

  test('English is the language for a system language the app does not have', () {
    expect(AppLocalizations.supportedLocales.first, const Locale('en'));
  });

  testWidgets('a French system gets the app in English', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const DartPilotApp());
    await tester.pumpAndSettle();
    expect(find.text('How are the darts counted?'), findsOneWidget);
  });

  test('counts read in the singular and the plural', () async {
    final de = await AppLocalizations.delegate.load(const Locale('de'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(de.referenceCamerasUsed(1), '1 Kamera');
    expect(en.findingBoardChanged(1), 'The empty board changed once between darts.');
    expect(en.diagnosisSummary('1:00', 2, 1), '1:00 · 2 empty boards · 1 dart');
  });
}
