import 'package:flutter/material.dart';

/// The app's colours, as semantic roles rather than hues.
///
/// Minimal by design: neutral surfaces, three tiers of text, and a single
/// indigo accent. Two colours sit outside that scheme because the calendar
/// needs them to mean something — [holiday] for Sundays and public holidays,
/// the red a Khmer wall calendar uses, and [holy] for Buddhist holy days.
///
/// Registered on both themes as a [ThemeExtension], so every colour follows the
/// system light/dark setting. Read it with `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.holiday,
    required this.holy,
    required this.scrim,
  });

  /// Behind everything.
  final Color background;

  /// Cards, sheets, the nav bar.
  final Color surface;

  /// Chips, pressed states and quiet fills.
  final Color surfaceMuted;

  /// Hairline outlines and dividers.
  final Color border;

  /// Outlines that need to read a little more — a focused field, a handle.
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;

  /// Hints, counts and metadata. Chosen to clear WCAG AA (4.5:1) against both
  /// [background] and [surfaceMuted] in each brightness, since small labels
  /// sit on both.
  final Color textTertiary;

  /// The one interactive colour: selection, today, links, primary buttons.
  final Color accent;

  /// Text and icons drawn on an [accent] fill.
  final Color onAccent;

  /// A tinted fill for selected-but-not-primary states.
  final Color accentSoft;

  /// Sundays, public holidays, and destructive actions.
  final Color holiday;

  /// Buddhist holy days and favourites. It colours the smallest text in the
  /// app — the lunar day under each calendar date — so it too clears AA on
  /// both [background] and [surfaceMuted].
  final Color holy;

  /// Dims content behind a sheet or the open FAB.
  final Color scrim;

  static const AppPalette light = AppPalette(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF3F3F6),
    border: Color(0xFFE6E6EB),
    borderStrong: Color(0xFFCDCDD5),
    textPrimary: Color(0xFF16161A),
    textSecondary: Color(0xFF55555F),
    textTertiary: Color(0xFF6E6E78),
    accent: Color(0xFF4F46E5),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0x1A4F46E5),
    holiday: Color(0xFFD1242F),
    holy: Color(0xFF9A5F0C),
    scrim: Color(0x66000000),
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF0F0F12),
    surface: Color(0xFF17171B),
    surfaceMuted: Color(0xFF212127),
    border: Color(0xFF2A2A31),
    borderStrong: Color(0xFF3C3C45),
    textPrimary: Color(0xFFEDEDF0),
    textSecondary: Color(0xFFA6A6B0),
    textTertiary: Color(0xFF7F7F8A),
    accent: Color(0xFF818CF8),
    onAccent: Color(0xFF0F0F12),
    accentSoft: Color(0x29818CF8),
    holiday: Color(0xFFF87171),
    holy: Color(0xFFE3B341),
    scrim: Color(0x99000000),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? holiday,
    Color? holy,
    Color? scrim,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      holiday: holiday ?? this.holiday,
      holy: holy ?? this.holy,
      scrim: scrim ?? this.scrim,
    );
  }

  /// Interpolated so a system light/dark switch cross-fades instead of
  /// snapping.
  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      accentSoft: mix(accentSoft, other.accentSoft),
      holiday: mix(holiday, other.holiday),
      holy: mix(holy, other.holy),
      scrim: mix(scrim, other.scrim),
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// The palette for the current brightness.
  ///
  /// Falls back to [AppPalette.light] where no app theme is installed, such as
  /// a widget test pumping a bare subtree, rather than throwing.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

/// The colours a note can be tagged with in the editor.
///
/// Stored on the note by index, so the order is fixed: each entry replaced the
/// neon hue it sits in the place of (violet → indigo, cyan → teal, and so on),
/// which keeps existing notes roughly the colour their owner chose. Mid-tone
/// on purpose, so the same swatch reads on both light and dark surfaces.
abstract final class NoteColors {
  static const List<Color> all = <Color>[
    Color(0xFF6366F1), // indigo
    Color(0xFF14B8A6), // teal
    Color(0xFFE11D48), // rose
    Color(0xFF22A06B), // green
    Color(0xFFD97706), // amber
    Color(0xFF64748B), // slate
  ];

  /// Spoken names for [all], so the colour picker is usable without sight.
  static const List<String> names = <String>[
    'Indigo',
    'Teal',
    'Rose',
    'Green',
    'Amber',
    'Slate',
  ];

  static Color at(int index) => all[index.abs() % all.length];
}
