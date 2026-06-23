// Data types for the experimental Gaze (head + blink) accessibility control.
//
// These are deliberately free of any `camera` / ML Kit types so the gaze
// *logic* (zone resolver, dwell tracker, blink detector) is pure Dart and
// fully unit-testable without a device — mirroring how `object_scan` keeps
// its mappers pure behind the `ObjectLabeler` interface.

/// The four edge targets a learner can point their head at, plus [none] for
/// the neutral resting state (head facing the screen) and when no face is
/// visible.
///
/// An *edge / cross* layout (one target per screen side) is used rather than
/// corners because a single dominant head movement — look up, down, left, or
/// right — is far easier and more reliable for a user with limited motor
/// control than a diagonal corner movement.
enum GazeZone { up, down, left, right, none }

/// A single, device-agnostic reading of the user's head pose and eyes.
///
/// [headTurn] and [headTilt] are expressed in the **user's** frame of
/// reference (already un-mirrored for the front camera by the detector):
///   * [headTurn]  > 0 → user is looking to **their right**; < 0 → their left.
///   * [headTilt]  > 0 → user is looking **up**;            < 0 → looking down.
/// Both are in degrees. Eye-open values are 0.0 (shut) … 1.0 (wide open);
/// they fall back to 1.0 ("assume open") when ML Kit cannot classify the eye,
/// so a low-confidence frame never triggers an accidental blink.
class FaceSignal {
  final bool hasFace;
  final double headTurn;
  final double headTilt;
  final double leftEyeOpen;
  final double rightEyeOpen;

  const FaceSignal({
    required this.hasFace,
    this.headTurn = 0,
    this.headTilt = 0,
    this.leftEyeOpen = 1,
    this.rightEyeOpen = 1,
  });

  /// No face in frame — the neutral signal the detector emits between faces.
  static const FaceSignal absent = FaceSignal(hasFace: false);
}

/// The output of [DwellTracker]: which zone is currently held, how far its
/// dwell timer has filled (0 … 1, for the progress ring), and whether *this*
/// update is the frame the selection fired on (one-shot, edge-triggered).
class GazeReading {
  final GazeZone zone;
  final double progress;
  final bool justSelected;

  const GazeReading({
    required this.zone,
    required this.progress,
    required this.justSelected,
  });

  static const GazeReading idle =
      GazeReading(zone: GazeZone.none, progress: 0, justSelected: false);
}
