import 'package:flutter/material.dart';

/// A selectable cosmetic skin for the Progress dashboard.
///
/// Purely decorative: gradients/accents are layered over the existing
/// cards without changing structure. In high-contrast or dyslexia mode the
/// consuming widgets ignore the theme and fall back to `HCColor` so
/// accessibility always wins (see the guard in progress_screen.dart /
/// child_detail_sheet.dart).
@immutable
class ProgressTheme {
  /// Stable key persisted per profile in Hive.
  final String id;
  final String displayName;

  /// Emoji shown on the picker swatch (cheap, localisation-free icon).
  final String emoji;

  /// Header / hero gradient stops (SliverAppBar, sheet header).
  final List<Color> headerGradient;

  /// Accent used for rings, progress bars, badges, chart series.
  final Color accent;

  /// Subtle tint behind cards/sections.
  final Color cardTint;

  /// True when the header gradient is light enough that dark text reads
  /// better than white over it.
  final bool darkHeaderText;

  const ProgressTheme({
    required this.id,
    required this.displayName,
    required this.emoji,
    required this.headerGradient,
    required this.accent,
    required this.cardTint,
    this.darkHeaderText = false,
  });

  /// Convenience LinearGradient for headers and swatches.
  LinearGradient get gradient => LinearGradient(
        colors: headerGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Best-contrast text/icon color to paint over [headerGradient].
  Color get onHeader =>
      darkHeaderText ? const Color(0xFF263238) : Colors.white;

  /// A card/section surface lightly washed with this skin's [cardTint], laid
  /// over the given [base] surface (usually `HCColor.of(context).surface`).
  ///
  /// Callers gate this behind their `useTheme` flag so High-Contrast and
  /// Dyslexia modes keep the plain surface. The blend is intentionally subtle
  /// (low alpha) so text contrast on top is preserved.
  Color cardSurface(Color base) =>
      Color.alphaBlend(cardTint.withValues(alpha: 0.35), base);

  /// A faint accent-tinted border for themed cards.
  Color get cardBorder => accent.withValues(alpha: 0.18);
}
