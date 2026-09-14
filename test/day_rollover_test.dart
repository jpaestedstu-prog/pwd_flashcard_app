import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/providers/today_routine_provider.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/routine_provider.dart';
import 'package:pwdpwdpwd/providers/wall_clock_provider.dart';

import 'support/lock_test_doubles.dart';
import 'support/routine_test_doubles.dart';

/// Midnight with the app still running.
///
/// Found on the emulator: after the date changed, Home's My Day card still
/// said "All done" for a day nothing had been ticked on, because the day was
/// read once when the provider was first built.
void main() {
  group('when the date has changed', () {
    final monday = DateTime(2030, 1, 7);

    test('another tick on the same day is not a new day', () {
      expect(isNewDay(monday, DateTime(2030, 1, 7, 0, 0, 1)), isFalse);
      expect(isNewDay(monday, DateTime(2030, 1, 7, 23, 59, 59)), isFalse);
    });

    test('midnight is', () {
      expect(isNewDay(monday, DateTime(2030, 1, 8)), isTrue);
    });

    test('so is a clock set back to an earlier day', () {
      expect(isNewDay(monday, DateTime(2030, 1, 6, 23, 30)), isTrue);
    });

    test('and a month or year boundary', () {
      expect(
        isNewDay(DateTime(2030, 1, 31), DateTime(2030, 2, 1, 0, 30)),
        isTrue,
      );
      expect(
        isNewDay(DateTime(2030, 12, 31), DateTime(2031, 1, 1, 0, 30)),
        isTrue,
      );
    });
  });

  test("the learner's day stops saying All done when the date changes",
      () async {
    final monday = DateTime(2026, 9, 14);
    final tuesday = DateTime(2026, 9, 15);
    final day = StateProvider<DateTime>((ref) => monday);
    final routine = buildTestRoutine();
    final allIds = {for (final s in routine.steps) s.id};

    RoutineDayLog log(DateTime d, Set<String> done) => RoutineDayLog(
          profileId: kTestProfileId,
          day: d,
          completedStepIds: done,
          updatedAt: d,
        );

    final container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(
          () => StubRoutineProfileNotifier(
            role: UserRole.student,
            disability: DisabilityType.none,
          ),
        ),
        settingsProvider.overrideWith(() => FixedSettings(const AppSettings())),
        currentDayProvider.overrideWith((ref) => ref.watch(day)),
        myRoutinesProvider.overrideWith((ref) => Stream.value([routine])),
        routineDayLogProvider(routineDayKey(kTestProfileId, monday))
            .overrideWith((ref) => Stream.value(log(monday, allIds))),
        routineDayLogProvider(routineDayKey(kTestProfileId, tuesday))
            .overrideWith((ref) => Stream.value(log(tuesday, const {}))),
        routineDayActionsProvider(routineDayKey(kTestProfileId, monday))
            .overrideWith(
          (ref) => Stream.value(RoutineDayActions.empty(kTestProfileId, monday)),
        ),
        routineDayActionsProvider(routineDayKey(kTestProfileId, tuesday))
            .overrideWith(
          (ref) =>
              Stream.value(RoutineDayActions.empty(kTestProfileId, tuesday)),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(todayRoutineProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(todayRoutineProvider).allDone, isTrue);

    // What the app shell does when the ticker crosses midnight.
    container.read(day.notifier).state = tuesday;
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final today = container.read(todayRoutineProvider);
    expect(today.allDone, isFalse);
    expect(today.done, 0);
    expect(today.nextStep?.id, routine.orderedSteps.first.id);
  });
}
