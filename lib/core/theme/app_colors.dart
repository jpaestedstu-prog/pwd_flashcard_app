import 'package:flutter/material.dart';
import '../../data/models/enums.dart';

/// App color palette — Soft & Playful (Pastel) theme
/// Designed for readability and accessibility with
/// optional high-contrast mode for PWD students.
class AppColors {
  AppColors._();

  // ─── Primary Pastel Palette ──────────────────────────
  static const Color primary = Color(0xFFB39DDB); // Soft purple
  static const Color primaryLight = Color(0xFFE6CEFF);
  static const Color primaryDark = Color(0xFF836FA9);

  static const Color secondary = Color(0xFF80CBC4); // Teal
  static const Color secondaryLight = Color(0xFFB2FEF7);
  static const Color secondaryDark = Color(0xFF4F9A94);

  static const Color accent = Color(0xFFF48FB1); // Coral pink
  static const Color accentLight = Color(0xFFFFC1E3);
  static const Color accentDark = Color(0xFFBF5F82);

  // ─── Background & Surface ───────────────────────────
  static const Color background = Color(0xFFFFF8E1); // Warm cream
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F0FF); // Light lavender
  static const Color surfaceLight = Color(0xFFF5F5F5); // Light grey
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFAF8FF);
  static const Color surfaceContainer = Color(0xFFF5F0FF);
  static const Color surfaceContainerHigh = Color(0xFFF0EAFF);
  static const Color surfaceContainerHighest = Color(0xFFEBE4F8);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // ─── Borders ────────────────────────────────────────
  static const Color border = Color(0xFFE0E0E0);

  // ─── Text ───────────────────────────────────────────
  static const Color textPrimary = Color(0xFF37474F); // Dark blue-grey
  static const Color textSecondary = Color(0xFF78909C);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ─── Semantic Colors ────────────────────────────────
  static const Color success = Color(0xFF81C784); // Soft green
  static const Color successLight = Color(0xFFC8E6C9);
  static const Color successDark = Color(0xFF2E7D32); // Dark green (text on success bg)
  static const Color error = Color(0xFFE57373); // Soft red
  static const Color errorLight = Color(0xFFFFCDD2);
  static const Color errorDark = Color(0xFFC62828); // Dark red (text on error bg)
  static const Color warning = Color(0xFFFFD54F); // Soft yellow
  static const Color warningLight = Color(0xFFFFF9C4);
  static const Color warningDark = Color(0xFFFF8F00); // Dark amber (text on warning bg)
  static const Color info = Color(0xFF64B5F6); // Soft blue
  static const Color infoLight = Color(0xFFBBDEFB);

  // ─── Section Header Colors (Home Screen) ───────────
  static const Color sectionLearning = Color(0xFF5C6BC0); // Indigo
  static const Color sectionAssessment = Color(0xFFEF6C00); // Deep orange
  static const Color sectionCommunication = Color(0xFF00897B); // Teal
  static const Color sectionSocial = Color(0xFF1E88E5); // Blue
  static const Color sectionWellbeing = Color(0xFFAB47BC); // Purple

  // ─── Feature Banner Gradient Colors ─────────────────
  static const Color bannerLearningStart = Color(0xFF7E57C2);
  static const Color bannerLearningEnd = Color(0xFF5C6BC0);
  static const Color bannerFslStart = Color(0xFF00897B);
  static const Color bannerFslEnd = Color(0xFF00ACC1);
  static const Color bannerCommBoardStart = Color(0xFF7B1FA2);
  static const Color bannerCommBoardEnd = Color(0xFFAB47BC);
  static const Color bannerAssessmentStart = Color(0xFF00695C);
  static const Color bannerAssessmentEnd = Color(0xFF26A69A);
  static const Color bannerShowcaseStart = Color(0xFF6A1B9A);
  static const Color bannerShowcaseEnd = Color(0xFFAB47BC);

  // ─── Category Colors (unique pastel for each) ──────
  static const Color categoryAnimals = Color(0xFFFFCC80); // Peach orange
  static const Color categoryColors = Color(0xFFEF9A9A); // Soft red
  static const Color categoryNumbers = Color(0xFF90CAF9); // Soft blue
  static const Color categoryBody = Color(0xFFA5D6A7); // Soft green
  static const Color categoryFood = Color(0xFFFFAB91); // Salmon
  static const Color categoryFamily = Color(0xFFCE93D8); // Soft violet

  // ─── Game Colors ────────────────────────────────────
  static const Color gameWordMatch = Color(0xFF80DEEA); // Cyan
  static const Color gameSpelling = Color(0xFFF48FB1); // Pink
  static const Color gameMemory = Color(0xFFA5D6A7); // Green
  static const Color gameDragDrop = Color(0xFFFFCC80); // Orange
  static const Color gameQuiz = Color(0xFFB39DDB); // Purple

  // ─── Gradients ──────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFB39DDB), Color(0xFF80CBC4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFF48FB1), Color(0xFFFFCC80)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient coolGradient = LinearGradient(
    colors: [Color(0xFF80CBC4), Color(0xFF90CAF9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFF48FB1), Color(0xFFCE93D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient splashGradient = LinearGradient(
    colors: [Color(0xFFE6CEFF), Color(0xFFB2FEF7), Color(0xFFFFC1E3)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient gameStartGradient = LinearGradient(
    colors: [Color(0xFFFF9800), Color(0xFFFFD54F)],
  );

  static const LinearGradient rewardGoldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Shadows ────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.15),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ─── High Contrast Palette (Accessibility) ─────────
  static const Color hcBackground = Color(0xFF000000);
  static const Color hcSurface = Color(0xFF1A1A1A);
  static const Color hcPrimary = Color(0xFFFFD740); // Bright yellow
  static const Color hcSecondary = Color(0xFF69F0AE); // Bright green
  static const Color hcAccent = Color(0xFFFF80AB); // Bright pink
  static const Color hcText = Color(0xFFFFFFFF);
  static const Color hcTextSecondary = Color(0xFFB0BEC5);
  static const Color hcSuccess = Color(0xFF00E676);
  static const Color hcError = Color(0xFFFF5252);
  static const Color hcWarning = Color(0xFFFFD740);
  static const Color hcInfo = Color(0xFF40C4FF);
  static const Color hcBorder = Color(0xFF616161);

  // ─── High-Contrast Category Colors ─────────────────
  static const Color hcCategoryAnimals = Color(0xFFFFAB00);
  static const Color hcCategoryColors = Color(0xFFFF5252);
  static const Color hcCategoryNumbers = Color(0xFF40C4FF);
  static const Color hcCategoryBody = Color(0xFF69F0AE);
  static const Color hcCategoryFood = Color(0xFFFF6E40);
  static const Color hcCategoryFamily = Color(0xFFEA80FC);

  // ─── High-Contrast Game Colors ─────────────────────
  static const Color hcGameWordMatch = Color(0xFF00E5FF);
  static const Color hcGameSpelling = Color(0xFFFF80AB);
  static const Color hcGameMemory = Color(0xFF69F0AE);
  static const Color hcGameDragDrop = Color(0xFFFFAB00);
  static const Color hcGameQuiz = Color(0xFFB388FF);
  static const Color hcGamePronunciation = Color(0xFF40C4FF);
}

/// Helper to resolve colors based on the current high-contrast mode.
/// Use `HCColor.of(context)` in widgets to get the correct adaptive color.
class HCColor {
  final bool hc;
  const HCColor._(this.hc);

  /// Create from BuildContext — reads the current theme brightness.
  factory HCColor.of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return HCColor._(brightness == Brightness.dark);
  }

  // Backgrounds & surfaces
  Color get background => hc ? AppColors.hcBackground : AppColors.background;
  Color get surface => hc ? AppColors.hcSurface : AppColors.surface;
  Color get surfaceVariant =>
      hc ? const Color(0xFF2C2C2C) : AppColors.surfaceVariant;
  Color get surfaceLight =>
      hc ? const Color(0xFF262626) : AppColors.surfaceLight;
  Color get cardBackground =>
      hc ? AppColors.hcSurface : AppColors.cardBackground;

  // Primary / Secondary / Accent
  Color get primary => hc ? AppColors.hcPrimary : AppColors.primary;
  Color get primaryLight =>
      hc ? const Color(0xFF3E2723) : AppColors.primaryLight;
  Color get primaryDark => hc ? AppColors.hcPrimary : AppColors.primaryDark;
  Color get secondary => hc ? AppColors.hcSecondary : AppColors.secondary;
  Color get accent => hc ? AppColors.hcAccent : AppColors.accent;

  // Text
  Color get textPrimary => hc ? AppColors.hcText : AppColors.textPrimary;
  Color get textSecondary =>
      hc ? AppColors.hcTextSecondary : AppColors.textSecondary;
  Color get textHint => hc ? const Color(0xFF757575) : AppColors.textHint;
  Color get textOnPrimary => hc ? Colors.black : AppColors.textOnPrimary;

  // Semantic
  Color get success => hc ? AppColors.hcSuccess : AppColors.success;
  Color get error => hc ? AppColors.hcError : AppColors.error;
  Color get warning => hc ? AppColors.hcWarning : AppColors.warning;
  Color get info => hc ? AppColors.hcInfo : AppColors.info;
  Color get border => hc ? AppColors.hcBorder : AppColors.border;

  // Category colors
  Color categoryColor(FlashcardCategory cat) => hc
      ? switch (cat) {
          FlashcardCategory.animals => AppColors.hcCategoryAnimals,
          FlashcardCategory.colorsAndShapes => AppColors.hcCategoryColors,
          FlashcardCategory.numbers => AppColors.hcCategoryNumbers,
          FlashcardCategory.bodyParts => AppColors.hcCategoryBody,
          FlashcardCategory.foodAndDrinks => AppColors.hcCategoryFood,
          FlashcardCategory.familyAndGreetings => AppColors.hcCategoryFamily,
          FlashcardCategory.clothing => const Color(0xFFFFD740),
          FlashcardCategory.weather => const Color(0xFF69F0AE),
          FlashcardCategory.classroom => const Color(0xFF40C4FF),
          FlashcardCategory.transportation => const Color(0xFFFF6E40),
          FlashcardCategory.emotions => const Color(0xFFB388FF),
          FlashcardCategory.daysAndTime => const Color(0xFFFF80AB),
        }
      : cat.color;

  // Game colors
  Color gameColor(GameType game) => hc
      ? switch (game) {
          GameType.wordMatch => AppColors.hcGameWordMatch,
          GameType.spellingBee => AppColors.hcGameSpelling,
          GameType.memoryMatch => AppColors.hcGameMemory,
          GameType.dragAndDrop => AppColors.hcGameDragDrop,
          GameType.flashcardQuiz => AppColors.hcGameQuiz,
          GameType.pronunciation => AppColors.hcGamePronunciation,
          GameType.sentenceBuilder => const Color(0xFFFF6E40),
          GameType.storyQuiz => const Color(0xFFB388FF),
          GameType.tracing => const Color(0xFF80CBC4),
          GameType.fslPractice => const Color(0xFFB388FF),
          GameType.jigsawPuzzle => const Color(0xFFFFE082),
          GameType.pictureWord => const Color(0xFFC5E1A5),
        }
      : game.color;

  // Gradients
  LinearGradient get primaryGradient => hc
      ? const LinearGradient(
          colors: [Color(0xFFFFD740), Color(0xFF69F0AE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : AppColors.primaryGradient;
}
