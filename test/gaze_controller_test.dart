import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:pwdpwdpwd/features/gaze_control/controllers/gaze_controller.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_action.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_overlay.dart';

class _FakeDetector implements GazeDetector {
  @override
  Future<FaceSignal> detect(InputImage image) async => FaceSignal.absent;
  @override
  Future<void> close() async {}
}

CameraDescription _cam(CameraLensDirection dir) =>
    CameraDescription(name: dir.name, lensDirection: dir, sensorOrientation: 0);

const _overlayActions = [
  GazeAction(
    zone: GazeZone.left,
    label: 'Prev',
    icon: Icons.arrow_back_rounded,
    color: Colors.teal,
    onSelect: _noop,
  ),
  GazeAction(
    zone: GazeZone.right,
    label: 'Next',
    icon: Icons.arrow_forward_rounded,
    color: Colors.green,
    onSelect: _noop,
  ),
];

void _noop() {}

void main() {
  GazeController build(Future<List<CameraDescription>> Function() loader) =>
      GazeController(
        settings: const GazeSettings(enabled: true),
        camerasLoader: loader,
        detectorFactory: _FakeDetector.new,
      );

  group('GazeController camera acquisition', () {
    testWidgets('reports noCamera when there are no cameras', (tester) async {
      final c = build(() async => const <CameraDescription>[]);
      await c.start();
      await tester.pump();
      expect(c.status, GazeStatus.noCamera);
      expect(c.isReady, isFalse);
      c.dispose();
    });

    testWidgets('reports noCamera when only a back lens exists', (tester) async {
      final c = build(() async => [_cam(CameraLensDirection.back)]);
      await c.start();
      await tester.pump();
      expect(c.status, GazeStatus.noCamera);
      c.dispose();
    });

    testWidgets('starts in the initializing state', (tester) async {
      final c = build(() async => const <CameraDescription>[]);
      expect(c.status, GazeStatus.initializing);
      await c.start();
      c.dispose();
    });
  });

  group('GazeViewerOverlay', () {
    testWidgets('shows a status chip when the camera is unavailable',
        (tester) async {
      final c = build(() async => const <CameraDescription>[]);
      await c.start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [GazeOverlay(controller: c, actions: _overlayActions)],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('no front camera'), findsOneWidget);
      c.dispose();
    });

    testWidgets('is non-interactive so touches fall through', (tester) async {
      final c = build(() async => const <CameraDescription>[]);
      await c.start();
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Center(
                  child: ElevatedButton(
                    onPressed: () => tapped = true,
                    child: const Text('beneath'),
                  ),
                ),
                GazeOverlay(controller: c, actions: _overlayActions),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      // The overlay covers the button, but IgnorePointer lets the tap through.
      await tester.tap(find.text('beneath'));
      expect(tapped, isTrue);
      c.dispose();
    });
  });
}
