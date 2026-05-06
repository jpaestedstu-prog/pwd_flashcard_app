import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/local/seed_stories.dart';
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';

/// Lists all stories grouped by category.
/// Stories unlock based on wordsLearned progress.
class StoryListScreen extends ConsumerWidget {
  const StoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = context.pagePadding;
    final progress = ref.watch(progressProvider);
    final wordsLearned = progress.wordsLearned;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 20, padding, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.auto_stories_rounded, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(AppLocalizations.of(context)!.stories, style: AppTypography.headlineLarge),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideX(begin: -0.05, end: 0),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)!.readStoriesAndAnswer,
                      style: AppTypography.bodyMedium.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                  ],
                ),
              ),
            ),

            // ─── Story Cards ────────────────────────
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
                          Text(category.label, style: AppTypography.titleMedium),
                        ],
                      ).animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: 12),
                      // Story tiles
                      ...stories.asMap().entries.map((entry) {
                        final index = entry.key;
                        final story = entry.value;
                        final unlocked = _isUnlocked(story, wordsLearned);
                        return _StoryCard(
                          story: story,
                          unlocked: unlocked,
                          onTap: unlocked
                              ? () => context.push('/stories/read/${story.id}')
                              : null,
                        )
                            .animate()
                            .fadeIn(
                                duration: 400.ms,
                                delay: (200 + index * 100).ms)
                            .slideY(begin: 0.1, end: 0);
                      }),
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

class _StoryCard extends StatefulWidget {
  final Story story;
  final bool unlocked;
  final VoidCallback? onTap;

  const _StoryCard({
    required this.story,
    required this.unlocked,
    this.onTap,
  });

  @override
  State<_StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<_StoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final story = widget.story;
    final locked = !widget.unlocked;

    return Semantics(
      button: widget.unlocked,
      label: locked
          ? '${story.titleEn} — locked'
          : '${story.titleEn} — tap to read',
      child: GestureDetector(
        onTapDown:
            widget.unlocked ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.unlocked
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap?.call();
              }
            : null,
        onTapCancel:
            widget.unlocked ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: locked
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        hc.surface,
                        story.category.color.withValues(alpha: 0.04),
                      ],
                    ),
              color: locked
                  ? hc.surface.withValues(alpha: 0.5)
                  : null,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: locked
                    ? AppColors.border
                    : story.category.color.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: locked
                  ? null
                  : [
                      BoxShadow(
                        color: story.category.color.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Emoji / Lock
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: locked
                        ? AppColors.border.withValues(alpha: 0.3)
                        : story.category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: locked
                        ? null
                        : [
                            BoxShadow(
                              color: story.category.color.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ],
                  ),
                  child: Center(
                    child: locked
                        ? Icon(Icons.lock_rounded,
                            color: hc.textSecondary, size: 28)
                        : Text(story.emoji,
                            style: const TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 14),
                // Title & info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.titleEn,
                        style: AppTypography.titleSmall.copyWith(
                          color: locked
                              ? hc.textSecondary
                              : hc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        story.titleFil,
                        style: AppTypography.bodySmall.copyWith(
                          color: hc.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${story.sentencesEn.length} sentences · ${story.questions.length} questions',
                        style: AppTypography.labelSmall.copyWith(
                          color: hc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow or lock hint
                Icon(
                  locked
                      ? Icons.lock_outline_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size: 20,
                  color: locked
                      ? hc.textSecondary.withValues(alpha: 0.4)
                      : AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
