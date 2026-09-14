import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/lock_enforcer.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_lock_screen.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_lock_recorder.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/lock_state_provider.dart';
import 'package:pwdpwdpwd/providers/routine_provider.dart';

/// Leaving the routine lock while the tablet itself is still locked.
///
/// Found on the NDL W09: a step finished over the PIN screen at 23:59, and the
/// learner's Home stood in front of the PIN pad for several seconds — "show
/// over the lock screen" was only turned off when the lock screen was
/// disposed, after the router had already built Home. Now the lock hands the
/// screen back first and waits for the tablet to be unlocked.
///
/// The native side is a mocked channel: `setShowWhenLocked(false)` answers
/// whether it moved FlashLearn behind a locked keyguard.

const _profileId = 'keyguard-learner';

const _brushing = RoutineStep(
  id: 'brush',
  activity: RoutineActivity.brushingTeeth,
  hour: 6,
  minute: 45,
);

const _channel = MethodChannel('flashlearn/routine_alarms');

class _FixedProfile extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: _profileId,
    name: 'Ana',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );
}

class _SilentRecorder extends RoutineLockRecorder {
  @override
  Future<void> lockShown(String profileId, String stepId) async {}
}

/// What the native side was asked, and whether the tablet is "locked".
final List<bool> _showWhenLockedCalls = [];
bool _keyguardLocked = false;

/// Pumps the lock on a real router, held on [_brushing] until the returned
/// controller clears it.
Future<StateController<LockReason?>> _pumpRouted(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final now = DateTime.now();
  final lock = StateProvider<LockReason?>(
    (ref) => const RoutineStepDue(_brushing),
  );
  final router = GoRouter(
    initialLocation: '/routine-lock',
    routes: [
      GoRoute(
        path: '/routine-lock',
        builder: (_, _) => const RoutineLockScreen(),
      ),
      GoRoute(path: '/home', builder: (_, _) => const Text('home')),
      GoRoute(
        path: '/profile-switcher',
        builder: (_, _) => const Text('switcher'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(_FixedProfile.new),
        routineLockRecorderProvider.overrideWithValue(_SilentRecorder()),
        lockStateProvider(_profileId).overrideWith((ref) => ref.watch(lock)),
        // No educator action today, so clearing the lock is the learner's own.
        routineDayViewProvider(routineDayKey(_profileId, now)).overrideWithValue(
          RoutineDayView.of(
            profileId: _profileId,
            day: now,
            actions: RoutineDayActions.empty(_profileId, now),
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  // Nothing to press on a routine lock — only until when.
  expect(find.textContaining('Please wait'), findsOneWidget);
  expect(find.text('I did it!'), findsNothing);
  return ProviderScope.containerOf(
    tester.element(find.byType(RoutineLockScreen)),
  ).read(lock.notifier);
}

/// A few frames: the provider change, the async hand-back, the navigation.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Someone unlocks the tablet and FlashLearn comes back to the front.
void _unlockAndReturn(WidgetTester tester) {
  _keyguardLocked = false;
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/routine_lock_keyguard');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'routines',
      'routine_logs',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  setUp(() {
    _showWhenLockedCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method != 'setShowWhenLocked') return null;
      final on = (call.arguments as Map)['on'] as bool;
      _showWhenLockedCalls.add(on);
      return !on && _keyguardLocked;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  testWidgets('an unlocked tablet goes Home at once, as before', (
    tester,
  ) async {
    _keyguardLocked = false;
    final lock = await _pumpRouted(tester);

    lock.state = null;
    await _settle(tester);

    expect(find.text('home'), findsOneWidget);
    expect(_showWhenLockedCalls, contains(false));
  });

  testWidgets('a locked tablet gets its PIN screen back before Home is built', (
    tester,
  ) async {
    _keyguardLocked = true;
    final lock = await _pumpRouted(tester);

    lock.state = null;
    await _settle(tester);

    // Handed back to the PIN pad, and Home was never put in front of it.
    expect(_showWhenLockedCalls.last, isFalse);
    expect(find.text('home'), findsNothing);
    expect(find.byType(RoutineLockScreen), findsOneWidget);

    _unlockAndReturn(tester);
    await _settle(tester);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a lock that is due again by the time it is unlocked stays', (
    tester,
  ) async {
    _keyguardLocked = true;
    final lock = await _pumpRouted(tester);

    lock.state = null;
    await _settle(tester);
    expect(find.text('home'), findsNothing);

    // The next step came due while the tablet sat locked.
    lock.state = const RoutineStepDue(_brushing);
    await _settle(tester);
    _unlockAndReturn(tester);
    await _settle(tester);

    expect(find.text('home'), findsNothing);
    expect(find.byType(RoutineLockScreen), findsOneWidget);
    // …and it may show over the lock screen again.
    expect(_showWhenLockedCalls.last, isTrue);
  });

  testWidgets('"Switch account" over a locked tablet goes back to the PIN pad', (
    tester,
  ) async {
    _keyguardLocked = true;
    await _pumpRouted(tester);

    await tester.tap(find.text('Switch account'));
    await _settle(tester);

    expect(_showWhenLockedCalls.last, isFalse);
    expect(find.text('switcher'), findsNothing);
    expect(find.byType(RoutineLockScreen), findsOneWidget);
  });

  testWidgets('"Switch account" on an unlocked tablet opens the switcher', (
    tester,
  ) async {
    _keyguardLocked = false;
    await _pumpRouted(tester);

    await tester.tap(find.text('Switch account'));
    await _settle(tester);

    expect(find.text('switcher'), findsOneWidget);
  });
}
