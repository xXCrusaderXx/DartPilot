// The app's colours, from the DartPilot icon (engine/apps/dartpilot_setup/icons/dartpilot.svg) and the same tokens
// as the setup tool (engine/apps/dartpilot_setup/Tokens.qml): night blue surfaces and the sky blue of the flight.
import 'package:flutter/material.dart';

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

ThemeData dartPilotTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.background,
    primaryContainer: AppColors.accentDeep,
    onPrimaryContainer: AppColors.text,
    secondary: AppColors.accentLight,
    onSecondary: AppColors.background,
    secondaryContainer: Color(0xFF1E3A4C),
    onSecondaryContainer: AppColors.accentLight,
    tertiary: AppColors.warning,
    onTertiary: AppColors.background,
    error: AppColors.bad,
    onError: AppColors.background,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textMuted,
    surfaceContainerLowest: AppColors.background,
    surfaceContainerLow: AppColors.sidebar,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surfaceRaised,
    surfaceContainerHighest: AppColors.surfaceRaised,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.background, surfaceTintColor: Colors.transparent),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.sidebar,
      indicatorColor: AppColors.accent.withValues(alpha: 0.2),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) =>
            IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.textMuted),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.sidebar,
      indicatorColor: AppColors.accent.withValues(alpha: 0.2),
      selectedIconTheme: const IconThemeData(color: AppColors.accent),
      unselectedIconTheme: const IconThemeData(color: AppColors.textMuted),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceRaised,
      contentTextStyle: TextStyle(color: AppColors.text),
    ),
    extensions: const [StatusColors(good: AppColors.good, warning: AppColors.warning, bad: AppColors.bad)],
  );
}
