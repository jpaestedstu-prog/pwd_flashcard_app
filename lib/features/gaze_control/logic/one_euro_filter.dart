import 'dart:math' as math;

/// The **One Euro filter** (Casiez, Roussel & Vogel, CHI 2012): a low-pass
/// filter whose cut-off rises with speed, so a head held still is steadied
/// hard while a deliberate turn passes through with little lag.
///
/// Raw head angles from the face detector tremble by a degree or two from
/// frame to frame. Near a learner's threshold that tremble flips the zone in
/// and out, and every flip restarts the hold — the learner turns, holds, and
/// nothing happens. Smoothing the angle before the zone is decided keeps the
/// hold running.
///
/// [minCutoff] (Hz) sets how much a still head is steadied (lower = steadier,
/// more lag); [beta] how quickly the cut-off opens up as the head moves.
///
/// Pure and timestamp-driven, so it is fully unit-testable.
class OneEuroFilter {
  OneEuroFilter({
    required this.minCutoff,
    required this.beta,
    this.derivativeCutoff = 1.0,
  });

  final double minCutoff;
  final double beta;
  final double derivativeCutoff;

  double? _x;
  double _dx = 0;
  Duration? _last;

  static double _alpha(double cutoff, double dtSeconds) {
    final tau = 1.0 / (2 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dtSeconds);
  }

  /// Filters [value], sampled at [timestamp] (monotonic).
  double filter(double value, Duration timestamp) {
    final previous = _x;
    final last = _last;
    _last = timestamp;
    if (previous == null || last == null) {
      _x = value;
      return value;
    }
    var dt = (timestamp - last).inMicroseconds / 1e6;
    // A frame stamped at (or before) the last one: nothing sensible to
    // filter against, so treat it as the next frame of a steady 15 fps feed.
    if (dt <= 0) dt = 1 / 15;
    final rawDx = (value - previous) / dt;
    final aD = _alpha(derivativeCutoff, dt);
    _dx = aD * rawDx + (1 - aD) * _dx;
    final cutoff = minCutoff + beta * _dx.abs();
    final a = _alpha(cutoff, dt);
    final next = a * value + (1 - a) * previous;
    _x = next;
    return next;
  }

  /// Forgets the history (camera restarted, face lost).
  void reset() {
    _x = null;
    _dx = 0;
    _last = null;
  }
}
