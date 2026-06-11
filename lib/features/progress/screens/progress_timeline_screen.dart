import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/session_tracker.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../widgets/charts/activity_heatmap.dart';
import '../../../widgets/app_back_button.dart';

/// Full-screen timeline view for a single student.
///
/// Shows: words learned trend, accuracy trend, daily study time,
/// and an 8-week activity heatmap.
///
/// Navigated from Parent Dashboard (child detail) or Teacher Analytics
/// (student row tap).
class ProgressTimelineScreen extends ConsumerWidget {
  final String profileId;
  final String profileName;

  const ProgressTimelineScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final progress = HiveService.getProgress(profileId);
    final dailyMinutes30 =
        SessionTracker.dailyStudyMinutes(profileId, days: 30);
    final recentScores = progress.recentScores;

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        leading: AppBackButton(
          fallbackRoute: '/progress',
          onBeforePop: () async {
            if (ref.read(profileProvider.notifier).isViewingAsStudent) {
              await ref.read(profileProvider.notifier).restoreEducatorProfile();
            }
            return true;
          },
        ),
        title: Text(
          '$profileName — Timeline',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Summary Stats ──────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _SummaryRow(progress: progress, hc: hc)
                    .animate()
                    .fadeIn(duration: 400.ms),
              ),
            ),

            // ─── Accuracy Trend (30 days) ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _AccuracyTrendChart(
                  recentScores: recentScores,
                  hc: hc,
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
              ),
            ),

            // ─── Study Time (30 days) ───────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _StudyTimeChart30(
                  dailyMinutes: dailyMinutes30,
                  hc: hc,
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
              ),
            ),

            // ─── Category Progress Bars ─────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _CategoryProgressSection(
                  categoryProgress: progress.categoryProgress,
                  hc: hc,
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
              ),
            ),

            // ─── Activity Heatmap (8 weeks) ─
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: ActivityHeatmap(profileId: profileId)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 400.ms),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Row ──────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final LearningProgress progress;
  final HCColor hc;

  const _SummaryRow({required this.progress, required this.hc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          _MiniStat(
            icon: Icons.school_rounded,
            value: '${progress.wordsLearned}',
            label: 'Words',
            color: AppColors.primary,
          ),
          _MiniStat(
            icon: Icons.star_rounded,
            value: '${progress.totalStars}',
            label: 'Stars',
            color: AppColors.warning,
          ),
          _MiniStat(
            icon: Icons.local_fire_department_rounded,
            value: '${progress.streakDays}',
            label: 'Streak',
            color: AppColors.error,
          ),
          _MiniStat(
            icon: Icons.sports_esports_rounded,
            value: '${progress.recentScores.length}',
            label: 'Games',
            color: AppColors.info,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: HCColor.of(context).textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Accuracy Trend Chart ──────────────────────────

class _AccuracyTrendChart extends StatelessWidget {
  final List<GameScore> recentScores;
  final HCColor hc;

  const _AccuracyTrendChart({
    required this.recentScores,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    // Group scores by day over last 30 days → daily avg accuracy
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 30));

    final Map<String, List<double>> dailyAccuracies = {};
    for (final s in recentScores) {
      if (s.date.isAfter(cutoff) && s.total > 0) {
        final key =
            '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
        dailyAccuracies.putIfAbsent(key, () => []).add(s.score / s.total);
      }
    }

    // Build spots: day index (0-30) → avg accuracy
    final spots = <FlSpot>[];
    for (int i = 0; i <= 30; i++) {
      final date = now.subtract(Duration(days: 30 - i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final values = dailyAccuracies[key];
      if (values != null && values.isNotEmpty) {
        final avg = values.reduce((a, b) => a + b) / values.length;
        spots.add(FlSpot(i.toDouble(), (avg * 100).clamp(0, 100)));
      }
    }

    if (spots.isEmpty) {
      return _EmptyChartCard(title: 'Accuracy Trend 📊', hc: hc);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accuracy Trend 📊',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Average daily accuracy — last 30 days',
            style:
                AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      getDotPainter: (spot, pct, bar, index) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: AppColors.primary,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 7,
                      getTitlesWidget: (value, meta) {
                        final day =
                            now.subtract(Duration(days: 30 - value.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${day.month}/${day.day}',
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 9,
                              color: hc.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 25,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 9,
                          color: hc.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      ),
                  rightTitles: const AxisTitles(
                      ),
                ),
                gridData: FlGridData(
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: hc.border.withValues(alpha: 0.5),
                    strokeWidth: 0.5,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) => touchedSpots
                        .map(
                          (s) => LineTooltipItem(
                            '${s.y.round()}%',
                            AppTypography.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Study Time Chart (30 days) ──────────────────────

class _StudyTimeChart30 extends StatelessWidget {
  final Map<String, int> dailyMinutes;
  final HCColor hc;

  const _StudyTimeChart30({
    required this.dailyMinutes,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(30, (i) {
      final date = now.subtract(Duration(days: 29 - i));
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    });

    final values = days.map((d) => (dailyMinutes[d] ?? 0).toDouble()).toList();
    final maxVal = values.fold<double>(1, (a, b) => a > b ? a : b);
    final totalMinutes = values.fold<double>(0, (a, b) => a + b);
    final avgMinutes = totalMinutes / 30;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Time ⏱️',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Minutes per day — last 30 days',
                      style: AppTypography.bodySmall
                          .copyWith(color: hc.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Avg: ${avgMinutes.round()} min/day',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.round()} min',
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
                      interval: 7,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= days.length) {
                          return const SizedBox();
                        }
                        final date = DateTime.parse(days[i]);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${date.month}/${date.day}',
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 8,
                              color: hc.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 9,
                          color: hc.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      ),
                  rightTitles: const AxisTitles(
                      ),
                ),
                gridData: FlGridData(
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: hc.border.withValues(alpha: 0.3),
                    strokeWidth: 0.5,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(30, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i],
                        color: AppColors.secondary,
                        width: 6,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
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

// ─── Category Progress Section ──────────────────────

class _CategoryProgressSection extends StatelessWidget {
  final Map<String, double> categoryProgress;
  final HCColor hc;

  const _CategoryProgressSection({
    required this.categoryProgress,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    if (categoryProgress.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = categoryProgress.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Progress 📚',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...sorted.map((entry) {
            final pct = (entry.value * 100).round();
            final color = pct >= 80
                ? AppColors.success
                : pct >= 50
                    ? AppColors.info
                    : pct >= 20
                        ? AppColors.warning
                        : AppColors.error;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          entry.key,
                          style: AppTypography.bodySmall.copyWith(
                            color: hc.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: AppTypography.labelSmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value.clamp(0.0, 1.0),
                      backgroundColor: color.withValues(alpha: 0.12),
                      color: color,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Empty Chart Card ────────────────────────────────

class _EmptyChartCard extends StatelessWidget {
  final String title;
  final HCColor hc;

  const _EmptyChartCard({required this.title, required this.hc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.border),
      ),
      child: Column(
        children: [
          Text(title,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              )),
          const SizedBox(height: 16),
          Icon(Icons.bar_chart_rounded,
              size: 48, color: hc.textHint),
          const SizedBox(height: 8),
          Text(
            'Not enough data yet',
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
        ],
      ),
    );
  }
}
