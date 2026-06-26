import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Gamified home for the Child role.
///
/// Designed for younger learners than the Student `HomeScreen`: bigger
/// targets, more emoji, fewer words. The deeper learning content is
/// reused from the existing routes (`/games`, `/flashcards`, `/stories`,
/// `/sticker-album`) so we don't fork the content layer — only the entry
/// surface differs.
///
/// The whole screen is a [CustomScrollView] and the tile grid sizes each
/// cell by `mainAxisExtent: context.hubTileHeight()` (never by width/aspect
/// ratio), so it can never throw a RenderFlex/bottom overflow on any tablet,
/// orientation, or font scale — it simply scrolls when space runs short.
class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final pad = context.pagePadding;
    // Two big tiles per row on phones/small tablets; all four in one row on
    // large tablets where there's room.
    final columns = context.screenWidth >= 900 ? 4 : 2;

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

    return GazeHomeRegistrar(
      active: gazeGrid.active,
      rows: gazeGrid.rows,
      child: HubScaffold(
      intensity: 0.30,
      slivers: [
                  // ─── Greeting strip ──────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          pad, AppSpacing.md, pad, AppSpacing.lg),
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
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurfaceVariant),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Inline accessibility shortcut — the Child home has
                          // no Settings gear, so this gives the learner self-
                          // service over text size, contrast, read-aloud, etc.
                          const AccessibilityQuickButton(),
                        ],
                      ),
                    ),
                  ),

                  // ─── Section: Play & Learn ───────────────
                  const _ChildSectionHeader(emoji: '🎮', title: 'Play & Learn'),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: pad),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: context.gridSpacing,
                        crossAxisSpacing: context.gridSpacing,
                        mainAxisExtent: context.hubTileHeight(),
                      ),
                      delegate: SliverChildListDelegate(
                        gazeGrid.section(
                          columns: columns,
                          entries: [
                            entry(
                              emoji: '🎮',
                              label: 'Play',
                              gradient: const [
                                AppColors.playerAccent,
                                AppColors.playerAccentLight,
                              ],
                              onTap: () => context.go('/games'),
                            ),
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
                              emoji: '🔤',
                              label: 'Words',
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
                                AppColors.bannerFslStart,
                                AppColors.bannerFslEnd,
                              ],
                              onTap: () => context.go('/stories'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ─── Section: Rewards & Feedback ─────────
                  const _ChildSectionHeader(
                      emoji: '⭐', title: 'Rewards & Feedback'),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: pad),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: context.gridSpacing,
                        crossAxisSpacing: context.gridSpacing,
                        mainAxisExtent: context.hubTileHeight(),
                      ),
                      delegate: SliverChildListDelegate(
                        gazeGrid.section(
                          columns: columns,
                          entries: [
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
                              label: 'How was it?',
                              gradient: const [
                                AppColors.bannerLearningStart,
                                AppColors.bannerLearningEnd,
                              ],
                              onTap: () => context.push('/smileyometer'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ─── Footer: parent-only switch profile entry ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.lg,
                        bottom: AppSpacing.lg,
                      ),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => context.push('/profile-switcher'),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('Switch profile'),
                        ),
                      ),
                    ),
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
