import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/models.dart';
import '../../../../l10n/app_localizations.dart';

/// Line chart showing words learned over the last 30 days.
///
/// Uses [LearningProgress.recentScores] dates + wordsLearned to
/// approximate daily learning. Because we only store the latest
/// cumulative word count, we plot the cumulative value as a running
/// total from game scores.
class LearningLineChart extends StatelessWidget {
  final List<GameScore> recentScores;
  final int currentWordsLearned;

  const LearningLineChart({
    super.key,
    required this.recentScores,
    required this.currentWordsLearned,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Aggregate score counts per day over the last 30 days
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 30));

    // Build daily word-learning events (approximate: correct answers)
    final Map<String, int> dailyWords = {};
    for (final s in recentScores) {
      if (s.date.isAfter(cutoff)) {
        final key =
            '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
        dailyWords[key] = (dailyWords[key] ?? 0) + s.score;
      }
    }

    // Build cumulative list of (dayIndex, cumulativeWords)
    final spots = <FlSpot>[];
    int cumulative = (currentWordsLearned -
            dailyWords.values.fold<int>(0, (a, b) => a + b))
        .clamp(0, currentWordsLearned);

    for (int i = 0; i <= 30; i++) {
      final date = now.subtract(Duration(days: 30 - i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      cumulative += dailyWords[key] ?? 0;
      spots.add(FlSpot(i.toDouble(), cumulative.toDouble()));
    }

    final maxY = spots.map((s) => s.y).fold<double>(1, (a, b) => a > b ? a : b);

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
            l10n.chartWordsLearnedTitle,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.chartWordsLearnedSubtitle,
            style: AppTypography.bodySmall.copyWith(
              color: hc.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 30,
                minY: 0,
                maxY: maxY * 1.1,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((spot) {
                      final date =
                          now.subtract(Duration(days: 30 - spot.x.toInt()));
                      return LineTooltipItem(
                        '${date.month}/${date.day}\n${spot.y.round()} words',
                        AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 4 ? maxY / 4 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 7,
                      getTitlesWidget: (value, meta) {
                        final date = now
                            .subtract(Duration(days: 30 - value.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${date.month}/${date.day}',
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 9,
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
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.secondary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.secondary.withValues(alpha: 0.15),
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
