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

/// `GazeDpadScope.onExit` is the way out of an immersive screen. The flashcard
/// viewer hides the nav bar and stands the shell's D-pad down, so before this
/// its action bar (Previous · FSL · Show Me · Examples · Flip · Next) was the
/// learner's whole world — a head-only learner who opened a deck could not
/// leave it without a caregiver.

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

void main() {
  setUp(() {
    while (gazeCameraOwners.isBusy) {
      gazeCameraOwners.release();
    }
  });

  /// A one-row action bar, like the viewer's.
  ({Widget widget, List<String> fired, ProviderContainer container}) harness({
    required void Function(GazeDpadState) onState,
    required bool withExit,
  }) {
    final fired = <String>[];
    final container = ProviderContainer(overrides: [
      gazeSettingsProvider
          .overrideWith(() => _FixedSettings(const GazeSettings(enabled: true))),
      settingsProvider.overrideWith(_StubAppSettings.new),
    ]);
    return (
      fired: fired,
      container: container,
      widget: UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GazeDpadScope(
            rows: [
              [
                GazeDpadCell(label: 'Flip', onActivate: () => fired.add('Flip')),
                GazeDpadCell(label: 'Next', onActivate: () => fired.add('Next')),
              ],
            ],
            onExit: withExit ? () => fired.add('EXIT') : null,
            camerasLoader: () async => const <CameraDescription>[],
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) {
              onState(gaze);
              return const Scaffold(body: Text('viewer-body'));
            },
          ),
        ),
      ),
    );
  }

  testWidgets('without onExit the screen keeps its old single-row grid',
      (tester) async {
    late GazeDpadState last;
    final h = harness(onState: (s) => last = s, withExit: false);
    addTearDown(h.container.dispose);
    await tester.pumpWidget(h.widget);
    await tester.pump();
    await tester.pump();

    expect(last.isFocused(0, 0), isTrue);
    expect(last.exitFocused, isFalse);
    expect(find.text('Back'), findsNothing);

    // Vertical movement is a no-op on a single-row grid, as before.
    final voice = tester.state(find.byType(GazeDpadScope)) as VoiceControlMixin;
    voice.onVoiceCommand('up');
    await tester.pump();
    expect(last.isFocused(0, 0), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('look up reaches the Back pill and a blink leaves the screen',
      (tester) async {
    late GazeDpadState last;
    final h = harness(onState: (s) => last = s, withExit: true);
    addTearDown(h.container.dispose);
    await tester.pumpWidget(h.widget);
    await tester.pump();
    await tester.pump();

    // The learner still starts on their own first control, not on Back — the
    // exit is somewhere to go, never where you land.
    expect(last.isFocused(0, 0), isTrue);
    expect(last.exitFocused, isFalse);
    expect(find.text('Back'), findsOneWidget);

    final voice = tester.state(find.byType(GazeDpadScope)) as VoiceControlMixin;

    // ▲ from the action bar reaches the exit row.
    voice.onVoiceCommand('up');
    await tester.pump();
    expect(last.exitFocused, isTrue);
    // While up there the screen sees no focused cell of its own, so it draws
    // no ring on a control that a blink would not activate.
    expect(last.focusRow, isNull);
    expect(last.isFocused(0, 0), isFalse);

    // A blink (here: "select") takes the exit.
    voice.onVoiceCommand('select');
    await tester.pump(const Duration(milliseconds: 200));
    expect(h.fired, ['EXIT']);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the screen\'s own rows keep their original indices',
      (tester) async {
    late GazeDpadState last;
    final h = harness(onState: (s) => last = s, withExit: true);
    addTearDown(h.container.dispose);
    await tester.pumpWidget(h.widget);
    await tester.pump();
    await tester.pump();

    final voice = tester.state(find.byType(GazeDpadScope)) as VoiceControlMixin;

    // Adopting onExit must not renumber the screen's cells: row 0 is still the
    // action bar as far as the builder is concerned.
    voice.onVoiceCommand('right');
    await tester.pump();
    expect(last.isFocused(0, 1), isTrue);
    voice.onVoiceCommand('select');
    await tester.pump(const Duration(milliseconds: 200));
    expect(h.fired, ['Next']);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a spoken "back" leaves without moving the cursor first',
      (tester) async {
    late GazeDpadState last;
    final h = harness(onState: (s) => last = s, withExit: true);
    addTearDown(h.container.dispose);
    await tester.pumpWidget(h.widget);
    await tester.pump();
    await tester.pump();
    expect(last.isFocused(0, 0), isTrue);

    final voice = tester.state(find.byType(GazeDpadScope)) as VoiceControlMixin;
    voice.onVoiceCommand('back');
    await tester.pump(const Duration(milliseconds: 200));
    expect(h.fired, ['EXIT']);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the exit pill is not drawn when Gaze Control is off',
      (tester) async {
    final container = ProviderContainer(overrides: [
      gazeSettingsProvider
          .overrideWith(() => _FixedSettings(const GazeSettings())),
      settingsProvider.overrideWith(_StubAppSettings.new),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: GazeDpadScope(
          rows: [
            [GazeDpadCell(label: 'Flip', onActivate: () {})],
          ],
          onExit: () {},
          camerasLoader: () async => const <CameraDescription>[],
          detectorFactory: _FakeDetector.new,
          builder: (context, gaze) => const Scaffold(body: Text('viewer-body')),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('viewer-body'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
    expect(gazeCameraOwners.isBusy, isFalse);
  });
}
