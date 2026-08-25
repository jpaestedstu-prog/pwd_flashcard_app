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
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_route_guard.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/nav_gaze_scope.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/shell_modal_observer.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show SettingsNotifier, settingsProvider;

/// Regression cover for the shell's "am I covered?" signal.
///
/// `NavGazeScope` wraps go_router's `ShellRoute` **builder**, so it sits above
/// the shell's inner navigator: its own `ModalRoute` is the shell route, which
/// stays `isCurrent` forever. A sheet or dialog opened from a hub screen pushes
/// onto that inner navigator and is invisible to `ModalRoute.of`.
///
/// The symptom was not subtle — the gaze D-pad kept driving the hub grid
/// *underneath* an open sheet, so a learner looking at a game's difficulty
/// chooser had the highlight running over the game tiles behind it, and a
/// commit would have opened whichever tile it happened to be on.
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

ProviderContainer _gazeOn() => ProviderContainer(
  overrides: [
    gazeSettingsProvider.overrideWith(
      () => _FixedSettings(const GazeSettings(enabled: true)),
    ),
    settingsProvider.overrideWith(_StubAppSettings.new),
  ],
);

/// Long enough for [GazeRouteGuard]'s 400 ms coverage ticker to notice.
const _pastCoverageTick = Duration(milliseconds: 600);

void main() {
  setUp(() {
    shellModalObserver.reset();
    while (gazeCameraOwners.isBusy) {
      gazeCameraOwners.release();
    }
  });
  tearDown(shellModalObserver.reset);

  group('ShellModalObserver counting', () {
    late ShellModalObserver observer;
    setUp(() => observer = ShellModalObserver());

    Route<void> route() => PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
    );

    test('the shell base page is not a layer on top', () {
      // go_router *swaps* the tab page rather than pushing, and the very first
      // route arrives with no previous route.
      observer.didPush(route(), null);
      expect(observer.isCovering, isFalse);
    });

    test('anything pushed above the base page counts as covering', () {
      observer.didPush(route(), null);
      final sheet = route();
      observer.didPush(sheet, route());
      expect(observer.isCovering, isTrue);
    });

    test('popping the sheet uncovers the shell again', () {
      observer.didPush(route(), null);
      final sheet = route();
      observer.didPush(sheet, route());
      observer.didPop(sheet, route());
      expect(observer.isCovering, isFalse);
    });

    test('a removed route also uncovers', () {
      observer.didPush(route(), null);
      final sheet = route();
      observer.didPush(sheet, route());
      observer.didRemove(sheet, route());
      expect(observer.isCovering, isFalse);
    });

    test('a replace swaps one layer for another, so depth is unchanged', () {
      observer.didPush(route(), null);
      observer.didPush(route(), route());
      observer.didReplace(newRoute: route(), oldRoute: route());
      expect(observer.isCovering, isTrue);
    });

    test('depth never goes negative, so a stray pop cannot wedge it', () {
      // An unbalanced pop must not leave the shell permanently "uncoverable".
      observer.didPop(route(), null);
      observer.didPop(route(), null);
      observer.didPush(route(), null);
      observer.didPush(route(), route());
      expect(observer.isCovering, isTrue);
    });

    test('nested layers need every one popped before the shell is clear', () {
      observer.didPush(route(), null);
      final sheet = route();
      final dialogOverSheet = route();
      observer.didPush(sheet, route());
      observer.didPush(dialogOverSheet, sheet);
      observer.didPop(dialogOverSheet, sheet);
      expect(observer.isCovering, isTrue, reason: 'the sheet is still up');
      observer.didPop(sheet, route());
      expect(observer.isCovering, isFalse);
    });
  });

  testWidgets('a real dialog on the observed navigator reports covering', (
    tester,
  ) async {
    // The end-to-end shape: the observer is installed on the navigator the hub
    // screens actually open their sheets from.
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [shellModalObserver],
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: Text('hub'));
          },
        ),
      ),
    );

    expect(shellModalObserver.isCovering, isFalse);

    unawaited(
      showDialog<void>(
        context: hostContext,
        builder: (_) => const AlertDialog(content: Text('sheet')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      shellModalObserver.isCovering,
      isTrue,
      reason: 'the gaze D-pad must stand down while this is up',
    );

    Navigator.of(hostContext, rootNavigator: true).pop();
    await tester.pumpAndSettle();
    expect(shellModalObserver.isCovering, isFalse);
  });

  testWidgets('NavGazeScope stands down when the observer reports covering', (
    tester,
  ) async {
    // The wiring that actually mattered on device. A sheet opened from a hub
    // screen pushes onto the shell's *inner* navigator, which `ModalRoute.of`
    // cannot see from the shell builder — so without the observer the tab ring
    // stayed lit and the D-pad kept driving the hub underneath it.
    final container = _gazeOn();
    addTearDown(container.dispose);
    late NavGazeState last;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
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
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(last.active, isTrue);
    expect(last.targetIndex, 0);

    // Exactly what a hub sheet does to the shell's own navigator.
    shellModalObserver.didPush(
      PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox.shrink()),
      PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox.shrink()),
    );
    await tester.pump(_pastCoverageTick);
    expect(
      last.active,
      isFalse,
      reason: 'the tab ring must not stay lit under a sheet',
    );
    expect(last.targetIndex, isNull);

    shellModalObserver.didPop(
      PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox.shrink()),
      null,
    );
    await tester.pump(_pastCoverageTick);
    expect(last.active, isTrue, reason: 'and must come back when it closes');
  });

  testWidgets('GazeRouteGuard treats extraCovered as covered', (tester) async {
    // The wiring that makes the observer matter: `NavGazeScope` overrides
    // `extraCovered` with it, and every input path gates on `gazeCovered`.
    await tester.pumpWidget(const MaterialApp(home: _GuardProbe()));
    final state = tester.state<_GuardProbeState>(find.byType(_GuardProbe));

    expect(state.gazeCovered, isFalse);
    state.covered = true;
    expect(
      state.gazeCovered,
      isTrue,
      reason: 'extraCovered alone must be enough to gate input off',
    );
  });
}

/// Minimal host for [GazeRouteGuard], so the `extraCovered` hook can be
/// exercised without standing up the whole navigation shell.
class _GuardProbe extends StatefulWidget {
  const _GuardProbe();
  @override
  State<_GuardProbe> createState() => _GuardProbeState();
}

class _GuardProbeState extends State<_GuardProbe> with GazeRouteGuard {
  bool covered = false;

  @override
  bool get extraCovered => covered;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Local `unawaited` so the test file needs no extra import.
void unawaited(Future<void> future) {}
