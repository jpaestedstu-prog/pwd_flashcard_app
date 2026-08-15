import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show AppSettings;
import 'package:pwdpwdpwd/features/gaze_control/logic/gaze_focus_driver.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_camera_owners.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/nav_gaze_scope.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/voice_control_mixin.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show SettingsNotifier, settingsProvider;

/// The published-grid D-pad only reaches cells a screen registered, so every
/// dialog and every un-adopted pushed screen used to be a hands-free dead end —
/// including the Daily Reward dialog a learner meets right after login.
/// `NavGazeScope` now hands head + voice input to Flutter's own directional
/// focus traversal whenever a route covers the shell, which makes Material's
/// buttons (and a screen's back button) reachable with no per-screen wiring.

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

  group('GazeFocusDriver (pure)', () {
    testWidgets('moves focus between real controls and activates the focused one',
        (tester) async {
      final pressed = <String>[];
      final first = FocusNode(debugLabel: 'first');
      final second = FocusNode(debugLabel: 'second');
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ElevatedButton(
                focusNode: first,
                onPressed: () => pressed.add('first'),
                child: const Text('First'),
              ),
              ElevatedButton(
                focusNode: second,
                onPressed: () => pressed.add('second'),
                child: const Text('Second'),
              ),
            ],
          ),
        ),
      ));

      first.requestFocus();
      await tester.pump();
      expect(GazeFocusDriver.focused, first);
      expect(GazeFocusDriver.focusedRect, isNotNull);

      expect(GazeFocusDriver.move(TraversalDirection.down), isTrue);
      await tester.pump();
      expect(GazeFocusDriver.focused, second);

      expect(GazeFocusDriver.activate(), isTrue);
      await tester.pump();
      expect(pressed, ['second']);

      expect(GazeFocusDriver.move(TraversalDirection.up), isTrue);
      await tester.pump();
      expect(GazeFocusDriver.focused, first);
    });

    testWidgets('scrolls a below-the-fold control into view when focused',
        (tester) async {
      // Traversal will happily focus something under the fold. On a long pushed
      // screen that leaves the learner steering a control they cannot see —
      // with the ring off-screen too — which defeats the whole fallback.
      final first = FocusNode(debugLabel: 'first');
      final buried = FocusNode(debugLabel: 'buried');
      addTearDown(first.dispose);
      addTearDown(buried.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                ElevatedButton(
                  focusNode: first,
                  onPressed: () {},
                  child: const Text('First'),
                ),
                // Push the second button far below the viewport.
                const SizedBox(height: 2000),
                ElevatedButton(
                  focusNode: buried,
                  onPressed: () {},
                  child: const Text('Buried'),
                ),
              ],
            ),
          ),
        ),
      ));

      first.requestFocus();
      await tester.pump();
      expect(find.text('Buried').hitTestable(), findsNothing,
          reason: 'starts off-screen');

      expect(GazeFocusDriver.move(TraversalDirection.down), isTrue);
      await tester.pumpAndSettle();

      expect(buried.hasFocus, isTrue);
      expect(find.text('Buried').hitTestable(), findsOneWidget,
          reason: 'focusing it must bring it on screen');
    });

    testWidgets('reports no rect when nothing real is focused', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('no focusables'))),
      );
      await tester.pump();
      // A bare scope node has nothing to press.
      expect(GazeFocusDriver.activate(), isFalse);
    });
  });

  group('NavGazeScope falls back to traversal while covered', () {
    Widget host({
      required ProviderContainer container,
      required GlobalKey<NavigatorState> navKey,
      required void Function(NavGazeState) onState,
    }) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navKey,
          home: NavGazeScope(
            currentIndex: 0,
            itemCount: 5,
            navLabels: const ['Home', 'Cards', 'Games', 'Stories', 'Progress'],
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

    testWidgets('spoken movement + select drive a dialog\'s buttons',
        (tester) async {
      final container = ProviderContainer(overrides: [
        gazeSettingsProvider.overrideWith(
            () => _FixedSettings(const GazeSettings(enabled: true))),
        settingsProvider.overrideWith(_StubAppSettings.new),
      ]);
      addTearDown(container.dispose);
      final navKey = GlobalKey<NavigatorState>();
      late NavGazeState last;
      final pressed = <String>[];

      await tester.pumpWidget(
          host(container: container, navKey: navKey, onState: (s) => last = s));
      await tester.pump();
      await tester.pump();
      expect(last.active, isTrue);

      // The Daily Reward dialog: two actions, touch-only before this change.
      final laterNode = FocusNode(debugLabel: 'later');
      final collectNode = FocusNode(debugLabel: 'collect');
      addTearDown(laterNode.dispose);
      addTearDown(collectNode.dispose);
      showDialog<void>(
        context: navKey.currentContext!,
        builder: (_) => AlertDialog(
          content: const Text('Daily Reward!'),
          actions: [
            TextButton(
              focusNode: laterNode,
              onPressed: () => pressed.add('later'),
              child: const Text('Later'),
            ),
            TextButton(
              focusNode: collectNode,
              onPressed: () => pressed.add('collect'),
              child: const Text('Collect'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Daily Reward!'), findsOneWidget);

      final voice =
          tester.state(find.byType(NavGazeScope)) as VoiceControlMixin;

      // Land on something real, then walk to the button we want.
      laterNode.requestFocus();
      await tester.pump();
      voice.onVoiceCommand('right');
      await tester.pump();
      expect(collectNode.hasFocus, isTrue);

      // "select" presses it — the learner has dismissed the dialog hands-free.
      voice.onVoiceCommand('select');
      await tester.pump(const Duration(milliseconds: 200));
      expect(pressed, ['collect']);

      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('an immersive activity gets traversal instead of a dead end',
        (tester) async {
      // Immersive routes hide the nav bar (`enabled: false`). The shell used to
      // tear its camera down there, so a screen with no gaze scope of its own —
      // Drag & Drop, Tracing, Create-a-Card — became a room with no door: no
      // gaze, and no way back. The grid is genuinely gone, but the screen's
      // controls (starting with its app-bar back button) are still there.
      final container = ProviderContainer(overrides: [
        gazeSettingsProvider.overrideWith(
            () => _FixedSettings(const GazeSettings(enabled: true))),
        settingsProvider.overrideWith(_StubAppSettings.new),
      ]);
      addTearDown(container.dispose);
      late NavGazeState last;
      var backs = 0;
      final backNode = FocusNode(debugLabel: 'back');
      addTearDown(backNode.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: NavGazeScope(
            currentIndex: 0,
            itemCount: 5,
            enabled: false, // immersive: nav bar hidden
            onCommit: (_) {},
            camerasLoader: () async => const <CameraDescription>[],
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) {
              last = gaze;
              return Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    focusNode: backNode,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => backs++,
                  ),
                ),
                body: const Text('immersive-activity'),
              );
            },
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();

      // No tab ring — the bar is hidden, so claiming one would be a lie.
      expect(last.active, isFalse);
      expect(last.targetIndex, isNull);

      // …but the head still drives the screen, and Back is reachable.
      backNode.requestFocus();
      await tester.pump();
      final voice =
          tester.state(find.byType(NavGazeScope)) as VoiceControlMixin;
      voice.onVoiceCommand('select');
      await tester.pump(const Duration(milliseconds: 200));
      expect(backs, 1, reason: 'an immersive screen must never trap a learner');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('the tab grid is untouched while the dialog is up',
        (tester) async {
      final container = ProviderContainer(overrides: [
        gazeSettingsProvider.overrideWith(
            () => _FixedSettings(const GazeSettings(enabled: true))),
        settingsProvider.overrideWith(_StubAppSettings.new),
      ]);
      addTearDown(container.dispose);
      final navKey = GlobalKey<NavigatorState>();
      late NavGazeState last;
      var commits = 0;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navKey,
          home: NavGazeScope(
            currentIndex: 0,
            itemCount: 5,
            navLabels: const ['Home', 'Cards', 'Games', 'Stories', 'Progress'],
            onCommit: (_) => commits++,
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

      showDialog<void>(
        context: navKey.currentContext!,
        builder: (_) => AlertDialog(
          content: const Text('a-dialog'),
          actions: [TextButton(onPressed: () {}, child: const Text('OK'))],
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));

      final voice =
          tester.state(find.byType(NavGazeScope)) as VoiceControlMixin;

      // Naming a tab must not switch tabs behind the dialog, and the tab ring
      // stays hidden — the grid belongs to the uncovered shell only.
      voice.onVoiceCommand('games');
      await tester.pump(const Duration(milliseconds: 200));
      expect(commits, 0);
      expect(last.targetIndex, isNull);
      expect(last.active, isFalse);

      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
