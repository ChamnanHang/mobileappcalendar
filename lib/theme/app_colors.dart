import 'package:flutter/material.dart';

/// Palette for the "dark glass + neon" look.
class AppColors {
  AppColors._();

  // Backdrop
  static const Color bg = Color(0xFF06070F);
  static const Color bgAlt = Color(0xFF0B0D1A);

  // Neon accents
  static const Color violet = Color(0xFF7C5CFF);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color pink = Color(0xFFFF5CA8);
  static const Color lime = Color(0xFFA3E635);
  static const Color amber = Color(0xFFFFB020);
  static const Color blue = Color(0xFF4C7DFF);

  static const List<Color> accents = <Color>[
    violet,
    cyan,
    pink,
    lime,
    amber,
    blue,
  ];

  static Color accentAt(int index) => accents[index.abs() % accents.length];

  // Type
  static const Color textHigh = Color(0xFFF2F3FA);
  static Color get textMid => textHigh.withValues(alpha: 0.64);
  static Color get textLow => textHigh.withValues(alpha: 0.38);

  // Glass
  static Color get glassFill => Colors.white.withValues(alpha: 0.055);
  static Color get glassFillStrong => Colors.white.withValues(alpha: 0.10);
  static Color get glassBorder => Colors.white.withValues(alpha: 0.11);
  static Color get glassBorderStrong => Colors.white.withValues(alpha: 0.20);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[violet, cyan],
  );
}
