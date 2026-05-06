import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/assessment/models/assessment_models.dart';

/// Grouped bar chart comparing pre-test vs post-test scores per category
class LearningGainBarChart extends StatelessWidget {
  final LearningGainReport report;

  const LearningGainBarChart({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final gains = report.categoryGains;
    final categories = gains.keys.toList();

    if (categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.softShadow,
        ),
        child: Center(
          child: Text(
            'No category data available',
            style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 22, color: hc.primary),
              const SizedBox(width: 8),
              Text(
                'Score by Category',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Legend
          const Row(
            children: [
              _LegendDot(color: AppColors.info, label: 'Pre-Test'),
              SizedBox(width: 16),
              _LegendDot(color: AppColors.success, label: 'Post-Test'),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: categories.length * 56.0 + 20,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = rodIndex == 0 ? 'Pre' : 'Post';
                      return BarTooltipItem(
                        '$label: ${rod.toY.round()}%',
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
                        final idx = value.toInt();
                        if (idx < 0 || idx >= categories.length) {
                          return const SizedBox.shrink();
                        }
                        final name = categories[idx];
                        // Truncate long names
                        final display = name.length > 10
                            ? '${name.substring(0, 9)}…'
                            : name;
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            display,
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 9,
                              color: hc.textSecondary,
                            ),
                          ),
                        );
                      },
                      reservedSize: 40,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 9,
                            color: hc.textHint,
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
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: hc.border,
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(categories.length, (i) {
                  final cat = categories[i];
                  final data = gains[cat]!;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: (data.pre * 100).clamp(0, 100),
                        color: AppColors.info,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: (data.post * 100).clamp(0, 100),
                        color: AppColors.success,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary card showing overall learning gain
class LearningGainSummaryCard extends StatelessWidget {
  final LearningGainReport report;

  const LearningGainSummaryCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final prePct = (report.preTestPercentage * 100).round();
    final postPct = (report.postTestPercentage * 100).round();
    final gain = (report.improvement * 100).round();
    final hasImproved = report.hasImproved;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasImproved
              ? [const Color(0xFF00C853), const Color(0xFF69F0AE)]
              : [const Color(0xFFFF6D00), const Color(0xFFFFAB40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (hasImproved
                    ? const Color(0xFF00C853)
                    : const Color(0xFFFF6D00))
                .withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            hasImproved ? '🎉' : '💪',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          Text(
            hasImproved ? 'Great Improvement!' : 'Keep Practicing!',
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.textOnPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            report.summary,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textOnPrimary.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ScoreCircle(
                label: 'Pre-Test',
                score: '$prePct%',
                isPost: false,
              ),
              Column(
                children: [
                  Icon(
                    hasImproved
                        ? Icons.trending_up_rounded
                        : gain == 0
                            ? Icons.trending_flat_rounded
                            : Icons.trending_down_rounded,
                    size: 36,
                    color: AppColors.textOnPrimary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${gain >= 0 ? '+' : ''}$gain%',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              _ScoreCircle(
                label: 'Post-Test',
                score: '$postPct%',
                isPost: true,
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
        );
  }
}

class _ScoreCircle extends StatelessWidget {
  final String label;
  final String score;
  final bool isPost;

  const _ScoreCircle({
    required this.label,
    required this.score,
    required this.isPost,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              score,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textOnPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textOnPrimary.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

/// Category gain detail rows
class CategoryGainList extends StatelessWidget {
  final LearningGainReport report;

  const CategoryGainList({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final gains = report.categoryGains;
    final sorted = gains.entries.toList()
      ..sort((a, b) => b.value.gain.compareTo(a.value.gain));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_list_numbered_rounded,
                  size: 22, color: hc.primary),
              const SizedBox(width: 8),
              Text(
                'Category Breakdown',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final cat = entry.value.key;
            final data = entry.value.value;
            final gain = (data.gain * 100).round();
            final pre = (data.pre * 100).round();
            final post = (data.post * 100).round();
            final isPositive = gain > 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      cat,
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Pre score
                  SizedBox(
                    width: 42,
                    child: Text(
                      '$pre%',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: hc.textHint,
                    ),
                  ),
                  // Post score
                  SizedBox(
                    width: 42,
                    child: Text(
                      '$post%',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? AppColors.success.withValues(alpha: 0.12)
                            : gain == 0
                                ? hc.surfaceVariant
                                : AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive
                                ? Icons.trending_up_rounded
                                : gain == 0
                                    ? Icons.trending_flat_rounded
                                    : Icons.trending_down_rounded,
                            size: 14,
                            color: isPositive
                                ? AppColors.success
                                : gain == 0
                                    ? hc.textHint
                                    : AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${gain >= 0 ? '+' : ''}$gain%',
                            style: AppTypography.labelSmall.copyWith(
                              color: isPositive
                                  ? AppColors.success
                                  : gain == 0
                                      ? hc.textHint
                                      : AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 300.ms, delay: (100 + i * 60).ms)
                .slideX(begin: 0.1, end: 0);
          }),
        ],
      ),
    );
  }
}

/// Assessment score trend line chart
class AssessmentTrendChart extends StatelessWidget {
  final List<({DateTime date, double score})> preTrend;
  final List<({DateTime date, double score})> postTrend;

  const AssessmentTrendChart({
    super.key,
    required this.preTrend,
    required this.postTrend,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final hasData = preTrend.isNotEmpty || postTrend.isNotEmpty;

    if (!hasData) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, size: 22, color: hc.primary),
              const SizedBox(width: 8),
              Text(
                'Score Trend Over Time',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _LegendDot(color: AppColors.info, label: 'Pre-Tests'),
              SizedBox(width: 16),
              _LegendDot(color: AppColors.success, label: 'Post-Tests'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: hc.border,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: 25,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 9,
                          color: hc.textHint,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    
                  ),
                  topTitles: const AxisTitles(
                    
                  ),
                  rightTitles: const AxisTitles(
                    
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  if (preTrend.isNotEmpty)
                    LineChartBarData(
                      spots: preTrend
                          .asMap()
                          .entries
                          .map((e) => FlSpot(
                                e.key.toDouble(),
                                (e.value.score * 100).clamp(0, 100),
                              ))
                          .toList(),
                      isCurved: true,
                      color: AppColors.info,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.info.withValues(alpha: 0.1),
                      ),
                    ),
                  if (postTrend.isNotEmpty)
                    LineChartBarData(
                      spots: postTrend
                          .asMap()
                          .entries
                          .map((e) => FlSpot(
                                e.key.toDouble(),
                                (e.value.score * 100).clamp(0, 100),
                              ))
                          .toList(),
                      isCurved: true,
                      color: AppColors.success,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.success.withValues(alpha: 0.1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: HCColor.of(context).textSecondary,
          ),
        ),
      ],
    );
  }
}
