import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/celebration_service.dart';
import '../../../data/models/shop_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/lottie_celebration_overlay.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../widgets/theme_preview_card.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ConfettiController _confettiController;
  bool _showCelebration = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final balance = progress.starBalance;

    final celebration = ref.read(celebrationServiceProvider);

    return AnimatedGradientBackground(
      preset: GradientPreset.shop,
      child: LottieCelebrationOverlay(
      show: _showCelebration,
      lottieAsset: celebration.lottieAssetFor(CelebrationType.purchase),
      child: Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Go back',
              onPressed: () => context.pop(),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.store_rounded, size: 24),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.starShop),
              ],
            ),
            actions: [
              // Star balance chip
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Chip(
                  avatar: const Icon(Icons.star_rounded,
                      size: 18, color: AppColors.warning),
                  label: Text(
                    '$balance',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                  side: BorderSide(
                    color: AppColors.warning.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: HCColor.of(context).textSecondary,
              indicatorColor: AppColors.primary,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(icon: const Icon(Icons.face_rounded), text: AppLocalizations.of(context)!.avatars),
                Tab(icon: const Icon(Icons.palette_rounded), text: AppLocalizations.of(context)!.themes),
                Tab(icon: const Icon(Icons.border_all_rounded), text: AppLocalizations.of(context)!.borders),
                const Tab(icon: Icon(Icons.badge_rounded), text: 'Titles'),
                const Tab(icon: Icon(Icons.music_note_rounded), text: 'Sounds'),
                const Tab(icon: Icon(Icons.celebration_rounded), text: 'Effects'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _ShopGrid(
                items: ShopData.byType(ShopItemType.avatar),
                onPurchase: _handlePurchase,
              ),
              _ThemeShopGrid(
                items: ShopData.byType(ShopItemType.theme),
                onPurchase: _handlePurchase,
              ),
              _ShopGrid(
                items: ShopData.byType(ShopItemType.border),
                onPurchase: _handlePurchase,
              ),
              _ShopGrid(
                items: ShopData.byType(ShopItemType.title),
                onPurchase: _handlePurchase,
              ),
              _ShopGrid(
                items: ShopData.byType(ShopItemType.soundPack),
                onPurchase: _handlePurchase,
              ),
              _ShopGrid(
                items: ShopData.byType(ShopItemType.celebration),
                onPurchase: _handlePurchase,
              ),
            ],
          ),
        ),
        // Confetti overlay
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 20,
            gravity: 0.3,
            emissionFrequency: 0.05,
            maxBlastForce: 15,
            colors: const [
              AppColors.primary,
              AppColors.accent,
              AppColors.warning,
              AppColors.success,
              AppColors.info,
            ],
          ),
        ),
      ],
    ),
    ),
    );
  }

  void _handlePurchase(ShopItem item) {
    final balance = ref.read(progressProvider).starBalance;

    if (ref.read(progressProvider.notifier).hasPurchased(item.id)) {
      AppSnackBar.info(context, message: AppLocalizations.of(context)!.alreadyOwned);
      return;
    }

    if (balance < item.cost) {
      AppSnackBar.warning(context, message: 'Not enough stars! You need ${item.cost - balance} more ⭐');
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Buy ${item.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.emoji,
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 12),
            Text(
              item.description,
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded,
                    size: 20, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  '${item.cost} stars',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _completePurchase(item);
            },
            child: Text(AppLocalizations.of(context)!.buy),
          ),
        ],
      ),
    );
  }

  void _completePurchase(ShopItem item) {
    final success =
        ref.read(progressProvider.notifier).purchaseItem(item.id, item.cost);
    if (success) {
      _confettiController.play();
      setState(() => _showCelebration = true);
      ref.read(celebrationServiceProvider).celebrate(CelebrationType.purchase);
      AppSnackBar.success(context, message: '🎉 You got ${item.name}!');
    }
  }
}

class _ShopGrid extends ConsumerWidget {
  final List<ShopItem> items;
  final void Function(ShopItem) onPurchase;

  const _ShopGrid({required this.items, required this.onPurchase});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final owned = ref.read(progressProvider.notifier).hasPurchased(item.id);
        final canAfford = progress.starBalance >= item.cost;
        final equippedId =
            ref.read(progressProvider.notifier).getEquippedItemId(item.type);
        final isEquipped = equippedId == item.id;

        return _ShopItemCard(
          item: item,
          owned: owned,
          canAfford: canAfford,
          isEquipped: isEquipped,
          onTap: () {
            if (owned) {
              // Toggle equip/unequip
              if (isEquipped) {
                ref.read(progressProvider.notifier).unequipItem(item.type);
              } else {
                ref.read(progressProvider.notifier).equipItem(item.id, item.type);
              }
            } else {
              onPurchase(item);
            }
          },
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: (100 + index * 80).ms)
            .scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1, 1),
              curve: Curves.easeOut,
            );
      },
    );
  }
}

class _ThemeShopGrid extends ConsumerWidget {
  final List<ShopItem> items;
  final void Function(ShopItem) onPurchase;

  const _ThemeShopGrid({required this.items, required this.onPurchase});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.65,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final owned = ref.read(progressProvider.notifier).hasPurchased(item.id);
        final canAfford = progress.starBalance >= item.cost;
        final equippedId =
            ref.read(progressProvider.notifier).getEquippedItemId(item.type);
        final isEquipped = equippedId == item.id;

        return ThemePreviewCard(
          item: item,
          owned: owned,
          canAfford: canAfford,
          isEquipped: isEquipped,
          onTap: () {
            if (owned) {
              if (isEquipped) {
                ref.read(progressProvider.notifier).unequipItem(item.type);
              } else {
                ref.read(progressProvider.notifier).equipItem(item.id, item.type);
              }
            } else {
              onPurchase(item);
            }
          },
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: (100 + index * 80).ms)
            .scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1, 1),
              curve: Curves.easeOut,
            );
      },
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final bool owned;
  final bool canAfford;
  final bool isEquipped;
  final VoidCallback onTap;

  const _ShopItemCard({
    required this.item,
    required this.owned,
    required this.canAfford,
    required this.isEquipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.name}, ${item.description}, '
          '${isEquipped ? "Equipped" : owned ? "Owned, tap to equip" : "${item.cost} stars"}',
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isEquipped
                ? AppColors.primary
                : owned
                    ? AppColors.success
                    : canAfford
                        ? item.color.withValues(alpha: 0.5)
                        : AppColors.border,
            width: isEquipped ? 2.5 : owned ? 2 : 1,
          ),
        ),
        color: isEquipped
            ? item.color.withValues(alpha: 0.25)
            : owned
                ? item.color.withValues(alpha: 0.15)
                : HCColor.of(context).surface,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji
              Text(
                item.emoji,
                style: TextStyle(
                  fontSize: 48,
                  color: owned || canAfford ? null : HCColor.of(context).textHint,
                ),
              ),
              const SizedBox(height: 8),
              // Name
              Text(
                item.name,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isEquipped
                      ? AppColors.primary
                      : owned
                          ? AppColors.success
                          : HCColor.of(context).textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Status badge
              if (isEquipped)
                Chip(
                  avatar: const Icon(Icons.check_circle_rounded,
                      size: 14, color: AppColors.primary),
                  label: Text(
                    AppLocalizations.of(context)!.equipped,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              else if (owned)
                Chip(
                  avatar: const Icon(Icons.touch_app_rounded,
                      size: 14, color: Color(0xFF2E7D32)),
                  label: Text(
                    AppLocalizations.of(context)!.tapToEquip,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.successDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  backgroundColor: AppColors.successLight,
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              else
                Chip(
                  avatar: Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: canAfford
                        ? AppColors.warning
                        : HCColor.of(context).textSecondary,
                  ),
                  label: Text(
                    '${item.cost}',
                    style: AppTypography.labelSmall.copyWith(
                      color: canAfford
                          ? AppColors.warning
                          : HCColor.of(context).textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  backgroundColor: canAfford
                      ? AppColors.warning.withValues(alpha: 0.15)
                      : HCColor.of(context).surfaceVariant,
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
