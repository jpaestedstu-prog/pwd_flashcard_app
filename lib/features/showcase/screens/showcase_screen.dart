import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/accessibility/sound_service.dart';
import '../../../providers/app_providers.dart';
import '../models/showcase_models.dart';
import '../providers/showcase_provider.dart';
import '../widgets/showcase_widgets.dart';

class ShowcaseScreen extends ConsumerStatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  ConsumerState<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends ConsumerState<ShowcaseScreen> {
  ShowcaseItemType? _filter;
  bool _isAutoPopulating = false;

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(showcaseProvider);
    final progress = ref.watch(progressProvider);
    final profile = ref.watch(profileProvider);
    final hc = HCColor.of(context);

    final filteredItems = _filter == null
        ? portfolio.sortedItems
        : portfolio.sortedItems
            .where((i) => i.type == _filter)
            .toList();

    final achievementCount =
        portfolio.items.where((i) => i.type == ShowcaseItemType.achievement).length;

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'My Portfolio',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        actions: [
          if (portfolio.items.isNotEmpty)
            IconButton(
              onPressed: () => context.push('/showcase/share'),
              icon: Icon(Icons.share_rounded, color: hc.textSecondary),
              tooltip: 'Share Portfolio',
            ),
          IconButton(
            onPressed: _isAutoPopulating ? null : () => _autoPopulate(ref),
            icon: _isAutoPopulating
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: hc.textSecondary,
                    ),
                  )
                : Icon(Icons.auto_awesome_rounded, color: hc.textSecondary),
            tooltip: 'Auto-curate portfolio',
          ),
        ],
      ),
      body: portfolio.items.isEmpty
          ? ShowcaseEmptyState(onAutoPopulate: () => _autoPopulate(ref))
          : CustomScrollView(
              slivers: [
                // ─── Portfolio Header ──────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: PortfolioHeader(
                      name: profile?.name ?? 'Learner',
                      totalItems: portfolio.items.length,
                      pinnedItems: portfolio.pinnedCount,
                      achievementCount: achievementCount,
                      starsEarned: progress.totalStars,
                    ),
                  ),
                ),

                // ─── Filter Chips ─────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: ShowcaseFilterChips(
                      selectedFilter: _filter,
                      typeCounts: portfolio.typeCounts,
                      onFilterChanged: (f) => setState(() => _filter = f),
                    ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                  ),
                ),

                // ─── Items Count ──────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      '${filteredItems.length} item${filteredItems.length == 1 ? '' : 's'}',
                      style: AppTypography.labelMedium.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  ),
                ),

                // ─── Portfolio Grid ───────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = filteredItems[index];
                        return ShowcaseCard(
                          item: item,
                          onTap: () =>
                              context.push('/showcase/detail', extra: item),
                          onPin: () => ref
                              .read(showcaseProvider.notifier)
                              .togglePin(item.id),
                          onRemove: () => _confirmRemove(context, ref, item),
                        )
                            .animate()
                            .fadeIn(
                              duration: 400.ms,
                              delay: (200 + index * 60).ms,
                            )
                            .slideY(begin: 0.1, end: 0);
                      },
                      childCount: filteredItems.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
      floatingActionButton: portfolio.items.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showAddNoteDialog(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Note'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
              .animate()
              .fadeIn(duration: 400.ms, delay: 400.ms)
              .slideY(begin: 0.3, end: 0)
          : null,
    );
  }

  Future<void> _autoPopulate(WidgetRef ref) async {
    setState(() => _isAutoPopulating = true);
    final progress = ref.read(progressProvider);
    final newItems =
        await ref.read(showcaseProvider.notifier).autoPopulate(progress);
    if (!mounted) return;
    setState(() => _isAutoPopulating = false);

    if (newItems.isNotEmpty) {
      ref.read(hapticServiceProvider).celebration();
      ref.read(soundServiceProvider).playStar();
      AppSnackBar.success(context, message: 'Added ${newItems.length} new item${newItems.length == 1 ? '' : 's'} to your portfolio!');
    } else {
      AppSnackBar.info(context, message: 'Portfolio is already up to date!');
    }
  }

  void _confirmRemove(
      BuildContext context, WidgetRef ref, ShowcaseItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Portfolio?'),
        content: Text(
            'Remove "${item.title}" from your showcase? You can always add it back later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(showcaseProvider.notifier).removeItem(item.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Text('📌', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Add a Note'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., "My Favorite Game"',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: 'Note',
                hintText: 'Write about your learning journey...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              final note = noteController.text.trim();
              if (title.isNotEmpty && note.isNotEmpty) {
                Navigator.pop(ctx);
                ref.read(showcaseProvider.notifier).addNote(title, note);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
