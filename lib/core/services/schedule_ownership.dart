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

  /// Hold it back while this profile is on screen, then bring it back
  /// unchanged: the schedule still belongs to the device's learner, but the
  /// profile now in use is somebody else's.
  suspend,
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

  /// Child alarms: a learner signing in schedules theirs. The educators
  /// responsible for the alarms' learner ([owner]) — whoever set one of
  /// their alarms or routines — and the profile picker leave them in place.
  /// Anyone else on a shared tablet suspends them while they are on screen:
  /// another learner, an unrelated Teacher or Parent, or a Player. Found on
  /// the tablet: a child's "Time to take a moment" alarm popped up in the
  /// middle of a different student's lesson.
  static ScheduleChange forAlarms(
    UserProfile? next, {
    String? owner,
    Set<String> responsibleEducators = const {},
  }) {
    if (isLearner(next)) return ScheduleChange.start;
    if (next == null || owner == null) return ScheduleChange.keep;
    if (next.role.isEducator && responsibleEducators.contains(next.id)) {
      return ScheduleChange.keep;
    }
    return ScheduleChange.suspend;
  }

  /// Routine reminders run for any profile with My Day switched on, a Player
  /// included. They stop only when the very profile they are scheduled for is
  /// on screen with My Day switched off — a Player turning the feature off
  /// must not cancel a Student's reminders, and an educator cannot turn off a
  /// learner's.
  ///
  /// Like child alarms, they are held back ([ScheduleChange.suspend]) while
  /// somebody else uses a shared tablet — an educator who did not set the
  /// learner's routine or alarms, or a Player with My Day off — so a child's
  /// "Please have your lunch now" (and its lock) never lands in their
  /// session. The responsible educator and the profile picker keep them.
  static ScheduleChange forRoutines({
    required UserProfile? next,
    required bool featureOn,
    required String? scheduledFor,
    Set<String> responsibleEducators = const {},
  }) {
    if (next == null) return ScheduleChange.keep;
    if (featureOn) return ScheduleChange.start;
    if (next.id == scheduledFor) return ScheduleChange.stop;
    if (scheduledFor == null) return ScheduleChange.keep;
    if (next.role.isEducator && responsibleEducators.contains(next.id)) {
      return ScheduleChange.keep;
    }
    return ScheduleChange.suspend;
  }
}
