import 'package:flutter/material.dart';

import '../../../../core/utils/responsive_utils.dart';
import '../../theme/progress_layout.dart';
import 'progress_stat_card.dart';

/// Immutable description of a single stat shown in a [ProgressStatGrid].
@immutable
class ProgressStat {
  final IconData icon;
  final String label;
  final String value;
  final String suffix;
  final Color color;

  const ProgressStat({
    required this.icon,
    required this.label,
    required this.value,
    this.suffix = '',
    required this.color,
  });
}

/// Lays out a list of [ProgressStatCard]s in a responsive, overflow-safe grid.
///
/// The column count comes from the active [ProgressLayout]'s preference but is
/// always clamped against the screen tier and the number of stats (and nudged
/// to avoid a lone orphan card), so it adapts from phones to ultra-wide
/// tablets. Every cell is an [Expanded] inside a [Row] (bounded width) and the
/// card content self-protects with `FittedBox` + ellipsis, so the grid can
/// never trigger a RenderFlex overflow at any width or font scale.
class ProgressStatGrid extends StatelessWidget {
  final List<ProgressStat> stats;
  final ProgressLayout layout;
  final double spacing;

  const ProgressStatGrid({
    super.key,
    required this.stats,
    required this.layout,
    this.spacing = 12,
  });

  /// Pick a sensible, width-aware column count for [itemCount] stats.
  static int resolveColumns(
    BuildContext context,
    ProgressLayout layout,
    int itemCount,
  ) {
    final pref =
        context.isTablet ? layout.statColumnsTablet : layout.statColumnsPhone;
    var cols = pref.clamp(1, itemCount);
    // Avoid a single orphan card on the last row when easy to balance.
    if (itemCount > cols && itemCount % cols == 1 && cols > 2) {
      cols -= 1;
    }
    return cols;
  }

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    final cols = resolveColumns(context, layout, stats.length);

    final rows = <Widget>[];
    for (var i = 0; i < stats.length; i += cols) {
      final rowItems = stats.sublist(
        i,
        (i + cols) > stats.length ? stats.length : i + cols,
      );
      final cells = <Widget>[];
      for (var c = 0; c < cols; c++) {
        if (c > 0) cells.add(SizedBox(width: spacing));
        if (c < rowItems.length) {
          final s = rowItems[c];
          cells.add(Expanded(
            child: ProgressStatCard(
              icon: s.icon,
              label: s.label,
              value: s.value,
              suffix: s.suffix,
              color: s.color,
            ),
          ));
        } else {
          // Keep card widths consistent across rows.
          cells.add(const Expanded(child: SizedBox.shrink()));
        }
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
      // IMPORTANT: do NOT use CrossAxisAlignment.stretch here. This Row sits in
      // an unbounded-height parent (Column → SliverList / scroll view), and
      // stretch would force `h=Infinity` onto each card, throwing
      // "BoxConstraints forces an infinite height". `start` top-aligns the
      // cards (icons line up) without ever forcing the cross-axis size.
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cells,
      ));
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}
