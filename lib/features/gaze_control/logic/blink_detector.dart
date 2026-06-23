/// Eye-open probability at or below which an eye counts as "shut".
const double kDefaultEyeClosedThreshold = 0.25;

/// How long both eyes must stay shut for a *deliberate* blink (vs. a normal,
/// involuntary one, which is far shorter).
const Duration kDefaultBlinkHold = Duration(milliseconds: 600);

/// Detects a deliberate long blink — both eyes held shut past [holdDuration] —
/// as an alternate "select / confirm" gesture for learners who can blink more
/// reliably than they can move their head.
///
/// Feed each frame's left/right eye-open probabilities (0 … 1) and a monotonic
/// [now] timestamp into [update]; it returns `true` exactly once per blink, on
/// the frame the hold completes. It re-arms only after the eyes reopen, so a
/// long hold confirms a single time.
///
/// Pure and deterministic — fully unit-testable with a fake clock.
class BlinkDetector {
  BlinkDetector({
    this.closedThreshold = kDefaultEyeClosedThreshold,
    this.holdDuration = kDefaultBlinkHold,
  });

  final double closedThreshold;
  final Duration holdDuration;

  Duration? _closedSince;
  bool _consumed = false;

  /// Returns true on the single frame a deliberate blink completes.
  bool update(double leftEyeOpen, double rightEyeOpen, Duration now) {
    final bothShut =
        leftEyeOpen <= closedThreshold && rightEyeOpen <= closedThreshold;

    if (!bothShut) {
      // Eyes (re)opened — disarm and wait for the next blink.
      _closedSince = null;
      _consumed = false;
      return false;
    }

    _closedSince ??= now;
    if (!_consumed && now - _closedSince! >= holdDuration) {
      _consumed = true;
      return true;
    }
    return false;
  }

  /// Clears blink state — call alongside [DwellTracker.reset].
  void reset() {
    _closedSince = null;
    _consumed = false;
  }
}
