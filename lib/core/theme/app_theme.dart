import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'semantic_colors.dart';

/// Main app theme — Soft & Playful (Pastel) theme
/// With rounded shapes, large touch targets, and warm feel.
class AppTheme {
  AppTheme._();

  // ─── Standard (Pastel) Theme ─────────────────────────
  static final ThemeData _lightTheme = _buildLightTheme();
  static ThemeData get light => _lightTheme;

  static ThemeData _buildLightTheme() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

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

  // ─── Shop Themes ─────────────────────────────────────

  /// Lookup a shop theme by its item ID.
  /// Returns null for unknown IDs; caller should fall back to [light].
  static ThemeData? shopTheme(String? themeId) {
    return switch (themeId) {
      'theme_ocean' => _ocean,
      'theme_sunset' => _sunset,
      'theme_forest' => _forest,
      'theme_galaxy' => _galaxy,
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
}
