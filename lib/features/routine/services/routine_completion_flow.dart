import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/hive_service.dart';
import '../models/routine_models.dart';
import '../models/routine_presentation.dart';
import '../widgets/routine_mood_prompt.dart';
import 'routine_step_action.dart';

/// Finishing one step of "My Day", including the question it earns.
///
/// [RoutineStepAction] is the write (tick, sound, speech, refresh). This is the
/// conversation around it, and it is what every "done" control calls — the
/// list's tick, the step screen's "I did it!", the Home card's Done button —
/// so the learner meets the same questions whichever way they finish a step:
///
///  * **A check-in step is answered, not ticked.** Its "done" opens the
///    check-in; picking a face records the mood *and* ticks the step. Backing
///    out leaves it undone. A check-in marked done with no answer would be a
///    lie in the day log and a hole in the data.
///  * **A step the educator marked "ask how they feel"** asks its own
///    question — "How do you feel after brushing your teeth?" — once ticked.
///  * **The last step of the day** asks how the day went — unless the step
///    that finished it already asked a question. One question per tap, never
///    two sheets stacked.
///  * **Un-ticking** asks nothing.
class RoutineCompletionFlow {
  const RoutineCompletionFlow._();

  /// Completes (or un-completes) [step] and asks whatever it earns.
  ///
  /// [todaysSteps] is the day as the caller is displaying it, used to tell
  /// whether this tap finished the day. Pass null where the caller does not
  /// know the whole day (a step screen opened on its own); the day-end
  /// question is then simply not asked from there.
  static Future<void> complete({
    required BuildContext context,
    required WidgetRef ref,
    required String profileId,
    required DateTime day,
    required RoutineStep step,
    required List<RoutineStep>? todaysSteps,
    required RoutinePresentation presentation,
    required bool filipino,
  }) async {
    final wasDone = HiveService.getRoutineDayLog(
      profileId,
      day,
    ).completedStepIds.contains(step.id);

    if (step.activity.isMoodCheckIn && !wasDone) {
      final answered = await showCheckInPopup(context, ref, step);
      if (!answered || !context.mounted) return;
      await RoutineStepAction.toggle(
        ref: ref,
        profileId: profileId,
        day: day,
        step: step,
        todaysSteps: todaysSteps ?? const <RoutineStep>[],
        presentation: presentation,
        filipino: filipino,
      );
      // They have just said how they feel. Asking "how did your day go?" on
      // the next frame — even if this finished the day — is the same question
      // twice.
      return;
    }

    final result = await RoutineStepAction.toggle(
      ref: ref,
      profileId: profileId,
      day: day,
      step: step,
      todaysSteps: todaysSteps ?? const <RoutineStep>[],
      presentation: presentation,
      filipino: filipino,
    );
    if (result.wasDone || !context.mounted) return;

    if (step.asksMoodAfter) {
      await askAboutStep(context, ref, step);
      return;
    }
    if (result.dayComplete) {
      await showRoutineMoodPrompt(context, ref);
    }
  }
}
