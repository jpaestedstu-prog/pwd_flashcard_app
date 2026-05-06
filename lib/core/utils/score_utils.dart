import 'dart:ui';
import '../theme/app_colors.dart';

/// Returns a colour based on how well the learner scored.
///
/// [fraction] is in the 0.0 – 1.0 range.
Color scoreColor(double fraction) {
  if (fraction >= 0.75) return AppColors.success;
  if (fraction >= 0.50) return AppColors.warning;
  return AppColors.error;
}

/// Convenience wrapper that accepts a 0 – 100 percentage.
Color scoreColorFromPercent(int percent) => scoreColor(percent / 100);
