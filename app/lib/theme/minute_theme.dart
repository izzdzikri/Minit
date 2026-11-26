import 'package:material_ui/material_ui.dart';

import 'minute_tokens.dart';

class MinuteTheme {
  MinuteTheme._();

  static final ThemeData _lightTheme = _build(Brightness.light, MinuteColors.light);
  static final ThemeData _darkTheme = _build(Brightness.dark, MinuteColors.dark);

  static ThemeData light() => _lightTheme;
  static ThemeData dark() => _darkTheme;

  static ThemeData _build(Brightness brightness, MinuteColors tokens) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.accent,
      onPrimary: tokens.accentForeground,
      primaryContainer: tokens.accentSubtle,
      onPrimaryContainer: tokens.accentText,
      secondary: tokens.textSecondary,
      onSecondary: tokens.surface,
      secondaryContainer: tokens.surfaceSubtle,
      onSecondaryContainer: tokens.textPrimary,
      tertiary: tokens.warning,
      onTertiary: tokens.surface,
      tertiaryContainer: tokens.warningSubtle,
      onTertiaryContainer: tokens.warning,
      error: tokens.danger,
      onError: tokens.accentForeground,
      errorContainer: tokens.dangerSubtle,
      onErrorContainer: tokens.danger,
      surface: tokens.surface,
      onSurface: tokens.textPrimary,
      onSurfaceVariant: tokens.textSecondary,
      outline: tokens.border,
      outlineVariant: tokens.border,
      surfaceContainerLowest: tokens.background,
      surfaceContainerLow: tokens.surface,
      surfaceContainer: tokens.surfaceSubtle,
      surfaceContainerHigh: tokens.surfaceSubtle,
      surfaceContainerHighest: tokens.border,
    );

    final baseTextTheme = ThemeData(brightness: brightness).textTheme.apply(
          fontFamily: MinuteTypography.uiFont,
          bodyColor: tokens.textPrimary,
          displayColor: tokens.textPrimary,
        );

    final textTheme = baseTextTheme.copyWith(
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.5,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 15,
        height: 1.45,
        color: tokens.textSecondary,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 13,
        color: tokens.textMuted,
      ),
    );

    final hairlineBorder = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(MinuteRadii.card),
      side: BorderSide(color: tokens.border, width: 1),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: MinuteTypography.uiFont,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      textTheme: textTheme,
      extensions: [tokens],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: Border(bottom: BorderSide(color: tokens.border, width: 1)),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: hairlineBorder,
      ),
      dividerTheme: DividerThemeData(
        color: tokens.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MinuteSpacing.md,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MinuteRadii.card),
          borderSide: BorderSide(color: tokens.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MinuteRadii.card),
          borderSide: BorderSide(color: tokens.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MinuteRadii.card),
          borderSide: BorderSide(color: tokens.accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.accentForeground,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: MinuteSpacing.md,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MinuteRadii.card),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: MinuteSpacing.md,
            vertical: 12,
          ),
          side: BorderSide(color: tokens.border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MinuteRadii.card),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accentText,
          minimumSize: const Size(48, 48),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.accentForeground;
          }
          return tokens.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.accent;
          }
          return tokens.surfaceSubtle;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.accent;
          }
          return tokens.textMuted;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.accent;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(tokens.accentForeground),
        side: BorderSide(color: tokens.textSecondary, width: 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? tokens.surfaceSubtle : tokens.textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: MinuteTypography.uiFont,
          color: isDark ? tokens.textPrimary : tokens.background,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MinuteRadii.card),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: hairlineBorder,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(MinuteRadii.card),
          ),
          side: BorderSide(color: tokens.border, width: 1),
        ),
      ),
    );
  }
}
