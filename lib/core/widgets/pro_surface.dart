import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// "Professional surface" kit — a structured, data-dense visual language for
/// the **teacher and parent** surfaces (dashboards, analytics, reports).
///
/// The student/child/player surfaces stay playful (soft 24px corners, gradient
/// backgrounds, slide-in animations, emoji). Educator surfaces are about
/// *responsible progress tracking*, so this kit deliberately reads as a
/// dashboard instead:
///
///   * **Square-ish corners** (12px) and a **hairline border** instead of soft
///     drop shadows — flat, document-like, scannable.
///   * **Tight, consistent spacing** from [AppSpacing].
///   * **Tabular numerals** so columns of figures line up.
///   * **No emoji**; restrained, label-led typography.
///
/// Everything here is **overflow-safe by construction** (no fixed heights that
/// fight the Font Size setting; long text ellipsizes; big numerals scale down
/// with `FittedBox`) and **theme-aware** via [HCColor], so the kit inherits the
/// high-contrast and dark themes automatically. It is covered by the
/// cross-device overflow matrix (see test/pro_surface_overflow_test.dart).
class ProSurface {
  ProSurface._();

  /// Corner radius for pro panels — squarer than the playful 24px cards.
  static const double radius = 12;

  /// Hairline border width.
  static const double borderWidth = 1;

  static BorderRadius get borderRadius => BorderRadius.circular(radius);
}

/// A flat, hairline-bordered container — the base building block of the
/// educator surfaces. No drop shadow; structure comes from the border and
/// spacing, not elevation.
///
/// Optionally renders a [title]/[subtitle] header with a [trailing] action,
/// and becomes tappable when [onTap] is provided.
class ProPanel extends StatelessWidget {
  const ProPanel({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = AppSpacing.paddingLg,
    this.onTap,
    this.accent,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Optional left accent stripe colour (e.g. status / category). When null no
  /// stripe is drawn.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          ProSectionHeader(title: title!, subtitle: subtitle, trailing: trailing),
          AppSpacing.gapMd,
        ],
        child,
      ],
    );

    content = Padding(padding: padding, child: content);

    if (accent != null) {
      // IntrinsicHeight gives the Row a bounded height so the stretched accent
      // stripe has a finite extent to match — without it, a stretch-Row throws
      // "BoxConstraints forces an infinite height" when the panel sits inside a
      // scroll view (the common dashboard case).
      content = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(child: content),
          ],
        ),
      );
    }

    final decorated = Container(
      decoration: BoxDecoration(
        color: hc.cardBackground,
        borderRadius: ProSurface.borderRadius,
        // ignore: avoid_redundant_argument_values  (width comes from the token)
        border: Border.all(color: hc.border, width: ProSurface.borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (onTap == null) return decorated;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: ProSurface.borderRadius,
        child: decorated,
      ),
    );
  }
}

/// A restrained section header: an uppercase, letter-spaced label with an
/// optional one-line subtitle and a trailing action (e.g. "View all").
class ProSectionHeader extends StatelessWidget {
  const ProSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: hc.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: hc.textHint,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

/// Direction of a metric's trend, for the optional delta indicator on a
/// [ProStatTile].
enum ProTrend { up, down, flat }

/// A compact metric cell: a small uppercase label, a large tabular-figure
/// value, and an optional trend delta + caption.
///
/// Designed to sit in a [ProStatGrid] cell of bounded width. The value scales
/// down with `FittedBox` and the label ellipsizes, so the tile never overflows
/// at any width or font scale.
class ProStatTile extends StatelessWidget {
  const ProStatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.trend,
    this.delta,
    this.accent,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final ProTrend? trend;

  /// Short delta text shown next to the trend arrow, e.g. "+12%".
  final String? delta;

  /// Accent colour for the icon; defaults to the theme primary.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final theme = Theme.of(context);
    final accentColor = accent ?? hc.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: hc.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Big numeral — scale down to fit the cell width rather than overflow.
        Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: hc.textPrimary,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        if (trend != null || caption != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if (trend != null) ...[
                _TrendChip(trend: trend!, delta: delta, hc: hc),
                if (caption != null) const SizedBox(width: AppSpacing.xs),
              ],
              if (caption != null)
                Expanded(
                  child: Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: hc.textHint,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.trend, required this.delta, required this.hc});

  final ProTrend trend;
  final String? delta;
  final HCColor hc;

  @override
  Widget build(BuildContext context) {
    final (IconData arrow, Color color) = switch (trend) {
      ProTrend.up => (Icons.arrow_upward_rounded, hc.success),
      ProTrend.down => (Icons.arrow_downward_rounded, hc.error),
      ProTrend.flat => (Icons.remove_rounded, hc.textSecondary),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(arrow, size: 14, color: color),
        if (delta != null)
          Text(
            delta!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
      ],
    );
  }
}

/// A label-left / value-right data row for compact tabular lists inside a
/// [ProPanel]. Label ellipsizes; value uses tabular figures and scales down,
/// so the row never overflows.
class ProDataRow extends StatelessWidget {
  const ProDataRow({
    super.key,
    required this.label,
    required this.value,
    this.leading,
    this.valueColor,
    this.dense = false,
  });

  final String label;
  final String value;
  final Widget? leading;
  final Color? valueColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: dense ? AppSpacing.xs : AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: hc.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: valueColor ?? hc.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays out [ProStatTile]s in a responsive, overflow-safe grid.
///
/// Uses the proven "rows of `Expanded` cells" pattern (bounded width per cell,
/// cells self-protect with `FittedBox`/ellipsis) so it can never trigger a
/// horizontal `RenderFlex` overflow at any width or font scale. Column count
/// adapts to the available width via [columnsForWidth].
class ProStatGrid extends StatelessWidget {
  const ProStatGrid({
    super.key,
    required this.tiles,
    this.spacing = AppSpacing.md,
    this.columns,
  });

  final List<ProStatTile> tiles;
  final double spacing;

  /// Force a column count; when null it's derived from the available width.
  final int? columns;

  /// Width-aware column count: 1 col on phones, 2 from ~520dp, 3 from ~840dp,
  /// 4 from ~1120dp — always clamped to the number of tiles.
  static int columnsForWidth(double width, int itemCount) {
    int cols;
    if (width >= 1120) {
      cols = 4;
    } else if (width >= 840) {
      cols = 3;
    } else if (width >= 520) {
      cols = 2;
    } else {
      cols = 1;
    }
    return cols.clamp(1, itemCount == 0 ? 1 : itemCount);
  }

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = columns ?? columnsForWidth(constraints.maxWidth, tiles.length);
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += cols) {
          final rowTiles = tiles.sublist(
            i,
            (i + cols) > tiles.length ? tiles.length : i + cols,
          );
          final cells = <Widget>[];
          for (var c = 0; c < cols; c++) {
            if (c > 0) cells.add(SizedBox(width: spacing));
            if (c < rowTiles.length) {
              cells.add(Expanded(
                child: _GridCell(child: rowTiles[c]),
              ));
            } else {
              // Pad the last row so cells keep a consistent width.
              cells.add(const Expanded(child: SizedBox.shrink()));
            }
          }
          if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
          rows.add(IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cells,
            ),
          ));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
      },
    );
  }
}

/// A single bordered cell wrapping a [ProStatTile] inside the grid.
class _GridCell extends StatelessWidget {
  const _GridCell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: hc.cardBackground,
        borderRadius: ProSurface.borderRadius,
        // ignore: avoid_redundant_argument_values  (width comes from the token)
        border: Border.all(color: hc.border, width: ProSurface.borderWidth),
      ),
      child: child,
    );
  }
}
