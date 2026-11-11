/// The controller's cursor over the ragged tile grid a hub publishes, both
/// ways round.
///
/// **By direction** ([moveVertical], [moveHorizontal]) for the D-pad, as the
/// hands-free gaze D-pad steers the same grid (`GazeGridCursor`): left and
/// right stay in the row, wrapping at its ends; up and down change row,
/// wrapping top to bottom. **One at a time** ([next], [previous]) for L2 and
/// R2: the rows flattened into a single sequence — left-to-right,
/// top-to-bottom, exactly how a screen reader walks a page — for a learner
/// who needs one unambiguous "next thing" per press.
///
/// It still reports a `(row, col)` because that is what `gazeHomeGrid.setFocus`
/// wants in order to draw the highlight ring, so the visible focus and the
/// spoken focus can never disagree.
///
/// Movement **wraps**, matching every other cursor in the app: stepping past
/// the last item lands on the first. Wrapping matters more here than elsewhere
/// — without it a blind learner who overshoots has no way to tell whether they
/// are at the end of the list or the controller has stopped responding.
class GamepadCursor {
  List<int> _rows = const [];
  int _index = 0;

  GamepadCursor({List<int> rowLengths = const []}) {
    setRows(rowLengths);
  }

  /// Total number of addressable cells.
  int get length {
    var total = 0;
    for (final n in _rows) {
      total += n;
    }
    return total;
  }

  bool get isEmpty => length == 0;

  /// Linear position in reading order, always in `0 … length-1` (0 when empty).
  int get index => _index;

  /// Row of the current cell, or 0 when the grid is empty.
  int get row {
    var remaining = _index;
    for (var r = 0; r < _rows.length; r++) {
      if (remaining < _rows[r]) return r;
      remaining -= _rows[r];
    }
    return 0;
  }

  /// Column of the current cell within [row], or 0 when the grid is empty.
  int get col {
    var remaining = _index;
    for (final n in _rows) {
      if (remaining < n) return remaining;
      remaining -= n;
    }
    return 0;
  }

  /// Re-shapes the cursor when the visible screen changes.
  ///
  /// The linear position is **clamped, not reset**, so a rebuild that merely
  /// adds a row (an assignments banner appearing, say) doesn't throw the
  /// learner back to the top of the screen mid-sentence.
  void setRows(List<int> rowLengths) {
    _rows = [for (final n in rowLengths) n < 0 ? 0 : n];
    final max = length;
    if (max == 0) {
      _index = 0;
    } else if (_index >= max) {
      _index = max - 1;
    } else if (_index < 0) {
      _index = 0;
    }
  }

  void next() => _step(1);
  void previous() => _step(-1);

  void _step(int delta) {
    _wantCol = null;
    final max = length;
    if (max == 0) return;
    _index = (_index + delta) % max;
    if (_index < 0) _index += max;
  }

  void first() {
    _wantCol = null;
    _index = 0;
  }

  void last() {
    _wantCol = null;
    final max = length;
    _index = max == 0 ? 0 : max - 1;
  }

  /// The column up and down aim for, kept while passing through shorter
  /// rows: from the right-hand tile of a three-wide row, down through a
  /// one-wide card and on into another wide row lands on its right-hand tile
  /// again, not on its first.
  int? _wantCol;

  /// Up ([delta] -1) or down (+1) a row, wrapping top to bottom and skipping
  /// empty rows; the column is kept where the new row is wide enough.
  void moveVertical(int delta) {
    if (isEmpty) return;
    final want = _wantCol ?? col;
    var r = row;
    for (var i = 0; i < _rows.length; i++) {
      r = (r + delta) % _rows.length;
      if (r < 0) r += _rows.length;
      if (_rows[r] > 0) break;
    }
    _goTo(r, want < _rows[r] ? want : _rows[r] - 1);
    _wantCol = want;
  }

  /// Left ([delta] -1) or right (+1) within the row, wrapping at its ends.
  void moveHorizontal(int delta) {
    if (isEmpty) return;
    final width = _rows[row];
    var c = (col + delta) % width;
    if (c < 0) c += width;
    _goTo(row, c);
    _wantCol = c;
  }

  void _goTo(int row, int col) {
    var linear = 0;
    for (var i = 0; i < row; i++) {
      linear += _rows[i];
    }
    _index = linear + col;
  }

  /// Jumps to a known cell — used to follow a focus change that came from
  /// somewhere else (a touch, or the gaze cursor), so the next controller
  /// press continues from what the learner last heard rather than from a stale
  /// position.
  void moveTo(int row, int col) {
    _wantCol = null;
    if (_rows.isEmpty) {
      _index = 0;
      return;
    }
    final r = row < 0
        ? 0
        : (row >= _rows.length ? _rows.length - 1 : row);
    var linear = 0;
    for (var i = 0; i < r; i++) {
      linear += _rows[i];
    }
    final width = _rows[r];
    final c = width <= 0 ? 0 : (col < 0 ? 0 : (col >= width ? width - 1 : col));
    _index = linear + c;
    final max = length;
    if (max == 0) {
      _index = 0;
    } else if (_index >= max) {
      _index = max - 1;
    }
  }
}
