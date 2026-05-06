import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Pie / donut chart showing stars earned vs spent vs available.
class StarPieChart extends StatelessWidget {
  final int totalStars;
  final int spentStars;

  const StarPieChart({
    super.key,
    required this.totalStars,
    required this.spentStars,
  });

  int get available => totalStars - spentStars;

  @override
  Widget build(BuildContext context) {
    final hasData = totalStars > 0;
    final hc = HCColor.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stars Overview ⭐',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Earned vs spent',
            style: AppTypography.bodySmall.copyWith(
              color: hc.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (!hasData)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No stars earned yet. Keep learning! ✨',
                  style: AppTypography.bodyMedium.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                // Donut chart
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 140,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 30,
                        sections: [
                          PieChartSectionData(
                            value: available.toDouble(),
                            title: '$available',
                            color: AppColors.warning,
                            radius: 35,
                            titleStyle: AppTypography.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          if (spentStars > 0)
                            PieChartSectionData(
                              value: spentStars.toDouble(),
                              title: '$spentStars',
                              color: AppColors.error.withValues(alpha: 0.7),
                              radius: 30,
                              titleStyle: AppTypography.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Legend
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LegendDot(
                        color: AppColors.warning,
                        label: 'Available',
                        value: '$available',
                      ),
                      const SizedBox(height: 8),
                      _LegendDot(
                        color: AppColors.error.withValues(alpha: 0.7),
                        label: 'Spent',
                        value: '$spentStars',
                      ),
                      const Divider(height: 16),
                      Text(
                        'Total: $totalStars ⭐',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label: $value',
            style: AppTypography.labelSmall.copyWith(
              color: HCColor.of(context).textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
