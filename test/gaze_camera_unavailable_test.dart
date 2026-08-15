import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show AppSettings;
import 'package:pwdpwdpwd/features/gaze_control/controllers/gaze_controller.dart'
    show GazeStatus;
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_camera_owners.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/nav_gaze_scope.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show SettingsNotifier, settingsProvider;

/// A camera that is never going to come up must say so.
///
/// The nav shell's hint only knew `ready` / `faceVisible`, so a denied camera
/// permission — or a device with no front lens — rendered as "Starting gaze…"
/// permanently: a hands-free learner waiting on something that will never
/// happen, with nothing telling them a permission is missing. `NavGazeState`
/// now carries the real [GazeStatus].

class _FakeDetector implements GazeDetector {
  @override
  Future<FaceSignal> detect(InputImage image) async => FaceSignal.absent;
  @override
  Future<void> close() async {}
}

class _FixedSettings extends GazeSettingsNotifier {
  @override
  GazeSettings build() => const GazeSettings(enabled: true);
}

class _StubAppSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

void main() {
  setUp(() {
    while (gazeCameraOwners.isBusy) {
      gazeCameraOwners.release();
    }
  });

  testWidgets('a device with no front camera reports noCamera, not "starting"',
      (tester) async {
    final container = ProviderContainer(overrides: [
      gazeSettingsProvider.overrideWith(_FixedSettings.new),
      settingsProvider.overrideWith(_StubAppSettings.new),
    ]);
    addTearDown(container.dispose);
    late NavGazeState last;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: NavGazeScope(
          currentIndex: 0,
          itemCount: 5,
          onCommit: (_) {},
          // No lenses at all — the same end state as a denied permission from
          // the learner's point of view: gaze will never start.
          camerasLoader: () async => const <CameraDescription>[],
          detectorFactory: _FakeDetector.new,
          builder: (context, gaze) {
            last = gaze;
            return const Scaffold(body: Text('shell-body'));
          },
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(last.active, isTrue, reason: 'the scope did arm');
    expect(last.ready, isFalse);
    expect(last.status, GazeStatus.noCamera,
        reason: 'the shell must be able to tell the learner why');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the inactive state defaults to initializing', (tester) async {
    // Nothing armed yet is genuinely "starting", so the default must not
    // masquerade as a failure.
    expect(NavGazeState.inactive.status, GazeStatus.initializing);
    expect(NavGazeState.inactive.ready, isFalse);
  });
}
