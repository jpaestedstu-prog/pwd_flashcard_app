import 'dart:async';

/// When the scanning highlight moves on — one clock for every gaze scope.
///
/// Each scope used to step its highlight on a plain periodic timer. Two things
/// went wrong with a real learner at the tablet:
///
///  * **Names were cut off.** With highlights read aloud, the next step
///    interrupted the name still being spoken: a long row ("Assessments,
///    Learning Gains, My Portfolio, My Goals") was stopped part-way, so a
///    learner who scans by ear could not tell what the row held. A step now
///    waits while [holdFor] says the name is still being read (and a moment
///    after it, to react to what was heard).
///  * **Presses landed one late.** A press that arrived just after the
///    highlight moved on picked the next control: the learner pressed on what
///    they saw, the tablet acted on what had replaced it a moment before.
///    [justMoved] tells a scope a press came within [forgiveness] of an
///    automatic move, so it can pick what was lit before instead.
///
/// A manual step (a controller's arrows) or a pick calls [restart]: the
/// highlight then always gets a full [step] before moving on, and as the
/// learner moved it on purpose, no forgiveness applies.
///
/// Timer-driven only (no wall clock), so it runs on fake time in tests.
class ScanClock {
  ScanClock({required this.step, required this.onStep, this.holdFor});

  /// Moves the highlight on by one.
  final void Function() onStep;

  /// How much longer the highlight should stay put before the next step —
  /// zero when nothing is holding it (see [GazeSessionMixin]'s spoken
  /// highlights).
  final Duration Function()? holdFor;

  /// Time each control stays lit.
  Duration step;

  Timer? _timer;
  Timer? _forgiveTimer;
  bool _justMoved = false;
  Duration _held = Duration.zero;

  /// Bumped by [start] and [stop], so an [onStep] that restarts or stops the
  /// clock is not followed by a second schedule.
  int _generation = 0;

  /// The longest a step is held for speech — a speech engine that never
  /// reports finishing must not freeze the scan.
  static const Duration maxHold = Duration(seconds: 8);

  /// The most a press may lag an automatic move and still count for what was
  /// lit before it.
  static const Duration maxForgiveness = Duration(milliseconds: 400);

  /// A quarter of the step, at most [maxForgiveness]: long enough for a press
  /// made as the highlight moved, far shorter than anyone takes to react to
  /// the new control.
  Duration get forgiveness {
    final quarter = step ~/ 4;
    return quarter < maxForgiveness ? quarter : maxForgiveness;
  }

  /// Whether the clock is running.
  bool get running => _timer != null;

  /// Whether the highlight moved by itself within the last [forgiveness].
  bool get justMoved => _justMoved;

  /// (Re)starts: the next step comes a full [step] from now.
  void start() {
    _generation++;
    _clearMove();
    _held = Duration.zero;
    _schedule(step);
  }

  /// The learner picked: a full step from now.
  void restart() => start();

  /// How long the highlight waits where the learner steered it (a
  /// controller's stick or arrows) before it moves by itself again.
  ///
  /// On the tablet, a learner steering with the stick paused to look and the
  /// scan carried the highlight two places away from where they had put it.
  /// Someone who steers wants it to stay; someone who only bumped the stick
  /// gets the scan back on its own.
  static const Duration steerPause = Duration(seconds: 10);

  /// The learner moved the highlight by hand: it stays there until they pick
  /// ([restart]) or leave it alone for [steerPause].
  void steered() {
    _generation++;
    _clearMove();
    _held = Duration.zero;
    _schedule(steerPause > step ? steerPause : step);
  }

  /// Stops stepping.
  void stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _clearMove();
    _held = Duration.zero;
  }

  /// The last automatic move has been dealt with (a late press was credited
  /// to what it replaced).
  void forgetMove() => _clearMove();

  /// Whether a press now is late for the last automatic move ([justMoved]) —
  /// and if so, that move counts as dealt with.
  bool takeJustMoved() {
    if (!_justMoved) return false;
    _clearMove();
    return true;
  }

  void _clearMove() {
    _forgiveTimer?.cancel();
    _forgiveTimer = null;
    _justMoved = false;
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _fire);
  }

  void _fire() {
    _timer = null;
    final generation = _generation;
    final hold = holdFor?.call() ?? Duration.zero;
    if (hold > Duration.zero && _held < maxHold) {
      _held += hold;
      _schedule(hold);
      return;
    }
    _held = Duration.zero;
    onStep();
    if (generation != _generation) return;
    _justMoved = true;
    _forgiveTimer?.cancel();
    final window = forgiveness;
    _forgiveTimer = window > Duration.zero
        ? Timer(window, () => _justMoved = false)
        : null;
    if (window <= Duration.zero) _justMoved = false;
    _schedule(step);
  }
}
