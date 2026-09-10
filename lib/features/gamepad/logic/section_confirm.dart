/// The **ask-before-you-move** state machine behind section navigation.
///
/// Pressing right does not switch tabs. It *offers* the next section — "Do you
/// want to go to the Cards section?" — and waits. **A** accepts and moves;
/// **B** declines and offers the one after that. That is the whole loop, and it
/// exists because a learner who cannot see the screen has no way to undo a
/// wrong tab change they didn't know they'd made: confirming first turns a
/// mistake into a question they simply answer "no" to.
///
/// Pure state, no speech and no navigation — the host turns [pending] into a
/// sentence and performs the move — so every path here is unit-testable.
class SectionConfirm {
  List<String> _sections;
  int _current;
  int? _pending;

  SectionConfirm({List<String> sections = const [], int current = 0})
      : _sections = List.unmodifiable(sections),
        _current = current;

  List<String> get sections => _sections;

  /// The section the learner is actually in.
  int get current => _current;

  /// The section being offered, or null when no question is on the table.
  int? get pending => _pending;

  /// Whether a question is waiting for A / B. Drives the contextual re-mapping
  /// of those two buttons (see `resolveGamepadAction`).
  bool get awaitingAnswer => _pending != null;

  /// Name of the section being offered, or null when nothing is pending.
  String? get pendingLabel =>
      _pending == null ? null : _labelAt(_pending!);

  /// Name of the section the learner is in, or null when there are none.
  String? get currentLabel => _sections.isEmpty ? null : _labelAt(_current);

  String _labelAt(int i) => _sections[i.clamp(0, _sections.length - 1)];

  /// Re-publishes the section list after a role switch (learners get five tabs,
  /// educators four) or a plain tab change from touch.
  ///
  /// A pending question is **dropped** whenever the live section changes
  /// underneath it: the learner has arrived somewhere by other means, and
  /// answering "yes" to a question about where they *were* going would move
  /// them a second time, unasked.
  void sync({required List<String> sections, required int current}) {
    final changed =
        current != _current || !_sameLabels(sections, _sections);
    _sections = List.unmodifiable(sections);
    _current = _sections.isEmpty ? 0 : current.clamp(0, _sections.length - 1);
    if (changed) _pending = null;
  }

  /// Offers the section after the one currently on the table (or after the
  /// live one, when nothing is pending yet). Returns the offered index, or
  /// null when there is nothing to offer.
  int? offerNext() => _offer(1);

  /// Offers the section before it.
  int? offerPrevious() => _offer(-1);

  int? _offer(int delta) {
    if (_sections.isEmpty) return null;
    // A single-section shell (the guest Player has no tabs at all) has nothing
    // to walk to, so asking would be a dead end.
    if (_sections.length == 1) return null;
    final from = _pending ?? _current;
    var next = (from + delta) % _sections.length;
    if (next < 0) next += _sections.length;
    _pending = next;
    return next;
  }

  /// Accepts the pending offer. Returns the section to move to, or null when
  /// nothing was pending.
  int? accept() {
    final target = _pending;
    if (target == null) return null;
    _pending = null;
    _current = target;
    return target;
  }

  /// Declines, and offers the *next* section instead — "if the user presses
  /// No, continue navigating through the available sections". Returns the
  /// newly offered index.
  int? decline() {
    if (_pending == null) return null;
    return offerNext();
  }

  /// Abandons the question without moving. Used when the learner does
  /// something else entirely (steps through items, opens something), so a
  /// stale question can never be answered by a much later A press.
  void cancel() => _pending = null;

  static bool _sameLabels(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
