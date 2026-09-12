import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/routine_provider.dart';
import '../models/routine_catalog.dart';
import '../models/routine_models.dart';
import '../models/routine_presentation.dart';
import 'routine_service.dart';

/// What ticking a step off actually did.
class RoutineTickResult {
  const RoutineTickResult({
    required this.log,
    required this.wasDone,
    required this.dayComplete,
    required this.scheduledCount,
  });

  /// The day log after the tick.
  final RoutineDayLog log;

  /// Whether the step was already ticked (so this was an *un*-tick).
  final bool wasDone;

  /// Whether every step scheduled for today is now done. False for an
  /// un-tick, and false when nothing was scheduled — an empty day is not an
  /// achievement.
  final bool dayComplete;

  /// How many steps ran today, for the caller's own messaging.
  final int scheduledCount;
}

/// Ticking a routine step off, in one place.
///
/// There are now three ways to complete a step — the "My Day" list, the step
/// detail screen's "I did it!", and the Home card's Done button — and they all
/// have to behave identically: the same local-first write, the same sound cue
/// and spoken confirmation for the accessibility categories that get them, and
/// the same provider invalidation so every surface showing the day refreshes
/// together. Three copies of that is three chances for the Home shortcut to
/// quietly become a lesser version of the real thing.
///
/// Pure in the ways that matter: it takes the [RoutinePresentation] rather
/// than deciding per-disability policy itself, and it reports whether the day
/// just became complete rather than deciding what to do about it (see
/// `routineMoodPrompt`).
class RoutineStepAction {
  const RoutineStepAction._();

  /// Toggles [step] for [profileId] on [day] and runs the shared
  /// after-effects.
  ///
  /// [todaysSteps] is what ran today, used to answer "did that finish the
  /// day?". Pass the same ordered list the caller is displaying.
  static Future<RoutineTickResult> toggle({
    required WidgetRef ref,
    required String profileId,
    required DateTime day,
    required RoutineStep step,
    required List<RoutineStep> todaysSteps,
    required RoutinePresentation presentation,
    required bool filipino,
  }) async {
    // Hive, not `RoutineService.dayLog`: that merges a Firestore read, and a
    // network round-trip has no business between a child's tap and their
    // checkmark.
    final wasDone = HiveService.getRoutineDayLog(
      profileId,
      day,
    ).completedStepIds.contains(step.id);

    final log = await const RoutineService().toggleStep(
      profileId,
      day,
      step.id,
    );

    // Invalidate rather than setState: the day log is provider state and the
    // local write has already landed in Hive, so every surface watching the
    // day (the list, the Home card, the streak) re-reads together.
    ref.invalidate(routineDayLogProvider(routineDayKey(profileId, day)));

    final doneNow = todaysSteps
        .where((s) => log.completedStepIds.contains(s.id))
        .length;
    final dayComplete =
        !wasDone && todaysSteps.isNotEmpty && doneNow >= todaysSteps.length;

    if (!wasDone) {
      if (presentation.playSoundCues) {
        await ref.read(soundServiceProvider).playCorrect();
      }
      if (presentation.announceProgress) {
        final title = RoutineCatalog.titleFor(step, filipino: filipino);
        final tts = ref.read(ttsServiceProvider);
        await (filipino
            ? tts.speakFilipino('Tapos na ang $title. Magaling!')
            : tts.speakEnglish('$title done. Well done!'));
      }
    }

    return RoutineTickResult(
      log: log,
      wasDone: wasDone,
      dayComplete: dayComplete,
      scheduledCount: todaysSteps.length,
    );
  }
}
