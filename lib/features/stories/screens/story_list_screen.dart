import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/hub_header.dart';
import '../../../data/local/seed_stories.dart';
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../widgets/story_cover_card.dart';

/// Lists all stories grouped by category as a responsive grid of themed
/// cover cards. Stories unlock based on wordsLearned progress, and each card
/// shows the learner's read/quiz completion state.
///
/// The Child profile gets a simpler, larger "kid mode" layout (fewer columns,
/// bigger cards, no metadata chips).
class StoryListScreen extends ConsumerWidget {
  const StoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = context.pagePadding;
    final progress = ref.watch(progressProvider);
    final wordsLearned = progress.wordsLearned;
    final kidMode = ref.watch(profileProvider)?.role == UserRole.child;

    // 1 column on phones, 2–3 on tablets; kid mode caps at 1–2 so cards stay
    // large and uncluttered.
    final columns = kidMode ? (context.isTablet ? 2 : 1) : context.gridColumns;
    // Fixed cell height (mainAxisExtent) that grows with the Font Size setting
    // — never an aspect ratio, which is the pattern that avoids overflow.
    final cardHeight = context.scaledHeightCapped(
      kidMode
          ? context.responsiveTier(phone: 220.0, tablet: 240.0, large: 260.0)
          : context.responsiveTier(phone: 198.0, tablet: 210.0, large: 224.0),
    );
    final spacing = context.gridSpacing;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ─────────────────────────────
            SliverToBoxAdapter(
              child: HubHeader(
                leadingIcon: Icons.auto_stories_rounded,
                title: AppLocalizations.of(context)!.stories,
                subtitle: AppLocalizations.of(context)!.readStoriesAndAnswer,
              ),
            ),

            // ─── Story grid per category ────────────
            ...FlashcardCategory.values.map((category) {
              final stories = SeedStories.getByCategory(category);
              if (stories.isEmpty) return const SliverToBoxAdapter();
              return SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      // Category header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: category.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: category.color.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(category.icon, color: category.color, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(category.label,
                                style: AppTypography.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ).animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: 12),
                      // Story cover cards
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: stories.length,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: cardHeight,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                        ),
                        itemBuilder: (context, index) {
                          final story = stories[index];
                          final unlocked = _isUnlocked(story, wordsLearned);
                          return StoryCoverCard(
                            story: story,
                            unlocked: unlocked,
                            read: progress.completedStoryIds.contains(story.id),
                            stars: progress.storyBestStars[story.id] ?? 0,
                            kidMode: kidMode,
                            onTap: unlocked
                                ? () => context.push('/stories/read/${story.id}')
                                : null,
                          )
                              .animate()
                              .fadeIn(duration: 350.ms, delay: (80 * index).ms)
                              .slideY(begin: 0.08, end: 0);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  /// Stories unlock progressively:
  /// First story of each category: 0 words (always unlocked)
  /// Second story: 10 words learned
  /// Third story: 25 words learned
  bool _isUnlocked(Story story, int wordsLearned) {
    final stories = SeedStories.getByCategory(story.category);
    final index = stories.indexOf(story);
    return switch (index) {
      0 => true,
      1 => wordsLearned >= 10,
      _ => wordsLearned >= 25,
    };
  }
}
