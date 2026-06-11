import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/responsive_utils.dart';

/// Playful page header for the kid / guest "hub" surfaces — a leading icon chip
/// next to a title and optional subtitle.
///
/// Pair with [HubScaffold]; drop it into a [SliverToBoxAdapter] at the top of a
/// sliver list. Overflow-safe by construction: the icon chip is fixed, the text
/// column is [Expanded] and ellipsizes, so the header never overflows at any
/// width or font scale. Theme-aware via [HCColor] (high-contrast / dark /
/// dyslexia inherit automatically).
class HubHeader extends StatelessWidget {
  const HubHeader({
    super.key,
    required this.leadingIcon,
    required this.title,
    this.subtitle,
    this.iconColor,
  });

  final IconData leadingIcon;
  final String title;
  final String? subtitle;

  /// Accent for the icon chip; defaults to the theme primary.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final theme = Theme.of(context);
    final accent = iconColor ?? hc.primary;
    final pad = context.pagePadding;

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.md, pad, AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(leadingIcon, color: accent, size: context.scaleIcon(26)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: hc.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hc.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
