import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/mood_provider.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../mood_tracker/models/mood_context.dart';
import '../../mood_tracker/models/mood_models.dart';
import '../../mood_tracker/models/mood_presentation.dart';
import '../../mood_tracker/services/quick_mood_check_in.dart';
import '../models/routine_catalog.dart';
import '../models/routine_models.dart';

// ─── The three questions "My Day" asks ─────────────────
//
// This file is where Mood Check-In and My Day are actually joined. Each
// question is asked at a moment that means something, and each answer is
// recorded against *that moment* — so the data reads "how brushing teeth
// felt", not merely "how the learner felt at 6:50".
//
//  1. [askAboutStep] — after a step the educator marked "ask how they feel":
//     "How do you feel after brushing your teeth?"
//  2. [showCheckInPopup] — a scheduled "Check-In Time" step comes due:
//     "Check-in time! Please do your check-in now."
//  3. [showRoutineMoodPrompt] — the last step of the day is ticked:
//     "You finished your day! How do you feel?"
//
// All three offer exactly the learner's own face set
// ([MoodPresentation.choices]), speak the question aloud for the categories
// that are spoken to, and are asked once: a question already answered today
// is not asked again.

/// Asks how the day went, once the learner has finished it.
///
/// Recorded against [MoodContext.afterRoutine], the one context an adult can
/// act on directly — a run of "tired" after a morning routine is a bedtime
/// conversation, not a mystery. "Not now" is a full-width control of its own,
/// never a small cross in a corner.
Future<void> showRoutineMoodPrompt(BuildContext context, WidgetRef ref) async {
  if (!context.mounted) return;
  if (hasCheckedInFor(ref.read(moodProvider), MoodContext.afterRoutine)) {
    return;
  }
  final isFilipino = ref.read(settingsProvider).locale == 'fil';
  final picked = await _askInSheet(
    context,
    ref,
    emoji: '🎉',
    question: MoodContext.afterRoutine.promptOf(isFilipino: isFilipino),
  );
  if (picked == null || !context.mounted) return;
  await _recordAndThank(
    context,
    ref,
    picked,
    moodContext: MoodContext.afterRoutine,
  );
}

/// Asks the question [step] earns once ticked — "How do you feel after
/// brushing your teeth?" — and records the answer against that step.
///
/// Only for steps the educator marked `askMood`, and only once per step per
/// day: ticking a step off, un-ticking it and ticking it again is not three
/// reasons to ask.
Future<void> askAboutStep(
  BuildContext context,
  WidgetRef ref,
  RoutineStep step,
) async {
  if (!context.mounted) return;
  if (hasCheckedInFor(
    ref.read(moodProvider),
    MoodContext.afterStep,
    routineStepId: step.id,
  )) {
    return;
  }
  final isFilipino = ref.read(settingsProvider).locale == 'fil';
  final picked = await _askInSheet(
    context,
    ref,
    emoji: RoutineCatalog.emojiFor(step),
    question: RoutineCatalog.moodQuestionFor(step, filipino: isFilipino),
  );
  if (picked == null || !context.mounted) return;
  await _recordAndThank(
    context,
    ref,
    picked,
    moodContext: MoodContext.afterStep,
    step: step,
  );
}

/// The scheduled check-in: "Check-in time! Please do your check-in now."
///
/// A centred pop-up rather than a bottom sheet — it arrives unprompted, at a
/// time the educator chose, and should read as *the app asking*, not as a
/// panel the learner opened. Tapping outside does not close it: an accidental
/// brush with the screen (a real risk for a learner with a motor disability)
/// must not count as an answer. "Later" is the way out, and puts the check-in
/// off for a quarter of an hour rather than for the day.
///
/// Returns true when a mood was recorded. Ticking the step off is the
/// caller's job, so the same pop-up serves the watcher and every "done"
/// control.
Future<bool> showCheckInPopup(
  BuildContext context,
  WidgetRef ref,
  RoutineStep step,
) async {
  if (!context.mounted) return false;
  final isFilipino = ref.read(settingsProvider).locale == 'fil';
  final presentation = ref.read(moodPresentationProvider);
  final question = RoutineCatalog.moodQuestionFor(step, filipino: isFilipino);

  _speakIfWanted(
    ref,
    isFilipino
        ? 'Oras na ng check-in. Pakigawa na ang iyong check-in ngayon. '
              '$question'
        : 'Check-in time. Please do your check-in now. $question',
  );

  final picked = await showDialog<MoodType>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _QuestionPresence(
      child: _CheckInDialog(
        question: question,
        choices: presentation.choices,
        isFilipino: isFilipino,
      ),
    ),
  );
  if (picked == null || !context.mounted) return false;
  return _recordAndThank(
    context,
    ref,
    picked,
    moodContext: MoodContext.checkIn,
    step: step,
  );
}

// ─── Shared plumbing ────────────────────────────────────

/// How many of these questions are on screen right now.
///
/// The check-in watcher reads [isMoodQuestionOpen] so its scheduled pop-up
/// never lands on top of a question the learner is already answering — two
/// "how do you feel?" prompts stacked is one too many.
///
/// Counted by the question widget's own lifecycle ([_QuestionPresence]), not
/// by awaiting the sheet's future. A future only completes when the route
/// pops normally; a sheet torn down with its screen (a profile switch, a
/// navigation that replaces the stack) never completes it, and a counter
/// decremented in a `finally` would then stay up for good — silently
/// blocking every later check-in until the app restarted. `dispose` always
/// runs.
int _openQuestions = 0;

/// Whether a "My Day" mood question (sheet or pop-up) is showing.
bool get isMoodQuestionOpen => _openQuestions > 0;

/// Marks a question as on screen for exactly as long as it is mounted.
class _QuestionPresence extends StatefulWidget {
  const _QuestionPresence({required this.child});

  final Widget child;

  @override
  State<_QuestionPresence> createState() => _QuestionPresenceState();
}

class _QuestionPresenceState extends State<_QuestionPresence> {
  @override
  void initState() {
    super.initState();
    _openQuestions++;
  }

  @override
  void dispose() {
    _openQuestions--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<MoodType?> _askInSheet(
  BuildContext context,
  WidgetRef ref, {
  required String emoji,
  required String question,
}) {
  final isFilipino = ref.read(settingsProvider).locale == 'fil';
  final presentation = ref.read(moodPresentationProvider);
  final reducedMotion = ref.read(settingsProvider).reducedMotion;
  _speakIfWanted(ref, question);
  return showModalBottomSheet<MoodType>(
    context: context,
    isScrollControlled: true,
    // Reduced motion turns off the drag-to-dismiss gesture (and its
    // rubber-banding); the layout and the "Not now" button are identical
    // either way, so nothing is lost by it.
    enableDrag: !reducedMotion,
    builder: (_) => _QuestionPresence(
      child: _MoodQuestionSheet(
        emoji: emoji,
        question: question,
        choices: presentation.choices,
        isFilipino: isFilipino,
      ),
    ),
  );
}

/// Speaks [text] for the categories that are spoken to — anyone already using
/// text-to-speech, and always the visual / multiple-disability learners for
/// whom the faces carry nothing (see [MoodPresentation.speakSelection]).
void _speakIfWanted(WidgetRef ref, String text) {
  if (!ref.read(moodPresentationProvider).speakSelection) return;
  // Fire and forget: a learner should never wait on the speaker.
  ref.read(ttsServiceProvider).speak(text);
}

Future<bool> _recordAndThank(
  BuildContext context,
  WidgetRef ref,
  MoodType picked, {
  required MoodContext moodContext,
  RoutineStep? step,
}) async {
  final isFilipino = ref.read(settingsProvider).locale == 'fil';
  final ok = await QuickMoodCheckIn.record(
    ref,
    mood: picked,
    context: moodContext,
    routineStepId: step?.id,
    routineActivity: step?.activity.index,
    // Frozen as the learner saw it, so a renamed step never re-labels the
    // answer (see MoodEntry.routineStepTitle).
    routineStepTitle: step == null
        ? null
        : RoutineCatalog.titleFor(step, filipino: isFilipino),
  );
  if (!context.mounted) return ok;
  if (!ok) {
    AppSnackBar.error(
      context,
      message: isFilipino
          ? 'Hindi na-save ang mood. Subukan ulit.'
          : 'Could not save your mood. Please try again.',
    );
    return false;
  }
  AppSnackBar.success(
    context,
    message: isFilipino
        ? 'Salamat! Na-record ang pakiramdam mo. ${picked.emoji}'
        : 'Thanks for telling us! ${picked.emoji}',
  );
  return true;
}

// ─── Widgets ────────────────────────────────────────────

/// The bottom sheet used after a step and at the end of the day.
class _MoodQuestionSheet extends StatelessWidget {
  const _MoodQuestionSheet({
    required this.emoji,
    required this.question,
    required this.choices,
    required this.isFilipino,
  });

  final String emoji;
  final String question;
  final List<MoodType> choices;
  final bool isFilipino;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        // Scrollable so the sheet survives the big-font settings rather than
        // clipping the "Not now" button off the bottom.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: hc.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                emoji,
                style: const TextStyle(fontSize: 34),
                textScaler: const TextScaler.linear(1.0),
              ),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: Text(
                  question,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: hc.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              _FaceGrid(choices: choices, isFilipino: isFilipino),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(isFilipino ? 'Sa susunod na lang' : 'Not now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The scheduled check-in pop-up.
class _CheckInDialog extends StatelessWidget {
  const _CheckInDialog({
    required this.question,
    required this.choices,
    required this.isFilipino,
  });

  final String question;
  final List<MoodType> choices;
  final bool isFilipino;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: hc.hc
            ? BorderSide(color: hc.primary, width: 2)
            : BorderSide.none,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        // Scrollable: at the largest font setting the question and six faces
        // are taller than a phone, and "Later" must stay reachable.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '⏰',
                style: TextStyle(fontSize: 40),
                textScaler: TextScaler.linear(1.0),
              ),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: Text(
                  isFilipino ? 'Oras na ng check-in!' : 'Check-in time!',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w900,
                    color: hc.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isFilipino
                    ? 'Pakigawa na ang iyong check-in ngayon.'
                    : 'Please do your check-in now.',
                style: AppTypography.bodyLarge.copyWith(
                  color: hc.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                question,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _FaceGrid(choices: choices, isFilipino: isFilipino),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(isFilipino ? 'Mamaya na' : 'Later'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaceGrid extends StatelessWidget {
  const _FaceGrid({required this.choices, required this.isFilipino});

  final List<MoodType> choices;
  final bool isFilipino;

  @override
  Widget build(BuildContext context) {
    // Fewer faces buy bigger targets, matching the Home card.
    final size = choices.length <= 3 ? 76.0 : 60.0;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final mood in choices)
          _Face(
            mood: mood,
            size: size,
            isFilipino: isFilipino,
            onTap: () => Navigator.of(context).pop(mood),
          ),
      ],
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.mood,
    required this.size,
    required this.isFilipino,
    required this.onTap,
  });

  final MoodType mood;
  final double size;
  final bool isFilipino;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final tint = hc.hc
        ? hc.primary
        : (hc.isDark ? mood.darkColor : mood.color);
    final label = mood.labelOf(isFilipino: isFilipino);

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      // Its own Material: this is rendered in a route above the app's, and a
      // bare InkWell there has no ink to splash on.
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: hc.hc ? 0.30 : 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: tint, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    mood.emoji,
                    style: TextStyle(
                      fontSize: size * 0.45,
                      height: 1.0,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                    textScaler: const TextScaler.linear(1.0),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  // Comfortably wider than the circle, because the label is
                  // what has to fit — not the face. Tied to the circle it was
                  // 68px, and "Frustrated" is one word wider than that, so
                  // Flutter broke it mid-word ("Frustrat / ed").
                  width: size + 40,
                  child: Text(
                    label,
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
