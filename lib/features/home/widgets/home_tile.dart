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

  const HomeTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.gradient,
    required this.onTap,
    this.subtitle,
    this.compact = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final double emojiSize = compact ? 24 : 34;
    final double badge = compact ? 42 : 56;

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
      semanticLabel:
          semanticLabel ?? (subtitle == null ? label : '$label. $subtitle'),
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
