/// What happens on the child's device when a [ChildAlarm] fires.
///
/// Stored as the `int` index in Firestore so adding new actions doesn't
/// rewrite existing rows. Order is therefore append-only — never reorder.
enum AlarmAction {
  /// Show a notification only. Used for gentle reminders ("Time to read")
  /// where the child stays in control.
  notifyOnly,

  /// Fire a notification AND lock the app to the [TimeUpLockScreen].
  /// Used for hard cut-offs like "Bedtime" or "Homework time over".
  /// Requires a parent/teacher PIN to dismiss.
  lockScreen,

  /// Fire a notification AND end the active learning session, returning
  /// the child to the home screen. Doesn't require PIN unlock.
  endSession,
}

/// Helper for serialising an [AlarmAction] to Firestore.
extension AlarmActionJson on AlarmAction {
  int toJson() => index;

  static AlarmAction fromJson(dynamic raw) {
    final i = (raw as int?) ?? 0;
    if (i < 0 || i >= AlarmAction.values.length) return AlarmAction.notifyOnly;
    return AlarmAction.values[i];
  }
}
