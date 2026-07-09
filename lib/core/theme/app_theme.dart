import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../data/models/enums.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'semantic_colors.dart';
import 'theme_marker.dart';

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
    // SemanticColors.of(context) always resolves on the active theme,
    // plus the marker that tells HCColor which theme family is active.
    extensions: const [SemanticColors.defaults, ThemeMarker.light],
  );

  // ─── High Contrast Theme (Accessibility) ─────────────
  //
  // One bright accent on pure black. The accent varies per accessibility
  // profile (see [highContrastFor]) so that Visual / Hearing / Multiple
  // learners — whose presets all enable high contrast — each get a clearly
  // distinct look instead of one identical yellow theme.
  static final ThemeData _highContrastTheme =
      _buildHighContrastTheme(AppColors.hcPrimary);
  static ThemeData get highContrast => _highContrastTheme;

  /// Cached per-profile high-contrast variants.
  static final Map<DisabilityType, ThemeData> _hcVariants = {};

  /// High-contrast theme with the accessibility profile's signature accent:
  /// Visual → yellow (maximum luminance contrast), Hearing → cyan,
  /// Motor → orange, Cognitive → mint green, Multiple → magenta,
  /// None / null → the classic yellow.
  static ThemeData highContrastFor(DisabilityType? type) {
    if (type == null) return _highContrastTheme;
    return _hcVariants.putIfAbsent(type, () {
      final accent = switch (type) {
        DisabilityType.visual => AppColors.hcPrimary, // yellow
        DisabilityType.hearing => const Color(0xFF00E5FF), // cyan
        DisabilityType.motor => const Color(0xFFFFAB40), // orange
        DisabilityType.cognitive => const Color(0xFF69F0AE), // mint
        DisabilityType.multiple => const Color(0xFFEA80FC), // magenta
        DisabilityType.none => AppColors.hcPrimary, // yellow
      };
      return accent == AppColors.hcPrimary
          ? _highContrastTheme
          : _buildHighContrastTheme(accent);
    });
  }

  static ThemeData _buildHighContrastTheme(Color accent) => light.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.hcBackground,
    extensions: const [SemanticColors.highContrast, ThemeMarker.highContrast],
    // The base light theme's textTheme carries BLACK default colors (merged
    // in by ThemeData for light brightness). Without this override, any Text
    // that doesn't set an explicit color renders black-on-black in high
    // contrast — re-ink the whole ramp white.
    textTheme: AppTypography.textTheme.apply(
      bodyColor: AppColors.hcText,
      displayColor: AppColors.hcText,
      decorationColor: AppColors.hcText,
    ),
    // Same story for bare Icon()s — the light base leaves them near-black.
    iconTheme: const IconThemeData(color: AppColors.hcText),
    colorScheme: ColorScheme.dark(
      primary: accent,
      primaryContainer: const Color(0xFF3E2723),
      // Keep the companion accents distinct from the profile accent so
      // success chips / FABs never blend into the primary.
      secondary: accent == AppColors.hcSecondary
          ? AppColors.hcPrimary
          : AppColors.hcSecondary,
      secondaryContainer: const Color(0xFF1B5E20),
      tertiary: accent == AppColors.hcAccent
          ? AppColors.hcPrimary
          : AppColors.hcAccent,
      surface: AppColors.hcSurface,
      error: AppColors.hcError,
    ),
    cardTheme: CardThemeData(
      color: AppColors.hcSurface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: accent, width: 2),
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
      indicatorColor: accent.withValues(alpha: 0.3),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: accent, size: 24);
        }
        return const IconThemeData(color: AppColors.hcTextSecondary, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTypography.labelSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: accent,
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
        backgroundColor: accent,
        foregroundColor: Colors.black,
        textStyle: AppTypography.buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        textStyle: AppTypography.buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: accent, width: 2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        textStyle: AppTypography.buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent == AppColors.hcAccent
          ? AppColors.hcPrimary
          : AppColors.hcAccent,
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
        borderSide: BorderSide(color: accent, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.hcBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accent, width: 2),
      ),
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.hcTextSecondary,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.hcSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: accent, width: 2),
      ),
      elevation: 8,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? accent
            : AppColors.hcTextSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? accent.withValues(alpha: 0.4)
            : AppColors.hcBorder,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: AppColors.hcBorder,
      thumbColor: accent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.hcSurface,
      contentTextStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.hcText,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.hcSurface,
      selectedColor: accent,
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
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
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
    extensions: const [SemanticColors.defaults, ThemeMarker.dark],
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
        // Soft black instead of the pure-black brightness default — per the
        // BDA style guide, lower contrast halo on the cream background.
        textTheme: AppTypography.dyslexiaTextTheme.apply(
          bodyColor: AppColors.dyslexiaText,
          displayColor: AppColors.dyslexiaText,
        ),
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
        extensions: const [SemanticColors.dyslexia, ThemeMarker.dyslexia],
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

  // ─── Profile-group themes (Classroom vs Family) ──────
  // Distinct palettes so the teacher-managed Classroom (Student + Teacher) and
  // the parent-managed Family Group (Child + Parent) read as clearly different
  // environments. Built on the light-theme structure (same shapes / sizes /
  // accessibility), only the colour scheme differs — and applied BELOW the
  // accessibility + shop themes in the cascade (see main.dart), so a learner's
  // accessibility mode or purchased theme always wins.

  /// Classroom group — cool, academic blue / indigo.
  static final ThemeData _classroom = _buildShopTheme(
    name: 'Classroom',
    primary: const Color(0xFF3D5AFE),
    primaryLight: const Color(0xFFD3DAFF),
    secondary: const Color(0xFF0094C6),
    secondaryLight: const Color(0xFFC9EDFB),
    accent: const Color(0xFF4895EF),
    accentLight: const Color(0xFFE2F0FF),
    background: const Color(0xFFF0F3FF),
    surface: const Color(0xFFFFFFFF),
    card: const Color(0xFFF6F8FF),
  );

  /// Family Group — warm, homey coral / orange.
  static final ThemeData _family = _buildShopTheme(
    name: 'Family',
    primary: const Color(0xFFE85D4E),
    primaryLight: const Color(0xFFFFD8D0),
    secondary: const Color(0xFFE8843C),
    secondaryLight: const Color(0xFFFFE3C9),
    accent: const Color(0xFFF4A300),
    accentLight: const Color(0xFFFFEFC7),
    background: const Color(0xFFFFF4EF),
    surface: const Color(0xFFFFFFFF),
    card: const Color(0xFFFFF8F4),
  );

  /// The light group theme for [role], or null for Player / no profile (which
  /// keep the default theme). Classroom = Student + Teacher; Family Group =
  /// Child + Parent. Returned by the light branch of the theme cascade.
  static ThemeData? groupTheme(UserRole? role) => switch (role) {
        UserRole.student || UserRole.teacher => _classroom,
        UserRole.child || UserRole.parent => _family,
        _ => null,
      };

  // ─── Accessibility-profile themes (learners) ─────────
  // Every accessibility category gets its own signature palette so the six
  // profiles are clearly distinct from one another (and from the educator
  // themes). Student (Classroom) profiles keep the cool/neutral backdrop;
  // Child (Family Group) profiles get a visibly warmer wash of the same
  // palette, so Student vs Child stay distinct within each category too.
  //
  //   Visual    → indigo + amber   (high-legibility)
  //   Hearing   → teal + sky       (visual-first)
  //   Motor     → coral + sand     (big & bold)
  //   Cognitive → honey + cream    (calm focus)
  //   Multiple  → violet + rose    (all access)
  //   None      → meadow green     (fresh)
  //
  // Sits below accessibility MODES and shop themes in the cascade, so high
  // contrast / dyslexia / an equipped shop theme always win.

  /// Warm Family-Group wash applied to the Child variant of each palette.
  static Color _warmed(Color base, [int alpha = 0x2E]) =>
      Color.alphaBlend(const Color(0xFFFFA726).withAlpha(alpha), base);

  /// Cached learner themes, keyed by "type-isChild".
  static final Map<String, ThemeData> _learnerThemes = {};
  static final Map<DisabilityType, ThemeData> _learnerDarkThemes = {};

  /// The light theme for a learner's accessibility profile, or null for
  /// educators / players / no profile (they fall through to [groupTheme]).
  static ThemeData? learnerTheme(DisabilityType? type, UserRole? role) {
    if (type == null) return null;
    if (role != UserRole.student && role != UserRole.child) return null;
    final isChild = role == UserRole.child;
    return _learnerThemes.putIfAbsent('${type.name}-$isChild', () {
      final p = _learnerPalette(type);
      return _buildShopTheme(
        name: 'Learner-${type.name}',
        primary: p.primary,
        primaryLight: p.primaryLight,
        secondary: p.secondary,
        secondaryLight: p.secondaryLight,
        accent: p.accent,
        accentLight: p.accentLight,
        background: isChild ? _warmed(p.background) : p.background,
        surface: isChild ? const Color(0xFFFFFDF6) : const Color(0xFFFFFFFF),
        card: isChild ? _warmed(p.card, 0x16) : p.card,
      );
    });
  }

  /// The dark variant of a learner's accessibility-profile theme, or null
  /// when there is no learner profile (falls through to stock [dark]).
  static ThemeData? learnerThemeDark(DisabilityType? type) {
    if (type == null) return null;
    return _learnerDarkThemes.putIfAbsent(type, () {
      final p = _learnerPalette(type);
      return _buildShopThemeDark(
        primary: p.dkPrimary,
        primaryContainer: p.dkPrimaryContainer,
        secondary: p.dkSecondary,
        accent: p.dkAccent,
        background: p.dkBackground,
        surface: p.dkSurface,
        card: p.dkCard,
        border: p.dkBorder,
        semantic: p.dkSemantic,
      );
    });
  }

  static _LearnerPalette _learnerPalette(DisabilityType type) =>
      switch (type) {
        // Visual — indigo + amber, strong hue steps for low vision.
        DisabilityType.visual => const _LearnerPalette(
            primary: Color(0xFF3F51B5),
            primaryLight: Color(0xFFC5CAE9),
            secondary: Color(0xFF00695C),
            secondaryLight: Color(0xFFB2DFDB),
            accent: Color(0xFFFFB300),
            accentLight: Color(0xFFFFECB3),
            background: Color(0xFFEDF0FA),
            card: Color(0xFFF6F8FF),
            dkPrimary: Color(0xFF9FA8DA),
            dkPrimaryContainer: Color(0xFF3949AB),
            dkSecondary: Color(0xFF80CBC4),
            dkAccent: Color(0xFFFFD54F),
            dkBackground: Color(0xFF0E1126),
            dkSurface: Color(0xFF181D3A),
            dkCard: Color(0xFF20264A),
            dkBorder: Color(0xFF2E3560),
            dkSemantic: SemanticColors.galaxyDark,
          ),
        // Hearing — teal + sky, crisp visual-first identity.
        DisabilityType.hearing => const _LearnerPalette(
            primary: Color(0xFF00838F),
            primaryLight: Color(0xFFB2EBF2),
            secondary: Color(0xFF0277BD),
            secondaryLight: Color(0xFFB3E5FC),
            accent: Color(0xFF26C6DA),
            accentLight: Color(0xFFE0F7FA),
            background: Color(0xFFE9F6F8),
            card: Color(0xFFF3FBFC),
            dkPrimary: Color(0xFF4DD0E1),
            dkPrimaryContainer: Color(0xFF00838F),
            dkSecondary: Color(0xFF81D4FA),
            dkAccent: Color(0xFF80DEEA),
            dkBackground: Color(0xFF06222A),
            dkSurface: Color(0xFF0E3440),
            dkCard: Color(0xFF14424F),
            dkBorder: Color(0xFF1D4C5A),
            dkSemantic: SemanticColors.oceanDark,
          ),
        // Motor — coral + sand, generous and bold.
        DisabilityType.motor => const _LearnerPalette(
            primary: Color(0xFFD84315),
            primaryLight: Color(0xFFFFCCBC),
            secondary: Color(0xFF8D6E63),
            secondaryLight: Color(0xFFD7CCC8),
            accent: Color(0xFFFF8A65),
            accentLight: Color(0xFFFBE9E7),
            background: Color(0xFFFDF1EC),
            card: Color(0xFFFFF7F3),
            dkPrimary: Color(0xFFFFAB91),
            dkPrimaryContainer: Color(0xFFBF360C),
            dkSecondary: Color(0xFFBCAAA4),
            dkAccent: Color(0xFFFF8A65),
            dkBackground: Color(0xFF23120C),
            dkSurface: Color(0xFF33201A),
            dkCard: Color(0xFF3E2822),
            dkBorder: Color(0xFF4E3129),
            dkSemantic: SemanticColors.sunsetDark,
          ),
        // Cognitive — honey + cream, low-stimulation warmth. (The preset
        // also enables Dyslexia mode, which then takes precedence; this
        // palette shows when that mode is switched off.)
        DisabilityType.cognitive => const _LearnerPalette(
            primary: Color(0xFF8F5F00),
            primaryLight: Color(0xFFFFE0B2),
            secondary: Color(0xFF6D5B43),
            secondaryLight: Color(0xFFE3D9C6),
            accent: Color(0xFFFFB74D),
            accentLight: Color(0xFFFFF3E0),
            background: Color(0xFFFAF3E3),
            card: Color(0xFFFFFBF0),
            dkPrimary: Color(0xFFFFCC80),
            dkPrimaryContainer: Color(0xFF8F5F00),
            dkSecondary: Color(0xFFD7CCC8),
            dkAccent: Color(0xFFFFB74D),
            dkBackground: Color(0xFF201808),
            dkSurface: Color(0xFF2E2410),
            dkCard: Color(0xFF382C16),
            dkBorder: Color(0xFF4A3B1E),
            dkSemantic: SemanticColors.sunsetDark,
          ),
        // Multiple — violet + rose, every modality welcome.
        DisabilityType.multiple => const _LearnerPalette(
            primary: Color(0xFF7E57C2),
            primaryLight: Color(0xFFD1C4E9),
            secondary: Color(0xFFAD1457),
            secondaryLight: Color(0xFFF8BBD0),
            accent: Color(0xFFBA68C8),
            accentLight: Color(0xFFF3E5F5),
            background: Color(0xFFF4EFFB),
            card: Color(0xFFFAF6FF),
            dkPrimary: Color(0xFFB39DDB),
            dkPrimaryContainer: Color(0xFF5E35B1),
            dkSecondary: Color(0xFFF48FB1),
            dkAccent: Color(0xFFCE93D8),
            dkBackground: Color(0xFF17102A),
            dkSurface: Color(0xFF241A3E),
            dkCard: Color(0xFF2D224C),
            dkBorder: Color(0xFF383060),
            dkSemantic: SemanticColors.galaxyDark,
          ),
        // None — meadow green, fresh and standard.
        DisabilityType.none => const _LearnerPalette(
            primary: Color(0xFF2E7D32),
            primaryLight: Color(0xFFC8E6C9),
            secondary: Color(0xFF00695C),
            secondaryLight: Color(0xFFB2DFDB),
            accent: Color(0xFF9CCC65),
            accentLight: Color(0xFFF1F8E9),
            background: Color(0xFFF0F7EE),
            card: Color(0xFFF7FBF4),
            dkPrimary: Color(0xFF81C784),
            dkPrimaryContainer: Color(0xFF2E7D32),
            dkSecondary: Color(0xFF80CBC4),
            dkAccent: Color(0xFFA5D6A7),
            dkBackground: Color(0xFF0F1B12),
            dkSurface: Color(0xFF1A2B1F),
            dkCard: Color(0xFF223528),
            dkBorder: Color(0xFF2E4636),
            dkSemantic: SemanticColors.forestDark,
          ),
      };

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
      extensions: [semantic, ThemeMarker.light],
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
      extensions: [semantic, ThemeMarker.dark],
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

/// Signature palette for one accessibility category — light + dark colors
/// consumed by [AppTheme.learnerTheme] / [AppTheme.learnerThemeDark].
class _LearnerPalette {
  final Color primary;
  final Color primaryLight;
  final Color secondary;
  final Color secondaryLight;
  final Color accent;
  final Color accentLight;
  final Color background;
  final Color card;
  final Color dkPrimary;
  final Color dkPrimaryContainer;
  final Color dkSecondary;
  final Color dkAccent;
  final Color dkBackground;
  final Color dkSurface;
  final Color dkCard;
  final Color dkBorder;
  final SemanticColors dkSemantic;

  const _LearnerPalette({
    required this.primary,
    required this.primaryLight,
    required this.secondary,
    required this.secondaryLight,
    required this.accent,
    required this.accentLight,
    required this.background,
    required this.card,
    required this.dkPrimary,
    required this.dkPrimaryContainer,
    required this.dkSecondary,
    required this.dkAccent,
    required this.dkBackground,
    required this.dkSurface,
    required this.dkCard,
    required this.dkBorder,
    required this.dkSemantic,
  });
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
