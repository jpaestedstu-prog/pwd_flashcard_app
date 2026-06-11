import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/safe_scaffold.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/models/achievements.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/experiment_provider.dart';
import '../../../features/experiment/models/experiment_models.dart';
import '../theme/progress_theme_provider.dart';
import '../theme/progress_layout_provider.dart';
import '../theme/progress_theme_picker.dart';
import '../widgets/shared/progress_section_header.dart';
import '../widgets/shared/category_progress_row.dart';
import '../widgets/shared/progress_stat_grid.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final progress = ref.watch(progressProvider);
    final allCards = ref.watch(allFlashcardsProvider);

    final totalWords = allCards.length;
    final masteredWords = progress.wordsLearned;
    final streak = progress.streakDays;
    final totalStars = progress.totalStars;
    final masteryPct = totalWords > 0
        ? (masteredWords / totalWords).clamp(0.0, 1.0)
        : 0.0;

    // ─── Selectable skin + layout (yield to accessibility modes) ───
    final theme = ref.watch(progressThemeProvider);
    final layout = ref.watch(progressLayoutProvider);
    final settings = ref.watch(settingsProvider);
    final useTheme =
        !(settings.highContrastMode || settings.dyslexiaMode);
    // Subtle skin wash for neutral cards; null in accessibility modes so the
    // plain HCColor surface is used.
    final cardSurface =
        useTheme ? theme.cardSurface(HCColor.of(context).surface) : null;

    // Width-cap the content on wide tablets (center it) and use the
    // tier-aware page padding on the sides — prevents edge-to-edge stretch
    // on large screens and cramping on phones.
    final maxW = context.maxContentWidth;
    final sideInset = maxW.isFinite
        ? ((context.screenWidth - maxW) / 2).clamp(0.0, double.infinity)
        : 0.0;
    final contentHPad = context.pagePadding + sideInset;
    final headerGradient = useTheme
        ? theme.gradient
        : LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.85),
              AppColors.secondary.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final headerTextColor = useTheme ? theme.onHeader : Colors.white;
    final accent = useTheme ? theme.accent : HCColor.of(context).primary;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── App Bar ────────────────────────
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            actions: [
              IconButton(
                tooltip: 'Customize progress',
                icon: Icon(Icons.palette_rounded, color: headerTextColor),
                onPressed: () => showProgressCustomizeSheet(
                  context,
                  selectedThemeId: theme.id,
                  selectedLayoutId: layout.id,
                  onThemeSelected: (id) =>
                      ref.read(progressThemeProvider.notifier).select(id),
                  onLayoutSelected: (id) =>
                      ref.read(progressLayoutProvider.notifier).select(id),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 16,
                bottom: 16,
                end: 56, // clear the palette action at large font scales
              ),
              title: Text(
                "${profile?.name ?? 'Learner'}'s Progress",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium.copyWith(
                  color: headerTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(gradient: headerGradient),
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.fromLTRB(contentHPad, 20, contentHPad, 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─── Top Stats (responsive, overflow-safe grid) ──
                OverflowGuard(
                      label: 'progress-top-stats',
                      child: ProgressStatGrid(
                        layout: layout,
                        stats: [
                          ProgressStat(
                            icon: Icons.local_fire_department_rounded,
                            label: 'Streak',
                            value: '$streak',
                            suffix: 'days',
                            color: AppColors.accent,
                          ),
                          ProgressStat(
                            icon: Icons.star_rounded,
                            label: 'Stars',
                            value: '$totalStars',
                            color: AppColors.warning,
                          ),
                          ProgressStat(
                            icon: Icons.menu_book_rounded,
                            label: 'Words',
                            value: '$masteredWords',
                            suffix: '/ $totalWords',
                            color: AppColors.secondary,
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.15, end: 0),

                SizedBox(height: layout.sectionGap),

                // ─── Overall Mastery ─────────────
                Semantics(
                      label:
                          'Overall mastery: ${(masteryPct * 100).round()} percent. '
                          '$masteredWords out of $totalWords words learned.',
                      child: Center(
                        child: Builder(builder: (context) {
                          // Responsive, text-scaler-aware ring so it fits small
                          // tablets in portrait/split-screen and grows (capped)
                          // with the Font Size setting instead of clipping.
                          final ringRadius = context.scaledHeightCapped(
                            context.responsiveTier(
                                  phone: 72.0,
                                  tablet: 80.0,
                                  large: 92.0,
                                  xl: 100.0,
                                ) *
                                layout.heroScale,
                            max: 1.3,
                          );
                          return CircularPercentIndicator(
                          radius: ringRadius,
                          lineWidth: ringRadius * 0.17,
                          percent: masteryPct.clamp(0.0, 1.0),
                          center: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${(masteryPct * 100).round()}%',
                                style: AppTypography.headlineMedium.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: accent,
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
                          progressColor: accent,
                          backgroundColor: useTheme
                              ? accent.withValues(alpha: 0.15)
                              : HCColor.of(context).primaryLight,
                          circularStrokeCap: CircularStrokeCap.round,
                          animation: true,
                          animationDuration: 1000,
                          );
                        }),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 200.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                    ),

                SizedBox(height: layout.sectionGap),

                // ─── Leaderboard Button (gated by experiment config) ─────────
                if (ref.watch(gamificationFeatureProvider(GamificationFeature.leaderboard)))
                FilledButton.icon(
                      onPressed: () => context.push('/leaderboard'),
                      icon: const Icon(Icons.leaderboard_rounded),
                      label: Text(AppLocalizations.of(context)!.viewLeaderboard),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 350.ms)
                    .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                      onPressed: () => context.push('/analytics'),
                      icon: const Icon(Icons.analytics_rounded),
                      label: Text(AppLocalizations.of(context)!.detailedAnalytics),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 400.ms)
                    .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                      onPressed: () => context.push('/streak-calendar'),
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: const Text('Streak Calendar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 450.ms)
                    .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                      onPressed: () => context.push('/certificates'),
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: const Text('Certificates'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 500.ms)
                    .slideY(begin: 0.1, end: 0),

                SizedBox(height: layout.sectionGap),

                // ─── Category Progress ──────────
                ProgressSectionHeader(
                  title: AppLocalizations.of(context)!.categoryProgress,
                  icon: Icons.category_rounded,
                  iconColor: accent,
                ),
                const SizedBox(height: 12),

                ...FlashcardCategory.values.asMap().entries.map((entry) {
                  final i = entry.key;
                  final cat = entry.value;
                  final catCards = allCards
                      .where((c) => c.category == cat)
                      .toList();
                  final catPct = progress.categoryProgress[cat.label] ?? 0.0;
                  final catMastered = (catPct * catCards.length).round();

                  return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: CategoryProgressRow(
                          icon: cat.icon,
                          label: cat.label,
                          color: cat.color,
                          mastered: catMastered,
                          total: catCards.length,
                          percent: catPct,
                          surface: cardSurface,
                        ),
                      )
                      .animate()
                      .fadeIn(
                        duration: 400.ms,
                        delay: Duration(milliseconds: 300 + i * 80),
                      )
                      .slideX(begin: 0.1, end: 0);
                }),

                SizedBox(height: layout.sectionGap),

                // ─── Recent Games ─────────────
                ProgressSectionHeader(
                  title: AppLocalizations.of(context)!.recentGames,
                  icon: Icons.sports_esports_rounded,
                  iconColor: accent,
                ),
                const SizedBox(height: 12),
                if (progress.recentScores.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: HCColor.of(context).surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sports_esports_rounded,
                          size: 32,
                          color: HCColor.of(context).textHint,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.playGamePrompt,
                            style: AppTypography.bodyMedium.copyWith(
                              color: HCColor.of(context).textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 750.ms)
                else
                  ...progress.recentScores.reversed
                      .take(10)
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) {
                        final i = entry.key;
                        final score = entry.value;
                        return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _RecentGameTile(score: score),
                            )
                            .animate()
                            .fadeIn(
                              duration: 400.ms,
                              delay: Duration(milliseconds: 750 + i * 60),
                            )
                            .slideX(begin: 0.1, end: 0);
                      }),

                SizedBox(height: layout.sectionGap),

                // ─── Star Collection ─────────────
                ProgressSectionHeader(
                  title: AppLocalizations.of(context)!.starCollection,
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppColors.warning,
                ),
                const SizedBox(height: 12),
                _StarGrid(
                  totalStars: totalStars,
                ).animate().fadeIn(duration: 400.ms, delay: 800.ms),

                SizedBox(height: layout.sectionGap),

                // ─── Achievement Badges ──────────
                ProgressSectionHeader(
                  title: AppLocalizations.of(context)!.achievements,
                  icon: Icons.emoji_events_rounded,
                  iconColor: AppColors.warning,
                ),
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  final unlockedIds = Achievements.unlockedIds(progress);
                  if (unlockedIds.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: HCColor.of(context).surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            size: 32,
                            color: HCColor.of(context).textHint,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Keep learning to unlock your first badge!',
                              style: AppTypography.bodyMedium.copyWith(
                                color: HCColor.of(context).textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 900.ms);
                  }
                  return _AchievementRow(
                    achievements: Achievements.all,
                    unlockedIds: unlockedIds,
                  ).animate().fadeIn(duration: 400.ms, delay: 900.ms);
                }),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────
// Star Collection Grid
// ────────────────────────────────────────
class _StarGrid extends StatelessWidget {
  final int totalStars;
  const _StarGrid({required this.totalStars});

  @override
  Widget build(BuildContext context) {
    final displayCount = totalStars > 20 ? totalStars : 20;
    return Semantics(
      label: '$totalStars stars earned',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalStars > 20)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '⭐ $totalStars stars collected!',
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(displayCount.clamp(0, 50), (i) {
              final earned = i < totalStars;
              return Icon(
                earned ? Icons.star_rounded : Icons.star_border_rounded,
                size: 32,
                color: earned ? AppColors.warning : HCColor.of(context).border,
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────
// Achievement Badges
// ────────────────────────────────────────
class _AchievementRow extends StatelessWidget {
  final List<Achievement> achievements;
  final Set<String> unlockedIds;
  const _AchievementRow({
    required this.achievements,
    required this.unlockedIds,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: achievements.map((a) {
        final unlocked = unlockedIds.contains(a.id);
        return Semantics(
          label:
              '${a.title} achievement${unlocked ? ', unlocked' : ', locked'}',
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked
                      ? a.color.withValues(alpha: 0.15)
                      : HCColor.of(context).surfaceLight,
                  border: Border.all(
                    color: unlocked ? a.color : HCColor.of(context).border,
                    width: 2,
                  ),
                  boxShadow: unlocked
                      ? [
                          BoxShadow(
                            color: a.color.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  a.icon,
                  color: unlocked ? a.color : HCColor.of(context).textHint,
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                // Grow the label box with the Font Size setting (capped) so the
                // 2-line title doesn't clip at large scales.
                width: context.scaleIcon(64).clamp(64.0, 96.0),
                child: Text(
                  a.title,
                  style: AppTypography.labelSmall.copyWith(
                    color: unlocked
                        ? HCColor.of(context).textPrimary
                        : HCColor.of(context).textHint,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ────────────────────────────────────────
// Recent Game Score Tile
// ────────────────────────────────────────
class _RecentGameTile extends StatelessWidget {
  final GameScore score;
  const _RecentGameTile({required this.score});

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final pct = score.total > 0 ? score.score / score.total : 0.0;
    final gt = score.gameType;
    return Semantics(
      label:
          '${gt.label}: ${score.score} of ${score.total}, '
          '${(pct * 100).round()} percent, '
          '${score.starsEarned} stars, ${_formatDate(score.date)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: HCColor.of(context).surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: gt.color.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: gt.color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: gt.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: gt.color.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(gt.icon, color: gt.color, size: 24),
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
                  const SizedBox(height: 2),
                  Text(
                    '${score.score}/${score.total}  •  ${(pct * 100).round()}%'
                    '  •  ${_formatDate(score.date)}',
                    style: AppTypography.labelSmall.copyWith(
                      color: HCColor.of(context).textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final earned = i < score.starsEarned;
                return Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(
                    earned ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 20,
                    color: earned ? AppColors.warning : HCColor.of(context).border,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
