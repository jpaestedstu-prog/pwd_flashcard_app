import 'package:flutter/foundation.dart';

import '../logic/voice_commands.dart' show VoiceTarget;

/// One gaze-navigable Home feature tile: a [label] (for accessibility / the
/// hint chip) and what to do when the learner opens it ([onActivate]).
///
/// Implements [VoiceTarget] so the same tiles the shell's D-pad drives are also
/// the ones spoken commands open by [label] (e.g. "flashcards", "games").
@immutable
class GazeTileCell implements VoiceTarget {
  @override
  final String label;
  final VoidCallback onActivate;
  const GazeTileCell({required this.label, required this.onActivate});

  /// Published tiles are always tappable (a hub never publishes a greyed tile).
  @override
  bool get enabled => true;
}

/// App-wide bridge between the long-lived navigation shell's gaze D-pad and the
/// foreground Home screen's feature tiles.
///
/// The Home screen **publishes** its tile grid here as rows of [GazeTileCell]
/// (matching the visual `SliverGrid` layout); the shell reads the row shape via
/// [rowLengths] to extend its [GazeGridCursor] over the tiles, and **publishes
/// back** which cell is focused ([setFocus]) so the Home screen can draw the
/// highlight ring and scroll the focused tile into view.
///
/// It is an app-wide singleton (like `gazeCameraOwners`) rather than a Riverpod
/// provider so it can be mutated safely from `initState`/`dispose` and from gaze
/// event callbacks without "modified a provider during build" hazards. It holds
/// no camera and stays empty/inert until a Home screen opts in (gaze enabled +
/// the "Bottom nav + Home tiles" scope), so touch and the nav-only D-pad are
/// completely unaffected by default.
class GazeHomeGrid extends ChangeNotifier {
  List<List<GazeTileCell>> _rows = const [];
  int? _focusRow;
  int? _focusCol;

  /// The registrar that currently owns the published grid. Used to ignore a
  /// stale [clearGrid] from an *outgoing* hub screen that disposes after the
  /// *incoming* one has already published — during a tab fade both briefly
  /// coexist, and without this guard the outgoing dispose would wipe the new
  /// grid. Null means no owner (or a token-less legacy/test caller).
  Object? _owner;

  /// The published tile grid (rows of cells). Empty when no Home grid is active.
  List<List<GazeTileCell>> get rows => _rows;

  /// Whether a Home screen currently has a navigable grid published.
  bool get hasGrid => _rows.isNotEmpty;

  /// Cell counts per row — the shape the shell's `GazeGridCursor` needs.
  List<int> get rowLengths => [for (final r in _rows) r.length];

  /// The focused cell published by the shell, or null when the cursor is on the
  /// bottom-nav bar (or no grid is active).
  int? get focusRow => _focusRow;
  int? get focusCol => _focusCol;

  /// Publishes the foreground hub's tile grid. Only notifies listeners when the
  /// *shape* (row lengths) changes: the hub screen re-publishes on every rebuild
  /// to keep the tap callbacks fresh, and notifying on every frame would thrash
  /// the shell's cursor re-sync. [owner] (when given) records who published, so
  /// a later [clearGrid] from a different screen can be ignored.
  void publishGrid(List<List<GazeTileCell>> rows, {Object? owner}) {
    _owner = owner;
    final sameShape = _sameShape(rows);
    _rows = rows;
    if (!sameShape) notifyListeners();
  }

  /// Clears the grid when the hub screen is dismissed, so the shell falls back
  /// to the nav-only D-pad. When [owner] is given it clears only if it still
  /// matches the current owner — so an outgoing screen disposing *after* the
  /// incoming one published can't wipe the newer grid. A null [owner]
  /// (legacy / tests) always clears.
  void clearGrid({Object? owner}) {
    if (owner != null && !identical(owner, _owner)) return;
    _owner = null;
    if (_rows.isEmpty && _focusRow == null && _focusCol == null) return;
    _rows = const [];
    _focusRow = null;
    _focusCol = null;
    notifyListeners();
  }

  /// Publishes which cell is focused (shell → Home). Pass nulls when the cursor
  /// leaves the grid (onto the bottom-nav bar).
  void setFocus(int? row, int? col) {
    if (_focusRow == row && _focusCol == col) return;
    _focusRow = row;
    _focusCol = col;
    notifyListeners();
  }

  /// The cell at [row]/[col], or null if out of range (defensive: the layout can
  /// change between a gaze event firing and its handler running).
  GazeTileCell? cellAt(int row, int col) {
    if (row < 0 || row >= _rows.length) return null;
    final r = _rows[row];
    if (col < 0 || col >= r.length) return null;
    return r[col];
  }

  /// True when [row]/[col] is the currently focused cell.
  bool isFocused(int row, int col) => _focusRow == row && _focusCol == col;

  bool _sameShape(List<List<GazeTileCell>> rows) {
    if (rows.length != _rows.length) return false;
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].length != _rows[i].length) return false;
    }
    return true;
  }
}

/// The single, app-wide Home-grid gaze bridge.
final GazeHomeGrid gazeHomeGrid = GazeHomeGrid();
