import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart' show hapticServiceProvider;
import '../../../data/models/models.dart';
import '../../../providers/sticker_provider.dart';
import '../../../providers/app_providers.dart';
import '../models/sticker_models.dart';
import '../models/sticker_progress.dart';
import '../widgets/sticker_unlocked_overlay.dart';

class StickerAlbumScreen extends ConsumerStatefulWidget {
  const StickerAlbumScreen({super.key});

  @override
  ConsumerState<StickerAlbumScreen> createState() => _StickerAlbumScreenState();
}

class _StickerAlbumScreenState extends ConsumerState<StickerAlbumScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Stickers earned but never announced, queued for the celebration.
  List<Sticker> _toCelebrate = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: StickerCategory.values.length,
      vsync: this,
    );

    // Check for new stickers on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final progress = ref.read(progressProvider);
      ref.read(stickerProvider.notifier).checkNewStickers(progress);

      // Anything earned since the last visit — including stickers unlocked
      // by the check above, and ones the learner earned mid-game on an
      // earlier run and was never told about.
      final unseen = ref.read(stickerProvider).unseen;
      if (unseen.isEmpty) {
        // Nothing to announce, but record the visit so a sticker earned from
        // here on is still recognised as new.
        ref.read(stickerProvider.notifier).markAllSeen();
        return;
      }
      setState(() {
        _toCelebrate = StickerData.allStickers
            .where((s) => unseen.contains(s.id))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _dismissCelebration() {
    setState(() => _toCelebrate = const []);
    // Marked seen only once the learner has actually been shown the cards.
    ref.read(stickerProvider.notifier).markAllSeen();
  }

  @override
  Widget build(BuildContext context) {
    final collection = ref.watch(stickerProvider);
    final settings = ref.watch(settingsProvider);
    final progress = ref.watch(progressProvider);
    final isFilipino = settings.locale == 'fil';
    final padding = context.pagePadding;
    final hc = HCColor.of(context);

    final total = collection.totalCount;
    final ownedCount = collection.ownedCount;
    final percent = total > 0 ? ownedCount / total : 0.0;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(isFilipino ? 'Album ng Sticker' : 'Sticker Album'),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: SafeArea(
            child: Column(
              children: [
                // ─── Progress Header ──────────
                Padding(
                  padding: EdgeInsets.fromLTRB(padding, 8, padding, 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircularPercentIndicator(
                          radius: 32,
                          percent: percent.clamp(0.0, 1.0),
                          center: Text(
                            '$ownedCount',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                          progressColor: AppColors.textOnPrimary,
                          backgroundColor:
                              AppColors.textOnPrimary.withValues(alpha: 0.3),
                          circularStrokeCap: CircularStrokeCap.round,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isFilipino ? 'Koleksyon' : 'Collection',
                                style: AppTypography.titleSmall.copyWith(
                                  color: AppColors.textOnPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '$ownedCount / $total stickers',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textOnPrimary
                                      .withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text('🎉', style: TextStyle(fontSize: 32)),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                ),

                // ─── Category Tabs ──────────
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: hc.textPrimary,
                  unselectedLabelColor: hc.textSecondary,
                  indicatorColor: AppColors.primary,
                  tabAlignment: TabAlignment.start,
                  tabs: StickerCategory.values.map((cat) {
                    return Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(cat.labelOf(isFilipino: isFilipino)),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                // ─── Sticker Grid ──────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: StickerCategory.values.map((cat) {
                      final stickers = StickerData.byCategory(cat);
                      return GridView.builder(
                        padding: EdgeInsets.all(padding),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: context.isTablet ? 4 : 3,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: stickers.length,
                        itemBuilder: (context, index) {
                          final sticker = stickers[index];
                          final isOwned = collection.contains(sticker.id);
                          return _StickerTile(
                            sticker: sticker,
                            isOwned: isOwned,
                            isNew: collection.isUnseen(sticker.id),
                            progress: isOwned
                                ? StickerProgress.none
                                : StickerProgress.forCondition(
                                    sticker.unlockConditionId,
                                    progress,
                                    ownedStickers: ownedCount,
                                  ),
                            isFilipino: isFilipino,
                            onTap: () => _showStickerDetail(
                              sticker,
                              isOwned,
                              progress,
                              ownedCount,
                            ),
                          )
                              // No per-index stagger. This grid is lazy, so a
                              // tile built after a scroll would begin its
                              // delay only once it came into view and sit
                              // blank for up to a second.
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .scale(
                                begin: const Offset(0.9, 0.9),
                                end: const Offset(1, 1),
                              );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── New-sticker celebration ──────────
        if (_toCelebrate.isNotEmpty)
          StickerUnlockedOverlay(
            stickers: _toCelebrate,
            isFilipino: isFilipino,
            reducedMotion: settings.reducedMotion,
            onDismiss: _dismissCelebration,
          ),
      ],
    );
  }

  void _showStickerDetail(
    Sticker sticker,
    bool isOwned,
    LearningProgress progress,
    int ownedCount,
  ) {
    final settings = ref.read(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final hc = HCColor.of(context);
    final unlockedAt = ref.read(stickerProvider).unlockedAt[sticker.id];
    final goal = isOwned
        ? StickerProgress.none
        : StickerProgress.forCondition(
            sticker.unlockConditionId,
            progress,
            ownedStickers: ownedCount,
          );

    ref.read(hapticServiceProvider).lightTap();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: hc.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Sticker emoji
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isOwned
                    ? sticker.rarity.surfaceOn(hc)
                    : hc.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOwned ? sticker.rarity.color : hc.border,
                  width: 2,
                ),
                boxShadow: isOwned
                    ? [
                        BoxShadow(
                          color: sticker.rarity.color.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: isOwned
                    ? Text(sticker.emoji, style: const TextStyle(fontSize: 44))
                    : Icon(Icons.lock_rounded, size: 36, color: hc.textHint),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isOwned ? sticker.nameOf(isFilipino: isFilipino) : '???',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            // Rarity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: sticker.rarity.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sticker.rarity.labelOf(isFilipino: isFilipino),
                style: AppTypography.labelSmall.copyWith(
                  color: sticker.rarity.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // How to unlock
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isOwned
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: isOwned ? AppColors.success : hc.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isOwned
                        ? (isFilipino ? 'Na-unlock na!' : 'Unlocked!')
                        : sticker.unlockDescriptionOf(isFilipino: isFilipino),
                    style: AppTypography.bodyMedium.copyWith(
                      color: isOwned ? AppColors.success : hc.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            // When it was earned. Only shown for stickers unlocked since the
            // app started recording dates — older ones simply omit the line
            // rather than inventing one.
            if (isOwned && unlockedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                isFilipino
                    ? 'Nakuha noong ${_formatDate(unlockedAt)}'
                    : 'Earned ${_formatDate(unlockedAt)}',
                style: AppTypography.labelSmall.copyWith(color: hc.textHint),
              ),
            ],
            // How close the learner is. "Learn 50 words" alone never said
            // whether they were at 3 or at 49.
            if (!isOwned && goal.isCountable) ...[
              const SizedBox(height: 14),
              _GoalBar(
                goal: goal,
                accent: sticker.rarity.color,
                unit: StickerGoalUnitX.forCondition(sticker.unlockConditionId),
                isFilipino: isFilipino,
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) => '${d.month}/${d.day}/${d.year}';
}

/// The progress bar behind a locked sticker.
class _GoalBar extends StatelessWidget {
  final StickerProgress goal;
  final Color accent;
  final StickerGoalUnit unit;
  final bool isFilipino;

  const _GoalBar({
    required this.goal,
    required this.accent,
    required this.unit,
    required this.isFilipino,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final remaining = (goal.target - goal.current).clamp(0, goal.target);
    final unitLabel =
        isFilipino ? unit.labelFilipino : unit.label;

    return Semantics(
      label: isFilipino
          ? '${goal.current} sa ${goal.target}'
          : '${goal.current} of ${goal.target}',
      child: Column(
        children: [
          // See _StickerTile: the bar's own percentage would be merged into
          // this node's label and read out as a bare number first.
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: goal.fraction,
                minHeight: 8,
                backgroundColor: hc.surfaceLight,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            remaining == 0
                ? goal.label
                : (isFilipino
                    ? '${goal.label} — $remaining $unitLabel pa'
                    : '${goal.label} — $remaining more $unitLabel'),
            style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StickerTile extends StatelessWidget {
  final Sticker sticker;
  final bool isOwned;
  final bool isNew;
  final StickerProgress progress;
  final bool isFilipino;
  final VoidCallback onTap;

  const _StickerTile({
    required this.sticker,
    required this.isOwned,
    required this.isNew,
    required this.progress,
    required this.isFilipino,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final name = sticker.nameOf(isFilipino: isFilipino);
    final rarityLabel = sticker.rarity.labelOf(isFilipino: isFilipino);

    // Screen-reader labels used to be built from the English fields
    // unconditionally, so a Filipino learner heard an English album.
    final semanticsLabel = isOwned
        ? (isFilipino
            ? '$name sticker, $rarityLabel${isNew ? ', bago' : ''}'
            : '$name sticker, $rarityLabel${isNew ? ', new' : ''}')
        : (isFilipino
            ? 'Naka-lock na sticker. ${sticker.unlockDescriptionOf(isFilipino: true)}'
                '${progress.isCountable ? '. ${progress.current} sa ${progress.target}' : ''}'
            : 'Locked sticker. ${sticker.unlockDescriptionOf(isFilipino: false)}'
                '${progress.isCountable ? '. ${progress.current} of ${progress.target}' : ''}');

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isOwned ? sticker.rarity.surfaceOn(hc) : hc.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isNew
                      ? sticker.rarity.color
                      : (isOwned
                          ? sticker.rarity.color.withValues(alpha: 0.4)
                          : hc.border),
                  width: isNew ? 2 : 1,
                ),
                boxShadow: isOwned
                    ? [
                        BoxShadow(
                          color: sticker.rarity.color.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isOwned
                      ? Text(sticker.emoji, style: const TextStyle(fontSize: 36))
                      : Icon(Icons.lock_rounded, size: 32, color: hc.textHint),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      isOwned ? name : '???',
                      style: AppTypography.labelSmall.copyWith(
                        color: isOwned ? hc.textPrimary : hc.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Owned: rarity stars. Locked with a countable goal: how
                  // near it is, so the shelf reads as goals rather than walls.
                  if (isOwned || !progress.isCountable)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        sticker.rarity.stars,
                        (i) => Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: isOwned ? sticker.rarity.color : hc.textHint,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      // Excluded from the a11y tree: LinearProgressIndicator
                      // publishes its own percentage, which merges into the
                      // tile's label and made a screen reader announce
                      // "62, Locked sticker. Learn 50 words. 31 of 50". The
                      // tile's label already states the goal in words.
                      child: ExcludeSemantics(
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress.fraction,
                                minHeight: 4,
                                backgroundColor: hc.surfaceLight,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  sticker.rarity.color.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              progress.label,
                              style: AppTypography.labelSmall.copyWith(
                                color: hc.textHint,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // "New!" flag — the learner has earned it but never been shown it.
            if (isNew)
              Positioned(
                top: -6,
                right: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sticker.rarity.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isFilipino ? 'BAGO' : 'NEW',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
