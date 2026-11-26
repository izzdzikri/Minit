import 'package:material_ui/material_ui.dart';

/// Spacing constants on an 8dp grid.
class MinuteSpacing {
  MinuteSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radii (12dp card/container standard).
class MinuteRadii {
  MinuteRadii._();

  static const double sm = 8;
  static const double card = 12;
  static const double pill = 999;
}

/// Motion durations (150-250ms) respecting system "remove animations".
class MinuteMotion {
  MinuteMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);

  static Duration duration(BuildContext context, [Duration base = normal]) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Duration.zero;
    }
    return base;
  }
}

/// Editorial typography helpers (`Inter` UI + `Source Serif 4` transcript/summary).
class MinuteTypography {
  MinuteTypography._();

  static const String uiFont = 'Inter';
  static const String editorialFont = 'SourceSerif4';

  static TextStyle editorialBody(
    BuildContext context, {
    Color? color,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    final c = color ?? Theme.of(context).extension<MinuteColors>()!.textPrimary;
    return TextStyle(
      fontFamily: editorialFont,
      fontSize: 17,
      height: 1.65,
      fontWeight: fontWeight,
      color: c,
    );
  }

  static TextStyle editorialSummary(BuildContext context, {Color? color}) {
    final c = color ?? Theme.of(context).extension<MinuteColors>()!.textPrimary;
    return TextStyle(
      fontFamily: editorialFont,
      fontSize: 17,
      height: 1.65,
      fontWeight: FontWeight.w400,
      color: c,
    );
  }
}

/// Semantic color tokens exposed via `Theme.of(context).extension<MinuteColors>()`.
@immutable
class MinuteColors extends ThemeExtension<MinuteColors> {
  const MinuteColors({
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentForeground,
    required this.accentSubtle,
    required this.accentText,
    required this.danger,
    required this.dangerSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.success,
    required this.successSubtle,
  });

  final Color background;
  final Color surface;
  final Color surfaceSubtle;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentForeground;
  final Color accentSubtle;
  final Color accentText;
  final Color danger;
  final Color dangerSubtle;
  final Color warning;
  final Color warningSubtle;
  final Color success;
  final Color successSubtle;

  static const light = MinuteColors(
    background: Color(0xFFFAFAF9),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF5F5F4),
    border: Color(0xFFE7E5E4),
    textPrimary: Color(0xFF1C1917),
    textSecondary: Color(0xFF57534E),
    textMuted: Color(0xFF78716C),
    accent: Color(0xFF0F766E),
    accentForeground: Color(0xFFFAFAF9),
    accentSubtle: Color(0xFFCCFBF1),
    accentText: Color(0xFF115E59),
    danger: Color(0xFFB91C1C),
    dangerSubtle: Color(0xFFFEE2E2),
    warning: Color(0xFFB45309),
    warningSubtle: Color(0xFFFEF3C7),
    success: Color(0xFF15803D),
    successSubtle: Color(0xFFDCFCE7),
  );

  static const dark = MinuteColors(
    background: Color(0xFF0C0A09),
    surface: Color(0xFF1C1917),
    surfaceSubtle: Color(0xFF292524),
    border: Color(0xFF292524),
    textPrimary: Color(0xFFFAFAF9),
    textSecondary: Color(0xFFA8A29E),
    textMuted: Color(0xFF78716C),
    accent: Color(0xFF0F766E),
    accentForeground: Color(0xFFFAFAF9),
    accentSubtle: Color(0xFF134E4A),
    accentText: Color(0xFF5EEAD4),
    danger: Color(0xFFF87171),
    dangerSubtle: Color(0xFF450A0A),
    warning: Color(0xFFFBBF24),
    warningSubtle: Color(0xFF451A03),
    success: Color(0xFF4ADE80),
    successSubtle: Color(0xFF052E16),
  );

  @override
  MinuteColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSubtle,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentForeground,
    Color? accentSubtle,
    Color? accentText,
    Color? danger,
    Color? dangerSubtle,
    Color? warning,
    Color? warningSubtle,
    Color? success,
    Color? successSubtle,
  }) {
    return MinuteColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      accentText: accentText ?? this.accentText,
      danger: danger ?? this.danger,
      dangerSubtle: dangerSubtle ?? this.dangerSubtle,
      warning: warning ?? this.warning,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      success: success ?? this.success,
      successSubtle: successSubtle ?? this.successSubtle,
    );
  }

  @override
  MinuteColors lerp(ThemeExtension<MinuteColors>? other, double t) {
    if (other is! MinuteColors) return this;
    return MinuteColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentForeground: Color.lerp(accentForeground, other.accentForeground, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSubtle: Color.lerp(dangerSubtle, other.dangerSubtle, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSubtle: Color.lerp(warningSubtle, other.warningSubtle, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSubtle: Color.lerp(successSubtle, other.successSubtle, t)!,
    );
  }
}

extension MinuteThemeContextX on BuildContext {
  MinuteColors get minuteColors =>
      Theme.of(this).extension<MinuteColors>() ?? MinuteColors.light;
}
