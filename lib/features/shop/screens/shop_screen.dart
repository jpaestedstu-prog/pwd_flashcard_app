import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/celebration_service.dart';
import '../../../core/services/celebration_style.dart';
import '../../../data/models/shop_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/lottie_celebration_overlay.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../widgets/shop_badge.dart';
import '../../../widgets/theme_preview_card.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/celebration_confetti.dart';
import '../logic/shop_advice.dart';
import '../widgets/shop_item_preview.dart';
import '../../../core/widgets/fit_text.dart';

/// Tab-strip metrics, shared by the layout and the width estimate below so the
/// two can never disagree about how wide a tab is.
///
/// Trimmed from Material's defaults (24 dp icon, 16 dp gutter): six shelves at
/// the roomier numbers did not fit a 686 dp tablet, and the space was going
/// into gaps rather than into anything a learner reads.
const double _kTabIcon = 22;
const double _kTabGap = 6;
const double _kTabGutter = 10;

/// Nominal size of a tab label, matching Material's `titleSmall` default.
const double _kTabLabelSize = 14;

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

  /// The style the purchase burst is fired in, when the thing just bought is
  /// itself a Celebration Effect.
  ///
  /// Buying Fireworks used to fire the *equipped* effect — the standard burst,
  /// since a purchase does not equip — so the one moment the app had to show
  /// a learner what their 25 stars had bought showed them something else.
  CelebrationStyle? _purchaseStyle;

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
            // Laid out by hand rather than with `Tab(icon:, text:)`, which
            // hard-codes a 72dp box: the label then has nowhere to grow, and
            // under the dyslexia theme at 2.0x (1.6 line height) it ran 5px
            // past the bottom. Icon *beside* the label instead of above needs
            // far less height, and the height below tracks the text scale so
            // nothing is shrunk to make it fit.
            //
            // Whether the strip scrolls is decided per build rather than fixed
            // on. Always-scrolling plus `TabAlignment.start` was fine at five
            // shelves and wrong at six: the row hugged the left edge and
            // "Effects" was sliced in half by the right edge of a 686 dp
            // tablet. When the six tabs fit, they now share the width evenly
            // with each label centred in its own tab; when the font is large
            // enough that they genuinely cannot, it goes back to scrolling
            // rather than squeezing the text a learner asked to enlarge.
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(
                48 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fits =
                      _tabStripWidth(context) <= constraints.maxWidth;
                  return TabBar(
                    controller: _tabController,
                    isScrollable: !fits,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: HCColor.of(context).textSecondary,
                    indicatorColor: AppColors.primary,
                    // Filled tabs are centred in their own share of the bar;
                    // a scrolling strip starts at the left so tab one is
                    // still the one you see first.
                    tabAlignment:
                        fits ? TabAlignment.fill : TabAlignment.start,
                    labelPadding: const EdgeInsets.symmetric(
                      horizontal: _kTabGutter,
                    ),
                    tabs: [
                      for (final type in _types)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_iconFor(type), size: _kTabIcon),
                              const SizedBox(width: _kTabGap),
                              Flexible(
                                child: Text(
                                  _labelFor(context, type),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
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
          child: CelebrationConfetti(
            controller: _confettiController,
            style: _purchaseStyle,
          ),
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
      ShopAdvice.soundPackNeedsSound => l10n.soundPackNeedsSound,
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

  /// Width every tab needs to be drawn in full, laid end to end.
  ///
  /// Estimated rather than measured, for the reason [FitText] documents: these
  /// labels render in a Google font that is not resolved at measure time, so a
  /// `TextPainter` reports a comfortable fit and the real face then overflows.
  /// 0.58 em per character is the same safe average used there.
  ///
  /// The 8% bias buys two things. It covers the estimate's own error — six
  /// English tabs at 1.2x measured 673 dp on the tablet against 668 dp
  /// predicted — and it means the bar only fills when the tabs fit
  /// *comfortably*. A 2% fit is not a fit worth taking: 13 dp of slack shared
  /// between six tabs leaves every label touching its gutter, which reads
  /// worse than the scrolling strip with its natural spacing.
  ///
  /// Filipino needs the room. "Mga Avatar" and "Mga Epekto" run 57 characters
  /// across the six shelves where English runs 39, so that language scrolls at
  /// every font size, correctly.
  double _tabStripWidth(BuildContext context) {
    final fontSize =
        _kTabLabelSize * MediaQuery.textScalerOf(context).scale(1.0);
    var total = 0.0;
    for (final type in _types) {
      total += _kTabIcon +
          _kTabGap +
          _kTabGutter * 2 +
          _labelFor(context, type).length * 0.58 * fontSize;
    }
    return total * 1.08;
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

    _showItemDialog(item, shortfall: item.cost - balance);
  }

  /// The one place an item explains itself.
  ///
  /// Opens for an item the learner can afford *and* for one they cannot
  /// ([shortfall] > 0). A warning snackbar used to be the whole answer to
  /// "you don't have enough", which meant the items worth saving for were the
  /// only ones a learner could never look at: the preview lives in this
  /// dialog, and the dialog only opened once you could already pay. Now the
  /// tap always shows the thing — it just swaps the Buy button for how many
  /// stars are still to go.
  void _showItemDialog(ShopItem item, {required int shortfall}) {
    final affordable = shortfall <= 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // AlertDialog gives its content a Flexible, not a scroll view, so a
        // tall dialog overflows rather than scrolling. This one is now a
        // preview, a description, an advice paragraph, a price and a
        // shortfall line, and at 2.0x on a 360x640 phone the plainest shelf of
        // all — an avatar — burst its box by 38 px. Scrolling is the accessible
        // answer: the learners who set the font that large are exactly the
        // ones who must not lose the Buy button off the bottom.
        scrollable: true,
        title: Text(
          affordable
              ? AppLocalizations.of(context)!.buyItem(_name(item))
              : _name(item),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShopItemPreview(item: item, isFilipino: _isFilipino),
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
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded,
                    size: 20, color: AppColors.warning),
                const SizedBox(width: 4),
                // Flexible because the price line is now localised: "45
                // bituin" is wider than "45 stars", and wider again at 2.0x
                // font inside a dialog that cannot grow.
                Flexible(
                  child: Text(
                    '${item.cost} ${AppLocalizations.of(context)!.stars}',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (!affordable) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.starsToGo(shortfall),
                style: AppTypography.bodyMedium.copyWith(
                  color: HCColor.of(context).textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actions: affordable
            ? [
                TextButton(
                  style: _kDialogCancelStyle,
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                FilledButton(
                  style: _kDialogConfirmStyle,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _completePurchase(item);
                  },
                  child: Text(AppLocalizations.of(context)!.buy),
                ),
              ]
            // Nothing to cancel and nothing to confirm — one way out, worded
            // as the encouragement it is rather than as a dead end.
            : [
                FilledButton(
                  style: _kDialogConfirmStyle,
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.of(context)!.keepEarning),
                ),
              ],
      ),
    );
  }

  /// The just-bought effect's own style, or null to leave the burst as the
  /// learner's equipped one — which is the right answer for every other type,
  /// where the purchase changes nothing about how confetti looks.
  CelebrationStyle? _boughtEffectStyle(ShopItem item) {
    if (item.type != ShopItemType.celebration) return null;
    final style = CelebrationStyle.forItemId(item.id);
    return ref.read(settingsProvider).reducedMotion ? style.calmed() : style;
  }

  void _completePurchase(ShopItem item) {
    final success =
        ref.read(progressProvider.notifier).purchaseItem(item.id, item.cost);
    if (success) {
      _confettiController.play();
      setState(() {
        _showCelebration = true;
        _purchaseStyle = _boughtEffectStyle(item);
      });
      ref.read(celebrationServiceProvider).celebrate(CelebrationType.purchase);
      AppSnackBar.success(
        context,
        message: AppLocalizations.of(context)!.purchaseSuccess(_name(item)),
      );
    }
  }
}

/// The buy dialog's two actions.
///
/// Spelled out rather than left to the theme's defaults because this is where
/// stars are actually spent: at the default density Material gave "Buy!" a
/// 99x58 dp box that was barely larger than the "Cancel" beside it, on a screen
/// whose users include learners aiming with a head pointer or a switch. A
/// minimum of 52 dp tall — the app's own CTA height — and a wider box for the
/// confirming action make the difference between the two visible before it is
/// read.
final ButtonStyle _kDialogConfirmStyle = FilledButton.styleFrom(
  minimumSize: const Size(132, 52),
  padding: const EdgeInsets.symmetric(horizontal: 24),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  textStyle: const TextStyle(fontWeight: FontWeight.w700),
);

final ButtonStyle _kDialogCancelStyle = TextButton.styleFrom(
  minimumSize: const Size(96, 52),
  padding: const EdgeInsets.symmetric(horizontal: 20),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
);

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

/// Outer padding and inter-cell gap for both shelves.
const double _kGridPad = 16;
const double _kGridGap = 14;

/// Card width each shelf aims for, in dp at the default font.
///
/// An item card holds a picture, one or two words and a price pill, so it wants
/// roughly a thumbnail's width. A theme card holds a whole miniature of the app
/// and wants more; both are targets, not minimums — [_gridColumns] rounds to
/// whole cards and the cells share out whatever is left over.
const double _kItemCardWidth = 190;
const double _kThemeCardWidth = 205;

/// How many cards fit across [width] dp of shelf.
///
/// Fixed at two columns, a 686 dp tablet drew a 315x420 dp card around a 48 dp
/// emoji and one word: most of every card was empty, and eight avatars needed
/// four screens of scrolling to see. Sizing from a *target card width* instead
/// keeps a phone at the two it always had and lets a tablet show three or four,
/// so a card ends up about as big as the thing it is selling.
///
/// The target grows with the learner's Font Size, so a large font buys fewer,
/// wider cards rather than the same cards with less room for the words — and
/// the floor of two means the biggest font can never leave a phone with a
/// single card per row.
int _gridColumns(BuildContext context, double width, double target) {
  final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 2.0);
  final scaled = target * (1 + 0.5 * (scale - 1));
  return (width / scaled).floor().clamp(2, 5);
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

    return LayoutBuilder(builder: (context, constraints) {
      final columns = _gridColumns(
        context,
        constraints.maxWidth - _kGridPad * 2,
        _kItemCardWidth,
      );

      return GridView.builder(
        padding: const EdgeInsets.all(_kGridPad),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: _kGridGap,
          crossAxisSpacing: _kGridGap,
          childAspectRatio: _scaledAspect(context, 1.0),
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final owned = ref.read(progressProvider.notifier).hasPurchased(item.id);
          final equippedId =
              ref.read(progressProvider.notifier).getEquippedItemId(item.type);
          final isEquipped = equippedId == item.id;

          return _ShopItemCard(
            item: item,
            isFilipino: isFilipino,
            advice: adviceFor(item, settings),
            recommended: isRecommendedFor(item, settings),
            owned: owned,
            starsShort:
                (item.cost - progress.starBalance).clamp(0, item.cost).toInt(),
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
    });
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

    return LayoutBuilder(builder: (context, constraints) {
      final columns = _gridColumns(
        context,
        constraints.maxWidth - _kGridPad * 2,
        _kThemeCardWidth,
      );

      return GridView.builder(
        padding: const EdgeInsets.all(_kGridPad),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: _kGridGap,
          crossAxisSpacing: _kGridGap,
          childAspectRatio: _scaledAspect(context, 0.80),
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final owned = ref.read(progressProvider.notifier).hasPurchased(item.id);
          final equippedId =
              ref.read(progressProvider.notifier).getEquippedItemId(item.type);
          final isEquipped = equippedId == item.id;

          return ThemePreviewCard(
            item: item,
            isFilipino: isFilipino,
            adviceLine: _ShopScreenState.adviceText(
              context,
              adviceFor(item, settings),
            ),
            owned: owned,
            starsShort:
                (item.cost - progress.starBalance).clamp(0, item.cost).toInt(),
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
    });
  }
}

class _ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final bool isFilipino;
  final ShopAdvice advice;
  final bool recommended;
  final bool owned;

  /// How many stars short of this item the learner is, 0 once they can pay.
  ///
  /// Carried as the gap rather than as a bool because a screen-reader user
  /// hearing "45 stars" has no way to tell an item they can buy from one they
  /// cannot — the greyed-out price that tells a sighted learner has no spoken
  /// equivalent.
  final int starsShort;
  final bool isEquipped;
  final VoidCallback onTap;

  bool get canAfford => starsShort <= 0;

  const _ShopItemCard({
    required this.item,
    required this.isFilipino,
    required this.advice,
    required this.recommended,
    required this.owned,
    required this.starsShort,
    required this.isEquipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final price = '${item.cost} ${l10n.stars}';
    final status = isEquipped
        ? l10n.equipped
        : owned
            ? l10n.tapToEquip
            : canAfford
                ? price
                : '$price, ${l10n.starsToGo(starsShort)}';

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
              // Positioned.fill, not a bare child: a Stack lays its
              // non-positioned children out *loosely* and then aligns them to
              // its own `alignment`, which defaults to the top start. The
              // padded Column therefore took only the width of its widest word
              // and was parked against the left edge of a 315 dp card — the
              // emoji, the name and the price all hugging one side of an
              // otherwise empty card, vertically centred because the Column
              // still filled the height. Filling the Stack gives the Column the
              // card's full width back, which is all its own
              // `CrossAxisAlignment.center` ever needed to centre the contents.
              Positioned.fill(
                child: Padding(
                  // The corner markers are drawn over this box, so when one is
                  // there the content starts below it. Without the inset a
                  // picture that fills its card slides straight under the
                  // Recommended thumb — the two shelves that carry advice
                  // (Effects under Reduced Motion, Sounds with sound off) are
                  // exactly the ones an accessibility preset turns on.
                  padding: EdgeInsets.fromLTRB(
                    12,
                    adviceLine != null || recommended ? 30 : 12,
                    12,
                    12,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Emoji, drawn at whatever size the space left over by
                      // the words allows.
                      //
                      // Flexible gives the name and the price first claim on
                      // the card — for a pre-literate learner the picture is
                      // the product, but a picture nobody can price is worse —
                      // and the leftover then sets a real `fontSize` rather
                      // than a `FittedBox` scale. Android's colour emoji are
                      // bitmaps, so a transform that blows a 48 dp glyph up to
                      // fill a card upscales a bitmap and softens it; asking
                      // for the size outright renders it sharp.
                      Flexible(
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final room = box.maxHeight.isFinite
                                ? box.maxHeight
                                : 64.0;
                            // 1.25 covers the emoji face's line height; the
                            // width bound keeps a short, wide cell (landscape,
                            // five columns) from asking for a glyph wider than
                            // the card.
                            final size = (room / 1.25)
                                .clamp(20.0, box.maxWidth.isFinite
                                    ? box.maxWidth.clamp(20.0, 120.0)
                                    : 120.0);
                            return Text(
                              item.emoji,
                              // The room was measured *after* the text scaler
                              // had already stretched the words below, so
                              // scaling this size again would spend the same
                              // font setting twice and overflow the card.
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                fontSize: size,
                                color: owned || canAfford
                                    ? null
                                    : HCColor.of(context).textHint,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Name
                      // Item names split as "Flamin / go" and "Unicor / n" in
                      // the fixed grid cell.
                      FitText(
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
                      ),
                      const SizedBox(height: 8),
                      // Status badge
                      if (isEquipped)
                        ShopBadge.equipped(context)
                      else if (owned)
                        ShopBadge.owned(context)
                      else
                        ShopBadge.price(
                          context,
                          cost: item.cost,
                          canAfford: canAfford,
                        ),
                    ],
                  ),
                ),
              ),
              // Corner markers last so they paint over the card body and their
              // tooltips stay reachable.
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
            ],
          ),
        ),
      ),
    );
  }
}
