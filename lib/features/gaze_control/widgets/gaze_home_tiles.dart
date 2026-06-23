import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/gaze_home_grid.dart';

/// A Home feature tile paired with the gaze cell that describes it: the visual
/// [tile] widget and the [GazeTileCell] (label + open callback) the shell's
/// D-pad activates. Built in row-major order, matching the `SliverGrid` layout.
typedef GazeTileEntry = ({Widget tile, GazeTileCell cell});

/// Assembles the Home feature-tile grid for gaze navigation as the screen
/// builds it, so the rows published to [gazeHomeGrid] always match the visual
/// `SliverGrid` layout exactly.
///
/// For each grid section the screen calls [section] with the section's column
/// count and its tiles in row-major order; it gets back the tile widgets (each
/// wrapped with a focus highlight when [active]) and the matching rows are
/// appended to [rows] for publishing. When [active] is false the tiles are
/// returned untouched and [rows] stays empty, so a gaze-off Home screen is
/// byte-for-byte unchanged.
class GazeTileGridBuilder {
  GazeTileGridBuilder({required this.active});

  /// Whether the "Bottom nav + Home tiles" reach is on. When false this builder
  /// is a pass-through.
  final bool active;

  /// The accumulated grid (rows of cells) to publish to [gazeHomeGrid].
  final List<List<GazeTileCell>> rows = [];

  /// Wraps one [columns]-wide grid section. [entries] are the tiles in
  /// row-major order. Returns the (possibly highlight-wrapped) tile widgets.
  ///
  /// Pass [expand] = false for tiles laid out in an unbounded list (e.g.
  /// full-width buttons in a `SliverList`) so each focus ring sizes to its child
  /// instead of requiring a bounded cell (see [GazeFocusable.expand]).
  List<Widget> section({
    required int columns,
    required List<GazeTileEntry> entries,
    bool expand = true,
  }) {
    if (!active || columns <= 0) {
      return [for (final e in entries) e.tile];
    }
    final out = <Widget>[];
    final base = rows.length;
    for (var i = 0; i < entries.length; i++) {
      final r = base + i ~/ columns;
      final c = i % columns;
      if (c == 0) rows.add(<GazeTileCell>[]);
      rows[r].add(entries[i].cell);
      out.add(
        GazeFocusable(row: r, col: c, expand: expand, child: entries[i].tile),
      );
    }
    return out;
  }
}

/// Wraps a single Home feature tile so it shows a bright highlight ring while
/// the gaze D-pad is resting on it (and scrolls itself into view when it gains
/// focus). The ring is an [IgnorePointer] overlay laid out with
/// [StackFit.expand], so it never changes the tile's size or intercepts touch —
/// the tile behaves exactly as before, just with an extra ring when focused.
class GazeFocusable extends StatefulWidget {
  final int row;
  final int col;
  final Widget child;

  /// When true (the default) the ring [Stack] fills its parent's bounds
  /// ([StackFit.expand]) — correct for fixed-extent grid cells, where the tile
  /// may be smaller than the cell and the ring should frame the whole cell.
  /// Pass false for a child in an unbounded list (e.g. a full-width button in a
  /// `SliverList`) so the [Stack] sizes to the child ([StackFit.loose]) instead
  /// of throwing on an unbounded main-axis constraint.
  final bool expand;

  const GazeFocusable({
    super.key,
    required this.row,
    required this.col,
    required this.child,
    this.expand = true,
  });

  @override
  State<GazeFocusable> createState() => _GazeFocusableState();
}

class _GazeFocusableState extends State<GazeFocusable> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focused = gazeHomeGrid.isFocused(widget.row, widget.col);
    gazeHomeGrid.addListener(_onGridChanged);
  }

  @override
  void didUpdateWidget(covariant GazeFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row != widget.row || oldWidget.col != widget.col) {
      _focused = gazeHomeGrid.isFocused(widget.row, widget.col);
    }
  }

  @override
  void dispose() {
    gazeHomeGrid.removeListener(_onGridChanged);
    super.dispose();
  }

  void _onGridChanged() {
    final focused = gazeHomeGrid.isFocused(widget.row, widget.col);
    if (focused == _focused || !mounted) return;
    setState(() => _focused = focused);
    if (focused) {
      // Scroll the freshly-focused tile into view after this frame, so a tile
      // below the fold becomes visible as the D-pad reaches it.
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
    }
  }

  void _ensureVisible() {
    if (!mounted) return;
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5, // centre the tile in the viewport
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: widget.expand ? StackFit.expand : StackFit.loose,
      children: [
        widget.child,
        if (_focused)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.5),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Publishes the Home feature-tile [rows] to [gazeHomeGrid] (when [active]) so
/// the long-lived shell's D-pad can reach them, and clears the registry when the
/// Home screen is dismissed. Publishing happens in a post-frame callback to
/// avoid any "notify during build" hazard; [gazeHomeGrid] de-dupes by shape, so
/// re-publishing on every rebuild (to refresh the tap callbacks) is cheap.
class GazeHomeRegistrar extends StatefulWidget {
  final bool active;
  final List<List<GazeTileCell>> rows;
  final Widget child;

  const GazeHomeRegistrar({
    super.key,
    required this.active,
    required this.rows,
    required this.child,
  });

  @override
  State<GazeHomeRegistrar> createState() => _GazeHomeRegistrarState();
}

class _GazeHomeRegistrarState extends State<GazeHomeRegistrar> {
  /// A stable identity for this registrar's tenure as grid owner, so a stale
  /// clear from a screen that already handed off is ignored (see [clearGrid]).
  final Object _token = Object();

  @override
  void initState() {
    super.initState();
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant GazeHomeRegistrar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleSync();
  }

  @override
  void dispose() {
    gazeHomeGrid.clearGrid(owner: _token);
    super.dispose();
  }

  void _scheduleSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.active) {
        gazeHomeGrid.publishGrid(widget.rows, owner: _token);
      } else {
        gazeHomeGrid.clearGrid(owner: _token);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
