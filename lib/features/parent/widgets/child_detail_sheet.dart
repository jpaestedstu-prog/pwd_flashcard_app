import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/parent_provider.dart';
import '../../../features/progress/widgets/charts/category_radar_chart.dart';
import '../../../features/progress/widgets/charts/study_time_chart.dart';
import 'learning_gain_card.dart';

/// Bottom sheet showing detailed progress for a single child.
class ChildDetailSheet extends StatelessWidget {
  final ChildSummary child;
  final VoidCallback? onViewFullDashboard;

  const ChildDetailSheet({
    super.key,
    required this.child,
    this.onViewFullDashboard,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: hc.background,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hc.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ─── Header ───────────────────────────
              Row(
                children: [
                  // Avatar with accuracy ring
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: child.averageAccuracy,
                            strokeWidth: 3,
                            backgroundColor: hc.border.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation(
                              child.isRecentlyActive
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight
                                .withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(child.avatarEmoji,
                                style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.name,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: hc.textPrimary,
                          ),
                        ),
                        if (child.disabilityType != DisabilityType.none)
                          Row(
                            children: [
                              Icon(child.disabilityType.icon,
                                  size: 14, color: hc.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                child.disabilityType.label,
                                style: AppTypography.labelSmall.copyWith(
                                  color: hc.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: child.isRecentlyActive
                                    ? AppColors.success
                                    : AppColors.textHint,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              child.isRecentlyActive
                                  ? 'Active today'
                                  : 'Last active ${_formatLastActive(child.lastActivityDate)}',
                              style: AppTypography.labelSmall.copyWith(
                                color: child.isRecentlyActive
                                    ? AppColors.success
                                    : hc.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (child.streakDays > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.warning.withValues(alpha: 0.2),
                            AppColors.warning.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(
                            '${child.streakDays} day streak',
                            style: AppTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 24),

              // ─── Quick Stats Grid ─────────────────
              _QuickStatsGrid(child: child, hc: hc)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 100.ms),

              const SizedBox(height: 20),

              // ─── Study Time Chart ─────────────────
              StudyTimeChart(dailyMinutes: child.dailyStudyMinutes)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms),

              const SizedBox(height: 20),

              // ─── Category Progress ────────────────
              CategoryRadarChart(categoryProgress: child.categoryProgress)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 300.ms),

              const SizedBox(height: 20),

              // ─── Learning Gain (Pre vs Post) ──────
              LearningGainCard(profileId: child.profileId)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 350.ms),

              const SizedBox(height: 20),

              // ─── Strengths & Weaknesses ───────────
              _StrengthsCard(child: child, hc: hc)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 400.ms),

              const SizedBox(height: 20),

              // ─── Recent Games ─────────────────────
              if (child.recentScores.isNotEmpty) ...[
                Text(
                  'Recent Games',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                ...child.recentScores
                    .reversed
                    .take(5)
                    .toList()
                    .asMap()
                    .entries
                    .map((entry) => _RecentGameRow(
                          score: entry.value,
                          hc: hc,
                        )
                            .animate()
                            .fadeIn(
                                duration: 300.ms,
                                delay: (500 + entry.key * 60).ms)
                            .slideX(begin: 0.03, end: 0)),
              ],

              // ─── View Full Dashboard Button ───────
              if (onViewFullDashboard != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onViewFullDashboard!();
                      },
                      icon: const Icon(Icons.dashboard_rounded),
                      label: const Text('View Full Dashboard'),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 550.ms),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  String _formatLastActive(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).round()} weeks ago';
  }
}

// ─── Quick Stats Grid ────────────────────────────────

class _QuickStatsGrid extends StatelessWidget {
  final ChildSummary child;
  final HCColor hc;

  const _QuickStatsGrid({required this.child, required this.hc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _DetailStatTile(
                icon: Icons.school_rounded,
                label: 'Words Learned',
                value: '${child.wordsLearned}',
                subtitle: 'of 144 total',
                color: AppColors.primary,
                progress: child.wordsLearned / 144,
              ),
              const SizedBox(width: 12),
              _DetailStatTile(
                icon: Icons.star_rounded,
                label: 'Stars Earned',
                value: '${child.totalStars}',
                subtitle: '${child.totalStars - (child.totalStars - child.totalStars)} balance',
                color: AppColors.warning,
                delay: 60,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _DetailStatTile(
                icon: Icons.percent_rounded,
                label: 'Accuracy',
                value: '${(child.averageAccuracy * 100).round()}%',
                subtitle: child.averageAccuracy >= 0.7
                    ? 'Great!'
                    : child.averageAccuracy >= 0.4
                        ? 'Good progress'
                        : 'Needs practice',
                color: AppColors.info,
                progress: child.averageAccuracy,
                delay: 120,
              ),
              const SizedBox(width: 12),
              _DetailStatTile(
                icon: Icons.category_rounded,
                label: 'Categories',
                value: '${child.masteredCategories}',
                subtitle: 'mastered (≥80%)',
                color: AppColors.secondary,
                progress: child.masteredCategories / 12,
                delay: 180,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _DetailStatTile(
                icon: Icons.timer_rounded,
                label: 'Study Time',
                value: '${child.studyMinutesThisWeek}m',
                subtitle: 'this week',
                color: AppColors.success,
                delay: 240,
              ),
              const SizedBox(width: 12),
              _DetailStatTile(
                icon: Icons.sports_esports_rounded,
                label: 'Games Played',
                value: '${child.gamesPlayed}',
                subtitle: '${child.totalSessions} sessions',
                color: AppColors.accent,
                delay: 300,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final double? progress;
  final int delay;

  const _DetailStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    this.progress,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.labelSmall.copyWith(
                      color: HCColor.of(context).textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.labelSmall.copyWith(
                color: HCColor.of(context).textSecondary,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms, delay: (150 + delay).ms)
          .scale(
            begin: const Offset(0.93, 0.93),
            end: const Offset(1, 1),
            delay: (150 + delay).ms,
            duration: 300.ms,
            curve: Curves.easeOutBack,
          ),
    );
  }
}

// ─── Strengths & Weaknesses Card ─────────────────────

class _StrengthsCard extends StatelessWidget {
  final ChildSummary child;
  final HCColor hc;

  const _StrengthsCard({required this.child, required this.hc});

  @override
  Widget build(BuildContext context) {
    final strongest = child.strongestCategory;
    final weakest = child.weakestCategory;
    final unexplored = child.unexploredCategories;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Strengths & Areas to Improve',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (strongest != null)
            _InsightRow(
              icon: Icons.emoji_events_rounded,
              iconColor: AppColors.success,
              title: 'Strongest: $strongest',
              subtitle:
                  '${((child.categoryProgress[strongest] ?? 0) * 100).round()}% mastery',
            ),
          if (weakest != null && weakest != strongest)
            _InsightRow(
              icon: Icons.trending_up_rounded,
              iconColor: AppColors.warning,
              title: 'Needs work: $weakest',
              subtitle:
                  '${((child.categoryProgress[weakest] ?? 0) * 100).round()}% mastery — encourage more practice here',
            ),
          if (unexplored.isNotEmpty)
            _InsightRow(
              icon: Icons.explore_rounded,
              iconColor: AppColors.info,
              title: '${unexplored.length} categories unexplored',
              subtitle: unexplored.take(4).join(', '),
            ),
          if (strongest == null && weakest == null)
            _InsightRow(
              icon: Icons.play_circle_rounded,
              iconColor: AppColors.primary,
              title: 'Just getting started!',
              subtitle:
                  'Encourage ${child.name} to try some flashcards or games.',
            ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _InsightRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: HCColor.of(context).textSecondary,
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

// ─── Recent Game Row ─────────────────────────────────

class _RecentGameRow extends StatelessWidget {
  final GameScore score;
  final HCColor hc;

  const _RecentGameRow({required this.score, required this.hc});

  @override
  Widget build(BuildContext context) {
    final pct = score.total > 0
        ? (score.score / score.total * 100).round()
        : 0;
    final diff = DateTime.now().difference(score.date);
    final timeAgo = diff.inDays > 0
        ? '${diff.inDays}d ago'
        : diff.inHours > 0
            ? '${diff.inHours}h ago'
            : '${diff.inMinutes}m ago';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hc.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(score.gameType.icon, size: 20, color: score.gameType.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score.gameType.label,
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  timeAgo,
                  style: AppTypography.labelSmall.copyWith(
                    color: hc.textHint,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.score}/${score.total}',
                style: AppTypography.labelMedium,
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pct >= 70
                      ? AppColors.success.withValues(alpha: 0.15)
                      : pct >= 40
                          ? AppColors.warning.withValues(alpha: 0.15)
                          : AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$pct%',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: pct >= 70
                        ? AppColors.success
                        : pct >= 40
                            ? AppColors.warning
                            : AppColors.error,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                  const SizedBox(width: 2),
                  Text('${score.starsEarned}',
                      style: AppTypography.labelSmall),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
