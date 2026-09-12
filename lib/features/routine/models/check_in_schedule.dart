import 'routine_models.dart';

/// When the "Please do your check-in now" pop-up should appear.
///
/// Pure — steps, the day log, the clock and the snoozes in; one step (or
/// nothing) out — so the policy that decides when a learner is interrupted is
/// testable without a device, a notification or a wall clock.
///
/// The OS notification fires at the step's time whatever the app is doing.
/// This is the *in-app* half: when the learner is already in the app at (or
/// after) check-in time, the question comes to them instead of waiting in the
/// notification shade.
class CheckInSchedule {
  const CheckInSchedule._();

  /// How long "Later" puts a check-in off for. Long enough to finish what the
  /// learner was doing; short enough that "later" still means today.
  static const Duration snoozeFor = Duration(minutes: 15);

  /// The check-in step that should pop up now, or null.
  ///
  /// A step qualifies when it is a [RoutineActivity.moodCheckIn] step that
  /// ran today, has a clock time, that time has arrived, it has not been
  /// answered, and the learner has not put it off within [snoozeFor].
  /// With several due (the app was closed all morning), the **earliest** wins —
  /// one pop-up at a time, oldest question first.
  ///
  /// [requestedStepId] is a tapped notification: the learner asked for this
  /// check-in, so it bypasses the clock and any snooze — but never the
  /// "already answered" rule, and never names a step that is not today's.
  static RoutineStep? due({
    required List<RoutineStep> todaysSteps,
    required RoutineDayLog? log,
    required DateTime now,
    Map<String, DateTime> snoozedUntil = const {},
    String? requestedStepId,
  }) {
    bool answered(RoutineStep s) => log?.isDone(s.id) ?? false;

    if (requestedStepId != null) {
      for (final s in todaysSteps) {
        if (s.id == requestedStepId &&
            s.activity.isMoodCheckIn &&
            !answered(s)) {
          return s;
        }
      }
    }

    RoutineStep? earliest;
    for (final s in todaysSteps) {
      if (!s.activity.isMoodCheckIn || !s.isScheduled || answered(s)) continue;
      final dueAt = DateTime(now.year, now.month, now.day, s.hour!, s.minute!);
      if (now.isBefore(dueAt)) continue;
      final snooze = snoozedUntil[s.id];
      if (snooze != null && now.isBefore(snooze)) continue;
      if (earliest == null || s.minutesOfDay! < earliest.minutesOfDay!) {
        earliest = s;
      }
    }
    return earliest;
  }

  /// Whether the learner is somewhere a pop-up may appear.
  ///
  /// A whitelist of calm places — the tab hubs and "My Day" itself — rather
  /// than a blacklist of busy ones. A check-in that lands in the middle of a
  /// timed game, a quiz, a story or an assessment costs the learner the thing
  /// they were doing, and the question keeps: it will be asked the moment they
  /// come back to a hub.
  static bool isCalmLocation(String location) {
    final path = location.split('?').first;
    const calm = {
      '/home',
      '/flashcards',
      '/games',
      '/stories',
      '/progress',
      '/routine',
    };
    return calm.contains(path);
  }
}
