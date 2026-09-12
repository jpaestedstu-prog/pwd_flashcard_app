import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/mood_provider.dart';
import '../models/mood_context.dart';
import '../models/mood_presentation.dart';
import '../models/mood_models.dart';

/// Today's most recent check-in, or null.
///
/// One implementation, because "has this learner checked in today?" is now
/// asked by the Home card, the Child home card, the post-routine prompt and
/// the mood screen, and four copies of a same-calendar-day comparison is four
/// chances to get the midnight boundary wrong.
MoodEntry? todaysMoodFrom(List<MoodEntry> entries, {DateTime? now}) {
  final today = now ?? DateTime.now();
  MoodEntry? latest;
  for (final e in entries) {
    final t = e.timestamp;
    if (t.year != today.year || t.month != today.month || t.day != today.day) {
      continue;
    }
    if (latest == null || t.isAfter(latest.timestamp)) latest = e;
  }
  return latest;
}

/// The signed-in learner's latest check-in today, live.
final todaysMoodProvider = Provider<MoodEntry?>((ref) {
  return todaysMoodFrom(ref.watch(moodProvider));
});

/// Today's latest answer that belongs to **My Day**, or null.
///
/// A step question ("How do you feel after brushing your teeth?"), a scheduled
/// check-in, or the end-of-day question — the answers the routine itself
/// collected. A plain Home check-in is deliberately excluded: it says how the
/// learner is, not how their day went, and the My Day card would be claiming
/// something it never asked.
MoodEntry? todaysRoutineMoodFrom(List<MoodEntry> entries, {DateTime? now}) {
  final today = now ?? DateTime.now();
  MoodEntry? latest;
  for (final e in entries) {
    final t = e.timestamp;
    if (t.year != today.year || t.month != today.month || t.day != today.day) {
      continue;
    }
    final linked = e.routineStepId != null ||
        MoodContextX.fromKey(e.activityContext) == MoodContext.afterRoutine;
    if (!linked) continue;
    if (latest == null || t.isAfter(latest.timestamp)) latest = e;
  }
  return latest;
}

/// The signed-in learner's latest My Day answer today, live.
final todaysRoutineMoodProvider = Provider<MoodEntry?>((ref) {
  return todaysRoutineMoodFrom(ref.watch(moodProvider));
});

/// Whether the learner has already answered *for a given moment* today.
///
/// The post-routine prompt uses this: a learner who said how they felt this
/// morning has not yet said how finishing their day felt, and re-asking the
/// second question is not nagging. Asking the same question twice is.
///
/// [routineStepId] narrows it to one step: having answered "How did you feel
/// when you woke up?" does not answer "How do you feel after brushing your
/// teeth?", even though both are [MoodContext.afterStep].
bool hasCheckedInFor(
  List<MoodEntry> entries,
  MoodContext context, {
  String? routineStepId,
  DateTime? now,
}) =>
    _todaysAnswerFor(entries, context, routineStepId, now: now) != null;

/// Today's latest answer to one specific question, or null.
MoodEntry? _todaysAnswerFor(
  List<MoodEntry> entries,
  MoodContext context,
  String? routineStepId, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  MoodEntry? latest;
  for (final e in entries) {
    final t = e.timestamp;
    if (t.year != today.year || t.month != today.month || t.day != today.day) {
      continue;
    }
    if (MoodContextX.fromKey(e.activityContext) != context) continue;
    if (e.routineStepId != routineStepId) continue;
    if (latest == null || t.isAfter(latest.timestamp)) latest = e;
  }
  return latest;
}

/// Records a mood in one tap, from wherever the learner is.
///
/// The full check-in screen exists for the things a screen is for — a written
/// note, correcting an earlier entry, the history — but answering "how are
/// you?" should not cost a screen change. A daily habit dies at the
/// navigation step, and for the learners this app is built for that step is
/// the expensive part.
///
/// Behaviour matches `MoodCheckInScreen._saveMood` deliberately: the same
/// haptic, the same spoken confirmation for the categories whose
/// [MoodPresentation.speakSelection] is on, and the same **correct in place**
/// rule — a learner who taps the wrong face is fixing today's answer, not
/// filing a second reading of the same moment.
class QuickMoodCheckIn {
  const QuickMoodCheckIn._();

  /// Saves [mood] for today against [context]. Returns false if the write
  /// failed, so the caller can tell the learner rather than pretending.
  ///
  /// [routineStepId] / [routineActivity] / [routineStepTitle] tie the answer
  /// to one step of "My Day" (see `MoodEntry.routineStepId`).
  ///
  /// [note] is the learner's own "why you feel this way", offered wherever
  /// typing is not itself the barrier ([MoodPresentation.showNote]). Passing
  /// null when re-answering leaves an earlier note alone rather than wiping
  /// it: a corrected face is not a retracted sentence.
  static Future<bool> record(
    WidgetRef ref, {
    required MoodType mood,
    String? note,
    MoodContext context = MoodContext.general,
    String? routineStepId,
    int? routineActivity,
    String? routineStepTitle,
  }) async {
    // Correct in place only when it is the *same question* being re-answered:
    // the same moment, and for a step question the same step. A morning
    // "happy", an after-brushing "tired" and an after-my-day "okay" are three
    // facts, and overwriting one with another would erase the very pattern
    // the insights screen exists to show.
    final existing = _todaysAnswerFor(
      ref.read(moodProvider),
      context,
      routineStepId,
    );
    try {
      if (existing != null) {
        await ref
            .read(moodProvider.notifier)
            .updateMood(existing.id, mood, note: note);
      } else {
        await ref.read(moodProvider.notifier).addMood(
              mood: mood,
              note: note,
              context: context,
              routineStepId: routineStepId,
              routineActivity: routineActivity,
              routineStepTitle: routineStepTitle,
            );
      }
    } catch (_) {
      return false;
    }

    ref.read(hapticServiceProvider).success();

    final isFilipino = ref.read(settingsProvider).locale == 'fil';
    if (ref.read(moodPresentationProvider).speakSelection) {
      final label = mood.labelOf(isFilipino: isFilipino);
      // Fire and forget — a learner should never wait on the speaker.
      ref.read(ttsServiceProvider).speak(
            isFilipino
                ? 'Na-save. Ang pakiramdam mo ay $label.'
                : 'Saved. You are feeling $label.',
          );
    }
    return true;
  }
}
