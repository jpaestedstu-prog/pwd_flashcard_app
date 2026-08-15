import 'package:flutter/widgets.dart';

/// The hands-free cursor shared between a race screen and the player widget
/// sitting on it.
///
/// Only **one** gaze camera may run app-wide (`gazeCameraOwners`), so the
/// single `GazeScope` has to live on the screen — but the thing it steers (the
/// answer grid, the memory board, the letter bank) lives inside the player
/// widget, which owns that state. This class is the seam: the player publishes
/// how many targets it currently has and what "choose" means, the screen reads
/// it to build its gaze actions, and both repaint when the highlight moves.
///
/// Deliberately not a Riverpod provider — its lifetime is exactly one screen,
/// and the player widget must be able to attach to it from `build` without a
/// container lookup.
class RaceCursor extends ChangeNotifier {
  int _index = 0;
  int _count = 0;
  bool _enabled = false;
  bool _highlight = false;
  VoidCallback? _onChoose;
  bool Function(int index)? _isEnabledAt;

  /// Where the highlight rests, in the player's own flat target order.
  int get index => _index;

  /// How many targets the player currently offers.
  int get count => _count;

  /// Draw the highlight ring. Set by the screen from the learner's Gaze
  /// Control setting, so a touch-only learner never sees a stray ring.
  bool get highlight => _highlight;
  set highlight(bool value) {
    if (_highlight == value) return;
    _highlight = value;
    notifyListeners();
  }

  /// There is more than one place to go.
  bool get canMove => _enabled && _reachableCount > 1;

  /// The focused target can be opened.
  bool get canChoose => _enabled && _count > 0 && _isReachable(_index);

  /// True when [i] is the focused target *and* the ring should be drawn.
  bool isFocused(int i) => _highlight && _enabled && _index == i;

  /// Called by the player widget from `build` to publish its current targets.
  ///
  /// [isEnabledAt] lets the player mark targets the cursor should skip over
  /// (a cleared memory pair, a letter already placed) so hands-free movement
  /// never parks on something that does nothing.
  ///
  /// Safe to call during build: it never notifies synchronously. When the
  /// shape actually changes it schedules one post-frame notification, so the
  /// screen's gaze actions catch up on the very next frame instead of lagging
  /// until something else happens to rebuild it.
  void attach({
    required int count,
    required bool enabled,
    required VoidCallback onChoose,
    bool Function(int index)? isEnabledAt,
  }) {
    _onChoose = onChoose;
    _isEnabledAt = isEnabledAt;
    final changed = _count != count || _enabled != enabled;
    _count = count;
    _enabled = enabled;
    if (_index >= count) _index = count == 0 ? 0 : count - 1;
    if (count > 0 && !_isReachable(_index)) {
      final next = _seek(_index, 1);
      if (next != null) _index = next;
    }
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    }
  }

  /// Release the player's callbacks when it leaves the tree, so a stale
  /// "choose" can't fire into a disposed widget.
  void detach() {
    _onChoose = null;
    _isEnabledAt = null;
    _count = 0;
    _enabled = false;
  }

  /// Step the highlight by [delta], wrapping, skipping unreachable targets.
  void move(int delta) {
    if (!canMove) return;
    final next = _seek(_index + delta, delta.isNegative ? -1 : 1);
    if (next == null || next == _index) return;
    _index = next;
    notifyListeners();
  }

  /// Open the focused target.
  void choose() {
    if (!canChoose) return;
    _onChoose?.call();
  }

  /// Put the highlight back on the first reachable target — used when the
  /// player moves to a fresh round so the ring doesn't linger mid-grid.
  void reset() {
    if (_index == 0) return;
    _index = 0;
    if (_count > 0 && !_isReachable(0)) {
      final next = _seek(0, 1);
      if (next != null) _index = next;
    }
    notifyListeners();
  }

  bool _isReachable(int i) =>
      i >= 0 && i < _count && (_isEnabledAt?.call(i) ?? true);

  int get _reachableCount {
    var n = 0;
    for (var i = 0; i < _count; i++) {
      if (_isReachable(i)) n++;
    }
    return n;
  }

  /// First reachable index at or after [from], walking in [step] direction and
  /// wrapping. Null when nothing is reachable.
  int? _seek(int from, int step) {
    if (_count <= 0) return null;
    var i = ((from % _count) + _count) % _count;
    for (var tries = 0; tries < _count; tries++) {
      if (_isReachable(i)) return i;
      i = (((i + step) % _count) + _count) % _count;
    }
    return null;
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
