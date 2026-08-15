import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// Bar chart showing daily study minutes over the last 7 days.
class StudyTimeChart extends StatelessWidget {
  /// Map of date string (e.g. "2026-02-17") to minutes studied.
  final Map<String, int> dailyMinutes;

  const StudyTimeChart({super.key, required this.dailyMinutes});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Get last 7 days
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    });

    final values = days.map((d) => (dailyMinutes[d] ?? 0).toDouble()).toList();
    final maxVal = values.fold<double>(1, (a, b) => a > b ? a : b);

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
            l10n.chartStudyTimeTitle,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.chartStudyTimeSubtitle,
            style: AppTypography.bodySmall.copyWith(
              color: hc.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.round()} ${l10n.chartMinutesShort}',
                        AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox();
                        final day = DateTime.parse(days[i]);
                        final label = _dayLabel(day);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 10,
                              color: hc.textSecondary,
                            ),
                          ),
                        );
                      },
                      reservedSize: 24,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 9,
                            color: hc.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      ),
                  rightTitles: const AxisTitles(
                      ),
                ),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxVal > 4 ? maxVal / 4 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: values.asMap().entries.map((entry) {
                  final i = entry.key;
                  final v = entry.value;
                  final isToday = i == values.length - 1;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: v,
                        color: isToday
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.5),
                        width: 22,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dayLabel(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
}
