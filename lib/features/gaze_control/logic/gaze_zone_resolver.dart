import '../models/gaze_models.dart';

/// Default head-turn (yaw) needed before the left/right targets engage, in
/// degrees. Tuned to be reachable with a small, comfortable head movement
/// while still clearing normal resting jitter.
const double kDefaultTurnThresholdDeg = 12;

/// Default head-tilt (pitch) needed before the up/down targets engage.
const double kDefaultTiltThresholdDeg = 10;

/// Pure mapping from a [FaceSignal] to the [GazeZone] the user is pointing at.
///
/// The angles in [signal] are already in the user's frame of reference (the
/// detector un-mirrors the front camera), so:
///   * looking right / left  → [GazeZone.right] / [GazeZone.left]
///   * looking up   / down   → [GazeZone.up]    / [GazeZone.down]
///
/// Each axis is normalised to "threshold units" (angle ÷ its threshold) so the
/// two thresholds can differ yet still be compared fairly. While **both** axes
/// sit inside their threshold the head is resting and the result is
/// [GazeZone.none]. Otherwise the axis with the larger normalised magnitude
/// wins, which makes selection forgiving: the user only has to move clearly in
/// *one* direction, never diagonally.
///
/// Pure and side-effect free — this is the unit-tested heart of the feature.
GazeZone resolveGazeZone(
  FaceSignal signal, {
  double turnThresholdDeg = kDefaultTurnThresholdDeg,
  double tiltThresholdDeg = kDefaultTiltThresholdDeg,
}) {
  if (!signal.hasFace) return GazeZone.none;

  // Guard against a zero/negative threshold producing a divide-by-zero or
  // NaN that would make every frame register as a selection.
  final turnT = turnThresholdDeg.abs();
  final tiltT = tiltThresholdDeg.abs();
  if (turnT == 0 || tiltT == 0) return GazeZone.none;

  final hRatio = signal.headTurn / turnT;
  final vRatio = signal.headTilt / tiltT;
  final hMag = hRatio.abs();
  final vMag = vRatio.abs();

  // Resting deadzone: neither axis has cleared its threshold.
  if (hMag < 1 && vMag < 1) return GazeZone.none;

  // Dominant axis wins; ties go to horizontal (left/right tend to be the
  // easier, higher-confidence movement on a front camera).
  if (hMag >= vMag) {
    return hRatio < 0 ? GazeZone.left : GazeZone.right;
  }
  return vRatio > 0 ? GazeZone.up : GazeZone.down;
}
