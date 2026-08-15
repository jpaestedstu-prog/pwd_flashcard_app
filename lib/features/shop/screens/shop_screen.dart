import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../../widgets/app_back_button.dart';
import '../../../widgets/celebration_confetti.dart';
import '../logic/shop_advice.dart';

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

  /// Only the categories with something to sell. Built once: the catalogue is
  /// compile-time data, and the TabController's length must match it.
  late final List<ShopItemType> _types;

  @override
  void initState() {
    super.initState();
    _types = ShopData.sellableTypes;
    _tabController = TabController(length: _types.length, vsync: this);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    // After the first frame: this writes to Hive and bumps progress state,
    // which is not safe to do while the tree is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refundWithdrawn());
  }

  /// Returns the stars for anything the learner bought that has since been
  /// pulled from sale, and tells them it happened — a balance that changes
  /// without explanation is worse than the original problem.
  void _refundWithdrawn() {
    if (!mounted) return;
    final refunded =
        ref.read(progressProvider.notifier).refundWithdrawnPurchases();
    if (refunded <= 0 || !mounted) return;
    AppSnackBar.info(
      context,
      message: AppLocalizations.of(context)!.starsRefunded(refunded),
    );
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
            leading: const AppBackButton(),
            // The star-balance chip in `actions` takes its width first, so on a
            // narrow phone the title box is left with less than the icon +
            // "Star Shop" need — 49 px short at the default font, 149 px at 2.0x.
            // Flexible lets the words give way instead of overflowing.
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.store_rounded, size: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    AppLocalizations.of(context)!.starShop,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                for (final type in _types)
                  Tab(
                    icon: Icon(_iconFor(type)),
                    text: _labelFor(context, type),
                  ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              for (final type in _types)
                if (type == ShopItemType.theme)
                  _ThemeShopGrid(
                    items: ShopData.sellableByType(type),
                    onPurchase: _handlePurchase,
                  )
                else
                  _ShopGrid(
                    items: ShopData.sellableByType(type),
                    onPurchase: _handlePurchase,
                  ),
            ],
          ),
        ),
        // Confetti overlay
        Align(
          alignment: Alignment.topCenter,
          // Buying an effect shows you the effect you just bought.
          child: CelebrationConfetti(controller: _confettiController),
        ),
      ],
    ),
    ),
    );
  }

  /// Whether the learner has chosen Filipino. Item names and descriptions are
  /// catalogue data rather than ARB entries (see [ShopItem.nameFilipino]), so
  /// they are resolved against this rather than through [AppLocalizations].
  bool get _isFilipino => ref.read(settingsProvider).locale == 'fil';

  String _name(ShopItem item) => item.localizedName(_isFilipino);

  /// The advice sentence for [advice], or null when there is nothing to say.
  static String? adviceText(BuildContext context, ShopAdvice advice) {
    final l10n = AppLocalizations.of(context)!;
    return switch (advice) {
      ShopAdvice.none => null,
      ShopAdvice.themeOverriddenByContrast => l10n.themeOverriddenByContrast,
      ShopAdvice.themeOverriddenByDyslexia => l10n.themeOverriddenByDyslexia,
      ShopAdvice.effectPlaysGently => l10n.effectPlaysGently,
    };
  }

  IconData _iconFor(ShopItemType type) => switch (type) {
        ShopItemType.avatar => Icons.face_rounded,
        ShopItemType.theme => Icons.palette_rounded,
        ShopItemType.border => Icons.border_all_rounded,
        ShopItemType.title => Icons.badge_rounded,
        ShopItemType.soundPack => Icons.music_note_rounded,
        ShopItemType.celebration => Icons.celebration_rounded,
      };

  String _labelFor(BuildContext context, ShopItemType type) {
    final l10n = AppLocalizations.of(context)!;
    return switch (type) {
      ShopItemType.avatar => l10n.avatars,
      ShopItemType.theme => l10n.themes,
      ShopItemType.border => l10n.borders,
      ShopItemType.title => l10n.titles,
      ShopItemType.soundPack => l10n.sounds,
      ShopItemType.celebration => l10n.effects,
    };
  }

  void _handlePurchase(ShopItem item) {
    final balance = ref.read(progressProvider).starBalance;

    // Belt and braces: withdrawn items are already filtered out of the grid,
    // so reaching here means a stale build — never take the stars.
    if (!item.available) {
      AppSnackBar.info(
        context,
        message: AppLocalizations.of(context)!.itemNotReady(_name(item)),
      );
      return;
    }

    if (ref.read(progressProvider.notifier).hasPurchased(item.id)) {
      AppSnackBar.info(context, message: AppLocalizations.of(context)!.alreadyOwned);
      return;
    }

    if (balance < item.cost) {
      AppSnackBar.warning(
        context,
        message: AppLocalizations.of(context)!
            .notEnoughStars(item.cost - balance),
      );
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.buyItem(_name(item))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.emoji,
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 12),
            Text(
              item.localizedDescription(_isFilipino),
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            // A learner whose own settings will override what they are about
            // to buy deserves to hear it here, not discover it afterwards.
            if (adviceText(
                  context,
                  adviceFor(item, ref.read(settingsProvider)),
                )
                case final advice?) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 18, color: AppColors.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        advice,
                        style: AppTypography.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
      AppSnackBar.success(
        context,
        message: AppLocalizations.of(context)!.purchaseSuccess(_name(item)),
      );
    }
  }
}

/// Grid cells are sized as a fraction of their width, but every part of a shop
/// card — emoji, name, status chip — grows with the learner's Font Size
/// setting. A fixed ratio therefore holds the cell still while its contents
/// grow: at XL font on a 360 dp phone the cards overflowed by 23 px (5.7 px on
/// the Themes tab). Trading width-for-height as the text scales keeps the
/// accessible font sizes readable instead of clipped.
///
/// Growth is capped at 2.0x — the largest scale the app supports (`main.dart`
/// clamps its own font setting to 1.5x, the rest comes from the OS) — so the
/// cells never grow without bound.
double _scaledAspect(BuildContext context, double base) {
  final scale = MediaQuery.textScalerOf(context).scale(1.0);
  return base / (1 + 0.5 * (scale - 1).clamp(0.0, 1.0));
}

class _ShopGrid extends ConsumerWidget {
  final List<ShopItem> items;
  final void Function(ShopItem) onPurchase;

  const _ShopGrid({required this.items, required this.onPurchase});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: _scaledAspect(context, 0.75),
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
          isFilipino: isFilipino,
          advice: adviceFor(item, settings),
          recommended: isRecommendedFor(item, settings),
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
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: _scaledAspect(context, 0.65),
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
          isFilipino: isFilipino,
          hasAdvice: adviceFor(item, settings) != ShopAdvice.none,
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
  final bool isFilipino;
  final ShopAdvice advice;
  final bool recommended;
  final bool owned;
  final bool canAfford;
  final bool isEquipped;
  final VoidCallback onTap;

  const _ShopItemCard({
    required this.item,
    required this.isFilipino,
    required this.advice,
    required this.recommended,
    required this.owned,
    required this.canAfford,
    required this.isEquipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = isEquipped
        ? l10n.equipped
        : owned
            ? l10n.tapToEquip
            : '${item.cost} ${l10n.stars}';

    final adviceLine = _ShopScreenState.adviceText(context, advice);
    final recommendedLine = recommended ? '${l10n.recommendedForYou}. ' : '';

    return Semantics(
      button: true,
      label: '${item.localizedName(isFilipino)}, '
          '${item.localizedDescription(isFilipino)}, $recommendedLine$status'
          '${adviceLine == null ? '' : '. $adviceLine'}',
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
          child: Stack(
            children: [
              if (adviceLine != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Tooltip(
                    message: adviceLine,
                    child: const Icon(Icons.info_outline_rounded,
                        size: 18, color: AppColors.info),
                  ),
                ),
              if (recommended)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Tooltip(
                    message: l10n.recommendedForYou,
                    child: const Icon(Icons.thumb_up_rounded,
                        size: 16, color: AppColors.success),
                  ),
                ),
              Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji. Flexible + scaleDown so the picture yields space to the
              // name and price rather than pushing them out of the card: for a
              // pre-literate learner the picture IS the product, so it must
              // survive every font size even if it has to shrink to do it.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.emoji,
                    style: TextStyle(
                      fontSize: 48,
                      color: owned || canAfford
                          ? null
                          : HCColor.of(context).textHint,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Name
              Text(
                item.localizedName(isFilipino),
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isEquipped
                      ? AppColors.primary
                      : owned
                          ? AppColors.success
                          : HCColor.of(context).textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
            ],
          ),
        ),
      ),
    );
  }
}
