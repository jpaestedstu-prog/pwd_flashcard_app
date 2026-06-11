import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../providers/app_providers.dart';
import '../../../core/widgets/hub_scaffold.dart';
import '../../../widgets/profile_avatar.dart';
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

    return HubScaffold(
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
                        ],
                      ),
                    ),
                  ),

                  // ─── Big tile grid ───────────────────────
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: pad),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: context.gridSpacing,
                        crossAxisSpacing: context.gridSpacing,
                        mainAxisExtent: context.hubTileHeight(),
                      ),
                      delegate: SliverChildListDelegate([
                        HomeTile(
                          emoji: '🎮',
                          label: 'Play',
                          gradient: const [
                            AppColors.playerAccent,
                            AppColors.playerAccentLight,
                          ],
                          onTap: () => context.go('/games'),
                        ),
                        HomeTile(
                          emoji: '🧑‍🤝‍🧑',
                          label: 'Play Together',
                          gradient: const [
                            AppColors.bannerPeerStart,
                            AppColors.bannerPeerEnd,
                          ],
                          onTap: () => context.push('/multiplayer'),
                        ),
                        HomeTile(
                          emoji: '🔤',
                          label: 'Words',
                          gradient: const [
                            AppColors.bannerLearningStart,
                            AppColors.bannerLearningEnd,
                          ],
                          onTap: () => context.go('/flashcards'),
                        ),
                        HomeTile(
                          emoji: '📖',
                          label: 'Stories',
                          gradient: const [
                            AppColors.bannerFslStart,
                            AppColors.bannerFslEnd,
                          ],
                          onTap: () => context.go('/stories'),
                        ),
                        HomeTile(
                          emoji: '⭐',
                          label: 'Stickers',
                          gradient: const [
                            AppColors.bannerStickerStart,
                            AppColors.bannerStickerEnd,
                          ],
                          onTap: () => context.push('/sticker-album'),
                        ),
                        HomeTile(
                          emoji: '😊',
                          label: 'How was it?',
                          gradient: const [
                            AppColors.bannerLearningStart,
                            AppColors.bannerLearningEnd,
                          ],
                          onTap: () => context.push('/smileyometer'),
                        ),
                      ]),
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
    );
  }
}
