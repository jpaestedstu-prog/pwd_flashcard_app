import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/session_tracker.dart';
import '../../../widgets/rich_empty_states.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../widgets/charts/category_radar_chart.dart';
import '../widgets/charts/difficulty_history_chart.dart';
import '../widgets/charts/game_score_bar_chart.dart';
import '../widgets/charts/learning_line_chart.dart';
import '../widgets/charts/spaced_repetition_heatmap.dart';
import '../widgets/charts/star_pie_chart.dart';
import '../widgets/charts/study_time_chart.dart';
import '../../../widgets/app_back_button.dart';

/// Enhanced analytics dashboard with adaptive difficulty history,
/// spaced repetition heatmap, and comprehensive learning insights.
class AdaptiveAnalyticsScreen extends ConsumerWidget {
  const AdaptiveAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final progress = ref.watch(progressProvider);
    final hc = HCColor.of(context);

    if (profile == null) {
      return Scaffold(
        body: RichEmptyState(
          emoji: '👤',
          title: 'No Profile Selected',
          description: 'Select a profile to view adaptive analytics.',
          actionLabel: 'Go Back',
          actionIcon: Icons.arrow_back_rounded,
          onAction: () => context.pop(),
        ),
      );
    }

    final profileId = profile.id;

    // Build category mastery map
    final catMastery = <String, double>{};
    for (final cat in FlashcardCategory.values) {
      catMastery[cat.label] = progress.categoryProgress[cat.label] ?? 0.0;
    }

    final dailyMinutes = SessionTracker.dailyStudyMinutes(profileId);
    final totalMin = SessionTracker.totalStudyMinutes(profileId);
    final avgMin = SessionTracker.averageSessionMinutes(profileId);
    final totalSess = SessionTracker.totalSessions(profileId);
    final totalGames = SessionTracker.totalGamesPlayed(profileId);

    // Compute insights
    final avgAccuracy = progress.recentScores.isNotEmpty
        ? progress.recentScores
            .map((s) => s.total > 0 ? s.score / s.total : 0.0)
            .reduce((a, b) => a + b) / progress.recentScores.length
        : 0.0;

    final masteredCats = catMastery.values.where((v) => v >= 0.8).length;
    final inProgressCats = catMastery.values.where((v) => v > 0 && v < 0.8).length;
    final notStartedCats = catMastery.values.where((v) => v == 0).length;

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          'Adaptive Analytics',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── Insight Cards Row ────────────────
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _InsightCard(
                  icon: Icons.star_rounded,
                  label: 'Stars',
                  value: '${progress.totalStars}',
                  color: hc.warning,
                  hc: hc,
                ),
                _InsightCard(
                  icon: Icons.auto_stories_rounded,
                  label: 'Words',
                  value: '${progress.wordsLearned}',
                  color: hc.secondary,
                  hc: hc,
                ),
                _InsightCard(
                  icon: Icons.timer_rounded,
                  label: 'Study Min',
                  value: '$totalMin',
                  color: hc.info,
                  hc: hc,
                ),
                _InsightCard(
                  icon: Icons.gamepad_rounded,
                  label: 'Games',
                  value: '$totalGames',
                  color: hc.accent,
                  hc: hc,
                ),
                _InsightCard(
                  icon: Icons.gps_fixed_rounded,
                  label: 'Accuracy',
                  value: '${(avgAccuracy * 100).toStringAsFixed(0)}%',
                  color: avgAccuracy >= 0.8
                      ? hc.success
                      : avgAccuracy >= 0.5
                          ? hc.warning
                          : hc.error,
                  hc: hc,
                ),
                _InsightCard(
                  icon: Icons.repeat_rounded,
                  label: 'Sessions',
                  value: '$totalSess',
                  color: hc.primary,
                  hc: hc,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

          const SizedBox(height: 20),

          // ─── Category Mastery Overview ────────
          _SummaryBar(
            masteredCats: masteredCats,
            inProgressCats: inProgressCats,
            notStartedCats: notStartedCats,
            hc: hc,
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

          const SizedBox(height: 20),

          // ─── Spaced Repetition Heatmap ────────
          SpacedRepetitionHeatmap(
            recentScores: progress.recentScores,
            dailyStudyMinutes: dailyMinutes,
          ).animate().fadeIn(duration: 400.ms, delay: 150.ms),

          const SizedBox(height: 20),

          // ─── Difficulty Adaptation History ────
          DifficultyHistoryChart(
            recentScores: progress.recentScores,
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

          const SizedBox(height: 20),

          // ─── Category Radar ───────────────────
          CategoryRadarChart(categoryProgress: catMastery)
              .animate()
              .fadeIn(duration: 400.ms, delay: 250.ms),

          const SizedBox(height: 20),

          // ─── Words Learned Over Time ──────────
          LearningLineChart(
            recentScores: progress.recentScores,
            currentWordsLearned: progress.wordsLearned,
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

          const SizedBox(height: 20),

          // ─── Game Score Comparison ────────────
          GameScoreBarChart(scores: progress.recentScores)
              .animate()
              .fadeIn(duration: 400.ms, delay: 350.ms),

          const SizedBox(height: 20),

          // ─── Daily Study Time ─────────────────
          StudyTimeChart(dailyMinutes: dailyMinutes)
              .animate()
              .fadeIn(duration: 400.ms, delay: 400.ms),

          const SizedBox(height: 20),

          // ─── Star Economy ─────────────────────
          StarPieChart(
            totalStars: progress.totalStars,
            spentStars: progress.spentStars,
          ).animate().fadeIn(duration: 400.ms, delay: 450.ms),

          const SizedBox(height: 20),

          // ─── Session Stats Card ───────────────
          _SessionStatsCard(
            avgMin: avgMin,
            totalSess: totalSess,
            streakDays: progress.streakDays,
            hc: hc,
          ).animate().fadeIn(duration: 400.ms, delay: 500.ms),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Insight Card (horizontal scroll) ─────────────────

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final HCColor hc;

  const _InsightCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              fontSize: 9,
              color: hc.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category Mastery Summary Bar ─────────────────────

class _SummaryBar extends StatelessWidget {
  final int masteredCats;
  final int inProgressCats;
  final int notStartedCats;
  final HCColor hc;

  const _SummaryBar({
    required this.masteredCats,
    required this.inProgressCats,
    required this.notStartedCats,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Overview',
            style: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // Stacked progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 20,
              child: Row(
                children: [
                  if (masteredCats > 0)
                    Expanded(
                      flex: masteredCats,
                      child: Container(color: hc.success),
                    ),
                  if (inProgressCats > 0)
                    Expanded(
                      flex: inProgressCats,
                      child: Container(color: hc.warning),
                    ),
                  if (notStartedCats > 0)
                    Expanded(
                      flex: notStartedCats,
                      child: Container(color: hc.surfaceLight),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _catLabel('🏆', '$masteredCats Mastered', hc.success),
              _catLabel('📖', '$inProgressCats Learning', hc.warning),
              _catLabel('🆕', '$notStartedCats New', AppColors.textHint),
            ],
          ),
        ],
      ),
    );
  }

  Widget _catLabel(String emoji, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTypography.labelSmall.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Session Stats Card ───────────────────────────────

class _SessionStatsCard extends StatelessWidget {
  final double avgMin;
  final int totalSess;
  final int streakDays;
  final HCColor hc;

  const _SessionStatsCard({
    required this.avgMin,
    required this.totalSess,
    required this.streakDays,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: hc.info, size: 22),
              const SizedBox(width: 8),
              Text(
                'Session Insights',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _sessionStat(
                Icons.av_timer_rounded,
                '${avgMin.toStringAsFixed(1)}m',
                'Avg Session',
                hc.info,
              ),
              const SizedBox(width: 12),
              _sessionStat(
                Icons.replay_rounded,
                '$totalSess',
                'Total Sessions',
                hc.accent,
              ),
              const SizedBox(width: 12),
              _sessionStat(
                Icons.local_fire_department_rounded,
                '$streakDays',
                'Day Streak',
                hc.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sessionStat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                fontSize: 9,
                color: hc.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
