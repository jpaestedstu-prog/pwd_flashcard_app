import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// A compact, overflow-safe statistic card shared across the Student and Child
/// progress views (streak, stars, words, accuracy, …).
///
/// Reuse-first: replaces the near-duplicate private stat tiles each progress
/// screen used to declare. The value is wrapped in a [FittedBox] and the
/// suffix/label are single-line + ellipsized, so the card never triggers a
/// RenderFlex overflow at large font scales or on narrow tablets.
///
/// Presentation-only: callers pass already-resolved colors (the progress
/// screens compute `useTheme`/`HCColor` and pass the result), so this widget
/// honors High-Contrast and Dyslexia modes without knowing about them.
class ProgressStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String suffix;
  final Color color;

  const ProgressStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.suffix = '',
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = HCColor.of(context).textSecondary;
    return Semantics(
      label: '$label: $value ${suffix.isNotEmpty ? suffix : ''}',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8),
                ],
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            if (suffix.isNotEmpty)
              Text(
                suffix,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(color: textSecondary),
              ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
