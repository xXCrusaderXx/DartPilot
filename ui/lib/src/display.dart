import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// How much room the window gives, by its width: a phone upright, a phone on its side or a tablet, a monitor or TV.
/// Layouts change at these widths and nowhere else.
enum WindowClass {
  compact,
  medium,
  large;

  static const double mediumFrom = 600;
  static const double largeFrom = 1200;

  static WindowClass forWidth(double width) => width >= largeFrom
      ? large
      : width >= mediumFrom
      ? medium
      : compact;

  static WindowClass of(BuildContext context) => forWidth(MediaQuery.sizeOf(context).width);
}

/// How a game is shown: clear and large in the app's own colours, or as a TV scoreboard that fits more on less room
enum DisplayStyle { auto, clear, scoreboard }

/// Whether the screen is read from close by (in the hand, on the desk) or from the oche (at the board, a TV)
enum ViewingDistance { auto, near, far }

/// Light or dark colours, or whichever the system uses
enum AppBrightness { system, dark, light }

/// Text size on top of the system's setting and the viewing distance
enum TextSize {
  small(0.9),
  normal(1.0),
  large(1.15),
  larger(1.3);

  const TextSize(this.factor);
  final double factor;
}

/// A starting point for the appearance; the player changes single values from there, and Reset returns to it.
enum AppearancePreset {
  standard(AppBrightness.dark, TextSize.normal, false, DisplayStyle.auto),
  light(AppBrightness.light, TextSize.normal, false, DisplayStyle.auto),
  highContrast(AppBrightness.dark, TextSize.large, true, DisplayStyle.clear),
  scoreboard(AppBrightness.dark, TextSize.normal, false, DisplayStyle.scoreboard);

  const AppearancePreset(this.brightness, this.textSize, this.strongContrast, this.style);
  final AppBrightness brightness;
  final TextSize textSize;
  final bool strongContrast;
  final DisplayStyle style;
}

/// The player's choice of how the app looks on this device; auto picks by the window.
class DisplaySettings extends ChangeNotifier {
  DisplaySettings({this.store = true});

  /// Whether the choice is kept in the device's preferences; tests keep it in memory
  final bool store;

  DisplayStyle style = DisplayStyle.auto;
  ViewingDistance distance = ViewingDistance.auto;

  /// Dark by default, as the app always was
  AppBrightness brightness = AppBrightness.dark;

  /// The colour the accent is made from, or the flight's blue
  Color? accent;
  TextSize textSize = TextSize.normal;
  bool highContrast = false;
  AppearancePreset preset = AppearancePreset.standard;

  static const _styleKey = 'display.style';
  static const _distanceKey = 'display.distance';
  static const _brightnessKey = 'display.brightness';
  static const _accentKey = 'display.accent';
  static const _textSizeKey = 'display.textSize';
  static const _highContrastKey = 'display.highContrast';
  static const _presetKey = 'display.preset';

  Future<void> load() async {
    if (!store) return;
    final prefs = await SharedPreferences.getInstance();
    style = DisplayStyle.values.asNameMap()[prefs.getString(_styleKey)] ?? DisplayStyle.auto;
    distance = ViewingDistance.values.asNameMap()[prefs.getString(_distanceKey)] ?? ViewingDistance.auto;
    brightness = AppBrightness.values.asNameMap()[prefs.getString(_brightnessKey)] ?? AppBrightness.dark;
    final argb = prefs.getInt(_accentKey);
    accent = argb == null ? null : Color(argb);
    textSize = TextSize.values.asNameMap()[prefs.getString(_textSizeKey)] ?? TextSize.normal;
    highContrast = prefs.getBool(_highContrastKey) ?? false;
    preset = AppearancePreset.values.asNameMap()[prefs.getString(_presetKey)] ?? AppearancePreset.standard;
    notifyListeners();
  }

  Future<void> set({
    DisplayStyle? style,
    ViewingDistance? distance,
    AppBrightness? brightness,
    TextSize? textSize,
    bool? highContrast,
  }) async {
    this.style = style ?? this.style;
    this.distance = distance ?? this.distance;
    this.brightness = brightness ?? this.brightness;
    this.textSize = textSize ?? this.textSize;
    this.highContrast = highContrast ?? this.highContrast;
    await _changed();
  }

  /// The accent from [colour], or the flight's blue when null
  Future<void> setAccent(Color? colour) async {
    accent = colour;
    await _changed();
  }

  /// Starts from [preset]: its brightness, text size, contrast and game display, with the default accent. The viewing
  /// distance belongs to where the device stands and is kept.
  Future<void> applyPreset(AppearancePreset preset) async {
    this.preset = preset;
    brightness = preset.brightness;
    textSize = preset.textSize;
    highContrast = preset.strongContrast;
    style = preset.style;
    accent = null;
    await _changed();
  }

  /// Back to the chosen preset
  Future<void> reset() => applyPreset(preset);

  Future<void> _changed() async {
    notifyListeners();
    if (!store) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_styleKey, style.name);
    await prefs.setString(_distanceKey, distance.name);
    await prefs.setString(_brightnessKey, brightness.name);
    final accent = this.accent;
    if (accent == null) {
      await prefs.remove(_accentKey);
    } else {
      await prefs.setInt(_accentKey, accent.toARGB32());
    }
    await prefs.setString(_textSizeKey, textSize.name);
    await prefs.setBool(_highContrastKey, highContrast);
    await prefs.setString(_presetKey, preset.name);
  }

  ThemeMode get themeMode => switch (brightness) {
    AppBrightness.system => ThemeMode.system,
    AppBrightness.dark => ThemeMode.dark,
    AppBrightness.light => ThemeMode.light,
  };

  /// The colours for [brightness] with the chosen contrast and accent
  AppPalette paletteFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = highContrast
        ? (dark ? AppPalette.highContrastDark : AppPalette.highContrastLight)
        : (dark ? AppPalette.dark : AppPalette.light);
    final accent = this.accent;
    return accent == null ? base : base.withAccent(accent);
  }

  /// The style a game uses in this window: on a phone the scoreboard fits more, elsewhere the clear style
  DisplayStyle styleFor(WindowClass window) => style != DisplayStyle.auto
      ? style
      : window == WindowClass.compact
      ? DisplayStyle.scoreboard
      : DisplayStyle.clear;

  /// Read from the oche: on a monitor or TV by default, in the hand or on a tablet from close by
  bool farFor(WindowClass window) =>
      distance == ViewingDistance.auto ? window == WindowClass.large : distance == ViewingDistance.far;
}

class DisplayScope extends InheritedNotifier<DisplaySettings> {
  const DisplayScope({super.key, required DisplaySettings settings, required super.child}) : super(notifier: settings);

  static final DisplaySettings _defaults = DisplaySettings(store: false);

  static DisplaySettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DisplayScope>()?.notifier ?? _defaults;
}

/// A motion's duration, or none where the system asks for less motion
Duration motion(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
