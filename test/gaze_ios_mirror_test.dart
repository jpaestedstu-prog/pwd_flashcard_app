import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:pwdpwdpwd/features/gaze_control/controllers/gaze_controller.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';

/// On iOS the camera plugin mirrors the front camera's frames (a selfie
/// view); Android's are the sensor's own. A head turn reads with the opposite
/// sign in a mirrored frame, so an iPhone or iPad would have moved the
/// highlight the wrong way. Readings are turned back into Android's frame,
/// where the left/right setting and a stored resting position are defined.

class _NoFace implements GazeDetector {
  @override
  Future<FaceSignal> detect(InputImage image) async => FaceSignal.absent;
  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only an iOS build treats frames as mirrored', () {
    // The host running the tests is never iOS.
    expect(GazeController.framesArriveMirrored, isFalse);
  });

  test('unmirroring flips the head turn and nothing else', () {
    const s = FaceSignal(
      hasFace: true,
      headTurn: 18,
      headTilt: -7,
      leftEyeOpen: 0.4,
      rightEyeOpen: 0.9,
    );
    final u = GazeController.unmirrored(s);
    expect(u.hasFace, isTrue);
    expect(u.headTurn, -18);
    expect(u.headTilt, -7);
    expect(u.leftEyeOpen, 0.4);
    expect(u.rightEyeOpen, 0.9);
  });

  test('the same physical turn lands on the same side on both platforms', () {
    GazeZone zoneFor(FaceSignal s) {
      final c = GazeController(
        settings: const GazeSettings(enabled: true),
        detectorFactory: _NoFace.new,
      );
      for (var ms = 0; ms <= 600; ms += 50) {
        c.debugFeed(s, Duration(milliseconds: ms));
      }
      final zone = c.zone;
      c.dispose();
      return zone;
    }

    // Android's unmirrored frame reads a turn as +25; an iOS mirrored frame
    // reads the very same turn as -25, and is turned back before use.
    const android = FaceSignal(hasFace: true, headTurn: 25);
    const iosMirrored = FaceSignal(hasFace: true, headTurn: -25);
    final androidZone = zoneFor(android);
    expect(androidZone, isNot(GazeZone.none));
    expect(zoneFor(GazeController.unmirrored(iosMirrored)), androidZone);
  });
}
