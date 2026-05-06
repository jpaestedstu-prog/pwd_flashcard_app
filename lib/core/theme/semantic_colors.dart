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
