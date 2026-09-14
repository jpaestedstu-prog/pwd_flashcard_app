import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/routine_models.dart';
import 'routine_reminder_scheduler.dart';
import 'routine_service.dart';

/// Writes "this step's time is over" into a Student's or Child's day log.
///
/// Their steps are never ticked by the learner: a step is finished when its
/// time ends ([RoutineService.finishEndedSteps]), and then its reminder, if
/// one is still waiting, has nothing left to say.
///
/// A provider as well as a service, so widget tests can replace it: an awaited
/// Hive write inside `testWidgets` hangs the whole file.
class RoutineTimeFinisher {
  const RoutineTimeFinisher();

  /// Records every step of [steps] that has ended by [now]; true when
  /// anything was written.
  Future<bool> finish(
    String profileId,
    DateTime day,
    List<RoutineStep> steps, {
    required DateTime now,
  }) async {
    final log = await const RoutineService().finishEndedSteps(
      profileId,
      day,
      steps,
      now: now,
    );
    if (log == null) return false;
    await RoutineReminderScheduler.refreshSettled();
    return true;
  }
}

final routineTimeFinisherProvider = Provider<RoutineTimeFinisher>(
  (ref) => const RoutineTimeFinisher(),
);
