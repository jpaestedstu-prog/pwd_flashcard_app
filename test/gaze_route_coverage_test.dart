import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show AppSettings;
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_action.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_camera_owners.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_dpad_scope.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_scope.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/nav_gaze_scope.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/voice_control_mixin.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show SettingsNotifier, settingsProvider;

/// A gaze scope drives *its* screen's controls. When a dialog or bottom sheet
/// covers that screen those controls are neither visible nor reachable, so the
/// scope must (a) stop firing them and (b) stop drawing an affordance that says
/// it still can. `NavGazeScope` always gated its input; `GazeScope` and
/// `GazeDpadScope` did not — the flashcard viewer's own "Show Me" / "Examples"
/// sheets left the hidden action bar live underneath.

class _FakeDetector implements GazeDetector {
  @override
  Future<FaceSignal> detect(InputImage image) async => FaceSignal.absent;
  @override
  Future<void> close() async {}
}

class _FixedSettings extends GazeSettingsNotifier {
  _FixedSettings(this._value);
  final GazeSettings _value;
  @override
  GazeSettings build() => _value;
}

class _StubAppSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

ProviderContainer _gazeOn() => ProviderContainer(overrides: [
      gazeSettingsProvider
          .overrideWith(() => _FixedSettings(const GazeSettings(enabled: true))),
      settingsProvider.overrideWith(_StubAppSettings.new),
    ]);

/// Long enough for [GazeRouteGuard]'s 400 ms coverage ticker to notice.
const _pastCoverageTick = Duration(milliseconds: 600);

void main() {
  setUp(() {
    while (gazeCameraOwners.isBusy) {
      gazeCameraOwners.release();
    }
  });

  group('GazeDpadScope under a covering route', () {
    testWidgets('spoken commands stop activating the hidden action bar',
        (tester) async {
      final container = _gazeOn();
      addTearDown(container.dispose);
      var flips = 0;
      final navKey = GlobalKey<NavigatorState>();
      late GazeDpadState last;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navKey,
          home: GazeDpadScope(
            rows: [
              [
                GazeDpadCell(label: 'flip', onActivate: () => flips++),
                GazeDpadCell(label: 'next', onActivate: () {}),
              ],
            ],
            camerasLoader: () async => const <CameraDescription>[],
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) {
              last = gaze;
              return const Scaffold(body: Text('viewer-body'));
            },
          ),
        ),
      ));
      await tester.pump();

      final voice =
          tester.state(find.byType(GazeDpadScope)) as VoiceControlMixin;

      // Uncovered: the label fires its control, as it always has.
      voice.onVoiceCommand('flip');
      await tester.pump();
      expect(flips, 1);
      expect(last.active, isTrue);

      // The viewer's own "Show Me" sheet goes up over the action bar.
      showDialog<void>(
        context: navKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('show-me-sheet')),
      );
      await tester.pumpAndSettle();
      expect(find.text('show-me-sheet'), findsOneWidget);

      // Same phrase, now inert — the button it names is behind the sheet.
      voice.onVoiceCommand('flip');
      await tester.pump();
      expect(flips, 1, reason: 'covered controls must not fire');

      // …and the ring stops claiming the D-pad is live.
      await tester.pump(_pastCoverageTick);
      expect(last.active, isFalse);
      expect(last.focusRow, isNull);

      // Dismissing the sheet hands control straight back.
      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pump(_pastCoverageTick);
      expect(last.active, isTrue);
      voice.onVoiceCommand('flip');
      await tester.pump();
      expect(flips, 2);
    });
  });

  group('GazeScope under a covering route', () {
    testWidgets('spoken commands stop firing the screen\'s edge actions',
        (tester) async {
      final container = _gazeOn();
      addTearDown(container.dispose);
      var speaks = 0;
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navKey,
          home: GazeScope(
            actions: [
              GazeAction(
                zone: GazeZone.up,
                label: 'Speak',
                icon: Icons.volume_up,
                color: Colors.blue,
                onSelect: () => speaks++,
              ),
            ],
            camerasLoader: () async => const <CameraDescription>[],
            detectorFactory: _FakeDetector.new,
            child: const Scaffold(body: Text('board-body')),
          ),
        ),
      ));
      await tester.pump();

      final voice = tester.state(find.byType(GazeScope)) as VoiceControlMixin;
      voice.onVoiceCommand('speak');
      await tester.pump();
      expect(speaks, 1);

      showDialog<void>(
        context: navKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('a-dialog')),
      );
      await tester.pumpAndSettle();

      voice.onVoiceCommand('speak');
      await tester.pump();
      expect(speaks, 1, reason: 'covered actions must not fire');

      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      voice.onVoiceCommand('speak');
      await tester.pump();
      expect(speaks, 2);
    });
  });

  group('NavGazeScope under a covering route', () {
    testWidgets('drops the tab ring and restores it on dismiss',
        (tester) async {
      final container = _gazeOn();
      addTearDown(container.dispose);
      final navKey = GlobalKey<NavigatorState>();
      late NavGazeState last;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navKey,
          home: NavGazeScope(
            currentIndex: 0,
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
      ));
      await tester.pump();
      await tester.pump();
      expect(last.active, isTrue);
      expect(last.targetIndex, 0);

      showDialog<void>(
        context: navKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('daily-reward')),
      );
      await tester.pumpAndSettle();
      await tester.pump(_pastCoverageTick);

      // The shell already ignored head input here; now it also stops drawing
      // a highlight that implies otherwise.
      expect(last.active, isFalse);
      expect(last.targetIndex, isNull);

      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pump(_pastCoverageTick);
      expect(last.active, isTrue);
      expect(last.targetIndex, 0);
    });
  });
}
