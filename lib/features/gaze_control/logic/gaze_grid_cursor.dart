import 'nav_gaze_cursor.dart' show wrapNavIndex;

/// Pure, camera-free **2D** cursor for gaze-driven navigation over a *ragged
/// grid* — a list of rows where each row may hold a different number of cells.
///
/// It generalises [NavGazeCursor]: a single-row grid behaves exactly like the
/// bottom-nav D-pad (look ◀ ▶ wraps across the one row, no vertical movement),
/// and extra rows *above* the nav row let the same head D-pad reach the Home
/// feature tiles (look ▲ ▼ moves between rows). The shell stacks the Home tile
/// rows on top and keeps the bottom-nav bar as the final row, so a single
/// cursor spans both regions seamlessly.
///
/// Movement model — identical wrap philosophy to the rest of the app's gaze
/// cursors (`NavGazeCursor`, `wrapBoardIndex`):
///   * **horizontal**: wraps within the current row (look-left from the first
///     cell lands on the last);
///   * **vertical**: wraps across rows (look-up from the top row lands on the
///     bottom/nav row), clamping the column into the destination row's width so
///     a shorter row never reports an out-of-range column.
///
/// No Flutter, no camera — so movement / wrap / clamp / re-sync is fully
/// unit-testable without a device.
class GazeGridCursor {
  GazeGridCursor({required List<int> rowLengths, int row = 0, int col = 0})
      : _rows = _sanitise(rowLengths) {
    _row = _clampRow(row);
    _col = _clampCol(col);
  }

  List<int> _rows;
  int _row = 0;
  int _col = 0;

  /// Number of rows in the grid (Home tile rows + the bottom-nav row).
  int get rowCount => _rows.length;

  /// The row the cursor is resting on (always in `0 … rowCount-1`, or 0 when
  /// the grid is empty).
  int get row => _row;

  /// The column within [row] the cursor is resting on (always in range).
  int get col => _col;

  /// Cell count of the row the cursor is currently on (0 when empty).
  int get currentRowLength => _rows.isEmpty ? 0 : _rows[_row];

  static List<int> _sanitise(List<int> rows) =>
      [for (final n in rows) n < 0 ? 0 : n];

  int _clampRow(int row) {
    if (_rows.isEmpty) return 0;
    if (row < 0) return 0;
    if (row >= _rows.length) return _rows.length - 1;
    return row;
  }

  int _clampCol(int col) {
    final len = currentRowLength;
    if (len <= 0) return 0;
    if (col < 0) return 0;
    if (col >= len) return len - 1;
    return col;
  }

  /// Moves the cursor within the current row by [delta], wrapping at the ends.
  void moveHoriz(int delta) {
    final len = currentRowLength;
    if (len <= 0) return;
    _col = wrapNavIndex(_col + delta, len);
  }

  /// Moves the cursor between rows by [delta], wrapping top↔bottom and keeping
  /// the column inside the destination row. A single-row grid has nowhere to
  /// move, so this is a no-op there (preserving nav-only D-pad behaviour).
  void moveVert(int delta) {
    if (_rows.length <= 1) return;
    _row = wrapNavIndex(_row + delta, _rows.length);
    _col = _clampCol(_col);
  }

  /// Jumps the cursor to a known cell — e.g. re-syncing to the live bottom-nav
  /// selection after a commit or a plain touch — clamping into range.
  void moveTo(int row, int col) {
    _row = _clampRow(row);
    _col = _clampCol(col);
  }

  /// Replaces the row shape when the layout changes (a Home grid appears or
  /// disappears, or a role switch changes the tab count), keeping the cursor in
  /// range so the highlight never points at a cell that no longer exists.
  void setRows(List<int> rowLengths) {
    _rows = _sanitise(rowLengths);
    _row = _clampRow(_row);
    _col = _clampCol(_col);
  }
}
