import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../l10n/app_localizations.dart';

/// The one badge every Star Shop card wears: what it costs, or the state it is
/// already in.
///
/// Written once and shared by both shelves because the two used to disagree.
/// The item cards used a Material [Chip] with `padding: EdgeInsets.zero`,
/// `VisualDensity.compact` *and* `MaterialTapTargetSize.shrinkWrap` — three
/// separate ways of asking for less — so the price a learner is deciding on
/// rendered as a 60x28 dp sliver with its star crowding the number, while the
/// Themes tab drew the same information as a comfortable pill. This is the
/// pill, for both.
///
/// It is deliberately not a [Chip]: Chip re-applies its own theme padding and
/// minimum tap target, which is what made the shrink-wrapped version so hard
/// to size in the first place.
class ShopBadge extends StatelessWidget {
  const ShopBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  /// The price to pay, greyed once the learner cannot afford it.
  factory ShopBadge.price(
    BuildContext context, {
    required int cost,
    required bool canAfford,
  }) {
    final hc = HCColor.of(context);
    return ShopBadge(
      icon: Icons.star_rounded,
      label: '$cost',
      foreground: canAfford ? AppColors.warning : hc.textSecondary,
      background: canAfford
          ? AppColors.warning.withValues(alpha: 0.18)
          : hc.surfaceVariant,
    );
  }

  /// "Tap to Equip" — bought, not worn.
  factory ShopBadge.owned(BuildContext context) => ShopBadge(
        icon: Icons.touch_app_rounded,
        label: AppLocalizations.of(context)!.tapToEquip,
        foreground: AppColors.successDark,
        background: AppColors.successLight,
      );

  /// "Equipped" — worn right now. [color] follows the theme being previewed on
  /// the Themes shelf, and the app's own primary everywhere else.
  factory ShopBadge.equipped(BuildContext context, {Color? color}) {
    final tint = color ?? AppColors.primary;
    return ShopBadge(
      icon: Icons.check_circle_rounded,
      label: AppLocalizations.of(context)!.equipped,
      foreground: tint,
      background: tint.withValues(alpha: 0.18),
    );
  }

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    // The icon is the one part that must not scale away from the text it sits
    // beside, so it tracks the label rather than staying at a fixed 14.
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 2.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 5 * scale),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14 * scale, color: foreground),
          SizedBox(width: 5 * scale),
          // Flexible, not fixed: "I-tap para i-equip" in a narrow cell at the
          // largest font wraps inside the pill instead of pushing its own
          // right edge off the card.
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
