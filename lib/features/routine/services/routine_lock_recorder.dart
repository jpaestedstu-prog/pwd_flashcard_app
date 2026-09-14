import '../models/routine_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routine_reminder_scheduler.dart';
import 'routine_service.dart';

/// What the learner's device reports about its own routine lock: that the
/// lock appeared, and that a step has waited long enough to need help.
///
/// A provider seam rather than a direct service call, because the lock screen
/// makes these reports from `build`. Every widget test that pumps the lock
/// would otherwise perform a real Hive write inside the fake-async zone, which
/// hangs the whole test file at teardown (see the project's Hive-hang notes).
/// Tests override this with a recorder that remembers instead of writing.
class RoutineLockRecorder {
  const RoutineLockRecorder();

  Future<void> lockShown(String profileId, String stepId) =>
      const RoutineService().markLockShown(profileId, DateTime.now(), stepId);

  Future<void> escalated(String profileId, String stepId) =>
      const RoutineService().markEscalated(profileId, DateTime.now(), stepId);
}

final routineLockRecorderProvider = Provider<RoutineLockRecorder>(
  (ref) => const RoutineLockRecorder(),
);

/// Raises "a learner needs help" on the educator's own device. A seam, like
/// [RoutineLockRecorder], so dashboard tests can count alerts instead of
/// touching the notification plugin.
class RoutineHelpAlerter {
  const RoutineHelpAlerter();

  Future<void> alert({
    required String key,
    required String title,
    required String body,
  }) =>
      RoutineReminderScheduler.showHelpAlert(key: key, title: title, body: body);
}

final routineHelpAlerterProvider = Provider<RoutineHelpAlerter>(
  (ref) => const RoutineHelpAlerter(),
);

/// `learner|day|step` keys already alerted on this device, so a learner who
/// needs help is announced once, not on every ten-second tick.
final routineHelpAlertedProvider = StateProvider<Set<String>>((ref) => {});

/// Starts the push that tells a stuck learner's educators, on their own
/// phones, that the learner needs help. A seam, like [RoutineLockRecorder]:
/// widget tests swap it out rather than touch Firestore.
class RoutineHelpRequester {
  const RoutineHelpRequester();

  Future<void> request({
    required String childProfileId,
    required String childName,
    required RoutineStep step,
    required List<String> educatorProfileIds,
  }) =>
      const RoutineService().requestHelpPush(
        childProfileId: childProfileId,
        childName: childName,
        step: step,
        educatorProfileIds: educatorProfileIds,
        at: DateTime.now(),
      );
}

final routineHelpRequesterProvider = Provider<RoutineHelpRequester>(
  (ref) => const RoutineHelpRequester(),
);
