import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/nav_gaze_cursor.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_camera_owners.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_home_grid.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/nav_gaze_scope.dart';

class _FakeDetector implements GazeDetector {
  @override
  Future<FaceSignal> detect(InputImage image) async => FaceSignal.absent;
  @override
  Future<void> close() async {}
}

/// Forces a particular [GazeSettings] without touching Hive.
class _FixedSettings extends GazeSettingsNotifier {
  _FixedSettings(this._value);
  final GazeSettings _value;
  @override
  GazeSettings build() => _value;
}

void main() {
  // The camera-owner gate and the home-grid bridge are app-wide singletons;
  // keep tests isolated.
  setUp(() {
    while (gazeCameraOwners.isBusy) {
      gazeCameraOwners.release();
    }
    gazeHomeGrid.clearGrid();
  });

  group('wrapNavIndex', () {
    test('stays put inside the range', () {
      expect(wrapNavIndex(0, 5), 0);
      expect(wrapNavIndex(3, 5), 3);
      expect(wrapNavIndex(4, 5), 4);
    });

    test('wraps off the right edge to the start', () {
      expect(wrapNavIndex(5, 5), 0);
      expect(wrapNavIndex(6, 5), 1);
    });

    test('wraps off the left edge to the end (look-left from first tab)', () {
      expect(wrapNavIndex(-1, 5), 4);
      expect(wrapNavIndex(-2, 5), 3);
    });

    test('empty bar is safe', () {
      expect(wrapNavIndex(0, 0), 0);
      expect(wrapNavIndex(-1, 0), 0);
      expect(wrapNavIndex(3, 0), 0);
    });

    test('handles large jumps in both directions', () {
      expect(wrapNavIndex(12, 5), 2);
      expect(wrapNavIndex(-12, 5), 3);
    });
  });

  // The 2D cursor that drives both the nav bar and the Home tile grid lives in
  // `gaze_grid_cursor_test.dart`; the single-row case there covers the old
  // nav-only D-pad behaviour.

  group('NavGazeScope (widget)', () {
    Widget host({
      required ProviderContainer container,
      required void Function(NavGazeState) onState,
      bool enabled = true,
    }) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: NavGazeScope(
            currentIndex: 0,
            itemCount: 5,
            enabled: enabled,
            onCommit: (_) {},
            camerasLoader: () async => const <CameraDescription>[],
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) {
              onState(gaze);
              return const Scaffold(body: Text('shell-body'));
            },
          ),
        ),
      );
    }

    testWidgets('inert when Gaze Control is disabled', (tester) async {
      final container = ProviderContainer(overrides: [
        gazeSettingsProvider.overrideWith(() => _FixedSettings(
              const GazeSettings(), // disabled
            )),
      ]);
      addTearDown(container.dispose);

      late NavGazeState last;
      await tester.pumpWidget(host(container: container, onState: (s) => last = s));
      await tester.pump();
      await tester.pump();

      expect(find.text('shell-body'), findsOneWidget);
      expect(last.active, isFalse);
      expect(last.targetIndex, isNull);
    });

    testWidgets('activates when enabled, but stays not-ready with no camera',
        (tester) async {
      final container = ProviderContainer(overrides: [
        gazeSettingsProvider.overrideWith(() => _FixedSettings(
              const GazeSettings(enabled: true),
            )),
      ]);
      addTearDown(container.dispose);

      late NavGazeState last;
      await tester.pumpWidget(host(container: container, onState: (s) => last = s));
      await tester.pump(); // run the post-frame evaluate → start controller
      await tester.pump(); // let the no-camera result settle

      expect(last.active, isTrue);
      expect(last.ready, isFalse); // no front camera in the test harness
      expect(last.targetIndex, 0);

      // Unmount cleanly (no pending timers / camera handles).
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('yields the camera while another surface owns it',
        (tester) async {
      final container = ProviderContainer(overrides: [
        gazeSettingsProvider.overrideWith(() => _FixedSettings(
              const GazeSettings(enabled: true),
            )),
      ]);
      addTearDown(container.dispose);

      late NavGazeState last;
      await tester.pumpWidget(host(container: container, onState: (s) => last = s));
      await tester.pump();
      await tester.pump();
      expect(last.active, isTrue);

      // A full-screen camera surface (e.g. a GazeScope activity) is pushed on
      // top → the shell nav-gaze must stand its camera down.
      gazeCameraOwners.acquire();
      await tester.pump(); // post-frame re-evaluate
      await tester.pump();
      expect(last.active, isFalse);

      // …and re-acquire it when that surface is dismissed.
      gazeCameraOwners.release();
      await tester.pump();
      await tester.pump();
      expect(last.active, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('disabled route gate (immersive) keeps it inert',
        (tester) async {
      final container = ProviderContainer(overrides: [
        gazeSettingsProvider.overrideWith(() => _FixedSettings(
              const GazeSettings(enabled: true),
            )),
      ]);
      addTearDown(container.dispose);

      late NavGazeState last;
      await tester.pumpWidget(
        host(container: container, onState: (s) => last = s, enabled: false),
      );
      await tester.pump();
      await tester.pump();

      expect(last.active, isFalse);
    });

    testWidgets('extends the D-pad over a published grid on a non-Home tab',
        (tester) async {
      // A hub other than Home (index 2) publishes a 2×2 tile grid. The gate is
      // no longer Home-only, so the cursor must reach those tiles.
      gazeHomeGrid.publishGrid([
        [
          GazeTileCell(label: 'a', onActivate: () {}),
          GazeTileCell(label: 'b', onActivate: () {}),
        ],
        [
          GazeTileCell(label: 'c', onActivate: () {}),
          GazeTileCell(label: 'd', onActivate: () {}),
        ],
      ]);
      addTearDown(gazeHomeGrid.clearGrid);

      final container = ProviderContainer(overrides: [
        gazeSettingsProvider.overrideWith(() => _FixedSettings(
              const GazeSettings(enabled: true),
            )),
      ]);
      addTearDown(container.dispose);

      late NavGazeState last;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: NavGazeScope(
              currentIndex: 2,
              itemCount: 5,
              onCommit: (_) {},
              camerasLoader: () async => const <CameraDescription>[],
              detectorFactory: _FakeDetector.new,
              builder: (context, gaze) {
                last = gaze;
                return const Scaffold(body: Text('shell-body'));
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(last.active, isTrue);
      expect(last.featureTilesActive, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
