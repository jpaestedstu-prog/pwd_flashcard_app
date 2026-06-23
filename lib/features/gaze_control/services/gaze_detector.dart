import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/gaze_models.dart';

/// On-device face/gaze detector behind a small interface so the gaze screen
/// can be widget-tested with a fake — the real one needs platform channels.
/// Mirrors the `ObjectLabeler` interface used by the Word Hunt feature.
abstract class GazeDetector {
  /// Runs detection on one camera frame (already wrapped as an [InputImage])
  /// and returns the dominant face as a device-agnostic [FaceSignal], or
  /// [FaceSignal.absent] when no face is visible.
  Future<FaceSignal> detect(InputImage image);

  Future<void> close();
}

/// Builds a [FaceSignal] from ML Kit's raw head-pose angles and eye-open
/// probabilities, normalising them into the user's frame of reference.
///
/// Pulled out as a pure function so the (device-dependent, easy-to-get-wrong)
/// sign handling is unit-testable without a camera:
///   * [mirrorHorizontal] flips yaw for the front camera, whose raw image is
///     mirrored relative to what the user sees. **This is the one value to
///     confirm on the first real-device run** — if left/right feel swapped,
///     flip it.
///   * [invertVertical] flips pitch if up/down feel swapped.
/// Missing eye classifications default to 1.0 ("assume open") so a
/// low-confidence frame never fires an accidental blink.
FaceSignal faceSignalFromAngles({
  double? rawEulerY,
  double? rawEulerX,
  double? leftEyeOpen,
  double? rightEyeOpen,
  bool mirrorHorizontal = true,
  bool invertVertical = false,
}) {
  return FaceSignal(
    hasFace: true,
    headTurn: (rawEulerY ?? 0) * (mirrorHorizontal ? -1 : 1),
    headTilt: (rawEulerX ?? 0) * (invertVertical ? -1 : 1),
    leftEyeOpen: leftEyeOpen ?? 1.0,
    rightEyeOpen: rightEyeOpen ?? 1.0,
  );
}

/// Returns the largest face (by bounding-box area) — the one nearest the
/// camera, i.e. the learner using the app rather than someone in the
/// background. Pure, so it is unit-testable with plain rectangles.
Face? largestFace(List<Face> faces) {
  if (faces.isEmpty) return null;
  Face best = faces.first;
  double bestArea = best.boundingBox.width * best.boundingBox.height;
  for (final f in faces.skip(1)) {
    final area = f.boundingBox.width * f.boundingBox.height;
    if (area > bestArea) {
      best = f;
      bestArea = area;
    }
  }
  return best;
}

/// ML Kit implementation — runs fully on-device/offline using the bundled
/// face model (no API key, no paid tier).
///
/// Classification is enabled (for eye-open probabilities) and the default *fast*
/// performance mode is used: gaze control only needs head pose + eye state at
/// interactive rates, not the slower contour pass.
class MlKitGazeDetector implements GazeDetector {
  MlKitGazeDetector({
    bool mirrorHorizontal = true,
    bool invertVertical = false,
  })  : _mirrorHorizontal = mirrorHorizontal,
        _invertVertical = invertVertical,
        _detector = FaceDetector(
          options: FaceDetectorOptions(enableClassification: true),
        );

  final FaceDetector _detector;
  final bool _mirrorHorizontal;
  final bool _invertVertical;

  @override
  Future<FaceSignal> detect(InputImage image) async {
    final faces = await _detector.processImage(image);
    final face = largestFace(faces);
    if (face == null) return FaceSignal.absent;
    return faceSignalFromAngles(
      rawEulerY: face.headEulerAngleY,
      rawEulerX: face.headEulerAngleX,
      leftEyeOpen: face.leftEyeOpenProbability,
      rightEyeOpen: face.rightEyeOpenProbability,
      mirrorHorizontal: _mirrorHorizontal,
      invertVertical: _invertVertical,
    );
  }

  @override
  Future<void> close() => _detector.close();
}
