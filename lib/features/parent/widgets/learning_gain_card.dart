import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../widgets/rich_empty_states.dart';
import '../../../features/assessment/services/assessment_service.dart';

/// Card that displays the learning gain (pre-test vs post-test) for a child.
///
/// Shows overall improvement percentage + per-category comparison bars.
/// Fetches data from [AssessmentService.getLearningGainReport].
class LearningGainCard extends StatelessWidget {
  final String profileId;

  const LearningGainCard({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final report = AssessmentService.getLearningGainReport(profileId);

    if (report == null) {
      return _NoDataCard(
        hc: hc,
        hasPreTest: AssessmentService.hasCompletedPreTest(profileId),
        hasPostTest: AssessmentService.hasCompletedPostTest(profileId),
      );
    }

    final prePercent = (report.preTestPercentage * 100).round();
    final postPercent = (report.postTestPercentage * 100).round();
    final gainPercent = (report.improvement * 100).round();
    final gains = report.categoryGains;

    // Professional panel chrome for consistency with the other parent
    // dashboard panels; the comparison bars stay as-is.
    return ProPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ─────────────────────
          Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                color: report.hasImproved
                    ? AppColors.success
                    : AppColors.warning,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Learning Gain',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: report.hasImproved
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  report.hasImproved ? '+$gainPercent%' : '$gainPercent%',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: report.hasImproved
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            report.summary,
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),

          const SizedBox(height: 16),

          // ─── Before/After Bars ──────────
          _ComparisonBar(
            label: 'Pre-Test',
            value: prePercent,
            color: AppColors.info,
            hc: hc,
          ),
          const SizedBox(height: 8),
          _ComparisonBar(
            label: 'Post-Test',
            value: postPercent,
            color: AppColors.success,
            hc: hc,
          ),

          // ─── Per-Category Gains ─────────
          if (gains.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Per-Category Breakdown',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: (gains.length * 36.0).clamp(100, 300),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final entry = gains.entries.elementAt(group.x);
                        final label = rodIndex == 0 ? 'Pre' : 'Post';
                        return BarTooltipItem(
                          '${entry.key}\n$label: ${(rod.toY).round()}%',
                          AppTypography.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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
                          if (i < 0 || i >= gains.length) {
                            return const SizedBox();
                          }
                          final name = gains.keys.elementAt(i);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              name.length > 8
                                  ? '${name.substring(0, 7)}…'
                                  : name,
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 8,
                                color: hc.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 25,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}%',
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 8,
                            color: hc.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                  ),
                  gridData: FlGridData(
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: hc.border.withValues(alpha: 0.4),
                      strokeWidth: 0.5,
                    ),
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: gains.entries.toList().asMap().entries.map((
                    entry,
                  ) {
                    final i = entry.key;
                    final cat = entry.value.value;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: (cat.pre * 100).clamp(0, 100),
                          color: AppColors.info,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                        BarChartRodData(
                          toY: (cat.post * 100).clamp(0, 100),
                          color: AppColors.success,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Legend
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: AppColors.info, label: 'Pre-Test'),
                SizedBox(width: 16),
                _LegendDot(color: AppColors.success, label: 'Post-Test'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Comparison Bar ──────────────────────────────

class _ComparisonBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final HCColor hc;

  const _ComparisonBar({
    required this.label,
    required this.value,
    required this.color,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: hc.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              backgroundColor: color.withValues(alpha: 0.12),
              color: color,
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '$value%',
            style: AppTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ─── Legend Dot ───────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
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

// ─── No Data Card ────────────────────────────────

class _NoDataCard extends StatelessWidget {
  final HCColor hc;

  /// Whether the child has completed at least one pre-test. Drives the
  /// CTA copy ("Take baseline test" vs. "Take post-test now").
  final bool hasPreTest;

  /// Whether the child has completed at least one post-test.
  final bool hasPostTest;

  const _NoDataCard({
    required this.hc,
    required this.hasPreTest,
    required this.hasPostTest,
  });

  @override
  Widget build(BuildContext context) {
    final String title;
    final String description;
    final String actionLabel;

    if (!hasPreTest && !hasPostTest) {
      title = "Track your child's progress";
      description =
          'Take a short baseline test now, then a follow-up later. '
          "We'll show how much your child has improved overall and per "
          'category.';
      actionLabel = 'Start baseline test';
    } else if (hasPreTest && !hasPostTest) {
      title = 'Baseline complete — keep practicing!';
      description =
          'Once your child has had time to learn, take the post-test '
          'to see their improvement.';
      actionLabel = 'Take post-test';
    } else {
      // hasPostTest && !hasPreTest — uncommon, but worth a clear nudge.
      title = 'Add a baseline to compare against';
      description =
          'A pre-test snapshot lets us measure how much your child has '
          'gained since starting.';
      actionLabel = 'Take pre-test';
    }

    return ProPanel(
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                color: hc.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Learning Gain',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichEmptyState(
            emoji: '📊',
            title: title,
            description: description,
            accentColor: AppColors.info,
            compact: true,
            actionLabel: actionLabel,
            actionIcon: Icons.play_arrow_rounded,
            onAction: () => context.push('/assessment'),
          ),
        ],
      ),
    );
  }
}
