import 'dart:convert';

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

/// The face the app's text is set in: the bundled one, the same on every device, or the system's. Scores keep the
/// bundled score face either way.
enum TextFont {
  bundled(textFontFamily),
  system(null);

  const TextFont(this.family);
  final String? family;
}

/// Which side of the score panel the board takes when they stand side by side
enum BoardSide { left, right }

/// The board's share of the game screen, within what the window leaves beside the score panel
enum BoardSize { small, medium, large }

/// What the score panel shows besides the score
enum PanelDetail { visitDarts, checkout, average, dartsThrown }

/// How strongly a 180 or a checkout is celebrated on the game screen
enum Celebration { full, subtle, off }

/// The colours the drawn board is painted in: the usual red and green, blue and orange that stay apart with red-green
/// colour blindness, or black and white with yellow and blue for the most contrast. A photographed board keeps its own.
enum BoardColours {
  classic(Color(0xFF1B1B1B), Color(0xFFF1E9D2), Color(0xFFD03A2B), Color(0xFF1E8F4E)),
  colourSafe(Color(0xFF1B1B1B), Color(0xFFF1E9D2), Color(0xFFE07B00), Color(0xFF1F5FBF)),
  contrast(Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFFFFD400), Color(0xFF0050D0));

  const BoardColours(this.darkSingle, this.lightSingle, this.darkRing, this.lightRing);

  /// The singles of the sectors that start at 20, and of the others
  final Color darkSingle;
  final Color lightSingle;

  /// Double and triple of the dark sectors and the bull, and of the light sectors and the outer bull
  final Color darkRing;
  final Color lightRing;
}

/// The colours a dart can be marked in on the board, besides the accent; each stands out on every field's dark single
const dartSwatches = [Color(0xFFFFFFFF), Color(0xFFFACC15), Color(0xFF22D3EE), Color(0xFFE879F9)];

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
  TextFont font = TextFont.bundled;
  bool highContrast = false;
  AppearancePreset preset = AppearancePreset.standard;
  BoardSide boardSide = BoardSide.left;
  BoardSize boardSize = BoardSize.medium;
  Set<PanelDetail> panelDetails = defaultPanelDetails;
  Celebration celebration = Celebration.full;
  BoardColours boardColours = BoardColours.classic;

  /// The colour of the darts on the board, or the accent
  Color? dartColour;

  static const defaultPanelDetails = {PanelDetail.visitDarts, PanelDetail.checkout, PanelDetail.average};

  static const _styleKey = 'display.style';
  static const _distanceKey = 'display.distance';
  static const _brightnessKey = 'display.brightness';
  static const _accentKey = 'display.accent';
  static const _textSizeKey = 'display.textSize';
  static const _fontKey = 'display.font';
  static const _highContrastKey = 'display.highContrast';
  static const _presetKey = 'display.preset';
  static const _boardSideKey = 'display.boardSide';
  static const _boardSizeKey = 'display.boardSize';
  static const _panelDetailsKey = 'display.panelDetails';
  static const _celebrationKey = 'display.celebration';
  static const _boardColoursKey = 'display.boardColours';
  static const _dartColourKey = 'display.dartColour';

  Future<void> load() async {
    if (!store) return;
    final prefs = await SharedPreferences.getInstance();
    style = DisplayStyle.values.asNameMap()[prefs.getString(_styleKey)] ?? DisplayStyle.auto;
    distance = ViewingDistance.values.asNameMap()[prefs.getString(_distanceKey)] ?? ViewingDistance.auto;
    brightness = AppBrightness.values.asNameMap()[prefs.getString(_brightnessKey)] ?? AppBrightness.dark;
    final argb = prefs.getInt(_accentKey);
    accent = argb == null ? null : Color(argb);
    textSize = TextSize.values.asNameMap()[prefs.getString(_textSizeKey)] ?? TextSize.normal;
    font = TextFont.values.asNameMap()[prefs.getString(_fontKey)] ?? TextFont.bundled;
    highContrast = prefs.getBool(_highContrastKey) ?? false;
    preset = AppearancePreset.values.asNameMap()[prefs.getString(_presetKey)] ?? AppearancePreset.standard;
    boardSide = BoardSide.values.asNameMap()[prefs.getString(_boardSideKey)] ?? BoardSide.left;
    boardSize = BoardSize.values.asNameMap()[prefs.getString(_boardSizeKey)] ?? BoardSize.medium;
    final details = prefs.getStringList(_panelDetailsKey);
    panelDetails = details == null
        ? defaultPanelDetails
        : {for (final name in details) ?PanelDetail.values.asNameMap()[name]};
    celebration = Celebration.values.asNameMap()[prefs.getString(_celebrationKey)] ?? Celebration.full;
    boardColours = BoardColours.values.asNameMap()[prefs.getString(_boardColoursKey)] ?? BoardColours.classic;
    final dart = prefs.getInt(_dartColourKey);
    dartColour = dart == null ? null : Color(dart);
    notifyListeners();
  }

  Future<void> set({
    DisplayStyle? style,
    ViewingDistance? distance,
    AppBrightness? brightness,
    TextSize? textSize,
    TextFont? font,
    bool? highContrast,
    BoardSide? boardSide,
    BoardSize? boardSize,
    Celebration? celebration,
    BoardColours? boardColours,
  }) async {
    this.style = style ?? this.style;
    this.distance = distance ?? this.distance;
    this.brightness = brightness ?? this.brightness;
    this.textSize = textSize ?? this.textSize;
    this.font = font ?? this.font;
    this.highContrast = highContrast ?? this.highContrast;
    this.boardSide = boardSide ?? this.boardSide;
    this.boardSize = boardSize ?? this.boardSize;
    this.celebration = celebration ?? this.celebration;
    this.boardColours = boardColours ?? this.boardColours;
    await _changed();
  }

  /// Darts on the board in [colour], or in the accent when null
  Future<void> setDartColour(Color? colour) async {
    dartColour = colour;
    await _changed();
  }

  /// Shows or hides one detail of the score panel
  Future<void> showDetail(PanelDetail detail, bool shown) async {
    panelDetails = shown ? {...panelDetails, detail} : ({...panelDetails}..remove(detail));
    await _changed();
  }

  bool shows(PanelDetail detail) => panelDetails.contains(detail);

  /// The accent from [colour], or the flight's blue when null
  Future<void> setAccent(Color? colour) async {
    accent = colour;
    await _changed();
  }

  /// Starts from [preset]: its brightness, text size, contrast and game display, with the default accent. The viewing
  /// distance and the game screen's layout belong to where the device stands and are kept, as are the celebration, the
  /// board's colours and the font.
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
    await prefs.setString(_fontKey, font.name);
    await prefs.setBool(_highContrastKey, highContrast);
    await prefs.setString(_presetKey, preset.name);
    await prefs.setString(_boardSideKey, boardSide.name);
    await prefs.setString(_boardSizeKey, boardSize.name);
    await prefs.setStringList(_panelDetailsKey, [for (final d in panelDetails) d.name]);
    await prefs.setString(_celebrationKey, celebration.name);
    await prefs.setString(_boardColoursKey, boardColours.name);
    final dart = dartColour;
    if (dart == null) {
      await prefs.remove(_dartColourKey);
    } else {
      await prefs.setInt(_dartColourKey, dart.toARGB32());
    }
  }

  /// What a shared appearance starts with, so that a code is told apart from other text and QR codes
  static const codePrefix = 'dartpilot-look:1:';

  /// The appearance as a short code for another device, as text or QR code. The viewing distance stays out: it
  /// belongs to where each device stands.
  String toCode() {
    final values = {
      'preset': preset.name,
      'style': style.name,
      'brightness': brightness.name,
      'accent': ?accent?.toARGB32(),
      'textSize': textSize.name,
      'font': font.name,
      'highContrast': highContrast,
      'boardSide': boardSide.name,
      'boardSize': boardSize.name,
      'details': [for (final d in panelDetails) d.name],
      'celebration': celebration.name,
      'boardColours': boardColours.name,
      'dartColour': ?dartColour?.toARGB32(),
    };
    return codePrefix + base64Url.encode(utf8.encode(jsonEncode(values))).replaceAll('=', '');
  }

  /// Takes over the appearance of [code]; false, changing nothing, when it is not one. Values this version does not
  /// know keep their defaults, so a code from a newer app still works.
  Future<bool> applyCode(String code) async {
    final trimmed = code.trim();
    if (!trimmed.startsWith(codePrefix)) return false;
    final Map<String, Object?> values;
    try {
      final data = trimmed.substring(codePrefix.length);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(data))));
      if (decoded is! Map<String, Object?>) return false;
      values = decoded;
    } on FormatException {
      return false;
    }
    T pick<T extends Enum>(List<T> all, String key, T fallback) => all.asNameMap()[values[key]] ?? fallback;
    Color? colour(String key) => switch (values[key]) {
      final int argb => Color(argb),
      _ => null,
    };
    preset = pick(AppearancePreset.values, 'preset', AppearancePreset.standard);
    style = pick(DisplayStyle.values, 'style', DisplayStyle.auto);
    brightness = pick(AppBrightness.values, 'brightness', AppBrightness.dark);
    accent = colour('accent');
    textSize = pick(TextSize.values, 'textSize', TextSize.normal);
    font = pick(TextFont.values, 'font', TextFont.bundled);
    highContrast = values['highContrast'] == true;
    boardSide = pick(BoardSide.values, 'boardSide', BoardSide.left);
    boardSize = pick(BoardSize.values, 'boardSize', BoardSize.medium);
    panelDetails = switch (values['details']) {
      final List<Object?> names => {for (final name in names) ?PanelDetail.values.asNameMap()[name]},
      _ => defaultPanelDetails,
    };
    celebration = pick(Celebration.values, 'celebration', Celebration.full);
    boardColours = pick(BoardColours.values, 'boardColours', BoardColours.classic);
    // Only the colours the settings offer, which are known to stand out on every board
    dartColour = dartSwatches.contains(colour('dartColour')) ? colour('dartColour') : null;
    await _changed();
    return true;
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
