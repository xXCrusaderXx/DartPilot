import 'package:dartpilot/src/app.dart';
import 'package:dartpilot/src/display.dart';
import 'package:dartpilot/src/theme.dart';
import 'package:dartpilot/src/widgets/appearance_tiles.dart';
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

/// Every colour a player can pick: the swatches, every 15° of hue, and greys
final _seeds = [
  ...accentSwatches,
  for (var hue = 0.0; hue < 360; hue += 15) HSLColor.fromAHSL(1, hue, 0.9, 0.6).toColor(),
  const Color(0xFFFFFFFF),
  const Color(0xFF000000),
  const Color(0xFF808080),
];

List<String> _failing(AppPalette palette) => [
  for (final (pair, fore, ground, needed) in _pairs(palette))
    if (contrastRatio(fore, ground) < needed) '$pair: ${contrastRatio(fore, ground).toStringAsFixed(2)} < $needed',
];

void main() {
  for (final (name, palette) in [
    ('high-contrast dark', AppPalette.highContrastDark),
    ('high-contrast light', AppPalette.highContrastLight),
  ]) {
    test('every colour pair of the $name palette keeps WCAG AA contrast', () => expect(_failing(palette), isEmpty));
  }

  test('any accent the player picks keeps WCAG AA on every palette', () {
    for (final base in [AppPalette.dark, AppPalette.light, AppPalette.highContrastDark, AppPalette.highContrastLight]) {
      for (final seed in _seeds) {
        expect(_failing(base.withAccent(seed)), isEmpty, reason: '${base.brightness} with $seed');
      }
    }
  });

  test('the accent keeps the hue the player picked', () {
    for (final seed in accentSwatches) {
      final accent = AppPalette.dark.withAccent(seed).accent;
      expect(HSLColor.fromColor(accent).hue, closeTo(HSLColor.fromColor(seed).hue, 2));
    }
  });

  test('a preset sets brightness, text size, contrast and display, and Reset returns to it', () async {
    final display = DisplaySettings(store: false);
    await display.applyPreset(AppearancePreset.highContrast);
    expect(display.highContrast, isTrue);
    expect(display.textSize, TextSize.large);
    expect(display.paletteFor(Brightness.dark), AppPalette.highContrastDark);

    await display.set(textSize: TextSize.small, brightness: AppBrightness.light);
    await display.setAccent(accentSwatches[1]);
    expect(display.paletteFor(Brightness.light).accent, isNot(AppPalette.highContrastLight.accent));
    await display.reset();
    expect(display.textSize, TextSize.large);
    expect(display.brightness, AppBrightness.dark);
    expect(display.accent, isNull);
    expect(display.preset, AppearancePreset.highContrast);
  });

  test('accent, text size, contrast and preset are kept for this device', () async {
    SharedPreferences.setMockInitialValues({});
    final display = DisplaySettings();
    await display.load();
    await display.applyPreset(AppearancePreset.scoreboard);
    await display.set(textSize: TextSize.larger, highContrast: true);
    await display.setAccent(accentSwatches[3]);
    final reloaded = DisplaySettings();
    await reloaded.load();
    expect(reloaded.preset, AppearancePreset.scoreboard);
    expect(reloaded.style, DisplayStyle.scoreboard);
    expect(reloaded.textSize, TextSize.larger);
    expect(reloaded.highContrast, isTrue);
    expect(reloaded.accent, accentSwatches[3]);

    await reloaded.setAccent(null);
    final again = DisplaySettings();
    await again.load();
    expect(again.accent, isNull);
  });

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

    await tester.tap(find.descendant(of: find.byKey(const ValueKey('brightness')), matching: find.text('Hell')));
    await tester.pumpAndSettle();
    expect(display.brightness, AppBrightness.light);
    expect(background(), AppPalette.light.background);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('brightness')), matching: find.text('System')));
    await tester.pumpAndSettle();
    expect(background(), AppPalette.dark.background);
  });

  testWidgets('the settings change accent, text size and contrast of the running app', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final display = DisplaySettings(store: false);
    await tester.pumpWidget(DartPilotApp(locale: const Locale('de'), display: display));
    await playOffline(tester);
    await openSettings(tester);
    AppPalette palette() => AppPalette.of(tester.element(find.byKey(const ValueKey('brightness'))));
    double scale() => MediaQuery.textScalerOf(tester.element(find.byKey(const ValueKey('brightness')))).scale(1);

    await tester.ensureVisible(find.byKey(const ValueKey('accent-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('accent-1')));
    await tester.pumpAndSettle();
    expect(palette(), AppPalette.dark.withAccent(accentSwatches[1]));

    await tester.ensureVisible(find.byKey(const ValueKey('accent-custom')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('accent-custom')));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const ValueKey('accent-hue')), const Offset(-400, 0));
    await tester.tap(find.byKey(const ValueKey('accent-apply')));
    await tester.pumpAndSettle();
    expect(HSLColor.fromColor(display.accent!).hue, lessThan(10));
    expect(_failing(palette()), isEmpty);

    await tester.ensureVisible(find.byKey(const ValueKey('text-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sehr groß'));
    await tester.pumpAndSettle();
    expect(scale(), closeTo(1.3, 0.001));

    await tester.ensureVisible(find.byKey(const ValueKey('high-contrast')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('high-contrast')));
    await tester.pumpAndSettle();
    expect(palette().background, AppPalette.highContrastDark.background);

    await tester.ensureVisible(find.byKey(const ValueKey('appearance-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appearance-reset')));
    await tester.pumpAndSettle();
    expect(palette(), AppPalette.dark);
    expect(scale(), 1.0);
  });
}
