import 'routine_models.dart';

/// When "My Day" should interrupt the learner with a pop-up.
///
/// Pure — steps, the day log, the clock and the snoozes in; one step (or
/// nothing) out — so the policy that decides when a child is interrupted is
/// testable without a device, a notification or a wall clock.
///
/// The OS notification fires at the step's time whatever the app is doing.
/// This is the *in-app* half: when the learner is already in the app, the step
/// comes to them — "It is lunch time." — instead of waiting in the
/// notification shade.
class RoutinePopupSchedule {
  const RoutinePopupSchedule._();

  /// How long "Later" puts a step off for. Long enough to finish what the
  /// learner was doing; short enough that "later" still means today.
  static const Duration snoozeFor = Duration(minutes: 15);

  /// How long after its time a **task** step still pops up.
  ///
  /// "Time to eat lunch!" at eight in the evening is not a reminder, it is a
  /// mistake — the moment has passed and the pop-up would only be in the way.
  /// A missed task is left to the list, where the learner can still tick it.
  /// A **check-in** has no such window: "how do you feel?" is worth asking
  /// whenever it is answered, so it stays due until it is.
  static const Duration taskFreshness = Duration(hours: 1);

  /// The step that should pop up now, or null.
  ///
  /// A step qualifies when it ran today, has a clock time, that time has
  /// arrived (and, for a task, has not gone stale), it is not done, and the
  /// learner has not put it off within [snoozeFor]. With several due — the app
  /// was closed all morning — the **earliest** wins: one pop-up at a time,
  /// oldest first.
  ///
  /// [skippedStepIds] are the steps an adult waved past for today on the
  /// routine lock (`RoutineLockSkips`). An adult who has just excused a step
  /// from holding the device has excused it, full stop — asking for the same
  /// step again in a pop-up two seconds later would undo their decision and
  /// make the gate look broken.
  ///
  /// [requestedStepId] is a tapped notification: the learner asked for this
  /// step, so it bypasses the clock, the freshness window and any snooze — but
  /// never the "already done" rule, and never names a step that is not
  /// today's.
  static RoutineStep? due({
    required List<RoutineStep> todaysSteps,
    required RoutineDayLog? log,
    required DateTime now,
    Map<String, DateTime> snoozedUntil = const {},
    Set<String> skippedStepIds = const <String>{},
    String? requestedStepId,
  }) {
    bool done(RoutineStep s) => log?.isDone(s.id) ?? false;

    if (requestedStepId != null) {
      for (final s in todaysSteps) {
        if (s.id == requestedStepId &&
            s.isScheduled &&
            !done(s) &&
            !skippedStepIds.contains(s.id)) {
          return s;
        }
      }
    }

    RoutineStep? earliest;
    for (final s in todaysSteps) {
      if (!s.isScheduled || done(s)) continue;
      if (skippedStepIds.contains(s.id)) continue;
      final dueAt = DateTime(now.year, now.month, now.day, s.hour!, s.minute!);
      if (now.isBefore(dueAt)) continue;
      if (!s.activity.isMoodCheckIn && now.difference(dueAt) > taskFreshness) {
        continue;
      }
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
  /// than a blacklist of busy ones. A pop-up that lands in the middle of a
  /// timed game, a quiz, a story or an assessment costs the learner the thing
  /// they were doing, and it keeps: it will be raised the moment they come
  /// back to a hub.
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
