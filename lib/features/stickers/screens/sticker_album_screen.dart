import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart' show hapticServiceProvider;
import '../../../providers/sticker_provider.dart';
import '../../../providers/app_providers.dart';
import '../models/sticker_models.dart';

class StickerAlbumScreen extends ConsumerStatefulWidget {
  const StickerAlbumScreen({super.key});

  @override
  ConsumerState<StickerAlbumScreen> createState() => _StickerAlbumScreenState();
}

class _StickerAlbumScreenState extends ConsumerState<StickerAlbumScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: StickerCategory.values.length,
      vsync: this,
    );

    // Check for new stickers on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final progress = ref.read(progressProvider);
      ref.read(stickerProvider.notifier).checkNewStickers(progress);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owned = ref.watch(stickerProvider);
    final stickerNotifier = ref.read(stickerProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final padding = context.pagePadding;
    final hc = HCColor.of(context);

    final total = stickerNotifier.totalCount;
    final ownedCount = stickerNotifier.ownedCount;
    final percent = total > 0 ? ownedCount / total : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Sticker Album' : 'Sticker Album'),
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
                      backgroundColor: AppColors.textOnPrimary.withValues(alpha: 0.3),
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
                            '$ownedCount / $total ${isFilipino ? 'stickers' : 'stickers'}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textOnPrimary.withValues(alpha: 0.85),
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
                      Text(cat.label),
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
                      final isOwned = owned.contains(sticker.id);
                      return _StickerTile(
                        sticker: sticker,
                        isOwned: isOwned,
                        isFilipino: isFilipino,
                        onTap: () => _showStickerDetail(sticker, isOwned),
                      )
                          .animate()
                          .fadeIn(
                            duration: 300.ms,
                            delay: (50 * index).ms,
                          )
                          .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStickerDetail(Sticker sticker, bool isOwned) {
    final settings = ref.read(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final hc = HCColor.of(context);

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
                    ? sticker.rarity.bgColor
                    : hc.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOwned
                      ? sticker.rarity.color
                      : hc.border,
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
                    ? Text(sticker.emoji,
                        style: const TextStyle(fontSize: 44))
                    : Icon(Icons.lock_rounded,
                        size: 36, color: hc.textHint),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isOwned
                  ? (isFilipino ? sticker.nameFilipino : sticker.name)
                  : '???',
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
                isFilipino ? sticker.rarity.labelFilipino : sticker.rarity.label,
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
                  isOwned ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 18,
                  color: isOwned ? AppColors.success : hc.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  isOwned
                      ? (isFilipino ? 'Na-unlock na!' : 'Unlocked!')
                      : (isFilipino
                          ? sticker.unlockDescriptionFilipino
                          : sticker.unlockDescription),
                  style: AppTypography.bodyMedium.copyWith(
                    color: isOwned ? AppColors.success : hc.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _StickerTile extends StatelessWidget {
  final Sticker sticker;
  final bool isOwned;
  final bool isFilipino;
  final VoidCallback onTap;

  const _StickerTile({
    required this.sticker,
    required this.isOwned,
    required this.isFilipino,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Semantics(
      button: true,
      label: isOwned
          ? '${sticker.name} sticker, ${sticker.rarity.label}'
          : 'Locked sticker. ${sticker.unlockDescription}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isOwned ? sticker.rarity.bgColor : hc.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOwned
                  ? sticker.rarity.color.withValues(alpha: 0.4)
                  : hc.border,
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
                  ? Text(sticker.emoji,
                      style: const TextStyle(fontSize: 36))
                  : Icon(Icons.lock_rounded,
                      size: 32, color: hc.textHint),
              const SizedBox(height: 6),
              Text(
                isOwned
                    ? (isFilipino ? sticker.nameFilipino : sticker.name)
                    : '???',
                style: AppTypography.labelSmall.copyWith(
                  color: isOwned ? hc.textPrimary : hc.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Rarity stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  sticker.rarity.stars,
                  (i) => Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: isOwned
                        ? sticker.rarity.color
                        : hc.textHint,
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
