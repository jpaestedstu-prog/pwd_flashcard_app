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
import '../widgets/charts/game_score_bar_chart.dart';
import '../widgets/charts/learning_line_chart.dart';
import '../widgets/charts/star_pie_chart.dart';
import '../widgets/charts/study_time_chart.dart';
import '../widgets/charts/activity_heatmap.dart';
import '../../../widgets/app_back_button.dart';

/// Full-page analytics dashboard with interactive fl_chart visuals.
class DetailedAnalyticsScreen extends ConsumerWidget {
  const DetailedAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final progress = ref.watch(progressProvider);

    if (profile == null) {
      return Scaffold(
        body: RichEmptyState(
          emoji: '👤',
          title: 'No Profile Selected',
          description: 'Select a profile to view detailed analytics.',
          actionLabel: 'Go Back',
          actionIcon: Icons.arrow_back_rounded,
          onAction: () => context.pop(),
        ),
      );
    }

    final profileId = profile.id;
    final categoryProgress = progress.categoryProgress;

    // Build category mastery map (label -> double)
    final catMastery = <String, double>{};
    for (final cat in FlashcardCategory.values) {
      catMastery[cat.label] = categoryProgress[cat.label] ?? 0.0;
    }

    final dailyMinutes =
        SessionTracker.dailyStudyMinutes(profileId);
    final totalMin = SessionTracker.totalStudyMinutes(profileId);
    final avgMin = SessionTracker.averageSessionMinutes(profileId);
    final totalSess = SessionTracker.totalSessions(profileId);

    return Scaffold(
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
          'Detailed Analytics',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── Summary Row ──────────────────────
          Row(
            children: [
              _MiniStat(
                icon: Icons.star_rounded,
                label: 'Stars',
                value: '${progress.totalStars}',
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              _MiniStat(
                icon: Icons.auto_stories_rounded,
                label: 'Words',
                value: '${progress.wordsLearned}',
                color: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              _MiniStat(
                icon: Icons.timer_rounded,
                label: 'Minutes',
                value: '$totalMin',
                color: AppColors.info,
              ),
              const SizedBox(width: 8),
              _MiniStat(
                icon: Icons.repeat_rounded,
                label: 'Sessions',
                value: '$totalSess',
                color: AppColors.accent,
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.1, end: 0),

          const SizedBox(height: 24),

          // ─── Category Radar ───────────────────
          CategoryRadarChart(categoryProgress: catMastery)
              .animate()
              .fadeIn(duration: 400.ms, delay: 100.ms),

          const SizedBox(height: 20),

          // ─── Words Learned Line Chart ─────────
          LearningLineChart(
            recentScores: progress.recentScores,
            currentWordsLearned: progress.wordsLearned,
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

          const SizedBox(height: 20),

          // ─── Game Score Bar Chart ─────────────
          GameScoreBarChart(scores: progress.recentScores)
              .animate()
              .fadeIn(duration: 400.ms, delay: 300.ms),

          const SizedBox(height: 20),

          // ─── Study Time Bar Chart ─────────────
          StudyTimeChart(dailyMinutes: dailyMinutes)
              .animate()
              .fadeIn(duration: 400.ms, delay: 400.ms),

          const SizedBox(height: 20),

          // ─── Activity Heatmap ─────────────────
          ActivityHeatmap(profileId: profileId)
              .animate()
              .fadeIn(duration: 400.ms, delay: 500.ms),

          const SizedBox(height: 20),

          // ─── Star Pie Chart ───────────────────
          StarPieChart(
            totalStars: progress.totalStars,
            spentStars: progress.spentStars,
          ).animate().fadeIn(duration: 400.ms, delay: 600.ms),

          const SizedBox(height: 20),

          // ─── Avg Session Info ─────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HCColor.of(context).surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.softShadow,
            ),
            child: Row(
              children: [
                const Icon(Icons.insights_rounded,
                    color: AppColors.info, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Average Session',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${avgMin.toStringAsFixed(1)} minutes per session',
                        style: AppTypography.bodySmall.copyWith(
                          color: HCColor.of(context).textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${avgMin.toStringAsFixed(0)}m',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 700.ms),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
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
                color: HCColor.of(context).textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
