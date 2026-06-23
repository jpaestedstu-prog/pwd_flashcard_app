import '../models/gaze_models.dart';

/// Default time a learner must hold their gaze on a target before it fires.
const Duration kDefaultDwellDuration = Duration(milliseconds: 1500);

/// Turns a stream of per-frame [GazeZone]s into a dwell-to-select interaction.
///
/// Feed every frame's resolved zone plus a monotonic [now] timestamp into
/// [update]; it returns a [GazeReading] with the current zone, the dwell
/// progress (0 … 1, drives the on-screen ring) and a one-shot [GazeReading.justSelected]
/// flag on the single frame the dwell completes.
///
/// The selection is *edge-triggered*: after it fires it will not fire again
/// until the user looks away (zone changes) and back, so a held gaze selects
/// exactly once. [GazeZone.none] never accumulates dwell.
///
/// Pure and deterministic — driven entirely by the timestamps passed in, so it
/// is fully unit-testable with a fake clock and no camera.
class DwellTracker {
  DwellTracker({this.dwellDuration = kDefaultDwellDuration});

  final Duration dwellDuration;

  GazeZone _zone = GazeZone.none;
  Duration? _zoneStart;
  bool _consumed = false;

  /// Advances the tracker to [zone] at time [now] and returns the reading.
  GazeReading update(GazeZone zone, Duration now) {
    // Zone changed (including to/from none): restart the dwell timer.
    if (zone != _zone) {
      _zone = zone;
      _consumed = false;
      _zoneStart = zone == GazeZone.none ? null : now;
      return GazeReading(zone: zone, progress: 0, justSelected: false);
    }

    if (zone == GazeZone.none || _zoneStart == null) {
      return GazeReading.idle;
    }

    // Hold continues on the same zone — accumulate dwell. Guard a zero-length
    // dwell so progress can't divide by zero.
    final total = dwellDuration.inMicroseconds;
    final elapsed = now - _zoneStart!;
    final progress = total <= 0
        ? 1.0
        : (elapsed.inMicroseconds / total).clamp(0.0, 1.0);

    var fired = false;
    if (!_consumed && elapsed >= dwellDuration) {
      _consumed = true;
      fired = true;
    }
    return GazeReading(zone: zone, progress: progress, justSelected: fired);
  }

  /// Clears all dwell state — call when the controller restarts or the screen
  /// re-acquires the camera so a stale timer can't fire on the first frame.
  void reset() {
    _zone = GazeZone.none;
    _zoneStart = null;
    _consumed = false;
  }
}
