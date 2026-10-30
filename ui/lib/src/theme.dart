// The app's colours, from the DartPilot icon (engine/apps/dartpilot_setup/icons/dartpilot.svg) and the same tokens
// as the setup tool (engine/apps/dartpilot_setup/Tokens.qml): night blue surfaces and the sky blue of the flight.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The dark palette as constants, for what is drawn over camera images and the board, which look the same in every
/// theme. Screens take their colours from the theme ([AppPalette.of]).
abstract final class AppColors {
  static const background = Color(0xFF0F1216);
  static const sidebar = Color(0xFF13171D);
  static const surface = Color(0xFF1A1F27);
  static const surfaceRaised = Color(0xFF222833);
  static const border = Color(0xFF2A313D);
  static const text = Color(0xFFE6E9EF);
  static const textMuted = Color(0xFF98A2B3);

  /// The flight's three blues, light to deep
  static const accentLight = Color(0xFF7DD3FC);
  static const accent = Color(0xFF38BDF8);
  static const accentDeep = Color(0xFF0284C7);

  static const good = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const bad = Color(0xFFF87171);
}

/// The design tokens of one brightness. Every colour a screen uses comes from here, so a change applies everywhere.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.sidebar,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.accentLight,
    required this.accent,
    required this.accentDeep,
    required this.onAccent,
    required this.accentContainer,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.notice,
    required this.good,
    required this.warning,
    required this.bad,
    required this.onStatus,
    required this.highlight,
    required this.onHighlight,
  });

  final Brightness brightness;
  final Color background;
  final Color sidebar;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color text;
  final Color textMuted;

  /// The flight's blues, light to deep, as they read on this palette's surfaces
  final Color accentLight;
  final Color accent;
  final Color accentDeep;
  final Color onAccent;

  /// Notices about the board (pull the darts), with text and an accent button on them
  final Color accentContainer;

  /// Quiet accent areas (selected chips, tonal buttons) and their text
  final Color accentSoft;
  final Color onAccentSoft;

  /// Notices that need the player (an uncertain dart, a correction): amber-tinted, so text stays readable
  final Color notice;

  final Color good;
  final Color warning;
  final Color bad;

  /// Text on a filled good, warning or bad mark
  final Color onStatus;

  /// The active player's block in the scoreboard style, the same yellow in every palette
  final Color highlight;
  final Color onHighlight;

  static const dark = AppPalette(
    brightness: Brightness.dark,
    background: AppColors.background,
    sidebar: AppColors.sidebar,
    surface: AppColors.surface,
    surfaceRaised: AppColors.surfaceRaised,
    border: AppColors.border,
    text: AppColors.text,
    textMuted: AppColors.textMuted,
    accentLight: AppColors.accentLight,
    accent: AppColors.accent,
    accentDeep: AppColors.accentDeep,
    onAccent: AppColors.background,
    accentContainer: Color(0xFF0B3B57),
    accentSoft: Color(0xFF1E3A4C),
    onAccentSoft: AppColors.accentLight,
    notice: Color(0xFF3B3117),
    good: AppColors.good,
    warning: AppColors.warning,
    bad: AppColors.bad,
    onStatus: AppColors.background,
    highlight: AppColors.warning,
    onHighlight: AppColors.background,
  );

  static const light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF4F6F9),
    sidebar: Color(0xFFE9EDF2),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFEEF1F5),
    border: Color(0xFFCBD3DD),
    text: Color(0xFF111827),
    textMuted: Color(0xFF4B5563),
    accentLight: Color(0xFF0369A1),
    accent: Color(0xFF075985),
    accentDeep: Color(0xFF0C4A6E),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFDCEFFB),
    accentSoft: Color(0xFFD6EEFB),
    onAccentSoft: Color(0xFF075985),
    notice: Color(0xFFFDF1D8),
    good: Color(0xFF047857),
    warning: Color(0xFFB45309),
    bad: Color(0xFFB91C1C),
    onStatus: Color(0xFFFFFFFF),
    highlight: AppColors.warning,
    onHighlight: Color(0xFF111827),
  );

  /// Pure black and white surfaces, stronger borders and muted text closer to the text
  static final highContrastDark = dark
      .copyWith(
        background: const Color(0xFF000000),
        sidebar: const Color(0xFF050505),
        surface: const Color(0xFF0D0D0D),
        surfaceRaised: const Color(0xFF1A1A1A),
        border: const Color(0xFF8C8C8C),
        text: const Color(0xFFFFFFFF),
        textMuted: const Color(0xFFD4D4D4),
        onAccent: const Color(0xFF000000),
        onStatus: const Color(0xFF000000),
        onHighlight: const Color(0xFF000000),
        notice: const Color(0xFF2E2508),
      )
      .withAccent(AppColors.accent);

  static final highContrastLight = light
      .copyWith(
        background: const Color(0xFFFFFFFF),
        sidebar: const Color(0xFFF2F2F2),
        surface: const Color(0xFFFFFFFF),
        surfaceRaised: const Color(0xFFF0F0F0),
        border: const Color(0xFF4D4D4D),
        text: const Color(0xFF000000),
        textMuted: const Color(0xFF262626),
        onHighlight: const Color(0xFF000000),
        good: const Color(0xFF035E44),
        warning: const Color(0xFF8A3F06),
        bad: const Color(0xFF991515),
      )
      .withAccent(AppColors.accent);

  /// The surfaces text and accents are drawn on
  List<Color> get grounds => [background, sidebar, surface, surfaceRaised];

  /// This palette with its accent from [seed]: the seed's hue and saturation, each shade made just dark or light
  /// enough to keep WCAG AA on this palette's surfaces, so any colour the player picks stays readable.
  AppPalette withAccent(Color seed) {
    final hsl = HSLColor.fromColor(seed);
    final dark = brightness == Brightness.dark;
    final onAccent = dark ? background : const Color(0xFFFFFFFF);
    bool readsOnGrounds(Color c) => [...grounds, notice].every((g) => contrastRatio(c, g) >= 4.5);
    final accent = _fitLightness(hsl, towardLight: dark, (c) => readsOnGrounds(c) && contrastRatio(onAccent, c) >= 4.5);
    final accentHsl = HSLColor.fromColor(accent);
    final accentLight = _fitLightness(
      accentHsl.withLightness((accentHsl.lightness + (dark ? 0.12 : 0.06)).clamp(0.0, 1.0)),
      towardLight: dark,
      (c) => contrastRatio(onAccent, c) >= 4.5 && grounds.every((g) => contrastRatio(c, g) >= 3),
    );
    final accentDeep = accentHsl.withLightness((accentHsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final container = _fitLightness(
      accentHsl.withSaturation(accentHsl.saturation * 0.8).withLightness(dark ? 0.2 : 0.92),
      towardLight: !dark,
      (c) => contrastRatio(text, c) >= 4.5 && contrastRatio(accent, c) >= 4.5,
    );
    final soft = _fitLightness(
      accentHsl.withSaturation(accentHsl.saturation * 0.45).withLightness(dark ? 0.21 : 0.9),
      towardLight: !dark,
      (c) => contrastRatio(dark ? accentLight : accent, c) >= 4.5,
    );
    return copyWith(
      accent: accent,
      accentLight: accentLight,
      accentDeep: accentDeep,
      onAccent: onAccent,
      accentContainer: container,
      accentSoft: soft,
      onAccentSoft: dark ? accentLight : accent,
    );
  }

  /// The colour of [start]'s hue and saturation nearest to its lightness that passes [ok], searching toward light or
  /// dark; the far end if none does.
  static Color _fitLightness(HSLColor start, bool Function(Color) ok, {required bool towardLight}) {
    for (var step = 0; step <= 100; ++step) {
      final l = start.lightness + (towardLight ? step : -step) / 100;
      if (l < 0 || l > 1) break;
      final c = start.withLightness(l).toColor();
      if (ok(c)) return c;
    }
    return towardLight ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  }

  static AppPalette of(BuildContext context) => Theme.of(context).extension<AppPalette>() ?? dark;

  List<Object> get _values => [
    brightness,
    background,
    sidebar,
    surface,
    surfaceRaised,
    border,
    text,
    textMuted,
    accentLight,
    accent,
    accentDeep,
    onAccent,
    accentContainer,
    accentSoft,
    onAccentSoft,
    notice,
    good,
    warning,
    bad,
    onStatus,
    highlight,
    onHighlight,
  ];

  @override
  bool operator ==(Object other) {
    if (other is! AppPalette) return false;
    final a = _values, b = other._values;
    for (var i = 0; i < a.length; ++i) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_values);

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? sidebar,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? accentLight,
    Color? accent,
    Color? accentDeep,
    Color? onAccent,
    Color? accentContainer,
    Color? accentSoft,
    Color? onAccentSoft,
    Color? notice,
    Color? good,
    Color? warning,
    Color? bad,
    Color? onStatus,
    Color? highlight,
    Color? onHighlight,
  }) => AppPalette(
    brightness: brightness ?? this.brightness,
    background: background ?? this.background,
    sidebar: sidebar ?? this.sidebar,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    border: border ?? this.border,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    accentLight: accentLight ?? this.accentLight,
    accent: accent ?? this.accent,
    accentDeep: accentDeep ?? this.accentDeep,
    onAccent: onAccent ?? this.onAccent,
    accentContainer: accentContainer ?? this.accentContainer,
    accentSoft: accentSoft ?? this.accentSoft,
    onAccentSoft: onAccentSoft ?? this.onAccentSoft,
    notice: notice ?? this.notice,
    good: good ?? this.good,
    warning: warning ?? this.warning,
    bad: bad ?? this.bad,
    onStatus: onStatus ?? this.onStatus,
    highlight: highlight ?? this.highlight,
    onHighlight: onHighlight ?? this.onHighlight,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: mix(background, other.background),
      sidebar: mix(sidebar, other.sidebar),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      border: mix(border, other.border),
      text: mix(text, other.text),
      textMuted: mix(textMuted, other.textMuted),
      accentLight: mix(accentLight, other.accentLight),
      accent: mix(accent, other.accent),
      accentDeep: mix(accentDeep, other.accentDeep),
      onAccent: mix(onAccent, other.onAccent),
      accentContainer: mix(accentContainer, other.accentContainer),
      accentSoft: mix(accentSoft, other.accentSoft),
      onAccentSoft: mix(onAccentSoft, other.onAccentSoft),
      notice: mix(notice, other.notice),
      good: mix(good, other.good),
      warning: mix(warning, other.warning),
      bad: mix(bad, other.bad),
      onStatus: mix(onStatus, other.onStatus),
      highlight: mix(highlight, other.highlight),
      onHighlight: mix(onHighlight, other.onHighlight),
    );
  }
}

/// WCAG 2.x contrast ratio of two opaque colours, from 1 (same) to 21 (black on white)
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Colours for states (camera ok, measured, warning, problem), so screens do not pick their own greens and ambers
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({required this.good, required this.warning, required this.bad});

  final Color good;
  final Color warning;
  final Color bad;

  static StatusColors of(BuildContext context) => Theme.of(context).extension<StatusColors>()!;

  @override
  StatusColors copyWith({Color? good, Color? warning, Color? bad}) =>
      StatusColors(good: good ?? this.good, warning: warning ?? this.warning, bad: bad ?? this.bad);

  @override
  StatusColors lerp(StatusColors? other, double t) => other == null
      ? this
      : StatusColors(
          good: Color.lerp(good, other.good, t)!,
          warning: Color.lerp(warning, other.warning, t)!,
          bad: Color.lerp(bad, other.bad, t)!,
        );
}

/// The bundled condensed face scores and big figures are set in, on every device (assets/fonts)
const scoreFontFamily = 'BarlowCondensed';

/// The bundled text face, unless the player chose the system's
const textFontFamily = 'Inter';

/// Scores and figures keep their width while they change, so 141 → 111 does not jitter.
const tabularFigures = [FontFeature.tabularFigures()];

/// [style] in the score face with figures of one width: remaining scores, visit totals, legs, points
TextStyle? scoreStyle(TextStyle? style) => style?.copyWith(fontFamily: scoreFontFamily, fontFeatures: tabularFigures);

/// The app's theme for one palette, dark by default, with text in [fontFamily] or the system's font when null
ThemeData dartPilotTheme([AppPalette p = AppPalette.dark, String? fontFamily = textFontFamily]) {
  final scheme = ColorScheme(
    brightness: p.brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    primaryContainer: p.accentContainer,
    onPrimaryContainer: p.text,
    secondary: p.accentLight,
    onSecondary: p.onAccent,
    secondaryContainer: p.accentSoft,
    onSecondaryContainer: p.onAccentSoft,
    tertiary: p.warning,
    onTertiary: p.onStatus,
    tertiaryContainer: p.notice,
    onTertiaryContainer: p.text,
    error: p.bad,
    onError: p.onStatus,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.textMuted,
    surfaceContainerLowest: p.background,
    surfaceContainerLow: p.sidebar,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceRaised,
    surfaceContainerHighest: p.surfaceRaised,
    outline: p.border,
    outlineVariant: p.border,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: fontFamily);
  final text = base.textTheme;
  return base.copyWith(
    // The display sizes are the big numbers: the score face. Titles and headlines keep the text face's own figures:
    // tabular ones would widen its hyphens and digits in words such as "X01-Spiel"; changing figures use scoreStyle.
    textTheme: text.copyWith(
      displayLarge: scoreStyle(text.displayLarge),
      displayMedium: scoreStyle(text.displayMedium),
      displaySmall: scoreStyle(text.displaySmall),
    ),
    scaffoldBackgroundColor: p.background,
    appBarTheme: AppBarTheme(backgroundColor: p.background, surfaceTintColor: Colors.transparent),
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      // Flat with a border: a shadow would show only on light surfaces
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.sidebar,
      indicatorColor: p.accent.withValues(alpha: 0.2),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? p.accent : p.textMuted),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: p.sidebar,
      indicatorColor: p.accent.withValues(alpha: 0.2),
      selectedIconTheme: IconThemeData(color: p.accent),
      unselectedIconTheme: IconThemeData(color: p.textMuted),
    ),
    dividerTheme: DividerThemeData(color: p.border),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surfaceRaised,
      contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: p.text),
    ),
    extensions: [
      p,
      StatusColors(good: p.good, warning: p.warning, bad: p.bad),
    ],
  );
}

/// The colours players are told apart by, in the order profiles get them; each keeps 3:1 on the surfaces of every
/// palette, as graphics need.
const playerColours = [
  Color(0xFF2F7FE0),
  Color(0xFFD9480F),
  Color(0xFF15924F),
  Color(0xFF9B51E0),
  Color(0xFFD6336C),
  Color(0xFF0E8C93),
  Color(0xFFB7791F),
  Color(0xFFE03131),
];

/// A player's colour as a small dot before the name, ringed so that it also stands out on a coloured block; nothing
/// for a player without one
class PlayerDot extends StatelessWidget {
  const PlayerDot(this.colour, {super.key, this.size = 12, this.ring});

  final Color? colour;
  final double size;

  /// The ring's colour, the text colour by default
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final colour = this.colour;
    if (colour == null) return const SizedBox.shrink();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colour,
        shape: BoxShape.circle,
        border: Border.all(color: ring ?? AppPalette.of(context).text, width: 1.5),
      ),
    );
  }
}
