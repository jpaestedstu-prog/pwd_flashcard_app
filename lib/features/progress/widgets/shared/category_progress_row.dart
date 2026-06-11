import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// A single category's mastery row: icon chip + name + "mastered / total"
/// count + a gradient progress bar.
///
/// Shared by the Student progress screen and the student profile detail screen
/// (which each previously declared a near-identical private row). The name
/// uses [Flexible] + ellipsis and the count is single-line, so the header row
/// never overflows at large font scales.
class CategoryProgressRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int mastered;
  final int total;
  final double percent;

  /// Optional themed card surface (the active skin's `cardSurface(...)`).
  /// When null the row uses the plain `HCColor` surface, so accessibility
  /// modes — which pass null — are unaffected.
  final Color? surface;

  const CategoryProgressRow({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.mastered,
    required this.total,
    required this.percent,
    this.surface,
  });

  @override
  Widget build(BuildContext context) {
    final p = percent.clamp(0.0, 1.0);
    return Semantics(
      label:
          '$label category: $mastered of $total words mastered, ${(p * 100).round()} percent',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface ?? HCColor.of(context).surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8),
                ],
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$mastered / $total',
                        maxLines: 1,
                        style: AppTypography.labelSmall.copyWith(
                          color: HCColor.of(context).textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        LinearProgressIndicator(
                          value: p,
                          minHeight: 8,
                          backgroundColor: HCColor.of(context).border,
                          color: Colors.transparent,
                        ),
                        FractionallySizedBox(
                          widthFactor: p,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  color,
                                  color.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
