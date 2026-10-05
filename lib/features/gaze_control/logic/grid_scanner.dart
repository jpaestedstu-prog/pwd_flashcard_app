import 'dart:math' as math;

import '../models/gaze_models.dart';

/// Pure **row–column scanning** over a ragged grid — the "Scanning mode"
/// selection method for learners who can blink but cannot move their head.
///
/// A timer calls [step]; the learner blinks to call [select]:
///
///  * **Row phase.** A whole row lights up at a time, top to bottom. Blinking
///    on a row with one control picks it straight away; blinking on a longer
///    row steps *into* it.
///  * **Button phase.** The controls of that row light up one by one, left to
///    right, and a blink picks the lit one. A pass through the row with no
///    blink goes back to the row phase on the same row, so a learner who
///    stepped into the wrong row is never stuck in it.
///
/// Row–column rather than one-by-one because the hubs are long: Home alone
/// can publish twenty-odd controls plus the five tabs, and lighting them one
/// at a time at two seconds each meant waiting most of a minute to reach the
/// tab bar. A grid with a single row skips the row phase entirely, so the
/// flashcard viewer's action bar or a nav-only tab bar scans plainly, one
/// button at a time.
///
/// After a pick the highlight stays where it is, so pressing "Next" again is
/// one blink rather than a full cycle. Changing the grid's shape (a new hub
/// published its tiles) starts over from the top.
///
/// No timers, no Flutter — so every step, wrap and pick is unit-testable.
class GridScanner {
  GridScanner(List<int> rowLengths) : _rows = _sanitise(rowLengths) {
    reset();
  }

  List<int> _rows;
  int _row = 0;
  int? _col;

  /// How many button-phase steps have been taken in the current row, so a
  /// full unanswered pass can hand control back to the row phase.
  int _stepsInRow = 0;

  /// Where the highlight was before the last [step] (see [undoStep]).
  ({int row, int? col, int steps})? _beforeStep;

  /// The row currently lit (or containing the lit control). Meaningless when
  /// [isEmpty].
  int get row => _row;

  /// The lit control within [row], or null while the whole row is lit.
  int? get col => _col;

  /// True while a whole row is lit rather than a single control.
  bool get onWholeRow => _col == null;

  /// True when there is nothing to scan.
  bool get isEmpty => !_rows.any((n) => n > 0);

  /// The current row shape.
  List<int> get rowLengths => List.unmodifiable(_rows);

  static List<int> _sanitise(List<int> rows) => [
    for (final n in rows) n < 0 ? 0 : n,
  ];

  /// More than one row that has controls in it — the case where a row phase
  /// is worth having at all.
  bool get _usesRowPhase => _rows.where((n) => n > 0).length > 1;

  /// Replaces the grid. A different shape starts the scan over from the top;
  /// the same shape (a screen re-publishing to refresh its callbacks) leaves
  /// the highlight exactly where it is.
  void setRows(List<int> rowLengths) {
    final next = _sanitise(rowLengths);
    if (_sameShape(next)) return;
    _rows = next;
    reset();
  }

  bool _sameShape(List<int> other) {
    if (other.length != _rows.length) return false;
    for (var i = 0; i < other.length; i++) {
      if (other[i] != _rows[i]) return false;
    }
    return true;
  }

  /// Back to the first row that has controls in it.
  void reset() {
    _row = _firstRowFrom(0);
    _stepsInRow = 0;
    _beforeStep = null;
    // A grid with a single scannable row has no row phase: start on its first
    // control.
    _col = (!isEmpty && !_usesRowPhase) ? 0 : null;
  }

  /// Moves the highlight on by one.
  void step() {
    if (isEmpty) return;
    _beforeStep = (row: _row, col: _col, steps: _stepsInRow);
    final col = _col;
    if (col == null) {
      _row = _firstRowFrom(_row + 1);
      return;
    }
    final len = _rows[_row];
    _stepsInRow++;
    if (_usesRowPhase && _stepsInRow >= len) {
      // A whole pass of the row went by without a pick: hand back to the row
      // phase, on this same row, so it can be re-entered or passed over.
      _col = null;
      _stepsInRow = 0;
      return;
    }
    _col = (col + 1) % len;
  }

  /// Puts the highlight back where it was before the last [step]: a press
  /// that arrived just as the highlight moved on means what it had lit, not
  /// what replaced it a moment before. Returns whether there was one to undo.
  bool undoStep() {
    final before = _beforeStep;
    if (before == null) return false;
    _beforeStep = null;
    _row = before.row;
    _col = before.col;
    _stepsInRow = before.steps;
    return true;
  }

  /// Steers the highlight the way a controller's stick or arrows were
  /// pushed, like a D-pad cursor: ▲ ▼ to the row above or below (onto its
  /// nearest control when one control is lit, wrapping top to bottom), ◀ ▶
  /// along the row — and on a whole lit row, ◀ ▶ step into it.
  ///
  /// The stick first followed the scan's own order instead, so ▶ on a whole
  /// row lit the next *row*: a learner pushing right to reach a row's second
  /// control was carried down the screen.
  void steer(GazeZone direction) {
    if (isEmpty || direction == GazeZone.none) return;
    _beforeStep = null;
    _stepsInRow = 0;
    final forward =
        direction == GazeZone.down || direction == GazeZone.right;
    final col = _col;
    if (!_usesRowPhase) {
      // One row: every direction walks along it.
      final len = _rows[_row];
      _col = ((col ?? 0) + (forward ? 1 : -1)) % len;
      return;
    }
    if (direction == GazeZone.up || direction == GazeZone.down) {
      final next = forward ? _firstRowFrom(_row + 1) : _lastRowFrom(_row - 1);
      _row = next;
      if (col != null) _col = math.min(col, _rows[next] - 1);
      return;
    }
    final len = _rows[_row];
    if (col == null) {
      _col = forward ? 0 : len - 1;
      return;
    }
    _col = (col + (forward ? 1 : -1)).clamp(0, len - 1);
  }

  /// Lights the whole of the current row again (the row phase) — where a
  /// learner coming back from a page lands: on the control they opened, one
  /// stray press opened that page again.
  void wholeRow() {
    if (isEmpty || !_usesRowPhase) return;
    _col = null;
    _stepsInRow = 0;
    _beforeStep = null;
  }

  /// The learner blinked. Returns the control to activate, or null when the
  /// blink only stepped into a row (or there is nothing to scan).
  ({int row, int col})? select() {
    if (isEmpty) return null;
    _beforeStep = null;
    final col = _col;
    if (col != null) {
      _stepsInRow = 0;
      return (row: _row, col: col);
    }
    if (_rows[_row] == 1) return (row: _row, col: 0);
    _col = 0;
    _stepsInRow = 0;
    return null;
  }

  /// The last row at or before [start] (wrapping) that has controls in it.
  int _lastRowFrom(int start) {
    if (_rows.isEmpty) return 0;
    for (var i = 0; i < _rows.length; i++) {
      final r = (start - i) % _rows.length;
      if (_rows[r] > 0) return r;
    }
    return 0;
  }

  /// The first row at or after [start] (wrapping) that has controls in it.
  int _firstRowFrom(int start) {
    if (_rows.isEmpty) return 0;
    for (var i = 0; i < _rows.length; i++) {
      final r = (start + i) % _rows.length;
      if (_rows[r] > 0) return r;
    }
    return 0;
  }
}
