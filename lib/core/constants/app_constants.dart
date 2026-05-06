/// App-wide constants for animations, layout, and game config
class AppConstants {
  AppConstants._();

  // ─── Animation Durations ────────────────────────────
  static const Duration instantDuration = Duration(milliseconds: 100);
  static const Duration fastDuration = Duration(milliseconds: 200);
  static const Duration normalDuration = Duration(milliseconds: 350);
  static const Duration slowDuration = Duration(milliseconds: 500);
  static const Duration pageDuration = Duration(milliseconds: 400);
  static const Duration splashDelay = Duration(milliseconds: 2500);
  static const Duration cardFlipDuration = Duration(milliseconds: 600);
  static const Duration celebrationDuration = Duration(seconds: 3);

  // ─── Stagger Delays ─────────────────────────────────
  static const Duration staggerDelay = Duration(milliseconds: 80);
  static const Duration listItemDelay = Duration(milliseconds: 50);

  // ─── Layout ─────────────────────────────────────────
  // Prefer context.maxContentWidth from ResponsiveExtension for
  // screen-aware values. These constants are fallbacks / defaults.
  static const double maxContentWidth = 1200.0;
  static const double tabletBreakpoint = 600.0;
  static const double cardBorderRadius = 24.0;
  static const double buttonBorderRadius = 20.0;
  static const double minTouchTarget = 56.0;
  static const double pageHorizontalPadding = 24.0;
  static const double pagePaddingTablet = 32.0;
  static const double gridSpacing = 16.0;
  static const int gridColumnsTablet = 2;
  static const int gridColumnsPhone = 1;

  // ─── Flashcard ──────────────────────────────────────
  static const int autoPlayIntervalSeconds = 5;
  static const int cardsPerDeck = 10;

  // ─── Games ──────────────────────────────────────────
  static const int wordMatchRounds = 10;
  static const int wordMatchChoices = 4;
  static const int memoryEasyPairs = 6; // 4×3
  static const int memoryMediumPairs = 8; // 4×4
  static const int memoryHardPairs = 10; // 5×4
  static const int dragDropItems = 5;
  static const int quizCardsPerSession = 15;
  static const int spellingHints = 3;
  static const int gameTimerSeconds = 60;

  // ─── Rewards ────────────────────────────────────────
  static const int starsForPerfect = 3;
  static const int starsForGood = 2;
  static const int starsForOk = 1;
  static const double perfectThreshold = 0.9;
  static const double goodThreshold = 0.7;
  static const int streakMilestone = 7;

  // ─── Hive Box Names ─────────────────────────────────
  static const String profilesBox = 'profiles';
  static const String flashcardsBox = 'flashcards';
  static const String decksBox = 'decks';
  static const String progressBox = 'progress';
  static const String settingsBox = 'settings';

  // ─── Accessibility Defaults ─────────────────────────
  static const double minFontScale = 0.8;
  static const double maxFontScale = 2.0;
  static const double defaultFontScale = 1.0;
  static const double defaultTtsSpeed = 0.5;
  static const double defaultTtsPitch = 1.0;
}
