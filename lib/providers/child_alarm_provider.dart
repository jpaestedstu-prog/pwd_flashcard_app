import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/child_alarm.dart';
import '../features/parent/services/child_alarm_service.dart';

/// Live stream of every alarm targeting one child.
///
/// Watched by:
///   • [ChildAlarmsScreen] — the parent's editor UI.
///   • `AlarmScheduler` on the child's device, which calls
///     `rescheduleAll(profileId, list)` on every emission so the OS-level
///     notifications mirror Firestore.
final childAlarmListProvider =
    StreamProvider.family<List<ChildAlarm>, String>(
  (ref, childProfileId) {
    return const ChildAlarmService().watchForChild(childProfileId);
  },
);

/// One-shot fetch of every alarm authored by an educator. Used by the
/// "alarms I've set" overview screens.
final childAlarmsBySetterProvider =
    FutureProvider.family<List<ChildAlarm>, String>(
  (ref, setterProfileId) {
    return const ChildAlarmService().listForSetter(setterProfileId);
  },
);
