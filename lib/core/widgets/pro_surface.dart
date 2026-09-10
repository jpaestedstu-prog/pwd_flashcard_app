import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'fit_text.dart';

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
          ProSectionHeader(
            title: title!,
            subtitle: subtitle,
            trailing: trailing,
          ),
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
  const _TrendChip({
    required this.trend,
    required this.delta,
    required this.hc,
  });

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
        final cols =
            columns ?? columnsForWidth(constraints.maxWidth, tiles.length);
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
              cells.add(Expanded(child: _GridCell(child: rowTiles[c])));
            } else {
              // Pad the last row so cells keep a consistent width.
              cells.add(const Expanded(child: SizedBox.shrink()));
            }
          }
          if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells,
              ),
            ),
          );
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

/// A large, tappable navigation button for the educator surfaces — the
/// professional counterpart to the playful `HomeTile`. An accent-tinted icon
/// badge over a bold label and an optional one-line caption, on a flat,
/// hairline-bordered card (square 12px corners, no emoji, no drop shadow) so it
/// reads as a dashboard action rather than a toy.
///
/// Overflow-safe by construction (mirrors [ProStatTile]): the icon badge is a
/// fixed size wrapped in a [FittedBox], the label/caption use `maxLines` +
/// ellipsis, and the column is `mainAxisSize.min` — so it can never trigger a
/// `RenderFlex` overflow at any cell width or font scale. Designed to sit in a
/// [ProActionGrid] cell of bounded width.
class ProActionTile extends StatelessWidget {
  const ProActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.caption,
    this.accent,
    this.compact = false,
    this.badgeCount,
    this.selected = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Count for a corner notification pip (unread messages, pending items…).
  /// Zero or null draws nothing, so callers can pass a live count straight
  /// through without branching.
  final int? badgeCount;

  /// Optional one-line description, shown on large (non-[compact]) tiles only.
  final String? caption;

  /// Accent colour for the icon badge; defaults to the theme primary.
  final Color? accent;

  /// Compact tiles (smaller badge/label, caption hidden) are used in the
  /// secondary "More" grid.
  final bool compact;

  /// Draws the tile as the *chosen* one of a set (a picker), rather than as a
  /// navigation button: filled icon badge, a full-strength 2px accent ring and
  /// a check pip. The state is announced too, so it never reads by colour
  /// alone — the picker has to work in the high-contrast theme and for a
  /// learner or educator who can't distinguish the accent.
  final bool selected;

  /// A tile that is visible but currently unavailable. It stops responding to
  /// taps and drops to the neutral border/text colours, so an option that
  /// doesn't apply to the current mode stays discoverable (with its caption
  /// explaining why) instead of vanishing.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final theme = Theme.of(context);
    final accentColor = enabled ? (accent ?? hc.primary) : hc.textHint;
    final double badge = compact ? 40 : 52;
    final double iconSize = compact ? 22 : 28;

    // A restrained dose of colour: the accent is *blended into* the surface so
    // the fill stays opaque (the screen sits on an animated gradient — a
    // translucent fill would bleed through) and auto-adapts to light/dark.
    // A selected tile blends in twice as much so the chosen option reads at a
    // glance from across a classroom.
    final Color fillStrong = Color.alphaBlend(
      accentColor.withValues(alpha: selected ? 0.22 : 0.12),
      hc.cardBackground,
    );
    final Color fillSoft = Color.alphaBlend(
      accentColor.withValues(alpha: selected ? 0.10 : 0.04),
      hc.cardBackground,
    );

    final content = Container(
      padding: compact ? AppSpacing.paddingMd : AppSpacing.paddingLg,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fillStrong, fillSoft],
        ),
        borderRadius: ProSurface.borderRadius,
        border: Border.all(
          color: selected ? accentColor : accentColor.withValues(alpha: 0.30),
          width: selected ? 2 : ProSurface.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed-size icon badge — never grows, so it always fits the cell.
          // The badge is the check mark's row-mate: both are fixed size, so a
          // selected tile is exactly as tall as its neighbours.
          Row(
            children: [
              Container(
                width: badge,
                height: badge,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? accentColor
                      : accentColor.withValues(alpha: 0.16),
                  borderRadius: ProSurface.borderRadius,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: selected ? Colors.white : accentColor,
                  ),
                ),
              ),
              if (selected) ...[
                const Spacer(),
                Icon(
                  Icons.check_circle_rounded,
                  size: compact ? 18 : 22,
                  color: accentColor,
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          // One-word tile labels must not split down the middle: this rendered
          // "Work / sheets" and "Expe / riment". `fittedStyle` rather than
          // `FitText` because these tiles sit in a grid that computes intrinsic
          // sizes, and the `LayoutBuilder` inside `FitText` throws there.
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: fittedStyle(
              context,
              label,
              (compact
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.titleMedium)
                  ?.copyWith(
                    color: enabled ? hc.textPrimary : hc.textHint,
                    fontWeight: FontWeight.w700,
                  ),
              // Deeper than the 0.85 default. A tile does not widen as the
              // font grows, and at the "Large" (1.3x) setting the default step
              // left an eleven-letter label — "Leaderboard" — a couple of
              // pixels short and breaking as "Leaderboar / d".
              factor: 0.78,
            ),
          ),
          if (!compact && caption != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: hc.textHint),
            ),
          ],
        ],
      ),
    );

    final count = badgeCount ?? 0;
    final base = caption == null ? label : '$label. $caption';

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      // The pip below is IgnorePointer, so the count has to be spoken here or
      // a screen-reader user never hears it.
      label: count > 0 ? '$base. $count new' : base,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: ProSurface.borderRadius,
          child: count > 0
              ? Stack(
                  clipBehavior: Clip.none,
                  // Without passthrough the non-positioned content gets *loose*
                  // constraints and shrink-wraps, so a badged tile drew
                  // narrower than its unbadged neighbours in the same grid row
                  // (and the pip floated in the gap beside it).
                  fit: StackFit.passthrough,
                  children: [
                    content,
                    Positioned(
                      top: compact ? 6 : 10,
                      right: compact ? 6 : 10,
                      child: IgnorePointer(
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : content,
        ),
      ),
    );
  }
}

/// Lays out [ProActionTile]s in the same responsive, overflow-safe grid as
/// [ProStatGrid] — rows of [Expanded] cells inside an [IntrinsicHeight] (so all
/// tiles in a row share a height and no cell can overflow horizontally at any
/// width or font scale).
///
/// [compact] grids pack one more column per tier and are meant for the
/// secondary "More" actions; the default (large) grid keeps tiles big and
/// easy to tap.
class ProActionGrid extends StatelessWidget {
  const ProActionGrid({
    super.key,
    required this.tiles,
    this.spacing = AppSpacing.md,
    this.compact = false,
  });

  final List<ProActionTile> tiles;
  final double spacing;
  final bool compact;

  /// Width-aware column count, clamped to the number of tiles. Large grids stay
  /// at two big columns on phones; compact grids fit more, smaller tiles.
  static int columnsForWidth(
    double width,
    int itemCount, {
    bool compact = false,
  }) {
    int cols;
    if (compact) {
      if (width >= 1120) {
        cols = 5;
      } else if (width >= 840) {
        cols = 4;
      } else if (width >= 520) {
        cols = 3;
      } else {
        cols = 2;
      }
    } else {
      if (width >= 1120) {
        cols = 4;
      } else if (width >= 840) {
        cols = 3;
      } else {
        cols = 2;
      }
    }
    return cols.clamp(1, itemCount == 0 ? 1 : itemCount);
  }

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        var cols = columnsForWidth(
          constraints.maxWidth,
          tiles.length,
          compact: compact,
        );
        // Drop a column when the cells would be too narrow for their labels at
        // the reader's font size. Width alone is not enough: a tile does not
        // widen as the type grows, so at the 2.0x accessibility scale two
        // columns on a 360dp phone left "Flashcards" rendering as
        // "Flash / cards" — the one thing a reader at 2.0x cannot afford. One
        // column there is not a compromise; it is the layout that stays
        // readable. (Covered by the readability guard in the screen matrices.)
        final scale = MediaQuery.textScalerOf(context).scale(1.0);
        final minCell = (compact ? 80.0 : 104.0) * (scale < 1 ? 1 : scale);
        while (cols > 1 &&
            (constraints.maxWidth - spacing * (cols - 1)) / cols < minCell) {
          cols--;
        }
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
              cells.add(Expanded(child: rowTiles[c]));
            } else {
              // Pad the last row so cells keep a consistent width.
              cells.add(const Expanded(child: SizedBox.shrink()));
            }
          }
          if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells,
              ),
            ),
          );
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

/// Lays out a handful of buttons (or any equal-weight controls) as **rows of
/// equal-width cells**, the same geometry [ProActionGrid] uses for tiles.
///
/// This is what turns a ragged `Wrap` of `OutlinedButton`s — where "1 min" is
/// half the width of "Extra large" and the last row trails off mid-line — into
/// the aligned blocks the educator Home reads as. Column count comes from the
/// available width and [minCellWidth], so the same call gives two columns on a
/// phone and four on a tablet without the caller measuring anything.
///
/// Overflow-safe by construction: every cell is an [Expanded] of a bounded
/// row, and rows share a height via [IntrinsicHeight], so a long label wraps
/// inside its cell instead of pushing its neighbours off-screen.
class ProButtonRow extends StatelessWidget {
  const ProButtonRow({
    super.key,
    required this.children,
    this.spacing = AppSpacing.sm,
    this.minCellWidth = 132,
    this.maxPerRow = 4,
  });

  final List<Widget> children;
  final double spacing;

  /// The narrowest a cell may get before the row drops a column.
  ///
  /// Unlike [ProActionGrid] this is not scaled by the text scaler: the labels
  /// here are one or two short words that wrap inside their cell rather than
  /// splitting, so the column count can stay fixed. Callers with longer labels
  /// pass a wider value (see the cast screen's readability rows).
  final double minCellWidth;

  /// Hard cap on columns, so a wide tablet doesn't string eight thumb-sized
  /// buttons across one line.
  final int maxPerRow;

  /// Width-aware column count, clamped to [maxPerRow] and the item count.
  static int columnsForWidth(
    double width,
    int itemCount, {
    double minCellWidth = 132,
    double spacing = AppSpacing.sm,
    int maxPerRow = 4,
  }) {
    if (itemCount <= 0) return 1;
    final fit = ((width + spacing) / (minCellWidth + spacing)).floor();
    return fit.clamp(1, maxPerRow < itemCount ? maxPerRow : itemCount);
  }

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = columnsForWidth(
          constraints.maxWidth,
          children.length,
          minCellWidth: minCellWidth,
          spacing: spacing,
          maxPerRow: maxPerRow,
        );
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          final rowItems = children.sublist(
            i,
            (i + cols) > children.length ? children.length : i + cols,
          );
          final cells = <Widget>[];
          for (var c = 0; c < cols; c++) {
            if (c > 0) cells.add(SizedBox(width: spacing));
            if (c < rowItems.length) {
              cells.add(Expanded(child: rowItems[c]));
            } else {
              // Pad the last row so a lone trailing button keeps the width of
              // the ones above it rather than stretching across the screen.
              cells.add(const Expanded(child: SizedBox.shrink()));
            }
          }
          if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells,
              ),
            ),
          );
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

/// An on/off setting as a flat, hairline-bordered row — the switch counterpart
/// to [ProActionTile], carrying the same accent icon badge, 12px corners and
/// label/caption typography so a screen of settings and a screen of actions
/// read as one system.
///
/// Built on [SwitchListTile] rather than a hand-rolled `Row` + `Switch` so it
/// inherits the framework's merged semantics (one "switch, on" node, not a
/// button and a switch) and its text-scale behaviour.
///
/// Pass `standalone: false` to stack several inside one [ProPanel]; the tile
/// then draws no border of its own.
class ProSwitchTile extends StatelessWidget {
  const ProSwitchTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.caption,
    this.accent,
    this.standalone = true,
  });

  final IconData icon;
  final String label;
  final bool value;

  /// Null disables the row (and greys it), for a setting that doesn't apply
  /// right now. The [caption] should then say why.
  final ValueChanged<bool>? onChanged;

  final String? caption;
  final Color? accent;
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final theme = Theme.of(context);
    final enabled = onChanged != null;
    final accentColor = enabled ? (accent ?? hc.primary) : hc.textHint;

    final tile = SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      secondary: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: value && enabled ? 0.16 : 0.08),
          borderRadius: ProSurface.borderRadius,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Icon(icon, size: 22, color: accentColor),
        ),
      ),
      title: Text(
        label,
        // Same long-word guard as [ProActionTile]: a ListTile title sits in a
        // narrow column between the badge and the switch, and "Fullscreen"
        // rendered as "Fulls / creen" at the 2.0x accessibility scale.
        style: fittedStyle(
          context,
          label,
          theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: enabled ? hc.textPrimary : hc.textHint,
          ),
        ),
      ),
      subtitle: caption == null
          ? null
          : Text(
              caption!,
              // The caption is prose, but it still sits in the narrow column
              // between the badge and the switch: under the dyslexia theme at
              // 2.0x "Chromecast" broke as "Chrom / ecast". A slightly smaller
              // caption is a far better trade than a split word.
              style: fittedStyle(
                context,
                caption!,
                theme.textTheme.bodySmall?.copyWith(color: hc.textHint),
                factor: 0.82,
                longWord: 9,
              ),
            ),
    );

    // A `SwitchListTile` paints its background and ink on the nearest Material
    // ancestor, and Flutter asserts if an opaque `DecoratedBox` sits in
    // between. Stacked inside a [ProPanel] that is exactly what happens (the
    // panel's own container), so a non-standalone tile still gets a Material —
    // a transparent one, so the panel's fill shows through.
    if (!standalone) {
      return Material(type: MaterialType.transparency, child: tile);
    }

    return Material(
      color: hc.cardBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: ProSurface.borderRadius,
        // ignore: avoid_redundant_argument_values  (width comes from the token)
        side: BorderSide(color: hc.border, width: ProSurface.borderWidth),
      ),
      child: tile,
    );
  }
}
