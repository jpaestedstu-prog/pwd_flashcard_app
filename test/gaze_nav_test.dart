import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show AppSettings;
import 'package:pwdpwdpwd/features/gaze_control/logic/nav_gaze_cursor.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_camera_owners.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_home_grid.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/nav_gaze_scope.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/voice_control_mixin.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show SettingsNotifier, settingsProvider;

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

/// Default [AppSettings] without touching Hive (the haptic service reads it
/// when a voice command moves the cursor).
class _StubAppSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
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

    // The Guest Player shell has no bottom nav: it passes itemCount 0, so the
    // scope must run without a nav row and drive only the published grid.
    Widget guestHost({
      required ProviderContainer container,
      required void Function(NavGazeState) onState,
    }) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: NavGazeScope(
            currentIndex: 0,
            itemCount: 0,
            onCommit: (_) => fail('nav commit must never fire with no tabs'),
            camerasLoader: () async => const <CameraDescription>[],
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) {
              onState(gaze);
              return const Scaffold(body: Text('guest-body'));
            },
          ),
        ),
      );
    }

    testWidgets('guest mode (itemCount 0) runs safely with no grid',
        (tester) async {
      final container = ProviderContainer(overrides: [
        gazeSettingsProvider.overrideWith(() => _FixedSettings(
              const GazeSettings(enabled: true),
            )),
      ]);
      addTearDown(container.dispose);

      late NavGazeState last;
      await tester.pumpWidget(
          guestHost(container: container, onState: (s) => last = s));
      await tester.pump();
      await tester.pump();

      expect(last.active, isTrue);
      expect(last.featureTilesActive, isFalse);
      // No grid published → nothing focused, no crash.
      expect(gazeHomeGrid.focusRow, isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('guest mode focuses the first row of a published grid',
        (tester) async {
      // The guest home publishes its action buttons as 1-col rows.
      gazeHomeGrid.publishGrid([
        [GazeTileCell(label: 'Start Learning', onActivate: () {})],
        [GazeTileCell(label: 'Browse flashcards', onActivate: () {})],
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
          guestHost(container: container, onState: (s) => last = s));
      await tester.pump();
      await tester.pump();

      expect(last.active, isTrue);
      expect(last.featureTilesActive, isTrue);
      // With no nav row the cursor starts on the top button, and the focus is
      // published so the guest home can draw its ring there.
      expect(gazeHomeGrid.focusRow, 0);
      expect(gazeHomeGrid.focusCol, 0);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('NavGazeScope voice commands', () {
    // Drives the scope exactly as the speech recogniser would: each spoken
    // phrase lands in [VoiceControlMixin.onVoiceCommand]. Movement words must
    // move the same cursor the head D-pad moves; "select" must commit.
    testWidgets('movement + select drive the D-pad cursor over tiles and tabs',
        (tester) async {
      final opened = <String>[];
      GazeTileCell cell(String label) =>
          GazeTileCell(label: label, onActivate: () => opened.add(label));
      gazeHomeGrid.publishGrid([
        [cell('Fruits'), cell('Animals')],
        [cell('Colors'), cell('Shapes')],
      ]);
      addTearDown(gazeHomeGrid.clearGrid);

      final container = ProviderContainer(overrides: [
        gazeSettingsProvider.overrideWith(() => _FixedSettings(
              const GazeSettings(
                enabled: true,
                navScope: GazeNavScope.bottomNavAndHomeTiles,
              ),
            )),
        settingsProvider.overrideWith(_StubAppSettings.new),
      ]);
      addTearDown(container.dispose);

      final committedTabs = <int>[];
      late NavGazeState last;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: NavGazeScope(
              currentIndex: 0,
              itemCount: 5,
              navLabels: const ['Home', 'Cards', 'Games', 'Stories', 'Progress'],
              onCommit: committedTabs.add,
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

      final voice =
          tester.state(find.byType(NavGazeScope)) as VoiceControlMixin;

      // Starts on the nav row (nothing focused up in the tiles).
      expect(gazeHomeGrid.focusRow, isNull);

      // "up" climbs from the nav row into the tile grid, like looking up.
      voice.onVoiceCommand('up');
      await tester.pump();
      expect(gazeHomeGrid.focusRow, 1);
      expect(gazeHomeGrid.focusCol, 0);

      voice.onVoiceCommand('up');
      await tester.pump();
      expect(gazeHomeGrid.focusRow, 0);

      // "right" moves within the row; "left" wraps back.
      voice.onVoiceCommand('right');
      await tester.pump();
      expect(gazeHomeGrid.focusCol, 1);

      // "select" opens the focused tile, like a blink.
      voice.onVoiceCommand('select');
      await tester.pump(const Duration(milliseconds: 200)); // haptic pattern
      expect(opened, ['Animals']);

      // "down" walks back towards the nav row.
      voice.onVoiceCommand('down');
      await tester.pump();
      expect(gazeHomeGrid.focusRow, 1);
      voice.onVoiceCommand('down');
      await tester.pump();
      expect(gazeHomeGrid.focusRow, isNull); // on the nav row again

      // On the nav row, "next" scrubs the tab highlight like looking right…
      voice.onVoiceCommand('next');
      await tester.pump();
      expect(last.targetIndex, 1);

      // …and a tab can still be opened by its name from anywhere.
      voice.onVoiceCommand('games');
      await tester.pump(const Duration(milliseconds: 200));
      expect(committedTabs, [2]);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('a tile label always beats a directional word it contains',
        (tester) async {
      final opened = <String>[];
      gazeHomeGrid.publishGrid([
        [
          GazeTileCell(label: 'Groups', onActivate: () => opened.add('Groups')),
          GazeTileCell(
              label: 'Countdown', onActivate: () => opened.add('Countdown')),
        ],
      ]);
      addTearDown(gazeHomeGrid.clearGrid);

      final container = ProviderContainer(overrides: [
        gazeSettingsProvider.overrideWith(() => _FixedSettings(
              const GazeSettings(
                enabled: true,
                navScope: GazeNavScope.bottomNavAndHomeTiles,
              ),
            )),
        settingsProvider.overrideWith(_StubAppSettings.new),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: NavGazeScope(
              currentIndex: 0,
              itemCount: 2,
              navLabels: const ['Home', 'Cards'],
              onCommit: (_) {},
              camerasLoader: () async => const <CameraDescription>[],
              detectorFactory: _FakeDetector.new,
              builder: (context, gaze) => const Scaffold(body: Text('body')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final voice =
          tester.state(find.byType(NavGazeScope)) as VoiceControlMixin;
      voice.onVoiceCommand('groups');
      voice.onVoiceCommand('countdown');
      await tester.pump(const Duration(milliseconds: 200));
      expect(opened, ['Groups', 'Countdown']);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
