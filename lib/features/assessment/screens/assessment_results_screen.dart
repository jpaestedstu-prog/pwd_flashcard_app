import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/score_utils.dart';
import '../../../providers/app_providers.dart';
import '../../../core/accessibility/learner_support.dart';
import '../models/assessment_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../core/utils/localized_date.dart';
import '../models/question_prompt.dart';
import '../providers/assessment_provider.dart';
import '../services/assessment_service.dart';
import '../../../widgets/app_back_button.dart';
import '../../../navigation/nav_extensions.dart';
import '../../../core/widgets/fit_text.dart';

/// Full analytics dashboard showing assessment history, score trends,
/// pre/post comparisons, and category breakdowns over time.
class AssessmentResultsScreen extends ConsumerWidget {
  const AssessmentResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final padding = context.pagePadding;
    final profile = ref.watch(profileProvider);
    final results = ref.watch(assessmentResultsProvider);
    final profileId = profile?.id ?? '';
    final gainReport = AssessmentService.getLearningGainReport(profileId);

    final masteryResults = results
        .where((r) => r.type == AssessmentType.categoryMastery)
        .toList();

    // Only the two halves of the study instrument: a mastery test is not an
    // "attempt" at anything, it is practice, and the history list below
    // already carries it.
    final attempts = <({AssessmentType type, List<AssessmentResult> results})>[
      for (final type in const [
        AssessmentType.preTest,
        AssessmentType.postTest,
      ])
        (type: type, results: AssessmentService.getAttempts(profileId, type)),
    ].where((g) => g.results.isNotEmpty).toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
                child: Row(
                  children: [
                    AppBackButton(
                      fallbackRoute: '/assessment-hub',
                      color: hc.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FitText(
                            (AppLocalizations.of(context) ??
                                    AppLocalizationsEn())
                                .resTitle,
                            style: AppTypography.headlineLarge.copyWith(
                              color: hc.textPrimary,
                            ),
                          ),
                          Text(
                            (AppLocalizations.of(context) ??
                                    AppLocalizationsEn())
                                .resCompletedCount(results.length),
                            style: AppTypography.bodyMedium.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              ),
            ),

            if (results.isEmpty)
              SliverFillRemaining(
                // Scrollable: the emoji is a fixed 64 pt and the copy grows
                // with the font, so this centred column ran off the bottom.
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📊', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text(
                        (AppLocalizations.of(context) ??
                                AppLocalizationsEn())
                            .resEmpty,
                        style: AppTypography.titleMedium.copyWith(
                          color: hc.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => context.popOrGo('/assessment'),
                        child: Text(
                          (AppLocalizations.of(context) ??
                                  AppLocalizationsEn())
                              .resTakeOne,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // ─── Learning Gain Comparison ──────────────
              if (gainReport != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: padding,
                      vertical: 16,
                    ),
                    child: _PrePostComparisonChart(report: gainReport)
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 100.ms)
                        .slideY(begin: 0.1, end: 0),
                  ),
                ),

              // ─── Overall Stats ─────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: _OverallStatsRow(results: results)
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 200.ms)
                      .slideY(begin: 0.1, end: 0),
                ),
              ),

              // ─── Score Trend Chart ─────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 24, padding, 0),
                  child: Text(
                    '📈 ${(AppLocalizations.of(context) ?? AppLocalizationsEn()).resTrend}',
                    style: AppTypography.titleLarge.copyWith(
                      color: hc.textPrimary,
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: padding,
                    vertical: 12,
                  ),
                  child: _ScoreTrendChart(results: results)
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 350.ms)
                      .slideY(begin: 0.1, end: 0),
                ),
              ),

              // ─── Category Mastery Radar ────────────────
              if (masteryResults.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
                    child: Text(
                      '🏆 ${(AppLocalizations.of(context) ?? AppLocalizationsEn()).resCategoryMastery}',
                      style: AppTypography.titleLarge.copyWith(
                        color: hc.textPrimary,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: padding,
                      vertical: 12,
                    ),
                    child: _CategoryMasteryBars(
                      results: masteryResults,
                    ).animate().fadeIn(duration: 500.ms, delay: 450.ms),
                  ),
                ),
              ],

              // ─── Attempts at each half ─────────────────
              // The learning gain is measured from the *newest* pre-test and
              // the *newest* post-test. With only one score ever shown, a
              // learner who retook the pre-test after a fortnight of lessons
              // could not see that their baseline had moved under them.
              if (attempts.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(padding, 16, padding, 8),
                    child: Text(
                      '🔁 ${AppLocalizations.of(context)?.assessYourAttempts ?? 'Your attempts'}',
                      style: AppTypography.titleLarge.copyWith(
                        color: hc.textPrimary,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 470.ms),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final group = attempts[index];
                      return _AttemptsCard(
                        type: group.type,
                        attempts: group.results,
                      ).animate().fadeIn(
                        duration: 400.ms,
                        delay: (490 + index * 60).ms,
                      );
                    }, childCount: attempts.length),
                  ),
                ),
              ],

              // ─── Assessment History List ───────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 8),
                  child: Text(
                    '📋 ${(AppLocalizations.of(context) ?? AppLocalizationsEn()).resHistory}',
                    style: AppTypography.titleLarge.copyWith(
                      color: hc.textPrimary,
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
                ),
              ),

              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final sorted = List.of(results)
                      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
                    final result = sorted[index];
                    return _HistoryTile(result: result)
                        .animate()
                        .fadeIn(duration: 300.ms, delay: (550 + index * 50).ms)
                        .slideX(begin: 0.05, end: 0);
                  }, childCount: results.length),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Pre/Post Comparison Chart ─────────────────────────

class _PrePostComparisonChart extends StatelessWidget {
  final LearningGainReport report;
  const _PrePostComparisonChart({required this.report});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final prePct = (report.preTestPercentage * 100).round();
    final postPct = (report.postTestPercentage * 100).round();
    final gain = (report.improvement * 100).round();
    final improved = report.hasImproved;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                improved
                    ? Icons.trending_up_rounded
                    : Icons.trending_flat_rounded,
                color: improved ? HCColor.of(context).graphic(AppColors.success) : HCColor.of(context).graphic(AppColors.warning),
                size: 28,
              ),
              const SizedBox(width: 10),
              // Expanded, not Text + Spacer: "Pag-unlad sa Pagkatuto" at a
              // large font pushed the gain badge off the card.
              Expanded(
                child: Text(
                  (AppLocalizations.of(context) ?? AppLocalizationsEn())
                      .resLearningGain,
                  style: AppTypography.titleMedium.copyWith(
                    color: hc.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (improved ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${gain >= 0 ? "+" : ""}$gain%',
                  style: AppTypography.labelLarge.copyWith(
                    color: improved ? HCColor.of(context).successText : HCColor.of(context).warningText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.round()}%',
                        AppTypography.labelMedium.copyWith(color: Colors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final label = (value == 0
                                ? AssessmentType.preTest
                                : AssessmentType.postTest)
                            .labelOf(AppLocalizations.of(context));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            style: AppTypography.labelSmall.copyWith(
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
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value % 25 != 0) return const SizedBox.shrink();
                        return Text(
                          '${value.toInt()}%',
                          style: AppTypography.labelSmall.copyWith(
                            color: hc.textHint,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                ),
                gridData: FlGridData(
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: hc.border, strokeWidth: 1),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: prePct.toDouble(),
                        color: const Color(0xFF5C6BC0),
                        width: 40,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: postPct.toDouble(),
                        color: const Color(0xFF00897B),
                        width: 40,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            report.summaryOf(AppLocalizations.of(context)),
            style: AppTypography.bodySmall.copyWith(
              color: hc.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          // Per-category gain breakdown
          if (report.categoryGains.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              (AppLocalizations.of(context) ?? AppLocalizationsEn())
                  .resPerCategoryGains,
              style: AppTypography.labelLarge.copyWith(color: hc.textPrimary),
            ),
            const SizedBox(height: 8),
            ...report.categoryGains.entries.map((entry) {
              final gain = (entry.value.gain * 100).round();
              final positive = gain >= 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        QuestionPrompt.categoryName(
                          entry.key,
                          AppLocalizations.of(context),
                        ),
                        style: AppTypography.bodySmall.copyWith(
                          color: hc.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${positive ? "+" : ""}$gain%',
                      style: AppTypography.labelMedium.copyWith(
                        color: positive ? HCColor.of(context).successText : HCColor.of(context).errorText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─── Overall Stats Row ─────────────────────────────────

class _OverallStatsRow extends StatelessWidget {
  final List<AssessmentResult> results;
  const _OverallStatsRow({required this.results});

  @override
  Widget build(BuildContext context) {
    final totalCorrect = results.fold<int>(0, (sum, r) => sum + r.score);
    final totalQuestions = results.fold<int>(
      0,
      (sum, r) => sum + r.totalQuestions,
    );
    final avgPct = totalQuestions > 0
        ? ((totalCorrect / totalQuestions) * 100).round()
        : 0;
    final totalTime = results.fold<int>(0, (sum, r) => sum + r.durationSeconds);

    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .resAvgScore,
            value: '$avgPct%',
            icon: Icons.bar_chart_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            label: (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .resAssessments,
            value: '${results.length}',
            icon: Icons.assignment_rounded,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            label: (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .resTotalTime,
            value: '${(totalTime / 60).ceil()}m',
            icon: Icons.timer_rounded,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(
              color: hc.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Score Trend Line Chart ────────────────────────────

class _ScoreTrendChart extends StatelessWidget {
  final List<AssessmentResult> results;
  const _ScoreTrendChart({required this.results});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    // Only sittings with a score: one answered on video alone would plot
    // as a fall to 0%.
    final sorted = results.where((r) => r.hasAutoScore).toList()
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    if (sorted.length < 2) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: hc.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .resNeedTwo,
            style: AppTypography.bodySmall.copyWith(color: hc.textHint),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < sorted.length; i++) {
      spots.add(FlSpot(i.toDouble(), sorted[i].percentage * 100));
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hc.border),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            horizontalInterval: 25,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: hc.border, strokeWidth: 1),
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= sorted.length) {
                    return const SizedBox.shrink();
                  }
                  final date = sorted[idx].completedAt;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.month}/${date.day}',
                      style: AppTypography.labelSmall.copyWith(
                        color: hc.textHint,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
                interval: (sorted.length / 5).ceilToDouble().clamp(1, 10),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, _) {
                  if (value % 25 != 0) return const SizedBox.shrink();
                  return Text(
                    '${value.toInt()}%',
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textHint,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: FlDotData(
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 4,
                      color: AppColors.primary,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.round()}%',
                    AppTypography.labelMedium.copyWith(color: Colors.white),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Category Mastery Bars ─────────────────────────────

class _CategoryMasteryBars extends StatelessWidget {
  final List<AssessmentResult> results;
  const _CategoryMasteryBars({required this.results});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    // Aggregate best score per category
    final bestScores = <String, double>{};
    for (final r in results) {
      for (final entry in r.categoryScores.entries) {
        final current = bestScores[entry.key] ?? 0.0;
        if (entry.value > current) {
          bestScores[entry.key] = entry.value;
        }
      }
    }

    if (bestScores.isEmpty) return const SizedBox.shrink();

    final entries = bestScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hc.border),
      ),
      child: Column(
        children: entries.map((entry) {
          final pct = (entry.value * 100).round();
          Color barColor;
          if (entry.value >= 0.75) {
            barColor = AppColors.success;
          } else if (entry.value >= 0.5) {
            barColor = AppColors.warning;
          } else {
            barColor = AppColors.error;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      QuestionPrompt.categoryName(
                        entry.key,
                        AppLocalizations.of(context),
                      ),
                      style: AppTypography.labelMedium.copyWith(
                        color: hc.textPrimary,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: AppTypography.labelMedium.copyWith(
                        color: barColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: entry.value.clamp(0, 1),
                    minHeight: 10,
                    backgroundColor: hc.border,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── History Tile ──────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  final AssessmentResult result;
  const _HistoryTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final pct = (result.percentage * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hc.border),
        ),
        child: Row(
          children: [
            Text(result.type.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.type.labelOf(AppLocalizations.of(context)),
                    style: AppTypography.titleSmall.copyWith(
                      color: hc.textPrimary,
                    ),
                  ),
                  Text(
                    (AppLocalizations.of(context) ?? AppLocalizationsEn())
                        .resHistoryLine(
                          LocalizedDate.monthDay(
                            result.completedAt,
                            AppLocalizations.of(context),
                          ),
                          result.totalQuestions,
                          _formatDuration(result.durationSeconds),
                        ),
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textHint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                if (!result.hasAutoScore)
                  Semantics(
                    label: (AppLocalizations.of(context) ?? AppLocalizationsEn())
                        .assessSentForReview,
                    child: Icon(
                      Icons.videocam_rounded,
                      color: HCColor.of(context).graphic(AppColors.info),
                    ),
                  )
                else
                Text(
                  '$pct%',
                  style: AppTypography.titleMedium.copyWith(
                    color: HCColor.of(context).readableOver(_scoreColor(result.percentage), _scoreColor(result.percentage).withValues(alpha: 0.15)),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  result.gradeOf(AppLocalizations.of(context)),
                  style: AppTypography.labelSmall.copyWith(
                    color: HCColor.of(context).readableOver(_scoreColor(result.percentage), _scoreColor(result.percentage).withValues(alpha: 0.15)),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double pct) => scoreColor(pct);

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    if (min == 0) return '${sec}s';
    return '${min}m ${sec}s';
  }
}

// ─── Attempts at one half of the instrument ────────────

/// Every sitting of one assessment type, newest first, saying plainly which
/// one the learning gain is measured from.
class _AttemptsCard extends StatelessWidget {
  final AssessmentType type;
  final List<AssessmentResult> attempts;

  const _AttemptsCard({required this.type, required this.attempts});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: hc.border),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(type.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    type.labelOf(l10n),
                    style: AppTypography.titleSmall.copyWith(
                      color: hc.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  attempts.length == 1
                      ? (l10n?.assessAttemptsOne ?? '1 attempt')
                      : (l10n?.assessAttemptsMany(attempts.length) ??
                            '${attempts.length} attempts'),
                  style: AppTypography.labelSmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < attempts.length; i++)
              _AttemptRow(
                result: attempts[i],
                // Newest first, so the first row is the one that counts.
                counts: i == 0,
                hc: hc,
              ),
          ],
        ),
      ),
    );
  }
}

class _AttemptRow extends StatelessWidget {
  final AssessmentResult result;
  final bool counts;
  final HCColor hc;

  const _AttemptRow({
    required this.result,
    required this.counts,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (result.percentage * 100).round();
    final accommodated = result.accommodations.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label: [
          (AppLocalizations.of(context) ?? AppLocalizationsEn())
              .resAttemptSemantics(
                pct,
                LocalizedDate.monthDayYear(
                  result.completedAt,
                  AppLocalizations.of(context),
                ),
              ),
          if (counts)
            (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .resAttemptCountsSemantics,
          if (accommodated)
            (AppLocalizations.of(context) ?? AppLocalizationsEn()).resSatWith(
              result.accommodations
                  .map((a) => a.labelOf(AppLocalizations.of(context)))
                  .join(', '),
            ),
        ].join('. '),
        child: ExcludeSemantics(
          // The row is stacked, not a Row: at a large font the date, the badge
          // and the score do not fit across a phone.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '$pct%',
                    style: AppTypography.labelLarge.copyWith(
                      color: scoreColor(result.percentage),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    LocalizedDate.monthDayYear(
                      result.completedAt,
                      AppLocalizations.of(context),
                    ),
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  if (counts)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppLocalizations.of(context)?.assessAttemptCounts ??
                            'Counts',
                        style: AppTypography.labelSmall.copyWith(
                          color: HCColor.of(context).successText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  for (final a in result.accommodations)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${a.emoji} ${a.shortLabelOf(AppLocalizations.of(context))}',
                        style: AppTypography.labelSmall.copyWith(
                          color: HCColor.of(context).infoText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
