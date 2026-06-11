import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'semantic_colors.dart';

/// Main app theme — Soft & Playful (Pastel) theme
/// With rounded shapes, large touch targets, and warm feel.
class AppTheme {
  AppTheme._();

  /// Shared icon-button styling applied to every theme.
  ///
  /// The Back / Menu / Close / Exit (and other) [IconButton]s used across the
  /// app inherit only Flutter defaults otherwise (24px icon). This bumps the
  /// icon to 26 — clearer for child students and low-vision users — and
  /// guarantees a ≥48dp tap target via [MaterialTapTargetSize.padded] even if
  /// a screen overrides padding/constraints. Colors are deliberately left to
  /// inherit from each theme's `colorScheme`, so the high-contrast, dark and
  /// dyslexia variants all stay correct without per-theme overrides.
  static final IconButtonThemeData _iconButtonTheme = IconButtonThemeData(
    style: IconButton.styleFrom(
      iconSize: 26,
      minimumSize: const Size(48, 48),
      tapTargetSize: MaterialTapTargetSize.padded,
    ),
  );

  // ─── Standard (Pastel) Theme ─────────────────────────
  static final ThemeData _lightTheme = _buildLightTheme();
  static ThemeData get light => _lightTheme;

  static ThemeData _buildLightTheme() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Tap reliability: Tooltip's default longPress trigger joins the gesture
    // arena and steals any press held >500ms (our students press slowly).
    // Manual mode never registers the recognizer; mouse-hover tooltips and
    // Semantics labels keep working.
    tooltipTheme:
        const TooltipThemeData(triggerMode: TooltipTriggerMode.manual),
    // InkSparkle (M3 Android default) compiles a shader on the first tap —
    // a 100-300ms hitch on low-end tablets that reads as a dead tap.
    splashFactory: InkRipple.splashFactory,

    // Colors
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      primaryContainer: AppColors.primaryLight,
      secondary: AppColors.secondary,
      secondaryContainer: AppColors.secondaryLight,
      tertiary: AppColors.accent,
      tertiaryContainer: AppColors.accentLight,
      surfaceContainerHighest: AppColors.surfaceVariant,
      surfaceContainerLow: AppColors.surfaceLight,
      outline: AppColors.border,
      outlineVariant: AppColors.border.withValues(alpha: 0.5),
      error: AppColors.error,
      onSecondary: AppColors.textOnPrimary,
      onSurface: AppColors.textPrimary,
    ),
    scaffoldBackgroundColor: AppColors.background,

    // Typography
    textTheme: AppTypography.textTheme,

    // AppBar
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      titleTextStyle: AppTypography.titleLarge.copyWith(
        color: AppColors.textPrimary,
      ),
    ),

    // Cards
    cardTheme: CardThemeData(
      elevation: 4,
      shadowColor: AppColors.primary.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      color: AppColors.cardBackground,
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 4,
        shadowColor: AppColors.primary.withValues(alpha: 0.3),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        textStyle: AppTypography.buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppTypography.buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppTypography.buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),

    // FAB
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.textOnPrimary,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    // Filled Button (M3)
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        textStyle: AppTypography.buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),

    // Icon Button — larger icon + guaranteed tap target (accessibility).
    iconButtonTheme: _iconButtonTheme,

    // Navigation Bar (M3)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primaryLight,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primary, size: 24);
        }
        return const IconThemeData(color: AppColors.textSecondary, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTypography.labelSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          );
        }
        return AppTypography.labelSmall.copyWith(
          color: AppColors.textSecondary,
        );
      }),
      height: 80,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),

    // Input
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textSecondary,
      ),
    ),

    // Dialogs
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 8,
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // Chip
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),

    // Divider
    dividerTheme: DividerThemeData(
      color: AppColors.primary.withValues(alpha: 0.1),
      thickness: 1,
      space: 24,
    ),

    // Transitions
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),

    // Theme extensions — palette-aware semantic colors so
    // SemanticColors.of(context) always resolves on the active theme.
    extensions: const [SemanticColors.defaults],
  );

  // ─── High Contrast Theme (Accessibility) ─────────────
  static final ThemeData _highContrastTheme = _buildHighContrastTheme();
  static ThemeData get highContrast => _highContrastTheme;

  static ThemeData _buildHighContrastTheme() => light.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.hcBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.hcPrimary,
      primaryContainer: Color(0xFF3E2723),
      secondary: AppColors.hcSecondary,
      secondaryContainer: Color(0xFF1B5E20),
      tertiary: AppColors.hcAccent,
      surface: AppColors.hcSurface,
      error: AppColors.hcError,
    ),
    cardTheme: CardThemeData(
      color: AppColors.hcSurface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.hcPrimary, width: 2),
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: AppColors.hcSurface,
      foregroundColor: AppColors.hcText,
      titleTextStyle: AppTypography.titleLarge.copyWith(
        color: AppColors.hcText,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.hcSurface,
      indicatorColor: AppColors.hcPrimary.withValues(alpha: 0.3),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.hcPrimary, size: 24);
        }
        return const IconThemeData(color: AppColors.hcTextSecondary, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTypography.labelSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.hcPrimary,
          );
        }
        return AppTypography.labelSmall.copyWith(
          color: AppColors.hcTextSecondary,
        );
      }),
      height: 80,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 4,
        backgroundColor: AppColors.hcPrimary,
        foregroundColor: Colors.black,
        textStyle: AppTypography.buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.hcPrimary,
        textStyle: AppTypography.buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: AppColors.hcPrimary, width: 2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.hcPrimary,
        textStyle: AppTypography.buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.hcAccent,
      foregroundColor: Colors.black,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.hcPrimary, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.hcBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.hcPrimary, width: 2),
      ),
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.hcTextSecondary,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.hcSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: AppColors.hcPrimary, width: 2),
      ),
      elevation: 8,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.hcPrimary
            : AppColors.hcTextSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.hcPrimary.withValues(alpha: 0.4)
            : AppColors.hcBorder,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.hcPrimary,
      inactiveTrackColor: AppColors.hcBorder,
      thumbColor: AppColors.hcPrimary,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.hcSurface,
      contentTextStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.hcText,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.hcPrimary),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.hcSurface,
      selectedColor: AppColors.hcPrimary,
      labelStyle: AppTypography.labelMedium.copyWith(color: AppColors.hcText),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.hcBorder, width: 1.5),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.hcBorder,
      thickness: 1,
      space: 24,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.hcPrimary,
      linearTrackColor: AppColors.hcBorder,
    ),
  );

  // ─── Dark Theme ──────────────────────────────────────
  static final ThemeData _darkTheme = _buildDarkTheme();
  static ThemeData get dark => _darkTheme;

  static const Color _dkBackground = Color(0xFF121218);
  static const Color _dkSurface = Color(0xFF1E1E2A);
  static const Color _dkCard = Color(0xFF252535);
  static const Color _dkBorder = Color(0xFF3A3A4E);
  static const Color _dkText = Color(0xFFE8E8F0);
  static const Color _dkTextSecondary = Color(0xFF9E9EB8);
  static const Color _dkPrimary = Color(0xFFCEB8F0); // Lighter pastel purple
  static const Color _dkAccent = Color(0xFFF9A8C8); // Lighter pastel pink
  static const Color _dkSecondary = Color(0xFF99DDD6); // Lighter teal

  static ThemeData _buildDarkTheme() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    // Tap reliability + first-tap jank: see _buildLightTheme.
    tooltipTheme:
        const TooltipThemeData(triggerMode: TooltipTriggerMode.manual),
    splashFactory: InkRipple.splashFactory,
    colorScheme: const ColorScheme.dark(
      primary: _dkPrimary,
      primaryContainer: Color(0xFF3D2E5E),
      secondary: _dkSecondary,
      secondaryContainer: Color(0xFF1B4D47),
      tertiary: _dkAccent,
      tertiaryContainer: Color(0xFF5E2A40),
      surface: _dkSurface,
      error: Color(0xFFEF9A9A),
      onPrimary: Color(0xFF1A1A1A),
      onSecondary: Color(0xFF1A1A1A),
      onSurface: _dkText,
      onError: Color(0xFF1A1A1A),
    ),
    scaffoldBackgroundColor: _dkBackground,
    textTheme: AppTypography.textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      foregroundColor: _dkText,
      titleTextStyle: AppTypography.titleLarge.copyWith(color: _dkText),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      color: _dkCard,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 2,
        shadowColor: _dkPrimary.withValues(alpha: 0.3),
        backgroundColor: _dkPrimary,
        foregroundColor: const Color(0xFF1A1A1A),
        textStyle: AppTypography.buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _dkPrimary,
        textStyle: AppTypography.buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: _dkPrimary, width: 2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _dkPrimary,
        textStyle: AppTypography.buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _dkPrimary,
        foregroundColor: const Color(0xFF1A1A1A),
        textStyle: AppTypography.buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    iconButtonTheme: _iconButtonTheme,
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _dkAccent,
      foregroundColor: const Color(0xFF1A1A1A),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _dkSurface,
      indicatorColor: _dkPrimary.withValues(alpha: 0.25),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: _dkPrimary, size: 24);
        }
        return const IconThemeData(color: _dkTextSecondary, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTypography.labelSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: _dkPrimary,
          );
        }
        return AppTypography.labelSmall.copyWith(
          color: _dkTextSecondary,
        );
      }),
      height: 80,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _dkCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _dkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _dkPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF9A9A), width: 2),
      ),
      hintStyle: AppTypography.bodyMedium.copyWith(color: _dkTextSecondary),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: _dkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 8,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _dkCard,
      contentTextStyle: AppTypography.bodyMedium.copyWith(color: _dkText),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? _dkPrimary
            : _dkTextSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? _dkPrimary.withValues(alpha: 0.4)
            : _dkBorder,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: _dkPrimary,
      inactiveTrackColor: _dkBorder,
      thumbColor: _dkPrimary,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _dkCard,
      selectedColor: _dkPrimary,
      labelStyle: AppTypography.labelMedium.copyWith(color: _dkText),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _dkBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: _dkBorder,
      thickness: 1,
      space: 24,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _dkPrimary,
      linearTrackColor: _dkBorder,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    extensions: const [SemanticColors.defaults],
  );

  // ─── Dyslexia-Friendly Theme ─────────────────────────
  //
  // Cream background + Lexend font + generous spacing. Aligned with
  // British Dyslexia Association style guide. Considered an
  // accessibility theme, so it sits above shop themes in the cascade
  // but below high-contrast.
  static final ThemeData _dyslexiaTheme = _buildDyslexiaTheme();
  static ThemeData get dyslexia => _dyslexiaTheme;

  static ThemeData _buildDyslexiaTheme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        // Tap reliability + first-tap jank: see _buildLightTheme.
        tooltipTheme:
            const TooltipThemeData(triggerMode: TooltipTriggerMode.manual),
        splashFactory: InkRipple.splashFactory,
        colorScheme: const ColorScheme.light(
          primary: AppColors.dyslexiaPrimary,
          primaryContainer: AppColors.dyslexiaPrimaryLight,
          secondary: AppColors.dyslexiaSecondary,
          secondaryContainer: AppColors.dyslexiaSecondaryLight,
          tertiary: AppColors.dyslexiaAccent,
          tertiaryContainer: AppColors.dyslexiaAccentLight,
          surface: AppColors.dyslexiaSurface,
          surfaceContainerHighest: AppColors.dyslexiaSurfaceVariant,
          outline: AppColors.dyslexiaBorder,
          error: Color(0xFFB3463E),
          onSecondary: Colors.white,
          onSurface: AppColors.dyslexiaText,
        ),
        scaffoldBackgroundColor: AppColors.dyslexiaBackground,
        textTheme: AppTypography.dyslexiaTextTheme,
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.dyslexiaText,
          titleTextStyle: AppTypography.dyslexiaTextTheme.titleLarge?.copyWith(
            color: AppColors.dyslexiaText,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: AppColors.dyslexiaPrimary.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          color: AppColors.dyslexiaCard,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            backgroundColor: AppColors.dyslexiaPrimary,
            foregroundColor: Colors.white,
            textStyle: AppTypography.dyslexiaTextTheme.labelLarge,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            minimumSize: const Size(56, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.dyslexiaPrimary,
            textStyle: AppTypography.dyslexiaTextTheme.labelLarge,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            minimumSize: const Size(56, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            side: const BorderSide(color: AppColors.dyslexiaPrimary, width: 2),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.dyslexiaPrimary,
            textStyle: AppTypography.dyslexiaTextTheme.labelLarge,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            minimumSize: const Size(56, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.dyslexiaPrimary,
            foregroundColor: Colors.white,
            textStyle: AppTypography.dyslexiaTextTheme.labelLarge,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            minimumSize: const Size(56, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        iconButtonTheme: _iconButtonTheme,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.dyslexiaAccent,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.dyslexiaSurface,
          indicatorColor: AppColors.dyslexiaPrimaryLight,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.dyslexiaPrimary, size: 24);
            }
            return const IconThemeData(color: AppColors.dyslexiaTextSecondary, size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final base = AppTypography.dyslexiaTextTheme.labelSmall;
            if (states.contains(WidgetState.selected)) {
              return base?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.dyslexiaPrimary,
              );
            }
            return base?.copyWith(color: AppColors.dyslexiaTextSecondary);
          }),
          height: 80,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.dyslexiaSurfaceVariant,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.dyslexiaBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.dyslexiaPrimary, width: 2),
          ),
          hintStyle: AppTypography.dyslexiaTextTheme.bodyMedium?.copyWith(
            color: AppColors.dyslexiaTextSecondary,
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.dyslexiaCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 4,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.dyslexiaSurfaceVariant,
          selectedColor: AppColors.dyslexiaPrimary,
          labelStyle: AppTypography.dyslexiaTextTheme.labelMedium?.copyWith(
            color: AppColors.dyslexiaText,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.dyslexiaBorder,
          thickness: 1,
          space: 24,
        ),
        extensions: const [SemanticColors.dyslexia],
      );

  // ─── Shop Themes ─────────────────────────────────────

  /// Lookup a shop theme by its item ID. Accepts both the light SKU
  /// (`theme_ocean`) and the synthetic dark variant (`theme_ocean_dark`)
  /// emitted by [shopThemeDark] — dark variants ship free with the
  /// matching light theme purchase.
  /// Returns null for unknown IDs; caller should fall back to [light].
  static ThemeData? shopTheme(String? themeId) {
    return switch (themeId) {
      'theme_ocean' => _ocean,
      'theme_sunset' => _sunset,
      'theme_forest' => _forest,
      'theme_galaxy' => _galaxy,
      'theme_ocean_dark' => _oceanDark,
      'theme_sunset_dark' => _sunsetDark,
      'theme_forest_dark' => _forestDark,
      'theme_galaxy_dark' => _galaxyDark,
      _ => null,
    };
  }

  /// Lookup the dark variant of the equipped shop theme. Returns null
  /// for non-shop themes so callers can fall through to [dark].
  static ThemeData? shopThemeDark(String? themeId) {
    return switch (themeId) {
      'theme_ocean' || 'theme_ocean_dark' => _oceanDark,
      'theme_sunset' || 'theme_sunset_dark' => _sunsetDark,
      'theme_forest' || 'theme_forest_dark' => _forestDark,
      'theme_galaxy' || 'theme_galaxy_dark' => _galaxyDark,
      _ => null,
    };
  }

  // ── Ocean Theme (cool blues & teals) ──
  static final ThemeData _ocean = _buildShopTheme(
    name: 'Ocean',
    primary: const Color(0xFF0288D1),
    primaryLight: const Color(0xFFB3E5FC),
    secondary: const Color(0xFF00838F),
    secondaryLight: const Color(0xFFB2EBF2),
    accent: const Color(0xFF4DD0E1),
    accentLight: const Color(0xFFE0F7FA),
    background: const Color(0xFFF0F9FF),
    surface: const Color(0xFFFFFFFF),
    card: const Color(0xFFF5FBFF),
    semantic: SemanticColors.ocean,
  );

  // ── Sunset Theme (warm oranges & pinks) ──
  static final ThemeData _sunset = _buildShopTheme(
    name: 'Sunset',
    primary: const Color(0xFFE65100),
    primaryLight: const Color(0xFFFFCC80),
    secondary: const Color(0xFFD81B60),
    secondaryLight: const Color(0xFFF8BBD0),
    accent: const Color(0xFFFF7043),
    accentLight: const Color(0xFFFBE9E7),
    background: const Color(0xFFFFF8F0),
    surface: const Color(0xFFFFFFFF),
    card: const Color(0xFFFFF5EE),
    semantic: SemanticColors.sunset,
  );

  // ── Forest Theme (natural greens & browns) ──
  static final ThemeData _forest = _buildShopTheme(
    name: 'Forest',
    primary: const Color(0xFF2E7D32),
    primaryLight: const Color(0xFFA5D6A7),
    secondary: const Color(0xFF5D4037),
    secondaryLight: const Color(0xFFBCAAA4),
    accent: const Color(0xFF66BB6A),
    accentLight: const Color(0xFFE8F5E9),
    background: const Color(0xFFF1F8E9),
    surface: const Color(0xFFFFFFFF),
    card: const Color(0xFFF5FBF2),
    semantic: SemanticColors.forest,
  );

  // ── Galaxy Theme (cosmic purples & indigos) ──
  static final ThemeData _galaxy = _buildShopTheme(
    name: 'Galaxy',
    primary: const Color(0xFF5C6BC0),
    primaryLight: const Color(0xFFC5CAE9),
    secondary: const Color(0xFF7B1FA2),
    secondaryLight: const Color(0xFFE1BEE7),
    accent: const Color(0xFFAB47BC),
    accentLight: const Color(0xFFF3E5F5),
    background: const Color(0xFFF5F0FF),
    surface: const Color(0xFFFFFFFF),
    card: const Color(0xFFF8F5FF),
    semantic: SemanticColors.galaxy,
  );

  /// Builds a shop theme from the given color palette.
  /// Reuses the light theme's structure/shapes/sizes, just swaps colors.
  static ThemeData _buildShopTheme({
    required String name,
    required Color primary,
    required Color primaryLight,
    required Color secondary,
    required Color secondaryLight,
    required Color accent,
    required Color accentLight,
    required Color background,
    required Color surface,
    required Color card,
    SemanticColors semantic = SemanticColors.defaults,
  }) {
    return light.copyWith(
      extensions: [semantic],
      colorScheme: ColorScheme.light(
        primary: primary,
        primaryContainer: primaryLight,
        secondary: secondary,
        secondaryContainer: secondaryLight,
        tertiary: accent,
        tertiaryContainer: accentLight,
        surface: surface,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: background,
      cardTheme: light.cardTheme.copyWith(
        color: card,
        shadowColor: primary.withValues(alpha: 0.15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 4,
          shadowColor: primary.withValues(alpha: 0.3),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: AppTypography.buttonText,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          minimumSize: const Size(56, 56),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          textStyle: AppTypography.buttonText,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          minimumSize: const Size(56, 56),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          side: BorderSide(color: primary, width: 2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: AppTypography.buttonText,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(56, 56),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primaryLight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary, size: 24);
          }
          return const IconThemeData(color: AppColors.textSecondary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: primary,
            );
          }
          return AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary,
          );
        }),
        height: 80,
        elevation: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primaryLight,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: primaryLight,
        thumbColor: primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: primary.withValues(alpha: 0.1),
        thickness: 1,
        space: 24,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  // ─── Dark Shop Themes ────────────────────────────────
  // Each one mirrors the light shop theme but on a deep tinted
  // background, with the light theme color as a glowing accent.

  static final ThemeData _oceanDark = _buildShopThemeDark(
    primary: AppColors.oceanDkPrimary,
    primaryContainer: AppColors.oceanDkPrimaryLight,
    secondary: AppColors.oceanDkSecondary,
    accent: AppColors.oceanDkAccent,
    background: AppColors.oceanDkBackground,
    surface: AppColors.oceanDkSurface,
    card: AppColors.oceanDkCard,
    border: AppColors.oceanDkBorder,
    semantic: SemanticColors.oceanDark,
  );

  static final ThemeData _sunsetDark = _buildShopThemeDark(
    primary: AppColors.sunsetDkPrimary,
    primaryContainer: AppColors.sunsetDkPrimaryLight,
    secondary: AppColors.sunsetDkSecondary,
    accent: AppColors.sunsetDkAccent,
    background: AppColors.sunsetDkBackground,
    surface: AppColors.sunsetDkSurface,
    card: AppColors.sunsetDkCard,
    border: AppColors.sunsetDkBorder,
    semantic: SemanticColors.sunsetDark,
  );

  static final ThemeData _forestDark = _buildShopThemeDark(
    primary: AppColors.forestDkPrimary,
    primaryContainer: AppColors.forestDkPrimaryLight,
    secondary: AppColors.forestDkSecondary,
    accent: AppColors.forestDkAccent,
    background: AppColors.forestDkBackground,
    surface: AppColors.forestDkSurface,
    card: AppColors.forestDkCard,
    border: AppColors.forestDkBorder,
    semantic: SemanticColors.forestDark,
  );

  static final ThemeData _galaxyDark = _buildShopThemeDark(
    primary: AppColors.galaxyDkPrimary,
    primaryContainer: AppColors.galaxyDkPrimaryLight,
    secondary: AppColors.galaxyDkSecondary,
    accent: AppColors.galaxyDkAccent,
    background: AppColors.galaxyDkBackground,
    surface: AppColors.galaxyDkSurface,
    card: AppColors.galaxyDkCard,
    border: AppColors.galaxyDkBorder,
    semantic: SemanticColors.galaxyDark,
  );

  /// Builds a dark shop-theme variant. Mirrors the structure of the
  /// stock dark theme but with a per-shop primary/accent palette.
  static ThemeData _buildShopThemeDark({
    required Color primary,
    required Color primaryContainer,
    required Color secondary,
    required Color accent,
    required Color background,
    required Color surface,
    required Color card,
    required Color border,
    required SemanticColors semantic,
  }) {
    const onPrimary = Color(0xFF1A1A1A);
    const textOnDark = Color(0xFFE8E8F0);
    const textSecondaryOnDark = Color(0xFFB0B0C8);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      // Tap reliability + first-tap jank: see _buildLightTheme.
      tooltipTheme:
          const TooltipThemeData(triggerMode: TooltipTriggerMode.manual),
      splashFactory: InkRipple.splashFactory,
      colorScheme: ColorScheme.dark(
        primary: primary,
        primaryContainer: primaryContainer,
        secondary: secondary,
        tertiary: accent,
        surface: surface,
        onPrimary: onPrimary,
        onSecondary: onPrimary,
        onSurface: textOnDark,
        outline: border,
      ),
      scaffoldBackgroundColor: background,
      textTheme: AppTypography.textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: textOnDark,
        titleTextStyle: AppTypography.titleLarge.copyWith(color: textOnDark),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        color: card,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          backgroundColor: primary,
          foregroundColor: onPrimary,
          textStyle: AppTypography.buttonText,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          minimumSize: const Size(56, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          textStyle: AppTypography.buttonText,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          minimumSize: const Size(56, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide(color: primary, width: 2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: AppTypography.buttonText,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(56, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          textStyle: AppTypography.buttonText,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          minimumSize: const Size(56, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      iconButtonTheme: _iconButtonTheme,
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.25),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary, size: 24);
          }
          return const IconThemeData(color: textSecondaryOnDark, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: primary,
            );
          }
          return AppTypography.labelSmall.copyWith(color: textSecondaryOnDark);
        }),
        height: 80,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: textSecondaryOnDark),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 8,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: primary,
        labelStyle: AppTypography.labelMedium.copyWith(color: textOnDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 24),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: border,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : textSecondaryOnDark,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.4)
              : border,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: border,
        thumbColor: primary,
      ),
      extensions: [semantic],
    );
  }

  /// Replace a theme's page transitions with an instant fade — used
  /// when `settings.reducedMotion` is on. Page transitions are the
  /// last bit of in-app motion not covered by [Animate.defaultDuration],
  /// so this closes the loop on the reduced-motion contract.
  static ThemeData withReducedMotion(ThemeData theme) {
    const instant = PageTransitionsTheme(builders: {
      TargetPlatform.android: _NoAnimationTransitionBuilder(),
      TargetPlatform.iOS: _NoAnimationTransitionBuilder(),
      TargetPlatform.fuchsia: _NoAnimationTransitionBuilder(),
      TargetPlatform.linux: _NoAnimationTransitionBuilder(),
      TargetPlatform.macOS: _NoAnimationTransitionBuilder(),
      TargetPlatform.windows: _NoAnimationTransitionBuilder(),
    });
    return theme.copyWith(pageTransitionsTheme: instant);
  }
}

/// Page transition builder that returns the destination immediately,
/// no slide/fade/scale. Required for the reduced-motion contract.
class _NoAnimationTransitionBuilder extends PageTransitionsBuilder {
  const _NoAnimationTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
