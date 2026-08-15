import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/models.dart';
import '../../../../l10n/app_localizations.dart';

/// Chart showing how the adaptive difficulty system has adjusted over time.
///
/// Plots recent game scores color-coded by difficulty, showing the
/// system's response to student performance.
class DifficultyHistoryChart extends StatelessWidget {
  final List<GameScore> recentScores;

  const DifficultyHistoryChart({super.key, required this.recentScores});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (recentScores.isEmpty) {
      return _emptyState(context);
    }

    // Group scores by game type and compute difficulty-like metrics
    final dataPoints = <FlSpot>[];
    final tooltipData = <int, _DifficultyPoint>{};

    for (int i = 0; i < recentScores.length; i++) {
      final score = recentScores[i];
      final accuracy = score.total > 0 ? score.score / score.total : 0.0;
      dataPoints.add(FlSpot(i.toDouble(), accuracy * 100));
      tooltipData[i] = _DifficultyPoint(
        gameType: score.gameType,
        accuracy: accuracy,
        starsEarned: score.starsEarned,
        date: score.date,
      );
    }

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
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, color: AppColors.info, size: 22),
              const SizedBox(width: 8),
              Text(
                l10n.chartDifficultyHistory,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.chartDifficultySubtitle,
            style: AppTypography.bodySmall.copyWith(
              color: hc.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Row(
            children: [
              _legendDot(context, AppColors.success, l10n.chartDifficultyHigh),
              const SizedBox(width: 16),
              _legendDot(context, AppColors.warning, l10n.chartDifficultyMedium),
              const SizedBox(width: 16),
              _legendDot(context, AppColors.error, l10n.chartDifficultyLow),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  horizontalInterval: 25,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 25,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
                        style: TextStyle(fontSize: 10, color: hc.textSecondary),
                      ),
                      reservedSize: 40,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (recentScores.length / 5).ceilToDouble().clamp(1, 5),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= recentScores.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '#${idx + 1}',
                            style: TextStyle(fontSize: 9, color: hc.textSecondary),
                          ),
                        );
                      },
                      reservedSize: 20,
                    ),
                  ),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Accuracy line
                  LineChartBarData(
                    spots: dataPoints,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      getDotPainter: (spot, percent, bar, index) {
                        final accuracy = spot.y / 100;
                        final color = accuracy >= 0.8
                            ? AppColors.success
                            : accuracy >= 0.5
                                ? AppColors.warning
                                : AppColors.error;
                        return FlDotCirclePainter(
                          radius: 4,
                          color: color,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  // Target line at 80%
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 80),
                      FlSpot((recentScores.length - 1).toDouble(), 80),
                    ],
                    color: AppColors.success.withValues(alpha: 0.4),
                    barWidth: 1,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        if (spot.barIndex != 0) return null;
                        final point = tooltipData[spot.spotIndex];
                        if (point == null) return null;
                        return LineTooltipItem(
                          '${point.gameType.label}\n'
                          '${(point.accuracy * 100).toStringAsFixed(0)}% • ⭐${point.starsEarned}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
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
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: HCColor.of(context).textSecondary)),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.trending_up_rounded, size: 40, color: AppColors.textHint),
            const SizedBox(height: 8),
            Text(
              l10n.chartDifficultyEmpty,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyPoint {
  final GameType gameType;
  final double accuracy;
  final int starsEarned;
  final DateTime date;

  const _DifficultyPoint({
    required this.gameType,
    required this.accuracy,
    required this.starsEarned,
    required this.date,
  });
}
