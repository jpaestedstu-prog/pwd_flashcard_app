/// A **reading-order** cursor over the ragged tile grid a hub publishes.
///
/// The hands-free gaze D-pad steers the same grids in 2-D (`GazeGridCursor`),
/// which suits someone who can see the layout. A learner who cannot see it
/// needs the opposite: one unambiguous "next thing" per press. So this cursor
/// flattens the rows into a single sequence — left-to-right, top-to-bottom,
/// exactly how a screen reader walks a page — and exposes `next`/`previous`
/// over that.
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
    final max = length;
    if (max == 0) return;
    _index = (_index + delta) % max;
    if (_index < 0) _index += max;
  }

  void first() => _index = 0;

  void last() {
    final max = length;
    _index = max == 0 ? 0 : max - 1;
  }

  /// Jumps to a known cell — used to follow a focus change that came from
  /// somewhere else (a touch, or the gaze cursor), so the next controller
  /// press continues from what the learner last heard rather than from a stale
  /// position.
  void moveTo(int row, int col) {
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
