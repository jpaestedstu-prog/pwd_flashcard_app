import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show AppSettings;
import 'package:pwdpwdpwd/features/gaze_control/controllers/gaze_controller.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_action.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_camera_owners.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_home_grid.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/screens/gaze_control_screen.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_dpad_scope.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_modal_region.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_scope.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_traversal_scope.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/nav_gaze_scope.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/shell_modal_observer.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/voice_control_mixin.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show SettingsNotifier, settingsProvider;

/// Every gaze scope now does two things it used to leave to the navigation
/// shell alone:
///
///  * **It hands over to focus traversal when something covers it** — a sheet
///    the flashcard viewer opened ("Show Me", "Examples", the FSL clip), a
///    dialog, or an in-screen modal such as a game's pause card. Before, the
///    scope rightly stopped driving its hidden controls and nothing took
///    over, so a hands-free learner could open those sheets and never close
///    them.
///  * **It scans.** "Scanning mode" was only implemented for a game's four
///    edge targets, so a blink-only learner could not use the hubs, the tab
///    bar, the viewer, the profile picker or a dialog at all.

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

ProviderContainer _container(GazeSettings settings) => ProviderContainer(
  overrides: [
    gazeSettingsProvider.overrideWith(() => _FixedSettings(settings)),
    settingsProvider.overrideWith(_StubAppSettings.new),
  ],
);

/// The newest live camera pipeline — what the learner's head and eyes reach.
GazeController get _camera => GazeController.debugLive.last;

/// Long enough for the 400 ms coverage ticker to notice a route.
const _pastCoverageTick = Duration(milliseconds: 600);

Future<List<CameraDescription>> _noCameras() async => const [];

/// A two-button dialog, as the viewer's sheets and the Daily Reward are.
Future<void> _openDialog(
  GlobalKey<NavigatorState> navKey,
  List<String> pressed,
) {
  return showDialog<void>(
    context: navKey.currentContext!,
    builder: (ctx) => AlertDialog(
      content: const Text('a-sheet'),
      actions: [
        TextButton(
          onPressed: () => pressed.add('stay'),
          child: const Text('Stay'),
        ),
        TextButton(
          onPressed: () {
            pressed.add('close');
            Navigator.of(ctx).pop();
          },
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void main() {
  setUp(() {
    while (gazeCameraOwners.isBusy) {
      gazeCameraOwners.release();
    }
    gazeHomeGrid.clearGrid();
  });

  group('a covered foreground scope drives what covers it', () {
    testWidgets('the viewer\'s own sheet can be operated and closed by gaze',
        (tester) async {
      final container = _container(const GazeSettings(enabled: true));
      addTearDown(container.dispose);
      final navKey = GlobalKey<NavigatorState>();
      final pressed = <String>[];
      var flips = 0;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navKey,
          home: GazeDpadScope(
            rows: [
              [GazeDpadCell(label: 'Flip', onActivate: () => flips++)],
            ],
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) =>
                const Scaffold(body: Text('viewer-body')),
          ),
        ),
      ));
      await tester.pump();

      _openDialog(navKey, pressed);
      await tester.pumpAndSettle();
      await tester.pump(_pastCoverageTick);

      // A blink first lands focus on the sheet's first control rather than
      // pressing the hidden action bar…
      expect(_camera.debugBlink(), isTrue);
      await tester.pump();
      expect(flips, 0, reason: 'the hidden action bar must never fire');
      // …a head move walks to the next one, and a blink presses it.
      _camera.debugSelect(GazeZone.right);
      await tester.pump();
      _camera.debugBlink();
      await tester.pumpAndSettle();
      expect(pressed, ['close']);
      expect(find.text('a-sheet'), findsNothing, reason: 'closed hands-free');

      // Uncovered again, the action bar is back under the learner's control.
      await tester.pump(_pastCoverageTick);
      _camera.debugBlink();
      await tester.pump();
      expect(flips, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('spoken "go back" closes a sheet over the viewer',
        (tester) async {
      final container = _container(const GazeSettings(enabled: true));
      addTearDown(container.dispose);
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navKey,
          home: GazeDpadScope(
            rows: [
              [GazeDpadCell(label: 'Flip', onActivate: () {})],
            ],
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) =>
                const Scaffold(body: Text('viewer-body')),
          ),
        ),
      ));
      await tester.pump();
      _openDialog(navKey, []);
      await tester.pumpAndSettle();

      final voice =
          tester.state(find.byType(GazeDpadScope)) as VoiceControlMixin;
      voice.onVoiceCommand('go back');
      await tester.pumpAndSettle();
      expect(find.text('a-sheet'), findsNothing);
      expect(find.text('viewer-body'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('a covering dialog no longer rebuilds the screen beneath',
        (tester) async {
      // The scope used to return its bare content while covered and a Stack
      // otherwise, so every sheet the viewer opened re-created the viewer.
      final container = _container(const GazeSettings(enabled: true));
      addTearDown(container.dispose);
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navKey,
          home: GazeDpadScope(
            rows: [
              [GazeDpadCell(label: 'Flip', onActivate: () {})],
            ],
            onExit: () {},
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) => const Scaffold(body: _Counter()),
          ),
        ),
      ));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bump')));
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget);

      _openDialog(navKey, []);
      await tester.pumpAndSettle();
      await tester.pump(_pastCoverageTick);
      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pump(_pastCoverageTick);

      expect(find.text('count 1'), findsOneWidget,
          reason: 'the screen\'s own state survived the sheet');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('every covering surface has a way out', () {
    /// A sheet like the child accessibility sheet: one switch, no close
    /// button — a touch user taps the dimmed area to leave.
    Future<void> openCloselessSheet(BuildContext context) {
      return showModalBottomSheet<void>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setState) {
            var on = false;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: SwitchListTile(
                title: const Text('closeless-sheet'),
                value: on,
                onChanged: (v) => setState(() => on = v),
              ),
            );
          },
        ),
      );
    }

    Widget shell(ProviderContainer container, GlobalKey<NavigatorState> key,
        {GlobalKey<NavigatorState>? innerKey}) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: key,
          home: NavGazeScope(
            currentIndex: 0,
            itemCount: 5,
            onCommit: (_) {},
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) => innerKey == null
                ? const Scaffold(body: Text('hub'))
                // The navigation shell's own navigator, as go_router builds it.
                : Navigator(
                    key: innerKey,
                    observers: [shellModalObserver],
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('hub')),
                    ),
                  ),
          ),
        ),
      );
    }

    testWidgets('look up from the first control, blink: the sheet closes',
        (tester) async {
      final container = _container(const GazeSettings(enabled: true));
      addTearDown(container.dispose);
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(shell(container, navKey));
      await tester.pump();
      await tester.pump();

      openCloselessSheet(navKey.currentContext!);
      await tester.pumpAndSettle();
      await tester.pump(_pastCoverageTick);
      expect(find.text('closeless-sheet'), findsOneWidget);

      _camera.debugSelect(GazeZone.down); // onto the switch
      await tester.pump();
      _camera.debugSelect(GazeZone.up); // past the first control: Back
      await tester.pump();
      _camera.debugBlink();
      await tester.pumpAndSettle();
      expect(find.text('closeless-sheet'), findsNothing,
          reason: 'a sheet with no close button is still escapable');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('"go back" closes a sheet on the shell\'s own navigator',
        (tester) async {
      final container = _container(const GazeSettings(enabled: true));
      addTearDown(container.dispose);
      final navKey = GlobalKey<NavigatorState>();
      final innerKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(shell(container, navKey, innerKey: innerKey));
      await tester.pump();
      await tester.pump();

      addTearDown(shellModalObserver.reset);
      // A hub's sheet goes on the inner navigator, which the scope's own
      // `Navigator.of` cannot reach — popping that one did nothing.
      openCloselessSheet(innerKey.currentContext!);
      await tester.pumpAndSettle();
      expect(find.text('closeless-sheet'), findsOneWidget);
      _camera.debugBlink(); // focus lands in the sheet
      await tester.pump();

      final voice =
          tester.state(find.byType(NavGazeScope)) as VoiceControlMixin;
      voice.onVoiceCommand('go back');
      await tester.pumpAndSettle();
      expect(find.text('closeless-sheet'), findsNothing);
      expect(find.text('hub'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('a sheet with nothing to press (Show Me) still closes',
        (tester) async {
      // The viewer's Show Me sheet is a looping clip and nothing else. Flutter
      // reports a directional move on such a surface as handled (it just
      // re-focuses the bare scope), so before this every look and blink was
      // swallowed and the learner could not leave — found on the tablet for
      // the Visual and Cognitive learners, whose viewer offers Show Me.
      final container = _container(const GazeSettings(enabled: true));
      addTearDown(container.dispose);
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navKey,
          home: GazeDpadScope(
            rows: [
              [GazeDpadCell(label: 'Show Me', onActivate: () {})],
            ],
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) => const Scaffold(body: Text('viewer')),
          ),
        ),
      ));
      await tester.pump();

      Future<void> openClipSheet() async {
        showModalBottomSheet<void>(
          context: navKey.currentContext!,
          builder: (_) => GestureDetector(
            onTap: () {},
            child: const SizedBox(height: 300, child: Text('clip-only')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(_pastCoverageTick);
        expect(find.text('clip-only'), findsOneWidget);
      }

      // A head move lights Back (there is nothing else), a blink takes it.
      await openClipSheet();
      _camera.debugSelect(GazeZone.up);
      await tester.pump();
      _camera.debugBlink();
      await tester.pumpAndSettle();
      expect(find.text('clip-only'), findsNothing);

      // Blinks alone: the first lights Back, the second takes it.
      await tester.pump(_pastCoverageTick);
      await openClipSheet();
      _camera.debugBlink();
      await tester.pump();
      expect(find.text('clip-only'), findsOneWidget);
      _camera.debugBlink();
      await tester.pumpAndSettle();
      expect(find.text('clip-only'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('scanning visits Back after the last control', (tester) async {
      final container = _container(
        const GazeSettings(enabled: true, scanMode: true, scanStepMs: 3000),
      );
      addTearDown(container.dispose);
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(shell(container, navKey));
      await tester.pump();
      await tester.pump();

      openCloselessSheet(navKey.currentContext!);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 3000)); // the switch
      await tester.pump(const Duration(milliseconds: 3000)); // Back
      _camera.debugBlink();
      await tester.pumpAndSettle();
      expect(find.text('closeless-sheet'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('screens outside the shell carry their own gaze', () {
    Widget tutorial(ProviderContainer container, void Function() onNext) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GazeTraversalScope(
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            child: Scaffold(
              body: Column(
                children: [
                  const Text('tutorial'),
                  ElevatedButton(onPressed: onNext, child: const Text('Next')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('inert, and camera-free, with gaze off', (tester) async {
      final container = _container(const GazeSettings());
      addTearDown(container.dispose);
      await tester.pumpWidget(tutorial(container, () {}));
      await tester.pump();
      expect(gazeCameraOwners.isBusy, isFalse);
      expect(find.text('tutorial'), findsOneWidget);
    });

    testWidgets('the first-run tutorial is operable by gaze', (tester) async {
      final container = _container(const GazeSettings(enabled: true));
      addTearDown(container.dispose);
      var next = 0;
      await tester.pumpWidget(tutorial(container, () => next++));
      await tester.pump();
      expect(gazeCameraOwners.count, 1);

      _camera.debugBlink(); // lands on Next
      await tester.pump();
      _camera.debugBlink(); // presses it
      await tester.pump();
      expect(next, 1, reason: 'no touch needed to get past the tutorial');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(gazeCameraOwners.isBusy, isFalse);
    });
  });

  group('in-screen modals cover their own scope', () {
    testWidgets('a game\'s pause card is reachable by blink', (tester) async {
      final container = _container(const GazeSettings(enabled: true));
      addTearDown(container.dispose);
      var hintFired = 0;
      var resumed = 0;
      var paused = true;

      late StateSetter setOuter;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return GazeScope(
                actions: [
                  GazeAction(
                    zone: GazeZone.down,
                    label: 'Choose',
                    icon: Icons.check,
                    color: Colors.green,
                    // Every edge target is disabled while paused.
                    enabled: !paused,
                    onSelect: () => hintFired++,
                  ),
                ],
                onBlink: () => hintFired++,
                camerasLoader: _noCameras,
                detectorFactory: _FakeDetector.new,
                child: Scaffold(
                  body: Stack(
                    children: [
                      const Text('game-body'),
                      if (paused)
                        GazeModalRegion(
                          child: Center(
                            child: FilledButton(
                              onPressed: () {
                                resumed++;
                                setOuter(() => paused = false);
                              },
                              child: const Text('Resume'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(_pastCoverageTick);

      // First blink lands on the card's button (the region took focus), the
      // second presses it — never the game's own blink action.
      _camera.debugBlink();
      await tester.pump();
      if (resumed == 0) {
        _camera.debugBlink();
        await tester.pump();
      }
      expect(resumed, 1);
      expect(hintFired, 0, reason: 'nothing behind the card may fire');

      // Unpaused: the game's own gaze controls are back.
      await tester.pump(_pastCoverageTick);
      _camera.debugBlink();
      await tester.pump();
      expect(hintFired, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('a celebration over the hubs stops the tab D-pad underneath',
        (tester) async {
      final container = _container(const GazeSettings(enabled: true));
      addTearDown(container.dispose);
      final commits = <int>[];
      var dismissed = 0;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: NavGazeScope(
            currentIndex: 0,
            itemCount: 5,
            onCommit: commits.add,
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) => Scaffold(
              body: Stack(
                children: [
                  const Text('hub'),
                  if (dismissed == 0)
                    GazeModalRegion(
                      child: Center(
                        child: FilledButton(
                          onPressed: () => dismissed++,
                          child: const Text('Awesome!'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      await tester.pump(_pastCoverageTick);

      _camera.debugBlink();
      await tester.pump();
      if (dismissed == 0) {
        _camera.debugBlink();
        await tester.pump();
      }
      expect(dismissed, 1);
      expect(commits, isEmpty, reason: 'no tab may open behind it');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('in-screen modals take the focus', () {
    testWidgets('a celebration over a focused hub control still gets it',
        (tester) async {
      // On the tablet the level-up celebration appeared while focus sat on a
      // hub tile; autofocus yielded to it, traversal steered the hub behind
      // the celebration, and the second blink opened Player Profile.
      final container = _container(const GazeSettings(enabled: true));
      addTearDown(container.dispose);
      final hubNode = FocusNode(debugLabel: 'hub-tile');
      addTearDown(hubNode.dispose);
      var hubPressed = 0;
      var dismissed = 0;
      late StateSetter showCelebration;
      var celebrating = false;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: NavGazeScope(
            currentIndex: 0,
            itemCount: 5,
            onCommit: (_) => fail('no tab may open'),
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) => StatefulBuilder(
              builder: (context, setState) {
                showCelebration = setState;
                return Scaffold(
                  body: Stack(
                    children: [
                      ElevatedButton(
                        focusNode: hubNode,
                        onPressed: () => hubPressed++,
                        child: const Text('Player Profile'),
                      ),
                      if (celebrating)
                        GazeModalRegion(
                          child: Center(
                            child: FilledButton(
                              onPressed: () => dismissed++,
                              child: const Text('Awesome!'),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      hubNode.requestFocus();
      await tester.pump();
      expect(hubNode.hasFocus, isTrue);

      showCelebration(() => celebrating = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(_pastCoverageTick);
      expect(hubNode.hasFocus, isFalse, reason: 'the celebration took focus');

      _camera.debugBlink(); // lands on Awesome!
      await tester.pump();
      _camera.debugBlink(); // presses it
      await tester.pump();
      expect(dismissed, 1);
      expect(hubPressed, 0, reason: 'nothing behind the celebration fires');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('scanning mode works on every scope', () {
    testWidgets('the shell scans hub rows, then tiles, then the tab bar',
        (tester) async {
      var c = 0;
      gazeHomeGrid.publishGrid([
        [
          GazeTileCell(label: 'a', onActivate: () {}),
          GazeTileCell(label: 'b', onActivate: () {}),
        ],
        [GazeTileCell(label: 'c', onActivate: () => c++)],
      ]);
      addTearDown(gazeHomeGrid.clearGrid);
      final container = _container(
        const GazeSettings(enabled: true, scanMode: true, scanStepMs: 1000),
      );
      addTearDown(container.dispose);
      final commits = <int>[];
      late NavGazeState last;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: NavGazeScope(
            currentIndex: 0,
            itemCount: 3,
            onCommit: commits.add,
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) {
              last = gaze;
              return const Scaffold(body: Text('hub'));
            },
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(last.scanning, isTrue);

      // Row phase: the whole first row is lit.
      expect(gazeHomeGrid.focusRow, 0);
      expect(gazeHomeGrid.focusCol, isNull);
      expect(gazeHomeGrid.isFocused(0, 1), isTrue);

      // A head move does nothing while scanning.
      _camera.debugSelect(GazeZone.right);
      await tester.pump();
      expect(gazeHomeGrid.focusRow, 0);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(gazeHomeGrid.focusRow, 1);
      // One control in the row: a blink opens it straight away.
      _camera.debugBlink();
      await tester.pump();
      expect(c, 1);

      // Then the whole tab bar…
      await tester.pump(const Duration(milliseconds: 1000));
      expect(last.wholeNavRow, isTrue);
      expect(gazeHomeGrid.focusRow, isNull);
      // …a blink steps into it, the tabs light in turn, a blink opens one.
      _camera.debugBlink();
      await tester.pump();
      expect(last.wholeNavRow, isFalse);
      expect(last.targetIndex, 0);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(last.targetIndex, 1);
      _camera.debugBlink();
      await tester.pump();
      expect(commits, [1]);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('a D-pad screen scans its own rows first, Back after',
        (tester) async {
      final container = _container(
        const GazeSettings(enabled: true, scanMode: true, scanStepMs: 1000),
      );
      addTearDown(container.dispose);
      final fired = <String>[];
      var exits = 0;
      late GazeDpadState last;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GazeDpadScope(
            rows: [
              [
                GazeDpadCell(label: 'Prev', onActivate: () => fired.add('p')),
                GazeDpadCell(label: 'Next', onActivate: () => fired.add('n')),
              ],
            ],
            onExit: () => exits++,
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) {
              last = gaze;
              return const Scaffold(body: Text('viewer'));
            },
          ),
        ),
      ));
      await tester.pump();

      // Starts on the screen's own row (whole), not on Back.
      expect(last.scanning, isTrue);
      expect(last.focusRow, 0);
      expect(last.focusCol, isNull);
      expect(last.isFocused(0, 1), isTrue);

      _camera.debugBlink(); // into the row
      await tester.pump();
      expect(last.isFocused(0, 0), isTrue);
      expect(last.isFocused(0, 1), isFalse);
      await tester.pump(const Duration(milliseconds: 1000));
      _camera.debugBlink(); // Next
      await tester.pump();
      expect(fired, ['n']);
      _camera.debugBlink(); // and again, without waiting a cycle
      await tester.pump();
      expect(fired, ['n', 'n']);

      // Let the row pass run out; scanning moves on to the Back row.
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 1000));
      expect(last.exitFocused, isTrue);
      _camera.debugBlink();
      await tester.pump();
      expect(exits, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('a dialog is scanned control by control', (tester) async {
      // A long step, so the dialog's own opening animation cannot use one up.
      final container = _container(
        const GazeSettings(enabled: true, scanMode: true, scanStepMs: 3000),
      );
      addTearDown(container.dispose);
      final navKey = GlobalKey<NavigatorState>();
      final pressed = <String>[];

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navKey,
          home: GazeDpadScope(
            rows: [
              [GazeDpadCell(label: 'Flip', onActivate: () {})],
            ],
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) => const Scaffold(body: Text('viewer')),
          ),
        ),
      ));
      await tester.pump();
      _openDialog(navKey, pressed);
      await tester.pumpAndSettle();

      // Two scan steps: Stay, then Close.
      await tester.pump(const Duration(milliseconds: 3000));
      await tester.pump(const Duration(milliseconds: 3000));
      _camera.debugBlink();
      await tester.pumpAndSettle();
      expect(pressed, ['close']);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    test('scanning always picks with a blink', () {
      const s = GazeSettings(blinkEnabled: false, scanMode: true);
      expect(s.blinkSelects, isTrue);
      expect(const GazeSettings(blinkEnabled: false).blinkSelects, isFalse);
    });
  });

  group('one camera, even when gaze screens stack', () {
    test('owners are a stack; a token releases exactly its own place', () {
      final owners = GazeCameraOwners();
      final lobby = owners.acquire();
      final race = owners.acquire();
      expect(owners.isTop(race), isTrue);
      expect(owners.isTop(lobby), isFalse);
      owners.release(lobby); // out of order: the race keeps the top
      expect(owners.isTop(race), isTrue);
      expect(owners.count, 1);
      owners.release(lobby); // already gone: ignored
      expect(owners.count, 1);
      owners.release();
      expect(owners.isBusy, isFalse);
      owners.release(); // extra release never goes negative
      expect(owners.count, 0);
    });

    testWidgets('a gaze screen stands down under another and comes back',
        (tester) async {
      // The Play Together lobby (a D-pad screen) opens a race (an edge-target
      // screen): two scopes, one front camera.
      final container = _container(const GazeSettings(enabled: true));
      addTearDown(container.dispose);
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navKey,
          home: GazeDpadScope(
            rows: [
              [GazeDpadCell(label: 'Race', onActivate: () {})],
            ],
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) => const Scaffold(body: Text('lobby')),
          ),
        ),
      ));
      await tester.pump();
      final lobby = _camera;
      expect(lobby.suspended, isFalse);

      navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const GazeScope(
          actions: [],
          camerasLoader: _noCameras,
          detectorFactory: _FakeDetector.new,
          child: Scaffold(body: Text('race')),
        ),
      ));
      await tester.pumpAndSettle();
      final race = _camera;
      expect(identical(race, lobby), isFalse);
      expect(lobby.suspended, isTrue, reason: 'the lobby gave up the camera');
      expect(race.suspended, isFalse);

      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(lobby.suspended, isFalse, reason: 'and took it back');
      expect(gazeCameraOwners.count, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(gazeCameraOwners.isBusy, isFalse);
    });
  });

  group('a page in the shell that is not a hub', () {
    Widget settingsPage(
      ProviderContainer container,
      void Function(NavGazeState) onState,
      void Function() onToggle,
    ) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: NavGazeScope(
            currentIndex: 0,
            itemCount: 5,
            hubPage: false, // Settings: publishes no grid
            onCommit: (_) => fail('no tab may open from a page control'),
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) {
              onState(gaze);
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: onToggle,
                    child: const Text('Gaze Control'),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    testWidgets('is driven by traversal under the full reach',
        (tester) async {
      final container = _container(const GazeSettings(enabled: true));
      addTearDown(container.dispose);
      late NavGazeState last;
      var opened = 0;
      await tester.pumpWidget(
        settingsPage(container, (s) => last = s, () => opened++),
      );
      await tester.pump();
      await tester.pump();

      expect(last.active, isFalse, reason: 'no tab ring on a page it skips');
      _camera.debugBlink(); // lands on the page's control
      await tester.pump();
      if (opened == 0) {
        _camera.debugBlink(); // presses it
        await tester.pump();
      }
      expect(opened, 1, reason: 'Settings is reachable hands-free');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('keeps the tab-bar D-pad under the nav-only reach',
        (tester) async {
      final container = _container(
        const GazeSettings(enabled: true, navScope: GazeNavScope.bottomNav),
      );
      addTearDown(container.dispose);
      late NavGazeState last;
      await tester.pumpWidget(settingsPage(container, (s) => last = s, () {}));
      await tester.pump();
      await tester.pump();
      expect(last.active, isTrue);
      expect(last.targetIndex, 0);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('the shell follows settings live', () {
    testWidgets('tuning and scanning apply without restarting the camera',
        (tester) async {
      final container = _container(const GazeSettings(enabled: true));
      addTearDown(container.dispose);
      late NavGazeState last;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: NavGazeScope(
            currentIndex: 0,
            itemCount: 5,
            onCommit: (_) {},
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) {
              last = gaze;
              return const Scaffold(body: Text('hub'));
            },
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      final camera = _camera;
      expect(camera.debugDescribe()['turnThresholdDeg'], 14.0);

      final notifier = container.read(gazeSettingsProvider.notifier);
      notifier.setSensitivity(5);
      notifier.setDwellMs(2500);
      notifier.setBlinkEnabled(false);
      await tester.pump();
      await tester.pump();

      expect(identical(_camera, camera), isTrue, reason: 'no restart');
      expect(camera.debugDescribe()['turnThresholdDeg'], 8.0);
      expect(camera.debugDescribe()['dwellMs'], 2500);
      expect(camera.debugBlink(), isFalse, reason: 'blink switched off');
      expect(last.blinkSelects, isFalse);

      notifier.setScanMode(true);
      await tester.pump();
      await tester.pump();
      expect(last.scanning, isTrue);
      expect(camera.debugBlink(), isTrue, reason: 'scanning needs blinks');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('"Try it now" is never a dead end', () {
    Future<GlobalKey<NavigatorState>> openPreview(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: Text('settings')),
        ),
      ));
      navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const GazeControlScreen(
          camerasLoader: _noCameras,
          detectorFactory: _FakeDetector.new,
        ),
      ));
      await tester.pumpAndSettle();
      return navKey;
    }

    testWidgets('trying every gesture, then a blink, goes back',
        (tester) async {
      final container = _container(const GazeSettings(enabled: true));
      addTearDown(container.dispose);
      await openPreview(tester, container);
      expect(find.text('settings'), findsNothing);

      for (final zone in [
        GazeZone.up,
        GazeZone.right,
        GazeZone.down,
        GazeZone.left,
      ]) {
        _camera.debugSelect(zone);
        await tester.pump();
      }
      _camera.debugBlink(); // the blink practice
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('settings'), findsNothing, reason: 'still practising');

      _camera.debugBlink(); // all done → back
      await tester.pumpAndSettle();
      expect(find.text('settings'), findsOneWidget);
    });

    testWidgets('with blinks off, looking up goes back', (tester) async {
      final container =
          _container(const GazeSettings(enabled: true, blinkEnabled: false));
      addTearDown(container.dispose);
      await openPreview(tester, container);

      for (final zone in [
        GazeZone.up,
        GazeZone.right,
        GazeZone.down,
        GazeZone.left,
      ]) {
        _camera.debugSelect(zone);
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 2));
      _camera.debugSelect(GazeZone.up);
      await tester.pumpAndSettle();
      expect(find.text('settings'), findsOneWidget);
    });

    testWidgets('scanning mode practises by blinking at lit targets',
        (tester) async {
      final container = _container(
        const GazeSettings(enabled: true, scanMode: true, scanStepMs: 1000),
      );
      addTearDown(container.dispose);
      await openPreview(tester, container);

      for (var i = 0; i < 4; i++) {
        _camera.debugBlink();
        await tester.pump(const Duration(milliseconds: 1000));
      }
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('settings'), findsNothing);
      _camera.debugBlink();
      await tester.pumpAndSettle();
      expect(find.text('settings'), findsOneWidget);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _n = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('count $_n'),
        TextButton(
          key: const Key('bump'),
          onPressed: () => setState(() => _n++),
          child: const Text('bump'),
        ),
      ],
    );
  }
}
