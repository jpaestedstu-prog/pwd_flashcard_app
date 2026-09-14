import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/lock_enforcer.dart';
import 'package:pwdpwdpwd/data/models/alarm_action.dart';
import 'package:pwdpwdpwd/data/models/child_alarm.dart';
import 'package:pwdpwdpwd/data/models/child_time_limit.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_popup_schedule.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/providers/today_routine_provider.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_lock_screen.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_lock_recorder.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/lock_state_provider.dart';
import 'package:pwdpwdpwd/providers/profile_role_provider.dart';
import 'package:pwdpwdpwd/providers/routine_provider.dart';
import 'package:pwdpwdpwd/providers/wall_clock_provider.dart';

/// "My Day" as a lock: at 6:45 the app holds the learner on Brushing Teeth
/// until they say they did it, and then asks how they feel.
///
/// The two halves of the feature are tested against each other throughout,
/// because the difference between them is the requirement: a **Student or
/// Child** can be held by a routine their Teacher or Parent set, and a
/// **Player** never can — their My Day is a checklist they own, with its own
/// on/off switch.
///
/// No Hive writes inside `testWidgets` here: an awaited `box.put` in a widget
/// test hangs the whole file (see the project's Hive-hang notes). Ticking a
/// step is covered by the routine service tests; this file covers when the
/// lock is raised, who it can be raised for, and what the screen says.

const _profileId = 'lock-learner';

const _brushing = RoutineStep(
  id: 'brush',
  activity: RoutineActivity.brushingTeeth,
  hour: 6,
  minute: 45,
);

const _lunch = RoutineStep(
  id: 'lunch',
  activity: RoutineActivity.lunch,
  hour: 12,
  minute: 0,
);

/// The same step with its two-minute timer — the case the lock's countdown
/// exists for.
const _timedBrushing = RoutineStep(
  id: 'brush-timed',
  activity: RoutineActivity.brushingTeeth,
  hour: 6,
  minute: 45,
  durationMinutes: 2,
);

const _checkIn = RoutineStep(
  id: 'check-in',
  activity: RoutineActivity.moodCheckIn,
  hour: 6,
  minute: 45,
  durationMinutes: 2,
);

/// Pumps the lock screen held on [step], without Hive writes.
Future<void> _pumpLock(WidgetTester tester, RoutineStep step) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(
          () => _FixedProfile(
            UserProfile(
              id: _profileId,
              name: 'Ana',
              role: UserRole.student,
              createdAt: DateTime(2026),
            ),
          ),
        ),
        lockStateProvider(_profileId).overrideWithValue(RoutineStepDue(step)),
        routineLockRecorderProvider.overrideWithValue(_recorder),
      ],
      child: const MaterialApp(home: RoutineLockScreen()),
    ),
  );
  await tester.pump();
}

/// Sequenced but not timed — there is no moment for a lock to begin at.
const _homework = RoutineStep(
  id: 'homework',
  activity: RoutineActivity.homework,
);

/// The educator's per-step exemption: it reminds, it never stops anyone.
const _quietBreakfast = RoutineStep(
  id: 'breakfast',
  activity: RoutineActivity.breakfast,
  hour: 7,
  minute: 30,
  lockScreen: false,
);

Routine _routine({
  required List<RoutineStep> steps,
  bool lockEnabled = true,
  bool enabled = true,
}) => Routine(
  id: 'r1',
  childProfileId: _profileId,
  setterProfileId: 'teacher-1',
  setterRole: UserRole.teacher,
  name: 'Morning',
  steps: steps,
  enabled: enabled,
  lockEnabled: lockEnabled,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

DateTime _at(int h, int m) => DateTime(2026, 9, 12, h, m);

LockReason? _evaluate({
  required List<RoutineStep> steps,
  required DateTime now,
  Set<String> done = const {},
  Set<String> skipped = const {},
  ChildTimeLimit? limit,
  List<ChildAlarm> alarms = const [],
  int minutesUsed = 0,
}) => LockEnforcer.evaluate(
  limit: limit,
  minutesUsedToday: minutesUsed,
  alarms: alarms,
  now: now,
  routineSteps: steps,
  completedStepIds: done,
  skippedStepIds: skipped,
);

void main() {
  // Every box anything under test reaches for: `lockStateProvider` composes
  // alarms, time limits and active time with the routine, and the lock screen
  // reads the learner's settings. Opened rather than overridden, so the tests
  // exercise the real composition that decides which lock wins.
  setUpAll(() async {
    Hive.init('./build/test_cache/routine_lock');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'routines',
      'routine_logs',
      'child_alarms',
      'child_time_limits',
      'active_time_logs',
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

  group('which steps can hold the device', () {
    test('a routine that does not lock offers nothing, however it is built', () {
      final r = _routine(steps: [_brushing, _lunch], lockEnabled: false);
      expect(r.lockingSteps, isEmpty);
      // The steps are still a perfectly good day — only the lock is off.
      expect(r.orderedSteps, hasLength(2));
    });

    test('a disabled routine locks nothing even with the switch on', () {
      expect(_routine(steps: [_brushing], enabled: false).lockingSteps, isEmpty);
    });

    test('unscheduled and exempted steps are left out', () {
      final r = _routine(steps: [_brushing, _homework, _quietBreakfast]);
      expect(r.lockingSteps.map((s) => s.id), ['brush']);
    });

    test('a disabled step is not a lock', () {
      final r = _routine(steps: [_brushing.copyWith(enabled: false), _lunch]);
      expect(r.lockingSteps.map((s) => s.id), ['lunch']);
    });

    test('locking steps come in clock order', () {
      final r = _routine(steps: [_lunch, _brushing]);
      expect(r.lockingSteps.map((s) => s.id), ['brush', 'lunch']);
    });
  });

  group('a step that locks, over the course of a day', () {
    final steps = _routine(steps: [_brushing, _lunch]).lockingSteps;

    test('before its time, nothing is locked', () {
      expect(_evaluate(steps: steps, now: _at(6, 30)), isNull);
    });

    test('at its time, the app is held on that step', () {
      final reason = _evaluate(steps: steps, now: _at(6, 45));
      expect(reason, isA<RoutineStepDue>());
      expect((reason! as RoutineStepDue).step.id, 'brush');
    });

    test('a minute late still counts — the tablet was in a bag', () {
      expect(_evaluate(steps: steps, now: _at(7, 30)), isA<RoutineStepDue>());
    });

    test('an hour later the moment has passed and the lock lifts', () {
      // Deliberate: a missed step stays missed and stays tickable in My Day.
      // A device switched off over a weekend must not come back locked to
      // Saturday breakfast.
      expect(_evaluate(steps: steps, now: _at(8, 0)), isNull);
    });

    test('doing it clears the lock', () {
      expect(
        _evaluate(steps: steps, now: _at(6, 50), done: {'brush'}),
        isNull,
      );
    });

    test('an adult excusing it clears the lock without ticking it', () {
      expect(
        _evaluate(steps: steps, now: _at(6, 50), skipped: {'brush'}),
        isNull,
      );
    });

    test('with two overdue at once, the earliest is asked for first', () {
      final earlyLunch = _lunch.copyWith(hour: 6, minute: 50);
      final reason = _evaluate(
        steps: [earlyLunch, _brushing],
        now: _at(6, 55),
      );
      expect((reason! as RoutineStepDue).step.id, 'brush');
    });

    test('finishing the first hands over to the next', () {
      final earlyLunch = _lunch.copyWith(hour: 6, minute: 50);
      final reason = _evaluate(
        steps: [earlyLunch, _brushing],
        now: _at(6, 55),
        done: {'brush'},
      );
      expect((reason! as RoutineStepDue).step.id, 'lunch');
    });
  });

  group('what outranks a routine step', () {
    final steps = _routine(steps: [_brushing]).lockingSteps;

    test('a daily limit that has run out', () {
      final reason = _evaluate(
        steps: steps,
        now: _at(6, 45),
        limit: ChildTimeLimit(
          childProfileId: _profileId,
          setterProfileId: 'teacher-1',
          setterRole: UserRole.teacher,
          dailyLimitEnabled: true,
          dailyLimitMinutes: 30,
          updatedAt: DateTime(2026),
        ),
        minutesUsed: 45,
      );
      // "Stop using the device" beats "go and do this in the device".
      expect(reason, isA<TimeLimitReached>());
    });

    test('an alarm that has just fired', () {
      final reason = _evaluate(
        steps: steps,
        now: _at(6, 45),
        alarms: [
          ChildAlarm(
            id: 'a1',
            childProfileId: _profileId,
            setterProfileId: 'teacher-1',
            setterRole: UserRole.teacher,
            label: 'Break',
            hour: 6,
            minute: 44,
            action: AlarmAction.lockScreen,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ],
      );
      expect(reason, isA<AlarmTriggered>());
    });

    test('study hours that have not started', () {
      final reason = _evaluate(
        steps: steps,
        now: _at(6, 45),
        limit: ChildTimeLimit(
          childProfileId: _profileId,
          setterProfileId: 'teacher-1',
          setterRole: UserRole.teacher,
          scheduleEnabled: true,
          allowedStartHour: 9,
          allowedEndHour: 17,
          updatedAt: DateTime(2026),
        ),
      );
      expect(reason, isA<OutsideSchedule>());
    });
  });

  group('a step an adult excused', () {
    test('stops popping up as well as stopping locking', () {
      // The gate is one decision, not two. Releasing the lock and then
      // asking for the same step in a pop-up two seconds later would undo
      // the adult who just excused it.
      expect(
        RoutinePopupSchedule.due(
          todaysSteps: const [_brushing],
          log: null,
          now: _at(6, 50),
          skippedStepIds: const {'brush'},
        ),
        isNull,
      );
      // …and without the skip it is still due, so the rule is doing the work.
      expect(
        RoutinePopupSchedule.due(
          todaysSteps: const [_brushing],
          log: null,
          now: _at(6, 50),
        ),
        isNotNull,
      );
    });

    test('is not resurrected by a tapped notification', () {
      expect(
        RoutinePopupSchedule.due(
          todaysSteps: const [_brushing],
          log: null,
          now: _at(6, 50),
          skippedStepIds: const {'brush'},
          requestedStepId: 'brush',
        ),
        isNull,
      );
    });
  });

  group('a device an adult unlocked', () {
    // Found on the NDL W09: the teacher's "Unlock 30 min" lifted the lock, and
    // two seconds later the same step was back as "Time for Play Time!".
    test('does not pop the step back up until the unlock ends', () {
      expect(
        RoutinePopupSchedule.due(
          todaysSteps: const [_brushing],
          log: null,
          now: _at(6, 50),
          unlockedUntil: _at(7, 15),
        ),
        isNull,
      );
      // Once the half hour is over the step is due again (still fresh).
      expect(
        RoutinePopupSchedule.due(
          todaysSteps: const [_brushing],
          log: null,
          now: _at(7, 16),
          unlockedUntil: _at(7, 15),
        ),
        _brushing,
      );
    });

    test('still opens a step the learner asked for from its notification', () {
      expect(
        RoutinePopupSchedule.due(
          todaysSteps: const [_brushing],
          log: null,
          now: _at(6, 50),
          unlockedUntil: _at(7, 15),
          requestedStepId: 'brush',
        ),
        _brushing,
      );
    });
  });

  group('where each lock sends the learner', () {
    test('a routine step goes to its own screen, everything else to the PIN', () {
      expect(lockRouteFor(const RoutineStepDue(_brushing)), '/routine-lock');
      expect(
        lockRouteFor(const TimeLimitReached(dailyLimitMinutes: 30, minutesUsed: 31)),
        '/time-up-lock',
      );
      expect(
        lockRouteFor(const OutsideSchedule(allowedStartHour: 8, allowedEndHour: 17)),
        '/time-up-lock',
      );
    });

    test('both lock screens are known to the redirect', () {
      expect(lockScreenRoutes, containsAll(['/time-up-lock', '/routine-lock']));
    });
  });

  group('who a routine can hold', () {
    test('a Student and a Child, and nobody else', () {
      expect(canBeLockedByRoutine(UserRole.student), isTrue);
      expect(canBeLockedByRoutine(UserRole.child), isTrue);
      // The requirement, stated as a test: a Player is never locked.
      expect(canBeLockedByRoutine(UserRole.player), isFalse);
      expect(canBeLockedByRoutine(UserRole.teacher), isFalse);
      expect(canBeLockedByRoutine(UserRole.parent), isFalse);
      expect(canBeLockedByRoutine(null), isFalse);
    });
  });

  group('a routine written before locking existed', () {
    test('stays a checklist, and its steps keep their default', () {
      final legacy = Routine.fromJson({
        'id': 'old',
        'child_profile_id': _profileId,
        'setter_profile_id': 'teacher-1',
        'setter_role': UserRole.teacher.index,
        'name': 'Morning',
        'steps': [
          {'id': 'brush', 'activity': RoutineActivity.brushingTeeth.index,
           'hour': 6, 'minute': 45},
        ],
      });
      // The routine must not start locking because the app updated…
      expect(legacy.lockEnabled, isFalse);
      expect(legacy.lockingSteps, isEmpty);
      // …but the step is ready to when an educator says so.
      expect(legacy.steps.single.lockScreen, isTrue);
    });

    test('both switches round-trip', () {
      final r = _routine(steps: [_brushing, _quietBreakfast]);
      final back = Routine.fromJson(r.toJson());
      expect(back.lockEnabled, isTrue);
      expect(back.steps.map((s) => s.lockScreen), [true, false]);
    });
  });

  // ─── Wiring: the same routine, two kinds of profile ───

  group('lockStateProvider', () {
    ProviderContainer containerFor(
      UserRole role, {
      DateTime? now,
      RoutineDayLog? log,
      RoutineDayActions? actions,
    }) {
      final at = now ?? _at(6, 50);
      final key = routineDayKey(_profileId, at);
      final container = ProviderContainer(
        overrides: [
          profileRoleProvider(_profileId).overrideWithValue(role),
          routineListProvider(_profileId).overrideWith(
            (ref) => Stream.value([
              _routine(steps: [_brushing, _lunch]),
            ]),
          ),
          routineDayLogProvider(key).overrideWith(
            (ref) => Stream.value(log ?? RoutineDayLog.empty(_profileId, at)),
          ),
          routineDayActionsProvider(key).overrideWith(
            (ref) => Stream.value(
              actions ?? RoutineDayActions.empty(_profileId, at),
            ),
          ),
          wallClockTickerProvider.overrideWith((ref) => Stream.value(at)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<LockReason?> settle(ProviderContainer c) async {
      // The routine list and the clock are streams; the first read of the
      // provider happens before either has emitted, so let both land.
      // Streams all the way down, and each layer only subscribes to the next
      // once the one above has produced a value — the routine list first,
      // then the day log and actions it unlocks. Let every layer land.
      c.listen(lockStateProvider(_profileId), (_, _) {});
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration.zero);
        c.read(lockStateProvider(_profileId));
      }
      return c.read(lockStateProvider(_profileId));
    }

    test('holds a Student on the step that is due', () async {
      final reason = await settle(containerFor(UserRole.student));
      expect(reason, isA<RoutineStepDue>());
      expect((reason! as RoutineStepDue).step.id, 'brush');
    });

    test('holds a Child the same way', () async {
      expect(
        await settle(containerFor(UserRole.child)),
        isA<RoutineStepDue>(),
      );
    });

    test('never holds a Player, with the very same routine', () async {
      expect(await settle(containerFor(UserRole.player)), isNull);
    });

    RoutineStepMark mark(DateTime at, RoutineMarkSource source) =>
        RoutineStepMark(
          at: at,
          byProfileId: 'teacher-1',
          byName: 'Rose',
          source: source,
        );

    test("an educator's mark-done from their own device lifts it", () async {
      final reason = await settle(containerFor(
        UserRole.student,
        actions: RoutineDayActions.empty(_profileId, _at(6, 50))
            .withApproval('brush', mark(_at(6, 48), RoutineMarkSource.educator)),
      ));
      expect(reason, isNull);
    });

    test('an excuse from the tablet lifts it, and a revocation re-arms it',
        () async {
      final onTablet = mark(_at(6, 47), RoutineMarkSource.learnerDevice);
      final excusedLog =
          RoutineDayLog.empty(_profileId, _at(6, 50)).withExcuse('brush', onTablet);
      expect(
        await settle(containerFor(UserRole.student, log: excusedLog)),
        isNull,
      );

      final revoked = RoutineDayActions.empty(_profileId, _at(6, 50))
          .withExcuse('brush', onTablet.revoke(at: _at(6, 49), byName: 'Rose'));
      expect(
        await settle(containerFor(
          UserRole.student,
          log: excusedLog,
          actions: revoked,
        )),
        isA<RoutineStepDue>(),
      );
    });

    test("an educator's reset re-arms a step ticked before it", () async {
      final ticked = RoutineDayLog.empty(_profileId, _at(6, 50))
          .setDone('brush', true, at: _at(6, 46));
      expect(
        await settle(containerFor(UserRole.student, log: ticked)),
        isNull,
      );
      final reset = RoutineDayActions.empty(_profileId, _at(6, 50))
          .withReset(at: _at(6, 48), byName: 'Rose');
      expect(
        await settle(containerFor(
          UserRole.student,
          log: ticked,
          actions: reset,
        )),
        isA<RoutineStepDue>(),
      );
    });

    test('nothing is due outside the step window', () async {
      expect(
        await settle(containerFor(UserRole.student, now: _at(5, 0))),
        isNull,
      );
    });
  });

  // ─── Who gets a My Day at all ───

  group('routineFeatureProvider', () {
    ProviderContainer containerFor(
      UserProfile? profile, {
      bool routineEnabled = true,
    }) {
      final container = ProviderContainer(
        overrides: [
          profileProvider.overrideWith(() => _FixedProfile(profile)),
          settingsProvider.overrideWith(
            () => _FixedSettings(AppSettings(routineEnabled: routineEnabled)),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    UserProfile who(UserRole role, {bool guest = false}) => UserProfile(
      id: _profileId,
      name: 'Someone',
      role: role,
      isGuestPlayer: guest,
      createdAt: DateTime(2026),
    );

    test('a Student always has it — it is not theirs to switch off', () {
      final c = containerFor(who(UserRole.student), routineEnabled: false);
      expect(c.read(routineFeatureProvider), isTrue);
    });

    test('a Child always has it', () {
      final c = containerFor(who(UserRole.child), routineEnabled: false);
      expect(c.read(routineFeatureProvider), isTrue);
    });

    test('a Player has it when their own setting says so', () {
      expect(
        containerFor(who(UserRole.player)).read(routineFeatureProvider),
        isTrue,
      );
      expect(
        containerFor(
          who(UserRole.player),
          routineEnabled: false,
        ).read(routineFeatureProvider),
        isFalse,
      );
    });

    test('a guest Player never has one — nothing they do is kept', () {
      final c = containerFor(who(UserRole.player, guest: true));
      expect(c.read(routineFeatureProvider), isFalse);
    });

    test('an educator has no My Day of their own', () {
      expect(
        containerFor(who(UserRole.teacher)).read(routineFeatureProvider),
        isFalse,
      );
      expect(
        containerFor(who(UserRole.parent)).read(routineFeatureProvider),
        isFalse,
      );
    });

    test('no profile, no day', () {
      expect(containerFor(null).read(routineFeatureProvider), isFalse);
    });

    test('a Player with it switched off has an empty day everywhere', () {
      final c = containerFor(who(UserRole.player), routineEnabled: false);
      final today = c.read(todayRoutineProvider);
      expect(today.isEmpty, isTrue);
      expect(today.steps, isEmpty);
    });
  });

  // ─── The screen itself ───

  group('the routine lock screen', () {
    testWidgets('an educator lifting the lock is announced, not vanished', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final lock = StateProvider<LockReason?>(
        (ref) => const RoutineStepDue(_brushing),
      );
      final now = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(
              () => _FixedProfile(
                UserProfile(
                  id: _profileId,
                  name: 'Ana',
                  role: UserRole.student,
                  createdAt: DateTime(2026),
                ),
              ),
            ),
            routineLockRecorderProvider.overrideWithValue(_recorder),
            lockStateProvider(_profileId).overrideWith((ref) => ref.watch(lock)),
            routineDayViewProvider(routineDayKey(_profileId, now))
                .overrideWithValue(
              RoutineDayView.of(
                profileId: _profileId,
                day: now,
                actions: RoutineDayActions.empty(_profileId, now).withApproval(
                  'brush',
                  RoutineStepMark(
                    at: now,
                    byProfileId: 'rose',
                    byName: 'Rose',
                    source: RoutineMarkSource.educator,
                  ),
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: RoutineLockScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('I did it!'), findsOneWidget);

      ProviderScope.containerOf(
        tester.element(find.byType(RoutineLockScreen)),
      ).read(lock.notifier).state = null;
      await tester.pump();

      expect(find.text('Rose marked Brushing Teeth done.'), findsOneWidget);
      expect(find.text('Going back to Home…'), findsOneWidget);
      expect(find.text('I did it!'), findsNothing);
      // Unmount before the notice's timer sends the learner Home.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a step that has waited too long asks for an adult, warmly',
        (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      _recorder.escalations.clear();

      final n = DateTime.now();
      final at = DateTime(n.year, n.month, n.day, 7, 5);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(
              () => _FixedProfile(
                UserProfile(
                  id: _profileId,
                  name: 'Ana',
                  role: UserRole.student,
                  createdAt: DateTime(2026),
                ),
              ),
            ),
            routineLockRecorderProvider.overrideWithValue(_recorder),
            lockStateProvider(_profileId)
                .overrideWithValue(const RoutineStepDue(_brushing)),
            wallClockTickerProvider.overrideWith((ref) => Stream.value(at)),
            routineListProvider(_profileId).overrideWith(
              (ref) => Stream.value([
                _routine(steps: const [_brushing]),
              ]),
            ),
          ],
          child: const MaterialApp(home: RoutineLockScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Still waiting on this one'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Ask a grown-up'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
        findsOneWidget,
      );
      expect(_recorder.escalations, ['$_profileId/brush']);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('before the escalation time there is no prompt', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final n = DateTime.now();
      final at = DateTime(n.year, n.month, n.day, 6, 50);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(
              () => _FixedProfile(
                UserProfile(
                  id: _profileId,
                  name: 'Ana',
                  role: UserRole.student,
                  createdAt: DateTime(2026),
                ),
              ),
            ),
            routineLockRecorderProvider.overrideWithValue(_recorder),
            lockStateProvider(_profileId)
                .overrideWithValue(const RoutineStepDue(_brushing)),
            wallClockTickerProvider.overrideWith((ref) => Stream.value(at)),
            routineListProvider(_profileId).overrideWith(
              (ref) => Stream.value([
                _routine(steps: const [_brushing]),
              ]),
            ),
          ],
          child: const MaterialApp(home: RoutineLockScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Still waiting on this one'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('reports that the lock appeared, once per step', (
      tester,
    ) async {
      _recorder.shown.clear();
      await _pumpLock(tester, _brushing);
      await tester.pump();
      await tester.pump();
      expect(_recorder.shown, ['$_profileId/brush']);
    });

    testWidgets('shows the step, its time, and the way out', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(
              () => _FixedProfile(
                UserProfile(
                  id: _profileId,
                  name: 'Ana',
                  role: UserRole.student,
                  createdAt: DateTime(2026),
                ),
              ),
            ),
            lockStateProvider(
              _profileId,
            ).overrideWithValue(const RoutineStepDue(_brushing)),
            routineLockRecorderProvider.overrideWithValue(_recorder),
          ],
          child: const MaterialApp(home: RoutineLockScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('It is time for this'), findsOneWidget);
      expect(find.text('Brushing Teeth'), findsOneWidget);
      expect(find.text('6:45 AM'), findsOneWidget);
      // Doing it is the primary way out; the adult gate is the other one.
      expect(find.text('I did it!'), findsOneWidget);
      expect(find.text('Ask a grown-up'), findsOneWidget);
      // A shared tablet must still be handed on.
      expect(find.text('Switch account'), findsOneWidget);
    });

    testWidgets('a timed step brings its countdown onto the lock', (
      tester,
    ) async {
      await _pumpLock(tester, _timedBrushing);
      expect(find.text('Timer'), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget);

      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('01:56'), findsOneWidget);
      // Guidance, never a gate: the way out stays open while it runs.
      final didIt = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('I did it!'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(didIt.onPressed, isNotNull);
    });

    testWidgets('an untimed step and a check-in show no timer', (tester) async {
      await _pumpLock(tester, _brushing);
      expect(find.text('Timer'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());

      await _pumpLock(tester, _checkIn);
      expect(find.text('Timer'), findsNothing);
    });

    testWidgets('the back button cannot dismiss it', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(
              () => _FixedProfile(
                UserProfile(
                  id: _profileId,
                  name: 'Ana',
                  role: UserRole.student,
                  createdAt: DateTime(2026),
                ),
              ),
            ),
            lockStateProvider(
              _profileId,
            ).overrideWithValue(const RoutineStepDue(_brushing)),
            routineLockRecorderProvider.overrideWithValue(_recorder),
          ],
          child: const MaterialApp(home: RoutineLockScreen()),
        ),
      );
      await tester.pump();

      // Matched by predicate rather than by type: `PopScope` is generic and
      // the screen builds it without a type argument, so `byType` would be
      // looking for an instantiation that is never constructed.
      expect(
        find.byWidgetPredicate((w) => w is PopScope && !w.canPop),
        findsOneWidget,
      );

      // And the gesture itself: Android's system back leaves the learner
      // exactly where they were.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Brushing Teeth'), findsOneWidget);
    });
  });
}

class _FixedProfile extends ProfileNotifier {
  _FixedProfile(this._profile);

  final UserProfile? _profile;

  @override
  UserProfile? build() => _profile;
}

class _FixedSettings extends SettingsNotifier {
  _FixedSettings(this._settings);

  final AppSettings _settings;

  @override
  AppSettings build() => _settings;
}

/// Remembers lock reports instead of writing them to Hive.
class _MemoryRecorder extends RoutineLockRecorder {
  final List<String> shown = [];
  final List<String> escalations = [];

  @override
  Future<void> lockShown(String profileId, String stepId) async {
    shown.add('$profileId/$stepId');
  }

  @override
  Future<void> escalated(String profileId, String stepId) async {
    escalations.add('$profileId/$stepId');
  }
}

final _recorder = _MemoryRecorder();
