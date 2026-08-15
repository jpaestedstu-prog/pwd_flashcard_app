import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/models/achievements.dart';
import '../../../data/local/daily_challenge.dart';
import '../../../core/utils/report_generator.dart';
import '../../../widgets/shared_widgets.dart';
import '../../../core/utils/csv_export_service.dart';
import '../../../core/services/session_tracker.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_back_button.dart';
import '../../../navigation/nav_extensions.dart';

/// Dashboard for Parent/Teacher roles — provides an overview of the
/// student's learning progress, weak areas, and recommendations.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final profile = ref.watch(profileProvider);
    final progress = ref.watch(progressProvider);
    final allCards = ref.watch(allFlashcardsProvider);
    final totalWords = allCards.length;
    final masteredWords = progress.wordsLearned;
    final masteryPct = totalWords > 0
        ? (masteredWords / totalWords).clamp(0.0, 1.0)
        : 0.0;
    final streak = progress.streakDays;
    final totalStars = progress.totalStars;
    final dailyStreak = profile != null
        ? DailyChallenge.getStreak(profile.id)
        : 0;

    // Find weakest & strongest categories
    final categoryScores = FlashcardCategory.values.map((cat) {
      return (cat, progress.categoryProgress[cat.label] ?? 0.0);
    }).toList()..sort((a, b) => a.$2.compareTo(b.$2));
    final weakCategories = categoryScores.take(2).toList();
    final strongCategories = categoryScores.reversed.take(2).toList();
    final hasAnyProgress = categoryScores.any((e) => e.$2 > 0);

    // Recent game stats
    final recentScores = progress.recentScores;
    final recentAvgPct = recentScores.isNotEmpty
        ? recentScores
                  .map((s) => s.total > 0 ? s.score / s.total : 0.0)
                  .reduce((a, b) => a + b) /
              recentScores.length
        : 0.0;

    // Achievements
    final unlockedIds = Achievements.unlockedIds(progress);
    final totalAchievements = Achievements.all.length;
    final unlockedCount = unlockedIds.length;

    // Check if educator is viewing a student's dashboard
    final isViewingAsStudent = ref
        .read(profileProvider.notifier)
        .isViewingAsStudent;
    final viewingLabel = isViewingAsStudent
        ? '${profile?.name ?? 'Student'} Dashboard'
        : '${profile?.role.label ?? 'Teacher'} Dashboard';

    return PopScope(
      canPop: !isViewingAsStudent,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (isViewingAsStudent) {
          await ref.read(profileProvider.notifier).restoreEducatorProfile();
        }
        if (context.mounted) context.popOrGo('/home');
      },
      child: Scaffold(
        appBar: AppBar(
          leading: AppBackButton(
            onBeforePop: () async {
              if (isViewingAsStudent) {
                await ref
                    .read(profileProvider.notifier)
                    .restoreEducatorProfile();
              }
              return true;
            },
          ),
          title: Text(
            viewingLabel,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            Semantics(
              button: true,
              label: 'Export data as CSV spreadsheet',
              child: IconButton(
                onPressed: profile != null
                    ? () {
                        CsvExportService.generateAndShare(
                          profile: profile,
                          progress: progress,
                          allCards: allCards,
                        );
                      }
                    : null,
                icon: const Icon(Icons.table_chart_rounded),
                tooltip: 'Export CSV Data',
              ),
            ),
            Semantics(
              button: true,
              label: 'Export progress report as PDF',
              child: IconButton(
                onPressed: profile != null
                    ? () {
                        ReportGenerator.generateAndShare(
                          profile: profile,
                          progress: progress,
                          allCards: allCards,
                        );
                      }
                    : null,
                icon: const Icon(Icons.picture_as_pdf_rounded),
                tooltip: 'Export PDF Report',
              ),
            ),
            Semantics(
              button: true,
              label: 'Export research data for thesis analysis',
              child: IconButton(
                onPressed: () => context.push('/research-export'),
                icon: const Icon(Icons.science_rounded),
                tooltip: 'Research Export',
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ─── Student Info Banner ──────────────
            _ProfileBanner(
              profile: profile,
              streak: streak,
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),

            const SizedBox(height: 24),

            // ─── Key Metrics Row ──────────────────
            Row(
                  children: [
                    _MetricCard(
                      icon: Icons.star_rounded,
                      label: 'Stars',
                      value: '$totalStars',
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 12),
                    _MetricCard(
                      icon: Icons.auto_stories_rounded,
                      label: 'Words',
                      value: '$masteredWords',
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 12),
                    _MetricCard(
                      icon: Icons.emoji_events_rounded,
                      label: 'Badges',
                      value: '$unlockedCount/$totalAchievements',
                      color: AppColors.accent,
                    ),
                  ],
                )
                .animate()
                .fadeIn(duration: 400.ms, delay: 100.ms)
                .slideY(begin: 0.1, end: 0),

            const SizedBox(height: 24),

            // ─── Overall Mastery ──────────────────
            const _SectionTitle(title: 'Overall Mastery'),
            const SizedBox(height: 12),
            _MasterySection(
              masteryPct: masteryPct,
              recentAvgPct: recentAvgPct,
              dailyStreak: dailyStreak,
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

            const SizedBox(height: 24),

            // ─── Category Breakdown ───────────────
            const _SectionTitle(title: 'Category Breakdown'),
            const SizedBox(height: 12),
            ...FlashcardCategory.values.asMap().entries.map((entry) {
              final i = entry.key;
              final cat = entry.value;
              final pct = progress.categoryProgress[cat.label] ?? 0.0;
              final catCards = allCards.where((c) => c.category == cat).length;
              return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CategoryBar(
                      category: cat,
                      progress: pct,
                      wordCount: catCards,
                    ),
                  )
                  .animate()
                  .fadeIn(
                    duration: 400.ms,
                    delay: Duration(milliseconds: 300 + i * 60),
                  )
                  .slideX(begin: 0.08, end: 0);
            }),

            const SizedBox(height: 24),

            // ─── Insights & Recommendations ───────
            const _SectionTitle(title: 'Insights & Recommendations'),
            const SizedBox(height: 12),
            if (!hasAnyProgress)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: hc.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'No learning data yet. Once the student starts playing games and reviewing flashcards, insights will appear here.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 500.ms)
            else ...[
              _InsightCard(
                icon: Icons.trending_down_rounded,
                iconColor: AppColors.error,
                title: 'Needs Practice',
                description: weakCategories
                    .map((e) => '${e.$1.label} (${(e.$2 * 100).round()}%)')
                    .join(', '),
                recommendation:
                    'Focus on ${weakCategories.first.$1.label} flashcards and games.',
              ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
              const SizedBox(height: 10),
              _InsightCard(
                icon: Icons.trending_up_rounded,
                iconColor: AppColors.success,
                title: 'Doing Great',
                description: strongCategories
                    .map((e) => '${e.$1.label} (${(e.$2 * 100).round()}%)')
                    .join(', '),
                recommendation:
                    'Keep it up! Consider trying harder difficulty levels.',
              ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
              const SizedBox(height: 10),
              _InsightCard(
                icon: Icons.lightbulb_rounded,
                iconColor: AppColors.warning,
                title: 'Engagement',
                description: streak > 0
                    ? '$streak-day learning streak active!'
                    : 'No active streak. Try daily practice.',
                recommendation: streak >= 3
                    ? 'Great consistency! The student is building a habit.'
                    : 'Encourage the student to play at least once a day.',
              ).animate().fadeIn(duration: 400.ms, delay: 700.ms),
            ],

            const SizedBox(height: 24),

            // ─── Study Time Analytics ─────────────
            const _SectionTitle(title: 'Study Time'),
            const SizedBox(height: 12),
            if (profile != null)
              _StudyTimeSection(
                profileId: profile.id,
              ).animate().fadeIn(duration: 400.ms, delay: 750.ms),

            const SizedBox(height: 24),

            // ─── Recent Activity ───────────────────
            const _SectionTitle(title: 'Recent Activity'),
            const SizedBox(height: 12),
            if (recentScores.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: hc.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'No game activity yet. Encourage the student to play games!',
                  style: AppTypography.bodyMedium.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              )
            else
              ...recentScores.reversed.take(5).toList().asMap().entries.map((
                entry,
              ) {
                final i = entry.key;
                final score = entry.value;
                return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ActivityTile(score: score),
                    )
                    .animate()
                    .fadeIn(
                      duration: 400.ms,
                      delay: Duration(milliseconds: 800 + i * 60),
                    )
                    .slideX(begin: 0.08, end: 0);
              }),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────
// Sub-widgets
// ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _ProfileBanner extends StatelessWidget {
  final UserProfile? profile;
  final int streak;
  const _ProfileBanner({required this.profile, required this.streak});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gradient: AppColors.primaryGradient,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            child: Text(
              profile?.name.isNotEmpty == true
                  ? profile!.name[0].toUpperCase()
                  : '?',
              style: AppTypography.headlineMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.name ?? 'Student',
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Student Progress',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '$streak',
                  style: AppTypography.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MasterySection extends StatelessWidget {
  final double masteryPct;
  final double recentAvgPct;
  final int dailyStreak;
  const _MasterySection({
    required this.masteryPct,
    required this.recentAvgPct,
    required this.dailyStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircularPercentIndicator(
              radius: 56,
              lineWidth: 10,
              percent: masteryPct.clamp(0.0, 1.0),
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(masteryPct * 100).round()}%',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'Mastery',
                    style: AppTypography.labelSmall.copyWith(
                      color: HCColor.of(context).textSecondary,
                    ),
                  ),
                ],
              ),
              progressColor: AppColors.primary,
              backgroundColor: AppColors.primaryLight,
              circularStrokeCap: CircularStrokeCap.round,
              animation: true,
              animationDuration: 800,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MiniMetric(
                    label: 'Recent Game Avg',
                    value: '${(recentAvgPct * 100).round()}%',
                    icon: Icons.trending_up_rounded,
                    color: recentAvgPct >= 0.7
                        ? AppColors.success
                        : recentAvgPct >= 0.4
                        ? AppColors.warning
                        : AppColors.error,
                  ),
                  const SizedBox(height: 10),
                  _MiniMetric(
                    label: 'Daily Challenge Streak',
                    value: '$dailyStreak days',
                    icon: Icons.local_fire_department_rounded,
                    color: dailyStreak >= 3
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final FlashcardCategory category;
  final double progress;
  final int wordCount;
  const _CategoryBar({
    required this.category,
    required this.progress,
    required this.wordCount,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final pctRound = (progress * 100).round();
    final statusColor = pctRound >= 70
        ? AppColors.success
        : pctRound >= 40
        ? AppColors.warning
        : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hc.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: category.color.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(category.icon, color: category.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category.label,
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$pctRound%',
                        style: AppTypography.labelSmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    color: category.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String recommendation;
  const _InsightCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tips_and_updates_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recommendation,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final GameScore score;
  const _ActivityTile({required this.score});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final pct = score.total > 0 ? score.score / score.total : 0.0;
    final gt = score.gameType;
    final statusColor = pct >= 0.7
        ? AppColors.success
        : pct >= 0.4
        ? AppColors.warning
        : AppColors.error;

    // Format duration if available
    final durationText = score.durationSeconds != null
        ? ' • ${_formatDuration(score.durationSeconds!)}'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hc.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: gt.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: gt.color.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(gt.icon, color: gt.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gt.label,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${score.score}/${score.total} • ${(pct * 100).round()}%$durationText',
                  style: AppTypography.labelSmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final earned = i < score.starsEarned;
                return Icon(
                  earned ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 16,
                  color: earned ? AppColors.warning : AppColors.border,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return sec > 0 ? '${min}m ${sec}s' : '${min}m';
  }
}

// ─── Study Time Analytics Section ─────────────────────

class _StudyTimeSection extends StatelessWidget {
  final String profileId;
  const _StudyTimeSection({required this.profileId});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final totalMin = SessionTracker.totalStudyMinutes(profileId);
    final avgMin = SessionTracker.averageSessionMinutes(profileId);
    final totalSess = SessionTracker.totalSessions(profileId);
    final dailyMinutes = SessionTracker.dailyStudyMinutes(profileId);
    final maxDaily = dailyMinutes.values.fold<int>(
      1,
      (prev, v) => v > prev ? v : prev,
    );

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
          // Stat row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StudyMetric(
                icon: Icons.timer_rounded,
                value: '${totalMin}m',
                label: 'Total Time',
                color: AppColors.info,
              ),
              _StudyMetric(
                icon: Icons.timelapse_rounded,
                value: '${avgMin.toStringAsFixed(1)}m',
                label: 'Avg Session',
                color: AppColors.secondary,
              ),
              _StudyMetric(
                icon: Icons.repeat_rounded,
                value: '$totalSess',
                label: 'Sessions',
                color: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Mini bar chart — last 7 days
          Text(
            'Last 7 Days',
            style: AppTypography.labelMedium.copyWith(
              color: hc.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dailyMinutes.entries.toList().reversed.map((entry) {
                final fraction = maxDaily > 0
                    ? (entry.value / maxDaily).clamp(0.0, 1.0)
                    : 0.0;
                // Parse day label
                final parts = entry.key.split('-');
                final dayLabel = parts.length == 3 ? parts[2] : '';

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (entry.value > 0)
                          Text(
                            '${entry.value}',
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 9,
                              color: hc.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: fraction * 50 + 4,
                          decoration: BoxDecoration(
                            color: entry.value > 0
                                ? AppColors.primary
                                : AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dayLabel,
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 9,
                            color: hc.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StudyMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
        ),
      ],
    );
  }
}
