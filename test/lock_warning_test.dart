import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/lock_presentation.dart';
import 'package:pwdpwdpwd/core/services/lock_warning.dart';
import 'package:pwdpwdpwd/data/models/alarm_action.dart';
import 'package:pwdpwdpwd/data/models/child_alarm.dart';
import 'package:pwdpwdpwd/data/models/child_time_limit.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/classroom/widgets/lock_warning_gate.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/child_time_limit_provider.dart';
import 'package:pwdpwdpwd/providers/lock_announcement_provider.dart';
import 'package:pwdpwdpwd/providers/lock_warning_provider.dart';
import 'package:pwdpwdpwd/providers/unlocking_educators_provider.dart';

import 'support/lock_test_doubles.dart';

/// The "nearly time" warning that fires before the lock lands.
///
///   * **[LockWarningEvaluator]** — fires for each of the three rules that
///     can lock a learner, stays quiet once the lock is actually due, and
///     honours the educator's switch and lead time.
///   * **[LockWarningSeenNotifier]** — one interruption per approaching
///     lock, re-armed when the window passes.
///   * **[LockWarningGate]** — announces once, shows a dismissible banner,
///     and never covers the whole screen.
void main() {
  // Friday 2026-07-31, mid-morning. Fixed so weekday-sensitive alarm cases
  // are deterministic.
  final now = DateTime(2026, 7, 31, 10);

  group('LockWarningEvaluator — daily limit', () {
    ChildTimeLimit limit({
      int minutes = 60,
      bool enabled = true,
      int lead = 5,
      bool warn = true,
    }) =>
        ChildTimeLimit(
          childProfileId: 'child-1',
          setterProfileId: 'teacher-1',
          setterRole: UserRole.teacher,
          dailyLimitEnabled: enabled,
          dailyLimitMinutes: minutes,
          warningEnabled: warn,
          warningMinutes: lead,
          updatedAt: now,
        );

    test('fires once the remaining budget is inside the lead time', () {
      final w = LockWarningEvaluator.evaluate(
        limit: limit(),
        minutesUsedToday: 56,
        alarms: const [],
        now: now,
      );
      expect(w, isNotNull);
      expect(w!.cause, LockWarningCause.dailyLimit);
      expect(w.minutesLeft, 4);
      expect(w.title, '4 minutes left');
    });

    test('stays quiet while there is still plenty of time', () {
      expect(
        LockWarningEvaluator.evaluate(
          limit: limit(),
          minutesUsedToday: 30,
          alarms: const [],
          now: now,
        ),
        isNull,
      );
    });

    test('stays quiet once the lock is actually due', () {
      // 60 of 60 used: LockEnforcer locks, so the banner must not stack on
      // top of the lock screen.
      expect(
        LockWarningEvaluator.evaluate(
          limit: limit(),
          minutesUsedToday: 60,
          alarms: const [],
          now: now,
        ),
        isNull,
      );
    });

    test('respects the educator turning warnings off', () {
      expect(
        LockWarningEvaluator.evaluate(
          limit: limit(warn: false),
          minutesUsedToday: 58,
          alarms: const [],
          now: now,
        ),
        isNull,
      );
    });

    test('respects a longer lead time', () {
      final w = LockWarningEvaluator.evaluate(
        limit: limit(lead: 20),
        minutesUsedToday: 45,
        alarms: const [],
        now: now,
      );
      expect(w?.cause, LockWarningCause.dailyLimit);
      expect(w?.minutesLeft, 15);
    });

    test('says nothing when the daily limit is switched off', () {
      expect(
        LockWarningEvaluator.evaluate(
          limit: limit(enabled: false),
          minutesUsedToday: 59,
          alarms: const [],
          now: now,
        ),
        isNull,
      );
    });

    test('a single-minute warning reads as singular', () {
      final w = LockWarningEvaluator.evaluate(
        limit: limit(),
        minutesUsedToday: 59,
        alarms: const [],
        now: now,
      );
      expect(w?.minutesLeft, 1);
      expect(w?.title, '1 minute left');
    });
  });

  group('LockWarningEvaluator — schedule', () {
    ChildTimeLimit limit({
      int end = 20,
      Set<int> days = const <int>{},
      int lead = 5,
    }) =>
        ChildTimeLimit(
          childProfileId: 'child-1',
          setterProfileId: 'teacher-1',
          setterRole: UserRole.teacher,
          scheduleEnabled: true,
          allowedEndHour: end,
          allowedDays: days,
          warningMinutes: lead,
          updatedAt: now,
        );

    test('fires as the allowed window is about to close', () {
      final w = LockWarningEvaluator.evaluate(
        limit: limit(),
        minutesUsedToday: 0,
        alarms: const [],
        now: DateTime(2026, 7, 31, 19, 57),
      );
      expect(w?.cause, LockWarningCause.schedule);
      expect(w?.minutesLeft, 3);
    });

    test('stays quiet in the middle of the window', () {
      expect(
        LockWarningEvaluator.evaluate(
          limit: limit(),
          minutesUsedToday: 0,
          alarms: const [],
          now: DateTime(2026, 7, 31, 14),
        ),
        isNull,
      );
    });

    test('stays quiet on a day the schedule does not apply to', () {
      // Schedule only on Monday; "now" is a Friday.
      expect(
        LockWarningEvaluator.evaluate(
          limit: limit(days: const {1}),
          minutesUsedToday: 0,
          alarms: const [],
          now: DateTime(2026, 7, 31, 19, 57),
        ),
        isNull,
      );
    });

    test('describes the schedule cause differently from the daily limit', () {
      const schedule =
          LockWarning(minutesLeft: 5, cause: LockWarningCause.schedule);
      const daily =
          LockWarning(minutesLeft: 5, cause: LockWarningCause.dailyLimit);
      expect(schedule.body('Mommy'), isNot(daily.body('Mommy')));
      expect(schedule.body('Mommy'), contains('Mommy'));
    });
  });

  group('LockWarningEvaluator — alarms', () {
    ChildAlarm alarm({
      required int hour,
      required int minute,
      AlarmAction action = AlarmAction.lockScreen,
      bool enabled = true,
      Set<int> days = const <int>{},
    }) =>
        ChildAlarm(
          id: 'a1',
          childProfileId: 'child-1',
          setterProfileId: 'teacher-1',
          setterRole: UserRole.teacher,
          label: 'Bedtime',
          hour: hour,
          minute: minute,
          daysOfWeek: days,
          action: action,
          enabled: enabled,
          createdAt: now,
          updatedAt: now,
        );

    final base = ChildTimeLimit(
      childProfileId: 'child-1',
      setterProfileId: 'teacher-1',
      setterRole: UserRole.teacher,
      updatedAt: now,
    );

    test('fires before a lock-screen alarm', () {
      final w = LockWarningEvaluator.evaluate(
        limit: base,
        minutesUsedToday: 0,
        alarms: [alarm(hour: 10, minute: 4)],
        now: now,
      );
      expect(w?.cause, LockWarningCause.alarm);
      expect(w?.minutesLeft, 4);
    });

    test('ignores alarms that only notify', () {
      expect(
        LockWarningEvaluator.evaluate(
          limit: base,
          minutesUsedToday: 0,
          alarms: [alarm(hour: 10, minute: 4, action: AlarmAction.notifyOnly)],
          now: now,
        ),
        isNull,
      );
    });

    test('ignores disabled alarms', () {
      expect(
        LockWarningEvaluator.evaluate(
          limit: base,
          minutesUsedToday: 0,
          alarms: [alarm(hour: 10, minute: 4, enabled: false)],
          now: now,
        ),
        isNull,
      );
    });

    test('ignores an alarm that does not fire today', () {
      // Monday-only alarm; "now" is Friday, so the next fire is days away.
      expect(
        LockWarningEvaluator.evaluate(
          limit: base,
          minutesUsedToday: 0,
          alarms: [alarm(hour: 10, minute: 4, days: const {1})],
          now: now,
        ),
        isNull,
      );
    });

    test('picks the soonest of several alarms', () {
      final w = LockWarningEvaluator.evaluate(
        limit: base,
        minutesUsedToday: 0,
        alarms: [
          alarm(hour: 10, minute: 5),
          alarm(hour: 10, minute: 2),
        ],
        now: now,
      );
      expect(w?.minutesLeft, 2);
    });

    test('an alarm outranks a daily limit that is further away', () {
      final w = LockWarningEvaluator.evaluate(
        limit: base.copyWith(
          dailyLimitEnabled: true,
          dailyLimitMinutes: 60,
        ),
        minutesUsedToday: 56,
        alarms: [alarm(hour: 10, minute: 1)],
        now: now,
      );
      // Alarm in 1 min beats the limit's 4 min, matching LockEnforcer's
      // precedence so the warning names the rule that will really fire.
      expect(w?.cause, LockWarningCause.alarm);
      expect(w?.minutesLeft, 1);
    });
  });

  group('LockWarning wording', () {
    test('every cause produces a non-empty message naming the guardian', () {
      for (final cause in LockWarningCause.values) {
        final w = LockWarning(minutesLeft: 5, cause: cause);
        expect(w.title, isNotEmpty);
        expect(w.body('Teacher Ana'), contains('Teacher Ana'));
        expect(w.bodySimple('Teacher Ana'), contains('Teacher Ana'));
        expect(w.bodyFilipino('Teacher Ana'), contains('Teacher Ana'));
      }
    });

    test('the event key ignores the minute count', () {
      // "5 minutes left" and "4 minutes left" are the same approaching
      // lock; if the keys differed the learner would be interrupted twice.
      const five =
          LockWarning(minutesLeft: 5, cause: LockWarningCause.dailyLimit);
      const four =
          LockWarning(minutesLeft: 4, cause: LockWarningCause.dailyLimit);
      expect(five.eventKey, four.eventKey);

      const schedule =
          LockWarning(minutesLeft: 5, cause: LockWarningCause.schedule);
      expect(five.eventKey, isNot(schedule.eventKey));
    });
  });

  group('ChildTimeLimit warning fields', () {
    test('round-trip and legacy defaults', () {
      final limit = ChildTimeLimit(
        childProfileId: 'child-1',
        setterProfileId: 'teacher-1',
        setterRole: UserRole.teacher,
        warningEnabled: false,
        warningMinutes: 12,
        updatedAt: DateTime(2026, 7, 31),
      );
      final restored = ChildTimeLimit.fromJson(limit.toJson());
      expect(restored.warningEnabled, isFalse);
      expect(restored.warningMinutes, 12);

      // A document written before the warning existed still gives notice.
      final legacy = ChildTimeLimit.fromJson(<String, dynamic>{
        'child_profile_id': 'child-1',
        'setter_profile_id': 'parent-1',
        'setter_role': UserRole.parent.index,
        'updated_at': '2026-01-01T00:00:00.000',
      });
      expect(legacy.warningEnabled, isTrue);
      expect(legacy.warningMinutes, 5);
    });

    test('the lead time is clamped into a sane range', () {
      ChildTimeLimit withLead(int m) => ChildTimeLimit(
            childProfileId: 'c',
            setterProfileId: 's',
            setterRole: UserRole.parent,
            warningMinutes: m,
            updatedAt: now,
          );
      // 0 would fire the warning at the same instant as the lock.
      expect(withLead(0).effectiveWarningMinutes,
          ChildTimeLimit.minWarningMinutes);
      expect(withLead(-5).effectiveWarningMinutes,
          ChildTimeLimit.minWarningMinutes);
      expect(withLead(999).effectiveWarningMinutes,
          ChildTimeLimit.maxWarningMinutes);
      expect(withLead(5).effectiveWarningMinutes, 5);
    });
  });

  group('LockPresentation.warningVariant', () {
    test('softens the announcement without dropping the learner\'s channel',
        () {
      for (final type in DisabilityType.values) {
        final full = LockPresentation.forProfile(type, const AppSettings());
        final warn = full.warningVariant;

        // A warning never repeats or shows video — the learner is still
        // mid-activity and will see the real thing shortly. That covers
        // *both* clip kinds: the alarm animation is a cut-off cue and
        // would contradict "you still have time".
        expect(warn.alarmRepeats, 1, reason: '$type');
        expect(warn.repeatSpokenMessage, isFalse, reason: '$type');
        expect(warn.showFslVideo, isFalse, reason: '$type');
        expect(warn.clip, LockClipKind.none, reason: '$type');
        expect(warn.showClip, isFalse, reason: '$type');
        expect(warn.visualAlert, isFalse, reason: '$type');

        // …but the channels that actually reach this learner survive.
        expect(warn.speakMessage, full.speakMessage, reason: '$type');
        expect(warn.haptics, full.haptics, reason: '$type');
        expect(warn.announce, full.announce, reason: '$type');
        expect(warn.minTouchTarget, full.minTouchTarget, reason: '$type');
      }
    });
  });

  group('LockWarningSeenNotifier', () {
    test('marks once, then re-arms after clear', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final seen = container.read(lockWarningSeenProvider('child-1').notifier);

      expect(seen.markShown('dailyLimit'), isTrue);
      expect(seen.markShown('dailyLimit'), isFalse);
      // A different rule is a different interruption.
      expect(seen.markShown('schedule'), isTrue);

      seen.clear('dailyLimit');
      expect(seen.markShown('dailyLimit'), isTrue);
    });

    test('is tracked per child', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(lockWarningSeenProvider('a').notifier).markShown('x'),
        isTrue,
      );
      expect(
        container.read(lockWarningSeenProvider('b').notifier).markShown('x'),
        isTrue,
      );
    });
  });

  group('LockWarningGate', () {
    testWidgets('announces once and shows a dismissible banner',
        (tester) async {
      final announcer = RecordingAnnouncer();
      final warning = ValueNotifier<LockWarning?>(null);
      addTearDown(warning.dispose);

      await _pumpGate(tester, announcer: announcer, warning: warning);
      expect(find.textContaining('minutes left'), findsNothing);

      warning.value =
          const LockWarning(minutesLeft: 5, cause: LockWarningCause.dailyLimit);
      await _settle(tester);

      expect(find.text('5 minutes left'), findsOneWidget);
      expect(find.textContaining('Teacher Ana'), findsOneWidget);
      expect(announcer.calls, hasLength(1));
      expect(announcer.calls.single.message, contains('5 minutes left'));
      // Softened: one chime, no repeat reading.
      expect(announcer.calls.single.presentation.alarmRepeats, 1);
      expect(announcer.calls.single.presentation.repeatSpokenMessage, isFalse);

      // The activity underneath is still visible and reachable — this is a
      // banner, not a blocking dialog.
      expect(find.text('ACTIVITY'), findsOneWidget);

      // Ticking down to 4 minutes is the same event: no second interruption.
      warning.value =
          const LockWarning(minutesLeft: 4, cause: LockWarningCause.dailyLimit);
      await _settle(tester);
      expect(announcer.calls, hasLength(1));
      // Still the original headline: the banner was not replaced.
      expect(find.text('5 minutes left'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await _settle(tester);
      expect(find.text('5 minutes left'), findsNothing);
    });

    testWidgets('retires itself so it never sits over the activity',
        (tester) async {
      final warning = ValueNotifier<LockWarning?>(null);
      addTearDown(warning.dispose);
      await _pumpGate(tester, warning: warning);

      warning.value =
          const LockWarning(minutesLeft: 5, cause: LockWarningCause.schedule);
      await _settle(tester);
      expect(find.text('5 minutes left'), findsOneWidget);

      await tester.pump(const Duration(seconds: 13));
      expect(find.text('5 minutes left'), findsNothing);
    });

    testWidgets('re-arms after the warning window passes', (tester) async {
      final announcer = RecordingAnnouncer();
      final warning = ValueNotifier<LockWarning?>(null);
      addTearDown(warning.dispose);
      await _pumpGate(tester, announcer: announcer, warning: warning);

      warning.value =
          const LockWarning(minutesLeft: 5, cause: LockWarningCause.dailyLimit);
      await _settle(tester);
      expect(announcer.calls, hasLength(1));

      // Educator granted more time / the day rolled over.
      warning.value = null;
      await _settle(tester);
      await tester.pump(const Duration(seconds: 13));

      // A genuinely new approach warns again.
      warning.value =
          const LockWarning(minutesLeft: 5, cause: LockWarningCause.dailyLimit);
      await _settle(tester);
      expect(announcer.calls, hasLength(2));

      await tester.pump(const Duration(seconds: 13));
    });

    testWidgets('stays out of the way for non-learner profiles',
        (tester) async {
      final warning = ValueNotifier<LockWarning?>(null);
      addTearDown(warning.dispose);
      await _pumpGate(
        tester,
        warning: warning,
        profile: UserProfile(
          id: 'teacher-1',
          name: 'Sir Kevin',
          role: UserRole.teacher,
          createdAt: DateTime(2026),
        ),
      );

      warning.value =
          const LockWarning(minutesLeft: 5, cause: LockWarningCause.dailyLimit);
      await _settle(tester);
      expect(find.text('5 minutes left'), findsNothing);
    });
  });
}

/// Pushes a bridged warning change through to the widget.
///
/// Two pumps, not one: the provider is invalidated lazily, so the first
/// frame recomputes it and the second delivers the `ref.listen` callback.
/// The settle finishes the banner's slide-in so taps land on it.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

/// Mounts [LockWarningGate] over a stand-in "activity", driving the warning
/// from [warning] so the test controls the clock rather than waiting on it.
Future<void> _pumpGate(
  WidgetTester tester, {
  required ValueNotifier<LockWarning?> warning,
  RecordingAnnouncer? announcer,
  UserProfile? profile,
}) async {
  final learner = profile ??
      UserProfile(
        id: 'child-1',
        name: 'Test Learner',
        role: UserRole.child,
        createdAt: DateTime(2026),
      );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(() => FixedProfile(learner)),
        settingsProvider.overrideWith(() => FixedSettings(const AppSettings())),
        lockAnnouncerProvider
            .overrideWithValue(announcer ?? RecordingAnnouncer()),
        childTimeLimitProvider(learner.id).overrideWith(
          (ref) => Stream.value(
            ChildTimeLimit(
              childProfileId: learner.id,
              setterProfileId: 'teacher-1',
              setterRole: UserRole.teacher,
              guardianPreferredName: 'Teacher Ana',
              dailyLimitEnabled: true,
              dailyLimitMinutes: 60,
              updatedAt: DateTime(2026, 7, 31),
            ),
          ),
        ),
        unlockingEducatorsProvider(learner.id)
            .overrideWith((ref) async => const <UserProfile>[]),
        // Bridge the ValueNotifier into the provider so the test drives the
        // warning directly instead of waiting on a real wall clock.
        lockWarningProvider(learner.id).overrideWith((ref) {
          void onChange() => ref.invalidateSelf();
          warning.addListener(onChange);
          ref.onDispose(() => warning.removeListener(onChange));
          return warning.value;
        }),
      ],
      // Mounted through `builder`, exactly as `main.dart` does — i.e.
      // *above* the Navigator, where there is no Overlay ancestor. A
      // Scaffold-hosted harness would quietly provide one and hide a whole
      // class of bug (a Tooltip in the banner threw here on device).
      child: MaterialApp(
        builder: (context, child) => LockWarningGate(child: child!),
        home: const Scaffold(body: Center(child: Text('ACTIVITY'))),
      ),
    ),
  );
  await tester.pump();
}
