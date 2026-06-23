import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/screens/gaze_control_screen.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';

import 'support/screen_matrix.dart';

/// Real cameras and ML Kit need platform channels; the screen takes both as
/// injectable factories so the no-front-camera fallback (what every
/// camera-less test environment shows) can render in tests.
class _FakeDetector implements GazeDetector {
  @override
  Future<FaceSignal> detect(InputImage image) async => FaceSignal.absent;

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets('gaze screen (no-camera fallback) survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => GazeControlScreen(
        camerasLoader: () async => const <CameraDescription>[],
        detectorFactory: _FakeDetector.new,
      ),
    );
  });

  testWidgets('falls back to no-camera when only a back lens exists',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: GazeControlScreen(
            camerasLoader: () async => [
              const CameraDescription(
                name: 'back',
                lensDirection: CameraLensDirection.back,
                sensorOrientation: 90,
              ),
            ],
            detectorFactory: _FakeDetector.new,
          ),
        ),
      ),
    );
    await tester.pump(); // let the async camera load resolve
    await tester.pump();
    expect(find.textContaining('front camera'), findsOneWidget);
  });
}
