import '../../data/models/enums.dart';
import '../../data/models/models.dart';

/// What a change of active profile does to a schedule already on the device.
enum ScheduleChange {
  /// (Re)schedule for the profile now on screen.
  start,

  /// Leave what is scheduled exactly as it is.
  keep,

  /// Cancel it: the profile it was for turned it off.
  stop,
}

/// Child alarms and routine reminders belong to **the learner who uses this
/// device**, not to whoever happens to be on screen.
///
/// They used to follow the active profile blindly, so the moment a teacher
/// opened their dashboard on the learner's tablet — or the profile picker was
/// simply showing — every alarm the learner had was cancelled, and came back
/// only when the learner signed in again. Found on the tablet: the child's
/// 1:20 PM alarms vanished while RoutineTeacher was signed in.
///
/// Pure, so the rules are tested without a plugin or a device.
class ScheduleOwnership {
  const ScheduleOwnership._();

  /// A Student or Child — the profiles alarms can lock.
  static bool isLearner(UserProfile? p) =>
      p != null &&
      (p.role == UserRole.student || p.role == UserRole.child) &&
      !p.isGuestPlayer;

  /// Child alarms: a learner signing in schedules theirs; anyone else leaves
  /// the last learner's alarms in place.
  static ScheduleChange forAlarms(UserProfile? next) =>
      isLearner(next) ? ScheduleChange.start : ScheduleChange.keep;

  /// Routine reminders run for any profile with My Day switched on, a Player
  /// included. They stop only when the very profile they are scheduled for is
  /// on screen with My Day switched off — a Player turning the feature off
  /// must not cancel a Student's reminders, and an educator cannot turn off a
  /// learner's.
  static ScheduleChange forRoutines({
    required UserProfile? next,
    required bool featureOn,
    required String? scheduledFor,
  }) {
    if (next == null) return ScheduleChange.keep;
    if (featureOn) return ScheduleChange.start;
    return next.id == scheduledFor ? ScheduleChange.stop : ScheduleChange.keep;
  }
}
