import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Theme-aware semantic colours (success / warning / error / info) that
/// adapt to the active shop theme.
///
/// The default light theme keeps the existing pastel green / orange / red
/// / blue palette. Each shop theme overrides these so a green "correct!"
/// toast doesn't clash on the warm Sunset palette or the cool Forest one.
///
/// Usage:
/// ```dart
/// final semantic = SemanticColors.of(context);
/// Container(color: semantic.success.withValues(alpha: 0.1), ...)
/// ```
class SemanticColors extends ThemeExtension<SemanticColors> {
  final Color success;
  final Color successLight;
  final Color warning;
  final Color warningLight;
  final Color error;
  final Color errorLight;
  final Color info;
  final Color infoLight;

  const SemanticColors({
    required this.success,
    required this.successLight,
    required this.warning,
    required this.warningLight,
    required this.error,
    required this.errorLight,
    required this.info,
    required this.infoLight,
  });

  /// Default palette — matches the values in [AppColors]. Used by the
  /// stock light and dark themes.
  static const SemanticColors defaults = SemanticColors(
    success: AppColors.success,
    successLight: AppColors.successLight,
    warning: AppColors.warning,
    warningLight: AppColors.warningLight,
    error: AppColors.error,
    errorLight: AppColors.errorLight,
    info: AppColors.info,
    infoLight: AppColors.infoLight,
  );

  /// Cool, ocean-friendly success/error palette.
  static const SemanticColors ocean = SemanticColors(
    success: Color(0xFF00897B), // teal-leaning green
    successLight: Color(0xFFB2DFDB),
    warning: Color(0xFF00ACC1), // cyan instead of orange to stay in palette
    warningLight: Color(0xFFB2EBF2),
    error: Color(0xFFD81B60), // pink-red, contrasts with blues
    errorLight: Color(0xFFF8BBD0),
    info: Color(0xFF1976D2),
    infoLight: Color(0xFFBBDEFB),
  );

  /// Warm, sunset-friendly palette — pulls success toward warm green and
  /// uses a deeper red so it stays distinct from the warm primary.
  static const SemanticColors sunset = SemanticColors(
    success: Color(0xFF558B2F),
    successLight: Color(0xFFDCEDC8),
    warning: Color(0xFFFB8C00),
    warningLight: Color(0xFFFFE0B2),
    error: Color(0xFFC62828),
    errorLight: Color(0xFFFFCDD2),
    info: Color(0xFFE65100),
    infoLight: Color(0xFFFFE0B2),
  );

  /// Earthy, forest-friendly palette.
  static const SemanticColors forest = SemanticColors(
    success: Color(0xFF388E3C),
    successLight: Color(0xFFC8E6C9),
    warning: Color(0xFFEF6C00),
    warningLight: Color(0xFFFFE0B2),
    error: Color(0xFFB71C1C),
    errorLight: Color(0xFFFFCDD2),
    info: Color(0xFF00796B),
    infoLight: Color(0xFFB2DFDB),
  );

  /// Cosmic, galaxy-friendly palette — biased toward bright, vibrant
  /// colours so the toasts don't disappear on the deep purples.
  static const SemanticColors galaxy = SemanticColors(
    success: Color(0xFF26A69A),
    successLight: Color(0xFFB2DFDB),
    warning: Color(0xFFFFB300),
    warningLight: Color(0xFFFFE082),
    error: Color(0xFFE91E63),
    errorLight: Color(0xFFF8BBD0),
    info: Color(0xFF7E57C2),
    infoLight: Color(0xFFD1C4E9),
  );

  /// High-contrast palette — maximum-luminance signals on black, matching
  /// the dedicated hc* colors in [AppColors].
  static const SemanticColors highContrast = SemanticColors(
    success: AppColors.hcSuccess,
    successLight: Color(0xFF003D1F),
    warning: AppColors.hcWarning,
    warningLight: Color(0xFF4A3B00),
    error: AppColors.hcError,
    errorLight: Color(0xFF4A0F0F),
    info: AppColors.hcInfo,
    infoLight: Color(0xFF00344A),
  );

  /// Dyslexia-friendly palette — muted saturation so success/error
  /// signals stand out on a warm cream surface without glare.
  static const SemanticColors dyslexia = SemanticColors(
    success: Color(0xFF5A8A6A),
    successLight: Color(0xFFC7DBC8),
    warning: Color(0xFFC57A2A),
    warningLight: Color(0xFFF4D9B0),
    error: Color(0xFFB3463E),
    errorLight: Color(0xFFEAC7C4),
    info: Color(0xFF2F5DAF),
    infoLight: Color(0xFFB6CDEC),
  );

  /// Dark Ocean — bright cyans against navy.
  static const SemanticColors oceanDark = SemanticColors(
    success: Color(0xFF4DB6AC),
    successLight: Color(0xFF1B4D47),
    warning: Color(0xFF4DD0E1),
    warningLight: Color(0xFF1B5560),
    error: Color(0xFFEC407A),
    errorLight: Color(0xFF5E1A36),
    info: Color(0xFF42A5F5),
    infoLight: Color(0xFF1A3A5C),
  );

  /// Dark Sunset — warm glow against plum.
  static const SemanticColors sunsetDark = SemanticColors(
    success: Color(0xFF9CCC65),
    successLight: Color(0xFF3D5224),
    warning: Color(0xFFFFB74D),
    warningLight: Color(0xFF5E3A12),
    error: Color(0xFFEF5350),
    errorLight: Color(0xFF5E1F1D),
    info: Color(0xFFFFA726),
    infoLight: Color(0xFF5C3210),
  );

  /// Dark Forest — leaf-bright against deep forest.
  static const SemanticColors forestDark = SemanticColors(
    success: Color(0xFF81C784),
    successLight: Color(0xFF1B5E20),
    warning: Color(0xFFFFB74D),
    warningLight: Color(0xFF5E3A12),
    error: Color(0xFFE57373),
    errorLight: Color(0xFF5E1F1D),
    info: Color(0xFF4DB6AC),
    infoLight: Color(0xFF1B4D47),
  );

  /// Dark Galaxy — vibrant magenta/violet against cosmic black.
  static const SemanticColors galaxyDark = SemanticColors(
    success: Color(0xFF4DD0E1),
    successLight: Color(0xFF1B4D5E),
    warning: Color(0xFFFFCA28),
    warningLight: Color(0xFF5E4810),
    error: Color(0xFFF06292),
    errorLight: Color(0xFF5E2240),
    info: Color(0xFFB39DDB),
    infoLight: Color(0xFF2E1F5C),
  );

  /// Convenience lookup that returns [defaults] if no extension is
  /// registered on the active theme.
  static SemanticColors of(BuildContext context) {
    return Theme.of(context).extension<SemanticColors>() ?? defaults;
  }

  @override
  SemanticColors copyWith({
    Color? success,
    Color? successLight,
    Color? warning,
    Color? warningLight,
    Color? error,
    Color? errorLight,
    Color? info,
    Color? infoLight,
  }) {
    return SemanticColors(
      success: success ?? this.success,
      successLight: successLight ?? this.successLight,
      warning: warning ?? this.warning,
      warningLight: warningLight ?? this.warningLight,
      error: error ?? this.error,
      errorLight: errorLight ?? this.errorLight,
      info: info ?? this.info,
      infoLight: infoLight ?? this.infoLight,
    );
  }

  @override
  SemanticColors lerp(ThemeExtension<SemanticColors>? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successLight: Color.lerp(successLight, other.successLight, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningLight: Color.lerp(warningLight, other.warningLight, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorLight: Color.lerp(errorLight, other.errorLight, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoLight: Color.lerp(infoLight, other.infoLight, t)!,
    );
  }
}
