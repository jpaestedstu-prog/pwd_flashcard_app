import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show AppSettings;
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_camera_owners.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_dpad_scope.dart';
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
  // The camera-owner gate is an app-wide singleton; keep tests isolated.
  setUp(() {
    while (gazeCameraOwners.isBusy) {
      gazeCameraOwners.release();
    }
  });

  // A single action row (like the flashcard viewer's bottom bar): a disabled
  // Previous, then Flip and Next. The head-move → focus → commit pipeline runs
  // off camera frames (covered by the pure `GazeGridCursor` tests); these widget
  // tests cover the scope's wiring + the *foreground* single-camera lifecycle.
  List<List<GazeDpadCell>> rows() => [
        [
          GazeDpadCell(label: 'prev', enabled: false, onActivate: () {}),
          GazeDpadCell(label: 'flip', onActivate: () {}),
          GazeDpadCell(label: 'next', onActivate: () {}),
        ],
      ];

  Widget host({
    required ProviderContainer container,
    required void Function(GazeDpadState) onState,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: GazeDpadScope(
          rows: rows(),
          camerasLoader: () async => const <CameraDescription>[],
          detectorFactory: _FakeDetector.new,
          builder: (context, gaze) {
            onState(gaze);
            return const Scaffold(body: Text('viewer-body'));
          },
        ),
      ),
    );
  }

  testWidgets('inert and camera-free when Gaze Control is disabled',
      (tester) async {
    final container = ProviderContainer(overrides: [
      gazeSettingsProvider.overrideWith(() => _FixedSettings(
            const GazeSettings(), // disabled
          )),
    ]);
    addTearDown(container.dispose);

    late GazeDpadState last;
    await tester.pumpWidget(host(container: container, onState: (s) => last = s));
    await tester.pump();

    expect(find.text('viewer-body'), findsOneWidget);
    expect(last.active, isFalse);
    expect(last.focusRow, isNull);
    // Opened no camera, so the shell's background nav-gaze is undisturbed.
    expect(gazeCameraOwners.isBusy, isFalse);
  });

  testWidgets('activates, owns the camera, and starts focus at (0,0)',
      (tester) async {
    final container = ProviderContainer(overrides: [
      gazeSettingsProvider.overrideWith(() => _FixedSettings(
            const GazeSettings(enabled: true),
          )),
    ]);
    addTearDown(container.dispose);

    late GazeDpadState last;
    await tester.pumpWidget(host(container: container, onState: (s) => last = s));
    await tester.pump(); // start controller
    await tester.pump(); // let the no-camera result settle

    expect(last.active, isTrue);
    expect(last.ready, isFalse); // no front camera in the harness
    expect(last.isFocused(0, 0), isTrue);
    // Foreground owner: claims the single camera so the shell nav-gaze yields.
    expect(gazeCameraOwners.isBusy, isTrue);

    // …and releases it again on dispose (no leaked owner count / camera handle).
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(gazeCameraOwners.isBusy, isFalse);
  });

  testWidgets('voice movement + select drive the same cursor as the head D-pad',
      (tester) async {
    final fired = <String>[];
    List<List<GazeDpadCell>> liveRows() => [
          [
            GazeDpadCell(
                label: 'Previous',
                enabled: false,
                onActivate: () => fired.add('Previous')),
            GazeDpadCell(label: 'Flip', onActivate: () => fired.add('Flip')),
            GazeDpadCell(label: 'Next', onActivate: () => fired.add('Next')),
          ],
        ];

    final container = ProviderContainer(overrides: [
      gazeSettingsProvider.overrideWith(() => _FixedSettings(
            const GazeSettings(enabled: true),
          )),
      settingsProvider.overrideWith(_StubAppSettings.new),
    ]);
    addTearDown(container.dispose);

    late GazeDpadState last;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GazeDpadScope(
            rows: liveRows(),
            camerasLoader: () async => const <CameraDescription>[],
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) {
              last = gaze;
              return const Scaffold(body: Text('viewer-body'));
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(last.isFocused(0, 0), isTrue);

    final voice =
        tester.state(find.byType(GazeDpadScope)) as VoiceControlMixin;

    // "right" moves the highlight exactly like looking right.
    voice.onVoiceCommand('right');
    await tester.pump();
    expect(last.isFocused(0, 1), isTrue);

    // "select" commits the focused control, like a blink.
    voice.onVoiceCommand('select');
    await tester.pump(const Duration(milliseconds: 200)); // haptic pattern
    expect(fired, ['Flip']);

    // "next" opens the button actually labelled Next, wherever the cursor is.
    voice.onVoiceCommand('next');
    await tester.pump(const Duration(milliseconds: 200));
    expect(fired, ['Flip', 'Next']);

    // "left" moves back; "select" on the disabled Previous does nothing.
    voice.onVoiceCommand('left');
    await tester.pump();
    expect(last.isFocused(0, 0), isTrue);
    voice.onVoiceCommand('select');
    await tester.pump(const Duration(milliseconds: 200));
    expect(fired, ['Flip', 'Next']);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
