import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/responsive_utils.dart';

/// Typography system using Nunito (headings) and Quicksand (body)
/// Optimized for tablet displays (1920×1200) with adaptive sizing.
///
/// Static styles are fixed-size (backward-compat).
/// Context-aware `scaled*` getters auto-scale with [ResponsiveExtension].
class AppTypography {
  AppTypography._();

  // ─── Display ─────────────────────────────────────────
  static TextStyle displayLarge = GoogleFonts.nunito(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle displayMedium = GoogleFonts.nunito(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.2,
  );

  static TextStyle displaySmall = GoogleFonts.nunito(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  // ─── Headings ────────────────────────────────────────
  static TextStyle headlineLarge = GoogleFonts.nunito(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static TextStyle headlineMedium = GoogleFonts.nunito(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle headlineSmall = GoogleFonts.nunito(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // ─── Title ───────────────────────────────────────────
  static TextStyle titleLarge = GoogleFonts.nunito(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );

  static TextStyle titleMedium = GoogleFonts.nunito(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.4,
  );

  static TextStyle titleSmall = GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
  );

  // ─── Body ────────────────────────────────────────────
  static TextStyle bodyLarge = GoogleFonts.quicksand(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.5,
  );

  static TextStyle bodyMedium = GoogleFonts.quicksand(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.25,
    height: 1.5,
  );

  static TextStyle bodySmall = GoogleFonts.quicksand(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    height: 1.5,
  );

  // ─── Label ───────────────────────────────────────────
  static TextStyle labelLarge = GoogleFonts.quicksand(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static TextStyle labelMedium = GoogleFonts.quicksand(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static TextStyle labelSmall = GoogleFonts.quicksand(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
  );

  // ─── Special Styles ──────────────────────────────────
  static TextStyle flashcardWord = GoogleFonts.nunito(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  static TextStyle gameScore = GoogleFonts.nunito(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    height: 1.1,
  );

  /// Round-counter / category title shown above each game prompt.
  /// Slightly smaller than `headlineSmall` so the prompt itself stays
  /// the visual focus.
  static TextStyle gameHeader = GoogleFonts.nunito(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
    height: 1.3,
  );

  /// Question / instruction text in games (e.g. "What word is this sign?").
  /// Larger than bodyLarge with a tighter line height so it reads as a
  /// directive instead of body copy.
  static TextStyle gamePrompt = GoogleFonts.nunito(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  /// Inline hint / helper text shown under the prompt or near a tile.
  static TextStyle gameHint = GoogleFonts.quicksand(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.italic,
    letterSpacing: 0.2,
    height: 1.4,
  );

  static TextStyle buttonText = GoogleFonts.quicksand(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    height: 1.4,
  );

  /// Build a complete [TextTheme] using our typography system
  static TextTheme get textTheme => TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );

  // ─── Context-Aware Scaled Styles ─────────────────────
  //
  // Use these when you need font sizes to adapt to the actual
  // screen width (phones ↔ tablets ↔ large tablets).

  /// Scale a base font size by the context's [fontScaleFactor].
  static double _scaled(BuildContext context, double base) =>
      base * context.fontScaleFactor;

  static TextStyle scaledDisplayLarge(BuildContext context) =>
      displayLarge.copyWith(fontSize: _scaled(context, 40));

  static TextStyle scaledDisplayMedium(BuildContext context) =>
      displayMedium.copyWith(fontSize: _scaled(context, 34));

  static TextStyle scaledDisplaySmall(BuildContext context) =>
      displaySmall.copyWith(fontSize: _scaled(context, 28));

  static TextStyle scaledHeadlineLarge(BuildContext context) =>
      headlineLarge.copyWith(fontSize: _scaled(context, 26));

  static TextStyle scaledHeadlineMedium(BuildContext context) =>
      headlineMedium.copyWith(fontSize: _scaled(context, 22));

  static TextStyle scaledHeadlineSmall(BuildContext context) =>
      headlineSmall.copyWith(fontSize: _scaled(context, 20));

  static TextStyle scaledTitleLarge(BuildContext context) =>
      titleLarge.copyWith(fontSize: _scaled(context, 20));

  static TextStyle scaledTitleMedium(BuildContext context) =>
      titleMedium.copyWith(fontSize: _scaled(context, 18));

  static TextStyle scaledBodyLarge(BuildContext context) =>
      bodyLarge.copyWith(fontSize: _scaled(context, 18));

  static TextStyle scaledBodyMedium(BuildContext context) =>
      bodyMedium.copyWith(fontSize: _scaled(context, 16));

  static TextStyle scaledLabelLarge(BuildContext context) =>
      labelLarge.copyWith(fontSize: _scaled(context, 16));

  // ─── Special Scaled Styles ───────────────────────────

  static TextStyle scaledFlashcardWord(BuildContext context) =>
      flashcardWord.copyWith(fontSize: _scaled(context, 36));

  static TextStyle scaledGameScore(BuildContext context) =>
      gameScore.copyWith(fontSize: _scaled(context, 48));

  static TextStyle scaledButtonText(BuildContext context) =>
      buttonText.copyWith(fontSize: _scaled(context, 18));

}
