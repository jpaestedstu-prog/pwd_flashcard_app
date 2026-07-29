import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/accessibility_content_policy.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../providers/app_providers.dart';
import '../../../core/widgets/hub_scaffold.dart';
import '../../../widgets/accessibility_quick_sheet.dart';
import '../../../widgets/profile_avatar.dart';
import '../../gaze_control/providers/gaze_home_grid.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';
import '../../gaze_control/widgets/gaze_home_tiles.dart';
import '../widgets/home_tile.dart';

/// Gamified home for the Child role (Family Group).
///
/// Mirrors the Student home's SECTION STRUCTURE — the same core surfaces
/// (Home stats, Cards, Games, Stories, Progress) plus the grouped feature
/// sections — while keeping its own kid-first design: bigger targets, more
/// emoji, fewer words, warmer Family-Group palette. The deeper learning
/// content is reused from the shared routes (`/games`, `/flashcards`,
/// `/stories`, `/progress`, …) so the content layer is never forked — only
/// the entry surface differs.
///
/// The whole screen is a [CustomScrollView] and the tile grids size each
/// cell by `mainAxisExtent: context.hubTileHeight()` (never by width/aspect
/// ratio), so it can never throw a RenderFlex/bottom overflow on any tablet,
/// orientation, or font scale — it simply scrolls when space runs short.
class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final pad = context.pagePadding;
    // Two big tiles per row on phones/small tablets; three or four on
    // large tablets where there's room.
    final columns = context.screenWidth >= 900
        ? 4
        : context.screenWidth >= 600
            ? 3
            : 2;

    // Content gating by the child's accessibility category (same policy the
    // Student home applies): FSL entry points hide where signing isn't the
    // right modality.
    final showFsl = ref.watch(accessibilityContentPolicyProvider).showFsl;

    // Hands-free "Bottom nav + Home tiles" reach: when enabled, these tiles
    // register with the shell's gaze D-pad and show a focus ring. Pure
    // pass-through otherwise, so the gaze-off layout / touch are unchanged.
    final gazeHomeOn = ref.watch(
      gazeSettingsProvider.select((s) => s.enabled && s.navHomeTiles),
    );
    final gazeGrid = GazeTileGridBuilder(active: gazeHomeOn);

    GazeTileEntry entry({
      required String emoji,
      required String label,
      required List<Color> gradient,
      required VoidCallback onTap,
    }) =>
        (
          tile: HomeTile(
            emoji: emoji,
            label: label,
            gradient: gradient,
            onTap: onTap,
          ),
          cell: GazeTileCell(label: label, onActivate: onTap),
        );

    /// A kid-sized tile grid sliver for one section.
    Widget grid(List<GazeTileEntry> entries) => SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: context.gridSpacing,
              crossAxisSpacing: context.gridSpacing,
              mainAxisExtent: context.hubTileHeight(),
            ),
            delegate: SliverChildListDelegate(
              gazeGrid.section(columns: columns, entries: entries),
            ),
          ),
        );

    return GazeHomeRegistrar(
      active: gazeGrid.active,
      rows: gazeGrid.rows,
      child: HubScaffold(
        intensity: 0.30,
        slivers: [
          // ─── Greeting strip ──────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  EdgeInsets.fromLTRB(pad, AppSpacing.md, pad, AppSpacing.md),
              child: Row(
                children: [
                  ProfileAvatar(profile: profile, radius: 32),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${profile?.name ?? "Friend"}!',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'What do you want to do today?',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Inline accessibility shortcut — the Child home has
                  // no Settings gear, so this gives the learner self-
                  // service over text size, contrast, read-aloud, etc.
                  // Its own gaze row (the topmost), so the D-pad can
                  // reach it too.
                  gazeGrid.section(
                    columns: 1,
                    expand: false,
                    entries: [
                      (
                        tile: const AccessibilityQuickButton(),
                        cell: GazeTileCell(
                          label: 'Accessibility',
                          onActivate: () =>
                              showAccessibilityQuickSheet(context),
                        ),
                      ),
                    ],
                  ).first,
                ],
              ),
            ),
          ),

          // ─── My day: streak / words / stars ──────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, AppSpacing.sm),
              child: _KidStatsStrip(
                streak: progress.streakDays,
                words: progress.wordsLearned,
                stars: progress.totalStars,
              ),
            ),
          ),

          // ─── Section: Play & Learn (core hub) ────
          // Mirrors the Student home's core tiles: Games, Cards, Stories,
          // FSL (policy-gated), practice, and Progress.
          const _ChildSectionHeader(emoji: '🎮', title: 'Play & Learn'),
          grid([
            entry(
              emoji: '🎮',
              label: 'Games',
              gradient: const [
                AppColors.playerAccent,
                AppColors.playerAccentLight,
              ],
              onTap: () => context.go('/games'),
            ),
            entry(
              emoji: '🔤',
              label: 'Cards',
              gradient: const [
                AppColors.bannerLearningStart,
                AppColors.bannerLearningEnd,
              ],
              onTap: () => context.go('/flashcards'),
            ),
            entry(
              emoji: '📖',
              label: 'Stories',
              gradient: const [
                AppColors.bannerStickerStart,
                AppColors.bannerStickerEnd,
              ],
              onTap: () => context.go('/stories'),
            ),
            if (showFsl)
              entry(
                emoji: '🤟',
                label: 'Sign Language',
                gradient: const [
                  AppColors.bannerFslStart,
                  AppColors.bannerFslEnd,
                ],
                onTap: () => context.go('/games/fsl-practice'),
              ),
            entry(
              emoji: '🧠',
              label: 'Practice Words',
              gradient: const [
                AppColors.bannerSmartReviewStart,
                AppColors.bannerSmartReviewEnd,
              ],
              onTap: () => context.push('/smart-review'),
            ),
            entry(
              emoji: '🏆',
              label: 'My Progress',
              gradient: const [
                AppColors.bannerLearningGainStart,
                AppColors.bannerLearningGainEnd,
              ],
              onTap: () => context.go('/progress'),
            ),
          ]),

          // ─── Section: Explore & Create ───────────
          const _ChildSectionHeader(emoji: '🗺️', title: 'Explore & Create'),
          grid([
            entry(
              emoji: '🗺️',
              label: 'Adventure Map',
              gradient: const [
                AppColors.bannerRecommendStart,
                AppColors.bannerRecommendEnd,
              ],
              onTap: () => context.push('/learning-paths'),
            ),
            entry(
              emoji: '✍️',
              label: 'Practice With Me',
              gradient: const [
                AppColors.bannerGuidedStart,
                AppColors.bannerGuidedEnd,
              ],
              onTap: () => context.push('/guided-practice'),
            ),
            entry(
              emoji: '📷',
              label: 'Word Hunt',
              gradient: const [
                AppColors.bannerWordHuntStart,
                AppColors.bannerWordHuntEnd,
              ],
              onTap: () => context.push('/object-scan'),
            ),
            entry(
              emoji: '💬',
              label: 'Talk Board',
              gradient: const [
                AppColors.bannerCommBoardStart,
                AppColors.bannerCommBoardEnd,
              ],
              onTap: () => context.push('/communication-board'),
            ),
          ]),

          // ─── Section: Friends ────────────────────
          const _ChildSectionHeader(emoji: '🧑‍🤝‍🧑', title: 'Friends'),
          grid([
            entry(
              emoji: '🧑‍🤝‍🧑',
              label: 'Play Together',
              gradient: const [
                AppColors.bannerPeerStart,
                AppColors.bannerPeerEnd,
              ],
              onTap: () => context.push('/multiplayer'),
            ),
            entry(
              emoji: '💌',
              label: 'Messages',
              gradient: const [
                AppColors.bannerMessagingStart,
                AppColors.bannerMessagingEnd,
              ],
              onTap: () => context.push('/messages'),
            ),
            // Read-only for the child: the notes screen hides its "New Note"
            // button for non-educators, so this is where they see what their
            // parent and teacher have written about them.
            entry(
              emoji: '📝',
              label: 'My Notes',
              gradient: const [
                AppColors.bannerRecommendStart,
                AppColors.bannerRecommendEnd,
              ],
              onTap: () => context.push('/parent-teacher-notes'),
            ),
          ]),

          // ─── Section: Rewards & Feelings ─────────
          const _ChildSectionHeader(emoji: '⭐', title: 'Rewards & Feelings'),
          grid([
            entry(
              emoji: '⭐',
              label: 'Stickers',
              gradient: const [
                AppColors.bannerStickerStart,
                AppColors.bannerStickerEnd,
              ],
              onTap: () => context.push('/sticker-album'),
            ),
            entry(
              emoji: '😊',
              label: 'My Feelings',
              gradient: const [
                AppColors.bannerMoodStart,
                AppColors.bannerMoodEnd,
              ],
              onTap: () => context.push('/mood-check-in'),
            ),
            entry(
              emoji: '🙂',
              label: 'How was it?',
              gradient: const [
                AppColors.bannerLearningStart,
                AppColors.bannerLearningEnd,
              ],
              onTap: () => context.push('/smileyometer'),
            ),
            entry(
              emoji: '📓',
              label: 'My Notebook',
              gradient: const [
                AppColors.bannerNotebookStart,
                AppColors.bannerNotebookEnd,
              ],
              onTap: () => context.push('/notebook'),
            ),
          ]),

          // ─── Footer: parent-only switch profile entry ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.lg,
              ),
              child: Center(
                child: gazeGrid.section(
                  columns: 1,
                  expand: false,
                  entries: [
                    (
                      tile: TextButton.icon(
                        onPressed: () => context.push('/profile-switcher'),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: const Text('Switch profile'),
                      ),
                      cell: GazeTileCell(
                        label: 'Switch profile',
                        onActivate: () => context.push('/profile-switcher'),
                      ),
                    ),
                  ],
                ).first,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A friendly one-row stats strip — streak / words / stars — matching the
/// Student home's stats banner but sized and worded for young learners.
/// Overflow-safe: each stat is an [Expanded] with FittedBox'd numbers.
class _KidStatsStrip extends StatelessWidget {
  const _KidStatsStrip({
    required this.streak,
    required this.words,
    required this.stars,
  });

  final int streak;
  final int words;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final onGrad = hc.textOnPrimary;
    return Semantics(
      label: 'My day: $streak day streak, $words words learned, '
          '$stars stars earned',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: hc.primaryGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            _KidStat(emoji: '🔥', value: '$streak', label: 'Streak',
                color: onGrad),
            _divider(onGrad),
            _KidStat(emoji: '📚', value: '$words', label: 'Words',
                color: onGrad),
            _divider(onGrad),
            _KidStat(emoji: '⭐', value: '$stars', label: 'Stars',
                color: onGrad),
          ],
        ),
      ),
    );
  }

  Widget _divider(Color ink) => Container(
        width: 1,
        height: 36,
        color: ink.withValues(alpha: 0.3),
      );
}

class _KidStat extends StatelessWidget {
  const _KidStat({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  final String emoji;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: color.withValues(alpha: 0.85)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Big, friendly section header for the Child home — an emoji plus a bold
/// title, sized for young learners. Returns a sliver so it can sit directly
/// in the home's [CustomScrollView] between the tile grids.
class _ChildSectionHeader extends StatelessWidget {
  const _ChildSectionHeader({required this.emoji, required this.title});

  final String emoji;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          AppSpacing.sm,
          context.pagePadding,
          AppSpacing.sm,
        ),
        child: Semantics(
          header: true,
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
