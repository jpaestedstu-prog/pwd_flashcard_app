import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../widgets/depth_3d.dart';
import '../../../widgets/shared_widgets.dart';

/// A colorful, icon-first tile for the game-style Home hub.
///
/// Built on [AppCard] and engineered to be overflow-proof at any text scale or
/// tablet size: it is meant to live in a grid whose cell height is fixed by
/// `mainAxisExtent: context.hubTileHeight(...)`. Inside that fixed cell the
/// icon badge is a fixed size wrapped in a [FittedBox], and the label/subtitle
/// are [Flexible] with `maxLines` + ellipsis — so the content can shrink to fit
/// and can never push past the cell (no RenderFlex overflow).
///
/// Foreground is white-on-gradient for strong, consistent contrast (matches the
/// app's existing `FeatureBanner` aesthetic) — important for PWD readability.
class HomeTile extends StatelessWidget {
  /// Emoji shown in the icon badge.
  final String emoji;

  /// Primary label.
  final String label;

  /// Optional one-line description. Shown on large tiles only.
  final String? subtitle;

  /// Two (or more) colors for the tile's diagonal gradient.
  final List<Color> gradient;

  /// Tap handler — opens the feature.
  final VoidCallback onTap;

  /// Compact tiles (smaller badge/label, no subtitle) are used in the
  /// secondary "More" grid.
  final bool compact;

  /// Accessibility label. Defaults to "label. subtitle".
  final String? semanticLabel;

  /// Count for a corner notification pip (unread messages, pending items…).
  /// Zero or null draws nothing, so a caller can pass a live count straight
  /// through without branching.
  final int? badgeCount;

  const HomeTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.gradient,
    required this.onTap,
    this.subtitle,
    this.compact = false,
    this.semanticLabel,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final double emojiSize = compact ? 24 : 34;
    final double badge = compact ? 42 : 56;
    final count = badgeCount ?? 0;

    final card = _card(emojiSize: emojiSize, badgeSize: badge);
    if (count <= 0) return card;

    // The pip sits *outside* the card's padded content so it can't reflow the
    // label at large text scales — the tile's layout is unchanged whether or
    // not there's a badge.
    return Stack(
      clipBehavior: Clip.none,
      // Without passthrough the non-positioned card gets *loose* constraints
      // and shrink-wraps, so a badged tile would draw narrower than its
      // unbadged neighbours in the same grid row.
      fit: StackFit.passthrough,
      children: [
        card,
        Positioned(
          top: compact ? 2 : 6,
          right: compact ? 2 : 6,
          child: IgnorePointer(
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: AppTypography.labelSmall.copyWith(
                    color: gradient.first,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({required double emojiSize, required double badgeSize}) {
    final count = badgeCount ?? 0;
    final base =
        semanticLabel ?? (subtitle == null ? label : '$label. $subtitle');
    final double badge = badgeSize;

    return AppCard(
      onTap: onTap,
      gradient: LinearGradient(
        colors: gradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: compact ? 18 : 22,
      padding: EdgeInsets.all(compact ? 10 : 14),
      // Vibrant 3D depth: glossy sheen, lit rim, layered shadow. Bubbles only on
      // the larger tiles where there's room (compact tiles stay clean).
      depth: true,
      depthBubbles: !compact,
      // The badge is drawn outside the card and marked IgnorePointer, so the
      // count has to be spoken here or a screen-reader user never hears it.
      semanticLabel: count > 0 ? '$base. $count new' : base,
      // Center the badge + labels both vertically and horizontally inside the
      // fixed-height grid cell. AppCard's depth mode lays its content out in a
      // Stack that defaults to top-start, so without this the content would hug
      // the top of the tile (the "misaligned / unevenly spaced" look). Center
      // expands to fill the bounded cell and centres the min-size column.
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed-size 3D "coin" badge — never grows, so it always fits the cell.
            Badge3D(
              size: badge,
              emoji: emoji,
              iconSize: emojiSize,
              circle: false,
              borderRadius: compact ? 12 : 16,
            ),
            SizedBox(height: compact ? 6 : 10),
            Flexible(
              child: Text(
                label,
                style:
                    (compact
                            ? AppTypography.labelMedium
                            : AppTypography.titleSmall)
                        .copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!compact && subtitle != null) ...[
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  subtitle!,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
