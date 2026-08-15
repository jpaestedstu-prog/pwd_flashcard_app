import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/accessibility/accessibility_content_policy.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../core/widgets/safe_scaffold.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/parent_provider.dart';
import '../screens/sign_check_screen.dart';
import '../../../features/progress/theme/progress_theme_provider.dart';
import '../../../features/progress/theme/progress_layout_provider.dart';
import '../../../features/progress/theme/progress_theme_picker.dart';
import '../../../features/progress/widgets/charts/category_radar_chart.dart';
import '../../../features/progress/widgets/charts/study_time_chart.dart';
import '../../../features/progress/widgets/shared/progress_section_header.dart';
import 'learning_gain_card.dart';

/// Bottom sheet showing detailed progress for a single child.
class ChildDetailSheet extends ConsumerWidget {
  final ChildSummary child;
  final VoidCallback? onViewFullDashboard;

  const ChildDetailSheet({
    super.key,
    required this.child,
    this.onViewFullDashboard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);

    // ─── Child's selectable skin + layout (yield to accessibility modes) ───
    final theme = ref.watch(progressThemeForProvider(child.profileId));
    final layout = ref.watch(progressLayoutForProvider(child.profileId));
    final settings = ref.watch(settingsProvider);
    final useTheme = !(settings.highContrastMode || settings.dyslexiaMode);
    final accent = useTheme ? theme.accent : AppColors.primary;
    final cardSurface = useTheme ? theme.cardSurface(hc.surface) : hc.surface;

    // Width-cap content on wide tablets (centered) + tier-aware side padding.
    final maxW = context.maxContentWidth;
    final sideInset = maxW.isFinite
        ? ((context.screenWidth - maxW) / 2).clamp(0.0, double.infinity)
        : 0.0;
    final contentHPad = context.pagePadding + sideInset;

    // Derive catalog totals so the "of X total" copy can't drift from seed data.
    final totalWords = ref.watch(allFlashcardsProvider).length;

    // Whether this learner has sign claims waiting on an educator's eye.
    // Scoped to the child's own accessibility type, like the Signs stat.
    final showFsl = AccessibilityContentPolicy.forType(
      child.disabilityType,
    ).showFsl;
    final claims = HiveService.fslMastery(child.profileId);
    final verdicts = HiveService.fslVerifications(child.profileId);
    final pendingSignClaims = claims.entries
        .where(
          (e) =>
              e.value != SignMastery.notSet &&
              (verdicts[e.key] ?? SignVerification.unreviewed) ==
                  SignVerification.unreviewed,
        )
        .length;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: hc.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.symmetric(horizontal: contentHPad),
            children: [
              // Handle bar + theme picker
              Row(
                children: [
                  const SizedBox(width: 40), // balances the trailing icon
                  Expanded(
                    child: Center(
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
                  ),
                  IconButton(
                    tooltip: 'Customize progress',
                    icon: Icon(Icons.palette_rounded, color: accent),
                    onPressed: () => showProgressCustomizeSheet(
                      context,
                      selectedThemeId: theme.id,
                      selectedLayoutId: layout.id,
                      onThemeSelected: (id) =>
                          selectProgressThemeFor(ref, child.profileId, id),
                      onLayoutSelected: (id) =>
                          selectProgressLayoutFor(ref, child.profileId, id),
                    ),
                  ),
                ],
              ),

              // ─── Header ───────────────────────────
              OverflowGuard(
                label: 'child-header',
                child: Row(
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
                              backgroundColor: hc.border.withValues(
                                alpha: 0.15,
                              ),
                              valueColor: AlwaysStoppedAnimation(
                                child.isRecentlyActive
                                    ? AppColors.success
                                    : accent,
                              ),
                            ),
                          ),
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                child.avatarEmoji,
                                style: const TextStyle(fontSize: 26),
                              ),
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: hc.textPrimary,
                            ),
                          ),
                          if (child.disabilityType != DisabilityType.none)
                            Row(
                              children: [
                                Icon(
                                  child.disabilityType.icon,
                                  size: 14,
                                  color: hc.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    child.disabilityType.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: hc.textSecondary,
                                    ),
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
                              Flexible(
                                child: Text(
                                  child.isRecentlyActive
                                      ? 'Active today'
                                      : 'Last active ${_formatLastActive(child.lastActivityDate)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: child.isRecentlyActive
                                        ? AppColors.success
                                        : hc.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (child.streakDays > 0)
                      ConstrainedBox(
                        // Cap the badge so it can't crowd out the name on a very
                        // narrow split-screen at huge font; the inner text then
                        // ellipsizes. Name keeps its Expanded priority otherwise.
                        constraints: BoxConstraints(
                          maxWidth: context.screenWidth * 0.42,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
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
                              Flexible(
                                child: Text(
                                  '${child.streakDays} day streak',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              SizedBox(height: layout.sectionGap),

              // ─── Quick Stats Grid ─────────────────
              _QuickStatsGrid(
                child: child,
                totalWords: totalWords,
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

              SizedBox(height: layout.sectionGap),

              // ─── Study Time Chart ─────────────────
              StudyTimeChart(
                dailyMinutes: child.dailyStudyMinutes,
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

              SizedBox(height: layout.sectionGap),

              // ─── Category Progress ────────────────
              CategoryRadarChart(
                categoryProgress: child.categoryProgress,
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

              SizedBox(height: layout.sectionGap),

              // ─── Learning Gain (Pre vs Post) ──────
              LearningGainCard(
                profileId: child.profileId,
              ).animate().fadeIn(duration: 400.ms, delay: 350.ms),

              SizedBox(height: layout.sectionGap),

              // ─── Strengths & Weaknesses ───────────
              _StrengthsCard(
                child: child,
                hc: hc,
                surface: cardSurface,
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

              SizedBox(height: layout.sectionGap),

              // ─── Recent Games ─────────────────────
              if (child.recentScores.isNotEmpty) ...[
                ProgressSectionHeader(
                  title: 'Recent Games',
                  icon: Icons.sports_esports_rounded,
                  iconColor: accent,
                ),
                const SizedBox(height: 10),
                ...child.recentScores.reversed
                    .take(5)
                    .toList()
                    .asMap()
                    .entries
                    .map(
                      (entry) => _RecentGameRow(score: entry.value, hc: hc)
                          .animate()
                          .fadeIn(
                            duration: 300.ms,
                            delay: (500 + entry.key * 60).ms,
                          )
                          .slideX(begin: 0.03, end: 0),
                    ),
              ],

              // ─── Sign Check ───────────────────────
              // Only for learners the FSL surfaces are shown to, and only
              // where the learner has actually claimed something — an empty
              // review queue is not worth a button.
              if (showFsl && pendingSignClaims > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondaryDark,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SignCheckScreen(
                              learnerId: child.profileId,
                              learnerName: child.name,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.sign_language_rounded),
                      label: Text('Sign Check · $pendingSignClaims to review'),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 500.ms),

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

class _QuickStatsGrid extends ConsumerWidget {
  final ChildSummary child;
  final int totalWords;

  const _QuickStatsGrid({required this.child, required this.totalWords});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accuracy = child.averageAccuracy;
    // Derived from THIS CHILD's accessibility type, not from
    // `accessibilityContentPolicyProvider` — that reads the signed-in profile,
    // which on this screen is the teacher or parent, not the learner.
    final showFsl = AccessibilityContentPolicy.forType(
      child.disabilityType,
    ).showFsl;
    final totalSigns =
        ref.watch(fslAvailabilityProvider).valueOrNull?.cardsWithVideo.length ??
        0;
    // Professional dashboard kit: a structured, overflow-safe stat grid in a
    // titled panel, replacing the fixed 2-per-row gradient tiles.
    return ProPanel(
      title: 'Quick Stats',
      child: ProStatGrid(
        tiles: [
          ProStatTile(
            icon: Icons.school_rounded,
            label: 'Words Learned',
            value: '${child.wordsLearned}',
            caption: 'of $totalWords total',
            accent: AppColors.primary,
          ),
          ProStatTile(
            icon: Icons.star_rounded,
            label: 'Stars Earned',
            value: '${child.totalStars}',
            caption: 'available',
            accent: AppColors.warning,
          ),
          // Only where signing is this learner's modality — a permanent zero
          // on a visual-impairment or cognitive profile would read as a
          // deficit rather than a setting. Same policy the learner's own
          // surfaces use.
          if (showFsl)
            ProStatTile(
              icon: Icons.sign_language_rounded,
              label: 'Signs Watched',
              value: '${child.signsWatched}',
              caption: totalSigns > 0 ? 'of $totalSigns signs' : 'FSL clips',
              accent: AppColors.secondaryDark,
            ),
          ProStatTile(
            icon: Icons.percent_rounded,
            label: 'Accuracy',
            value: '${(accuracy * 100).round()}%',
            caption: accuracy >= 0.7
                ? 'Great!'
                : accuracy >= 0.4
                ? 'Good progress'
                : 'Needs practice',
            trend: accuracy >= 0.7
                ? ProTrend.up
                : accuracy >= 0.4
                ? ProTrend.flat
                : ProTrend.down,
            accent: AppColors.info,
          ),
          ProStatTile(
            icon: Icons.category_rounded,
            label: 'Categories',
            value: '${child.masteredCategories}',
            caption: 'mastered (≥80%)',
            accent: AppColors.secondary,
          ),
          ProStatTile(
            icon: Icons.timer_rounded,
            label: 'Study Time',
            value: '${child.studyMinutesThisWeek}m',
            caption: 'this week',
            accent: AppColors.success,
          ),
          ProStatTile(
            icon: Icons.sports_esports_rounded,
            label: 'Games Played',
            value: '${child.gamesPlayed}',
            caption: '${child.totalSessions} sessions',
            accent: AppColors.accent,
          ),
          // Word Hunt is the one activity that happens away from the screen —
          // worth showing an educator on its own, since it never appears in a
          // game score. Shared by the Teacher and Parent surfaces.
          ProStatTile(
            icon: Icons.photo_camera_rounded,
            label: 'Word Hunt Finds',
            value: '${child.wordHuntFinds}',
            caption: child.wordHuntStreak > 0
                ? '${child.wordHuntStreak}-day streak'
                : 'with the camera',
            trend: child.wordHuntStreak > 0 ? ProTrend.up : null,
            accent: AppColors.bannerWordHuntStart,
          ),
        ],
      ),
    );
  }
}

// ─── Strengths & Weaknesses Card ─────────────────────

class _StrengthsCard extends StatelessWidget {
  final ChildSummary child;
  final HCColor hc;
  final Color surface;

  const _StrengthsCard({
    required this.child,
    required this.hc,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    final strongest = child.strongestCategory;
    final weakest = child.weakestCategory;
    final unexplored = child.unexploredCategories;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
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
    final pct = score.total > 0 ? (score.score / score.total * 100).round() : 0;
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
                  style: AppTypography.labelSmall.copyWith(color: hc.textHint),
                ),
              ],
            ),
          ),
          // Trailing metrics — a Wrap (inside Flexible) so the badges flow to
          // a second line instead of overflowing at large font / narrow width.
          Flexible(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${score.score}/${score.total}',
                  style: AppTypography.labelMedium,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${score.starsEarned}',
                      style: AppTypography.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
