import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';

/// Overflow-safe horizontal strip of action buttons.
///
/// Hand-rolled `Row`s of buttons throw a horizontal `RenderFlex` overflow when
/// the user's Font Size setting (up to 2.0×) or a narrow tablet / split-screen
/// width pushes their combined width past the viewport. [AppActionBar] lays the
/// same buttons out so they **wrap onto the next line** instead of overflowing,
/// which is the whole point on "any Android tablet, any Android version".
///
/// Two layouts:
///
///  - **Wrap (default):** children keep their natural width and flow to a new
///    line when they don't fit. Best for a variable number of equal-weight
///    controls (e.g. a flashcard tool strip: Prev / Listen / FSL / Flip / Next).
///  - **[equalWidth]:** children are stretched to equal widths using the proven
///    "row of `Expanded` cells" pattern (mirrors `ProStatGrid` in
///    `pro_surface.dart`), wrapping to a second row of equal cells when there
///    isn't room. Best for a small set of primary/secondary buttons (e.g.
///    Replay / Close, Cancel / Confirm).
class AppActionBar extends StatelessWidget {
  const AppActionBar({
    super.key,
    required this.children,
    this.spacing = AppSpacing.sm,
    this.runSpacing = AppSpacing.sm,
    this.alignment = WrapAlignment.center,
    this.equalWidth = false,
    this.minCellWidth = 120,
  });

  final List<Widget> children;

  /// Horizontal gap between buttons.
  final double spacing;

  /// Vertical gap between wrapped rows.
  final double runSpacing;

  /// Alignment of the buttons within a run (Wrap layout only).
  final WrapAlignment alignment;

  /// Stretch children to equal widths in rows of `Expanded` cells.
  final bool equalWidth;

  /// In [equalWidth] mode, the minimum width a cell may shrink to before the
  /// row breaks to a new line — keeps buttons comfortably tappable on narrow
  /// widths. Ignored in Wrap mode.
  final double minCellWidth;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    if (!equalWidth) {
      return Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        alignment: alignment,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        // How many equal cells fit at >= minCellWidth, allowing for the gaps.
        var perRow = children.length;
        if (maxW.isFinite) {
          perRow = ((maxW + spacing) / (minCellWidth + spacing)).floor();
          perRow = perRow.clamp(1, children.length);
        }

        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += perRow) {
          final slice = children.sublist(
            i,
            (i + perRow) > children.length ? children.length : i + perRow,
          );
          final cells = <Widget>[];
          for (var c = 0; c < perRow; c++) {
            if (c > 0) cells.add(SizedBox(width: spacing));
            if (c < slice.length) {
              cells.add(Expanded(child: slice[c]));
            } else {
              // Pad a short final row so its cells keep the same width as the
              // rows above (e.g. 3 buttons over a 2-column break).
              cells.add(const Expanded(child: SizedBox.shrink()));
            }
          }
          if (rows.isNotEmpty) rows.add(SizedBox(height: runSpacing));
          // Default (center) cross-axis alignment — no IntrinsicHeight needed
          // because we only need equal *widths*, which Expanded already gives.
          rows.add(Row(children: cells));
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}
