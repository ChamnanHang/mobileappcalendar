import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Light and dark themes, both derived from an [AppPalette].
///
/// Minimal on purpose: no elevation, no shadows, no gradients, and colour kept
/// for meaning — the accent marks what is selected or actionable, red marks a
/// holiday, gold a holy day. Everything else is a neutral surface or text tier.
class AppTheme {
  AppTheme._();

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  static ThemeData get light => _build(AppPalette.light, Brightness.light);
  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: p.accent,
          brightness: brightness,
        ).copyWith(
          primary: p.accent,
          onPrimary: p.onAccent,
          secondary: p.accent,
          onSecondary: p.onAccent,
          surface: p.surface,
          onSurface: p.textPrimary,
          onSurfaceVariant: p.textSecondary,
          outline: p.border,
          outlineVariant: p.border,
          error: p.holiday,
        );

    final TextTheme text = _textTheme(p);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[p],
      // A plain ripple rather than the sparkle: quieter, and it matches the
      // flat surfaces.
      splashFactory: InkRipple.splashFactory,
      splashColor: p.accentSoft,
      highlightColor: p.surfaceMuted,
      iconTheme: IconThemeData(color: p.textSecondary, size: 22),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        // Inverted, the way both platforms draw transient messages.
        backgroundColor: p.textPrimary,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.background),
        actionTextColor: p.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        isDense: true,
        hintStyle: text.bodyMedium?.copyWith(color: p.textTertiary),
        contentPadding: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.textPrimary,
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: text.labelSmall?.copyWith(color: p.background),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.surfaceMuted,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accentSoft,
        selectionHandleColor: p.accent,
      ),
    );
  }

  static TextTheme _textTheme(AppPalette p) {
    // The platform's system face (SF Pro / Roboto), so nothing is fetched at
    // runtime and the app stays fully offline. Weights are one step lighter
    // than before: in a minimal layout hierarchy comes from size and space,
    // not from everything being bold.
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        color: p.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: p.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 19,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: p.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: p.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: p.textPrimary,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: p.textPrimary),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: p.textPrimary),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, color: p.textSecondary),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: p.textPrimary,
      ),
      labelSmall: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: p.textSecondary,
      ),
    );
  }
}
