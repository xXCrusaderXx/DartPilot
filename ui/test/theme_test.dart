import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/display.dart';
import 'package:dartpilot/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'navigation.dart';

/// WCAG AA: 4.5 for text, 3 for icons, borders of controls and large figures
const _text = 4.5;
const _graphic = 3.0;

/// Every pair of colours a screen puts on top of each other, with the contrast it needs
List<(String, Color, Color, double)> _pairs(AppPalette p) => [
  for (final (name, ground) in [
    ('background', p.background),
    ('sidebar', p.sidebar),
    ('surface', p.surface),
    ('surfaceRaised', p.surfaceRaised),
  ]) ...[
    ('text on $name', p.text, ground, _text),
    ('textMuted on $name', p.textMuted, ground, _text),
    ('accent on $name', p.accent, ground, _text),
    ('good on $name', p.good, ground, _graphic),
    ('warning on $name', p.warning, ground, _graphic),
    ('bad on $name', p.bad, ground, _text),
  ],
  ('onAccent on accent', p.onAccent, p.accent, _text),
  ('onAccent on accentLight', p.onAccent, p.accentLight, _text),
  ('text on accentContainer', p.text, p.accentContainer, _text),
  ('accent on accentContainer', p.accent, p.accentContainer, _text),
  ('onAccentSoft on accentSoft', p.onAccentSoft, p.accentSoft, _text),
  ('text on notice', p.text, p.notice, _text),
  ('accent on notice', p.accent, p.notice, _text),
  ('onStatus on good', p.onStatus, p.good, _text),
  ('onStatus on warning', p.onStatus, p.warning, _text),
  ('onStatus on bad', p.onStatus, p.bad, _text),
  ('onHighlight on highlight', p.onHighlight, p.highlight, _text),
];

void main() {
  for (final (name, palette) in [('dark', AppPalette.dark), ('light', AppPalette.light)]) {
    test('every colour pair of the $name palette keeps WCAG AA contrast', () {
      final failing = [
        for (final (pair, fore, ground, needed) in _pairs(palette))
          if (contrastRatio(fore, ground) < needed)
            '$pair: ${contrastRatio(fore, ground).toStringAsFixed(2)} < $needed',
      ];
      expect(failing, isEmpty);
    });
  }

  test('the contrast ratio follows WCAG', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrastRatio(Colors.white, Colors.white), 1);
  });

  test('the brightness is kept for this device', () async {
    SharedPreferences.setMockInitialValues({});
    final display = DisplaySettings();
    await display.load();
    expect(display.brightness, AppBrightness.dark);
    expect(display.themeMode, ThemeMode.dark);

    await display.set(brightness: AppBrightness.light);
    final reloaded = DisplaySettings();
    await reloaded.load();
    expect(reloaded.brightness, AppBrightness.light);
    expect(reloaded.themeMode, ThemeMode.light);
  });

  testWidgets('the settings switch the whole app between dark, light and the system', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final display = DisplaySettings(store: false);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), display: display));
    await playOffline(tester);
    await openSettings(tester);
    Color background() => Theme.of(tester.element(find.byKey(const ValueKey('brightness')))).scaffoldBackgroundColor;
    expect(background(), AppPalette.dark.background);

    await tester.tap(find.text('Hell'));
    await tester.pumpAndSettle();
    expect(display.brightness, AppBrightness.light);
    expect(background(), AppPalette.light.background);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(background(), AppPalette.dark.background);
  });
}
