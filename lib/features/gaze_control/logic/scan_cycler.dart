/// Default time each item stays highlighted in scanning mode before the
/// highlight moves to the next one.
const Duration kDefaultScanStep = Duration(milliseconds: 2000);

/// Cycles a highlight index 0 … count-1 for the **scanning** selection mode —
/// the fallback for learners who can blink reliably but cannot move their head.
/// A timer calls [advance] on each step and the learner blinks to pick whatever
/// is currently highlighted.
///
/// Pure and deterministic (no timer of its own), so the wrap-around is fully
/// unit-testable.
class ScanCycler {
  ScanCycler({required this.count});

  /// Number of items being scanned. May be updated if the item set changes.
  int count;

  int _current = 0;

  /// The currently highlighted index, or -1 when there is nothing to scan.
  int get current => count <= 0 ? -1 : _current.clamp(0, count - 1);

  /// Moves the highlight to the next item (wrapping) and returns it.
  int advance() {
    if (count <= 0) return -1;
    _current = (current + 1) % count;
    return _current;
  }

  void reset() => _current = 0;
}
