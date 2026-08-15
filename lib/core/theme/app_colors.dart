import 'package:flutter/material.dart';
import '../../data/models/enums.dart';
import 'theme_marker.dart';

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
  static const Color successDark = Color(
    0xFF2E7D32,
  ); // Dark green (text on success bg)
  static const Color error = Color(0xFFE57373); // Soft red
  static const Color errorLight = Color(0xFFFFCDD2);
  static const Color errorDark = Color(
    0xFFC62828,
  ); // Dark red (text on error bg)
  static const Color warning = Color(0xFFFFD54F); // Soft yellow
  static const Color warningLight = Color(0xFFFFF9C4);
  static const Color warningDark = Color(
    0xFFFF8F00,
  ); // Dark amber (text on warning bg)
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

  // ─── Banner Gradient Colors (Student Home) ─────────
  static const Color playerAccent = Color(0xFF7C4DFF);
  static const Color playerAccentLight = Color(0xFF448AFF);
  static const Color playerAccentPurpleLight = Color(0xFFB388FF);
  static const Color bannerLearningGainStart = Color(0xFF2E7D32);
  static const Color bannerLearningGainEnd = Color(0xFF66BB6A);
  static const Color bannerRecommendStart = Color(0xFF5C6BC0);
  static const Color bannerRecommendEnd = Color(0xFF7E57C2);
  static const Color bannerMoodStart = Color(0xFFF06292);
  static const Color bannerMoodEnd = Color(0xFFE91E63);
  static const Color bannerStickerStart = Color(0xFFFFB74D);
  static const Color bannerStickerEnd = Color(0xFFF57C00);
  static const Color bannerGuidedStart = Color(0xFF26A69A);
  static const Color bannerGuidedEnd = Color(0xFF00897B);
  static const Color bannerAiTutorStart = Color(0xFF42A5F5);
  static const Color bannerAiTutorEnd = Color(0xFF1E88E5);
  static const Color bannerWordHuntStart = Color(0xFFFF7043);
  static const Color bannerWordHuntEnd = Color(0xFFF4511E);
  static const Color bannerMessagingStart = Color(0xFFAB47BC);
  static const Color bannerMessagingEnd = Color(0xFF8E24AA);
  static const Color bannerPeerStart = Color(0xFF66BB6A);
  static const Color bannerPeerEnd = Color(0xFF43A047);
  static const Color bannerNotebookStart = Color(0xFF8D6E63);
  static const Color bannerNotebookEnd = Color(0xFF6D4C41);
  static const Color bannerHardWordsStart = Color(0xFFEF5350);
  static const Color bannerHardWordsEnd = Color(0xFFD32F2F);
  static const Color bannerGoalsStart = Color(0xFFFF8F00);
  static const Color bannerGoalsEnd = Color(0xFFFFA726);
  static const Color bannerSmartReviewStart = Color(0xFF7C4DFF);
  static const Color bannerSmartReviewEnd = Color(0xFF448AFF);

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

  // ─── Dyslexia-Friendly Palette ──────────────────────
  // Per British Dyslexia Association style guide: cream background
  // (avoid pure white glare), muted dark text (avoid pure black for
  // less contrast halo), warm-tinted surfaces, calm blue accents.
  static const Color dyslexiaBackground = Color(0xFFFAF0D7); // Warm cream
  static const Color dyslexiaSurface = Color(0xFFFBF6E9);
  static const Color dyslexiaCard = Color(0xFFFFFCF3);
  static const Color dyslexiaSurfaceVariant = Color(0xFFEFE6CC);
  static const Color dyslexiaPrimary = Color(0xFF2F5DAF); // Calm blue
  static const Color dyslexiaPrimaryLight = Color(0xFFB6CDEC);
  static const Color dyslexiaSecondary = Color(0xFF5A8A6A); // Sage green
  static const Color dyslexiaSecondaryLight = Color(0xFFC7DBC8);
  static const Color dyslexiaAccent = Color(0xFFC57A2A); // Warm amber
  static const Color dyslexiaAccentLight = Color(0xFFF4D9B0);
  static const Color dyslexiaText = Color(0xFF2C2C2C); // Soft black
  static const Color dyslexiaTextSecondary = Color(0xFF5C5C5C);
  static const Color dyslexiaBorder = Color(0xFFD9CDA9);

  // ─── Dark Shop Theme Palettes ───────────────────────
  // Each shop theme gets a dark variant so equipped users have a
  // matched night-mode experience instead of being kicked back to
  // the stock dark theme when they toggle dark mode.

  // Ocean Dark — deep navy, glowing cyan
  static const Color oceanDkBackground = Color(0xFF0A1929);
  static const Color oceanDkSurface = Color(0xFF132F4C);
  static const Color oceanDkCard = Color(0xFF173A5E);
  static const Color oceanDkPrimary = Color(0xFF4FC3F7);
  static const Color oceanDkPrimaryLight = Color(0xFF1976D2);
  static const Color oceanDkSecondary = Color(0xFF4DD0E1);
  static const Color oceanDkAccent = Color(0xFF80DEEA);
  static const Color oceanDkBorder = Color(0xFF1E3A5F);

  // Sunset Dark — deep plum, glowing coral
  static const Color sunsetDkBackground = Color(0xFF1F0F1A);
  static const Color sunsetDkSurface = Color(0xFF301823);
  static const Color sunsetDkCard = Color(0xFF3A1F2C);
  static const Color sunsetDkPrimary = Color(0xFFFFB74D);
  static const Color sunsetDkPrimaryLight = Color(0xFFE65100);
  static const Color sunsetDkSecondary = Color(0xFFF48FB1);
  static const Color sunsetDkAccent = Color(0xFFFF8A65);
  static const Color sunsetDkBorder = Color(0xFF4A2A3A);

  // Forest Dark — deep forest, glowing leaf
  static const Color forestDkBackground = Color(0xFF0F1A12);
  static const Color forestDkSurface = Color(0xFF1B2A1F);
  static const Color forestDkCard = Color(0xFF22332A);
  static const Color forestDkPrimary = Color(0xFF81C784);
  static const Color forestDkPrimaryLight = Color(0xFF2E7D32);
  static const Color forestDkSecondary = Color(0xFFBCAAA4);
  static const Color forestDkAccent = Color(0xFFA5D6A7);
  static const Color forestDkBorder = Color(0xFF2D4434);

  // Galaxy Dark — true cosmic black, glowing purple
  static const Color galaxyDkBackground = Color(0xFF0A0E1A);
  static const Color galaxyDkSurface = Color(0xFF161B2E);
  static const Color galaxyDkCard = Color(0xFF1E2440);
  static const Color galaxyDkPrimary = Color(0xFFB39DDB);
  static const Color galaxyDkPrimaryLight = Color(0xFF5C6BC0);
  static const Color galaxyDkSecondary = Color(0xFFCE93D8);
  static const Color galaxyDkAccent = Color(0xFFE1BEE7);
  static const Color galaxyDkBorder = Color(0xFF2A3258);
}

/// Helper that resolves the app's custom-widget colors for the ACTIVE theme
/// family. Use `HCColor.of(context)` in widgets to get the correct adaptive
/// color.
///
/// Four families, each visually distinct (see [ThemeKind]):
///   • high contrast → dedicated bright-on-black palette (per-profile accent
///     comes from the scheme, so Visual / Hearing / Multiple profiles differ);
///   • dark → the dark scheme's soft pastels (NOT the high-contrast palette —
///     historically dark mode borrowed it, making the two modes identical);
///   • dyslexia → cream surfaces with muted text per the BDA style guide;
///   • light → the classic pastel palette, re-tinted by the scheme so shop /
///     group / accessibility-profile themes follow through automatically.
class HCColor {
  final ThemeKind _kind;

  /// Active color scheme. Lets the accent getters follow the equipped theme
  /// (group themes, shop themes, accessibility-profile themes, dyslexia)
  /// without touching the default theme — whose scheme already equals
  /// [AppColors], so this is a no-op there. Null only for legacy const
  /// construction.
  final ColorScheme? _scheme;

  /// The theme's scaffold background, so [background] matches the real page
  /// color under every theme (dark shop themes, learner palettes, …).
  final Color? _scaffoldBackground;

  /// The theme's card color (from `cardTheme.color`).
  final Color? _cardColor;

  const HCColor._(
    this._kind, [
    this._scheme,
    this._scaffoldBackground,
    this._cardColor,
  ]);

  /// Create from BuildContext — reads the current theme kind + scheme.
  factory HCColor.of(BuildContext context) {
    final theme = Theme.of(context);
    return HCColor._(
      theme.extension<ThemeMarker>()?.kind ??
          (theme.brightness == Brightness.dark
              ? ThemeKind.dark
              : ThemeKind.light),
      theme.colorScheme,
      theme.scaffoldBackgroundColor,
      theme.cardTheme.color,
    );
  }

  /// True ONLY for the high-contrast theme (bright accents on black).
  bool get hc => _kind == ThemeKind.highContrast;

  /// True for any dark-background theme family (dark mode, dark shop and
  /// learner variants, high contrast). Use this — not [hc] — when picking
  /// "light ink on dark paper" rendering.
  bool get isDark => hc || _kind == ThemeKind.dark;

  /// True for the dyslexia-friendly (cream + Lexend) theme.
  bool get isDyslexia => _kind == ThemeKind.dyslexia;

  // Backgrounds & surfaces
  Color get background => hc
      ? AppColors.hcBackground
      : (_scaffoldBackground ?? AppColors.background);
  Color get surface =>
      hc ? AppColors.hcSurface : (_scheme?.surface ?? AppColors.surface);
  Color get surfaceVariant => switch (_kind) {
    ThemeKind.highContrast => const Color(0xFF2C2C2C),
    // Lift the surface slightly so chips/inputs read on dark cards.
    ThemeKind.dark => Color.alphaBlend(
      Colors.white.withValues(alpha: 0.07),
      _scheme?.surface ?? const Color(0xFF1E1E2A),
    ),
    ThemeKind.dyslexia => AppColors.dyslexiaSurfaceVariant,
    ThemeKind.light => AppColors.surfaceVariant,
  };
  Color get surfaceLight => switch (_kind) {
    ThemeKind.highContrast => const Color(0xFF262626),
    ThemeKind.dark => Color.alphaBlend(
      Colors.white.withValues(alpha: 0.05),
      _scheme?.surface ?? const Color(0xFF1E1E2A),
    ),
    ThemeKind.dyslexia => AppColors.dyslexiaSurface,
    ThemeKind.light => AppColors.surfaceLight,
  };
  Color get cardBackground => hc
      ? AppColors.hcSurface
      : (_cardColor ?? _scheme?.surface ?? AppColors.cardBackground);

  // Primary / Secondary / Accent.
  // Always follow the active theme's scheme so the group / shop / dyslexia /
  // accessibility-profile themes (and the per-profile high-contrast accents)
  // re-tint the custom UI. The default light theme's scheme already equals
  // these AppColors, so it stays pixel-identical.
  Color get primary =>
      _scheme?.primary ?? (hc ? AppColors.hcPrimary : AppColors.primary);
  Color get primaryLight => hc
      ? const Color(0xFF3E2723)
      : (_scheme?.primaryContainer ?? AppColors.primaryLight);
  Color get primaryDark => switch (_kind) {
    ThemeKind.highContrast ||
    ThemeKind.dark => _scheme?.primary ?? AppColors.hcPrimary,
    _ => AppColors.primaryDark,
  };
  Color get secondary =>
      _scheme?.secondary ?? (hc ? AppColors.hcSecondary : AppColors.secondary);
  Color get accent =>
      _scheme?.tertiary ?? (hc ? AppColors.hcAccent : AppColors.accent);

  // Text — resolved per theme family so copy is always legible: white on
  // black (HC), soft off-white on dark, muted soft-black on cream (dyslexia),
  // dark blue-grey on pastel (light).
  Color get textPrimary => switch (_kind) {
    ThemeKind.highContrast => AppColors.hcText,
    ThemeKind.dark => _scheme?.onSurface ?? const Color(0xFFE8E8F0),
    ThemeKind.dyslexia => AppColors.dyslexiaText,
    ThemeKind.light => AppColors.textPrimary,
  };
  Color get textSecondary => switch (_kind) {
    ThemeKind.highContrast => AppColors.hcTextSecondary,
    ThemeKind.dark => const Color(0xFFB0B0C8),
    ThemeKind.dyslexia => AppColors.dyslexiaTextSecondary,
    ThemeKind.light => AppColors.textSecondary,
  };
  Color get textHint => switch (_kind) {
    ThemeKind.highContrast => const Color(0xFF757575),
    ThemeKind.dark => const Color(0xFF8888A0),
    ThemeKind.dyslexia => const Color(0xFF8A8271),
    ThemeKind.light => AppColors.textHint,
  };
  Color get textOnPrimary =>
      hc ? Colors.black : (_scheme?.onPrimary ?? AppColors.textOnPrimary);

  // Semantic
  Color get success => hc ? AppColors.hcSuccess : AppColors.success;
  Color get error => hc ? AppColors.hcError : AppColors.error;
  Color get warning => hc ? AppColors.hcWarning : AppColors.warning;
  Color get info => hc ? AppColors.hcInfo : AppColors.info;
  Color get border => switch (_kind) {
    ThemeKind.highContrast => AppColors.hcBorder,
    ThemeKind.dark => const Color(0xFF3A3A4E),
    ThemeKind.dyslexia => AppColors.dyslexiaBorder,
    ThemeKind.light => _scheme?.outline ?? AppColors.border,
  };

  // ─── Stat accents ─────────────────────────────────────
  //
  // Six colour-coded accents for metric tiles and their icons (stars, streak,
  // achievements, words, games, stickers). Distinct from the
  // [success]/[error]/[warning]/[info] semantics above: those mean "this went
  // well / badly", these only tell six metrics apart.
  //
  // Resolved per theme so the value stays legible **on [surface]**. Screens
  // used to hardcode the Material 500 swatches, which do not survive a white
  // card — `Colors.amber` on white is about 1.7:1 — and did not change at all
  // under the dark or high-contrast presets.

  /// Stars. Amber family.
  Color get statWarning => _stat(0xFFB26A00, 0xFFFFD54F, 0xFFFFD740);

  /// Streak. Deep-orange family.
  Color get statError => _stat(0xFFD84315, 0xFFFF8A65, 0xFFFF5252);

  /// Achievements. Purple family.
  Color get statAccent => _stat(0xFF7B1FA2, 0xFFCE93D8, 0xFFE040FB);

  /// Words learned. Blue family.
  Color get statInfo => _stat(0xFF1565C0, 0xFF64B5F6, 0xFF40C4FF);

  /// Games played. Teal family.
  Color get statSuccess => _stat(0xFF00695C, 0xFF4DB6AC, 0xFF00E676);

  /// Stickers. Pink family.
  Color get statSecondary => _stat(0xFFC2185B, 0xFFF48FB1, 0xFFFF80AB);

  /// Picks the [light] (also used for the cream dyslexia paper), [dark] or
  /// [highContrast] variant of a stat accent.
  Color _stat(int light, int dark, int highContrast) => switch (_kind) {
    ThemeKind.highContrast => Color(highContrast),
    ThemeKind.dark => Color(dark),
    ThemeKind.dyslexia || ThemeKind.light => Color(light),
  };

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
          FlashcardCategory.actions => const Color(0xFF18FFFF),
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
          GameType.yesOrNo => const Color(0xFF82B1FF),
          GameType.oddOneOut => const Color(0xFFEA80FC),
          GameType.firstLetter => const Color(0xFFFFAB40),
        }
      : game.color;

  // Gradients.
  // Non-high-contrast gradients are derived from the theme-aware accent getters
  // above, so the home's hero cards follow the active group theme (Classroom
  // blue / Family coral). For the default theme `[primary, secondary]` equals
  // [AppColors.primary, AppColors.secondary] == the old AppColors.primaryGradient,
  // so the stock look is unchanged. In dark mode the gradients use the DEEP
  // container colors instead of the light pastels, so the white copy painted
  // over the hero cards stays clearly readable.
  LinearGradient get primaryGradient => switch (_kind) {
    ThemeKind.highContrast => const LinearGradient(
      colors: [Color(0xFFFFD740), Color(0xFF69F0AE)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    ThemeKind.dark => LinearGradient(
      colors: [
        _scheme?.primaryContainer ?? const Color(0xFF3D2E5E),
        Color.alphaBlend(
          (_scheme?.secondary ?? AppColors.secondary).withValues(alpha: 0.35),
          _scheme?.surface ?? const Color(0xFF1E1E2A),
        ),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    _ => LinearGradient(
      colors: [primary, secondary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  };

  /// Spotlight gradient for the home's hero cards (Player Profile, level badge,
  /// Daily Challenge). Follows the active group theme instead of a fixed hue.
  LinearGradient get heroGradient => switch (_kind) {
    ThemeKind.highContrast => const LinearGradient(
      colors: [Color(0xFFFFD740), Color(0xFF40C4FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    ThemeKind.dark => LinearGradient(
      colors: [
        _scheme?.primaryContainer ?? const Color(0xFF3D2E5E),
        Color.alphaBlend(
          (_scheme?.tertiary ?? AppColors.accent).withValues(alpha: 0.40),
          _scheme?.surface ?? const Color(0xFF1E1E2A),
        ),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    _ => LinearGradient(
      colors: [primary, accent],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  };
}
