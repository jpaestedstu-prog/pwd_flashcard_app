import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/mood_provider.dart';
import '../../mood_tracker/models/mood_context.dart';
import '../../mood_tracker/models/mood_presentation.dart';
import '../../mood_tracker/services/quick_mood_check_in.dart';
import '../../mood_tracker/widgets/mood_picker.dart';
import '../models/routine_catalog.dart';
import '../models/routine_models.dart';
import 'routine_mood_prompt.dart';

/// "It is lunch time." — the step, brought to the learner, and then the
/// question about it.
///
/// A scheduled step used to arrive as a notification in the status bar and
/// nothing more: a learner already holding the tablet at 12:00 had to notice a
/// banner to learn that it was lunch time. This is the in-app half, and it is
/// deliberately an **interstitial**: it takes the screen, says the one thing
/// that is true right now, and offers exactly two ways on.
///
/// Up to two pages, in the order the day happens:
///
///  1. **The routine.** "Time for Lunch!", the cue the educator wrote (or the
///     catalog's), and the step's own time. "I did it!" or "Later". Always.
///  2. **The mood check-in.** "How do you feel after lunch?" — the learner's
///     own faces and, where typing is not the barrier, the optional "Write why
///     you feel this way" field. **Only for a step the educator marked "ask
///     how they feel"** ([RoutineStep.asksMoodAfter]).
///
/// That second page is the educator's call, not this pop-up's. The same switch
/// already governs the question after a manual tick, and a learner asked how
/// every scheduled step of a ten-step day felt is being interviewed, not
/// checked in on. With the switch off the reminder still arrives and still
/// ticks the step — it simply says the one thing it came to say.
///
/// One route for both pages rather than two dialogs in a row: the step and the
/// question about it are one moment, and a screen that blinks back to Home in
/// between invites a learner to walk away half-answered.
///
/// Returns true when the learner said they did the step, which is the caller's
/// cue to tick it off — the write stays with the caller so the pop-up can be
/// raised from the watcher, a notification tap, or a test, and tick in exactly
/// one place. A skipped or unanswered mood does not make it false: doing the
/// step and talking about it are separate things.
Future<bool> showRoutineNowPopup(
  BuildContext context,
  WidgetRef ref,
  RoutineStep step,
) async {
  if (!context.mounted) return false;

  // A check-in step *is* the question — there is no chore to announce first,
  // and its pop-up already says "Please do your check-in now".
  if (step.activity.isMoodCheckIn) {
    return showCheckInPopup(context, ref, step);
  }

  final isFilipino = ref.read(settingsProvider).locale == 'fil';
  final presentation = ref.read(moodPresentationProvider);
  final title = RoutineCatalog.titleFor(step, filipino: isFilipino);
  final headline = isFilipino ? 'Oras na para sa $title!' : 'Time for $title!';
  final cue = RoutineCatalog.audioCueFor(step, filipino: isFilipino);
  final question = RoutineCatalog.moodQuestionFor(step, filipino: isFilipino);

  // The educator's switch decides whether there is a question at all, and
  // then it is asked once a day: a learner who already said how lunch felt is
  // not asked again because they re-opened the app.
  final askMood =
      step.asksMoodAfter &&
      !hasCheckedInFor(
        ref.read(moodProvider),
        MoodContext.afterStep,
        routineStepId: step.id,
      );

  speakMoodQuestion(ref, '$headline $cue');

  final result = await showDialog<_NowResult>(
    context: context,
    // An accidental brush with the screen — a real risk for a learner with a
    // motor disability — must not dismiss the one thing they need to see.
    barrierDismissible: false,
    builder: (_) => MoodQuestionPresence(
      child: _RoutineNowDialog(
        step: step,
        headline: headline,
        cue: cue,
        question: question,
        askMood: askMood,
        presentation: presentation,
        isFilipino: isFilipino,
        onAskMood: () => speakMoodQuestion(ref, question),
      ),
    ),
  );

  if (result == null) return false;
  final answer = result.answer;
  if (answer != null && context.mounted) {
    await recordMoodAnswer(
      context,
      ref,
      answer,
      moodContext: MoodContext.afterStep,
      step: step,
    );
  }
  return result.did;
}

/// What the learner did with the interstitial.
class _NowResult {
  const _NowResult({required this.did, this.answer});

  /// They said they did the step.
  final bool did;

  /// Their mood, if they answered the second page.
  final MoodAnswer? answer;
}

class _RoutineNowDialog extends StatefulWidget {
  const _RoutineNowDialog({
    required this.step,
    required this.headline,
    required this.cue,
    required this.question,
    required this.askMood,
    required this.presentation,
    required this.isFilipino,
    required this.onAskMood,
  });

  final RoutineStep step;
  final String headline;
  final String cue;
  final String question;

  /// Whether the mood page follows "I did it!" at all.
  final bool askMood;

  final MoodPresentation presentation;
  final bool isFilipino;

  /// Speaks the question, for the categories that are spoken to, at the moment
  /// the second page appears — not when the pop-up opens, or a learner would
  /// hear the question before the step.
  final VoidCallback onAskMood;

  @override
  State<_RoutineNowDialog> createState() => _RoutineNowDialogState();
}

class _RoutineNowDialogState extends State<_RoutineNowDialog> {
  bool _asking = false;

  void _didIt() {
    if (!widget.askMood) {
      Navigator.of(context).pop(const _NowResult(did: true));
      return;
    }
    setState(() => _asking = true);
    widget.onAskMood();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final isFilipino = widget.isFilipino;

    return PopScope(
      // On the mood page, a back press means "I would rather not say" — not
      // "I did not do it". Without this it popped the whole interstitial with
      // nothing, and the step the learner had just said they did stayed
      // unticked.
      canPop: !_asking,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _asking) {
          Navigator.of(context).pop(const _NowResult(did: true));
        }
      },
      child: Dialog(
        // Not inset by the keyboard — see the note on the check-in dialog:
        // the scroll view below carries the inset so the content clears the
        // keyboard instead of the whole dialog being squeezed above it.
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: hc.hc
              ? BorderSide(color: hc.primary, width: 2)
              : BorderSide.none,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          // Scrollable: at the largest font setting a headline, a cue and six
          // faces are taller than a phone, and the way out must stay
          // reachable.
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              24,
              20,
              12 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: _asking ? _moodPage(hc, isFilipino) : _stepPage(hc, isFilipino),
          ),
        ),
      ),
    );
  }

  /// Page 1: the routine.
  Widget _stepPage(HCColor hc, bool isFilipino) {
    final step = widget.step;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          RoutineCatalog.emojiFor(step),
          style: const TextStyle(fontSize: 44),
          textScaler: const TextScaler.linear(1.0),
        ),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(
            widget.headline,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w900,
              color: hc.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (widget.cue.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            widget.cue,
            style: AppTypography.bodyLarge.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
        if (step.isScheduled) ...[
          const SizedBox(height: 10),
          _TimeChip(step: step),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: Semantics(
            button: true,
            label: isFilipino
                ? 'Tapos na. Markahan ang hakbang na tapos.'
                : 'I did it. Mark this step done.',
            excludeSemantics: true,
            child: ElevatedButton.icon(
              onPressed: _didIt,
              icon: const Icon(Icons.check_rounded, color: Colors.white),
              label: Text(
                isFilipino ? 'Tapos na!' : 'I did it!',
                style: AppTypography.titleSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hc.primary,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
            ),
          ),
        ),
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
    );
  }

  /// Page 2: the mood check-in about the step just finished.
  Widget _moodPage(HCColor hc, bool isFilipino) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Said plainly, because the tick is a write the learner cannot see
        // behind the dialog: their answer to page 1 has been taken.
        Text(
          isFilipino ? 'Ayos! ✅' : 'Nice work! ✅',
          style: AppTypography.titleSmall.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(
            widget.question,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: hc.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        MoodPicker(
          choices: widget.presentation.choices,
          showNote: widget.presentation.showNote,
          isFilipino: isFilipino,
          onAnswer: (answer) => Navigator.of(
            context,
          ).pop(_NowResult(did: true, answer: answer)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            // Skipping the question still finishes the step: the tick is not
            // held hostage to a feeling the learner does not want to name.
            onPressed: () =>
                Navigator.of(context).pop(const _NowResult(did: true)),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(isFilipino ? 'Laktawan' : 'Skip'),
          ),
        ),
      ],
    );
  }
}

/// The step's own time — "12:00 PM" — so the pop-up says *when* as well as
/// what. Orientation for a learner who has just picked the tablet up.
class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.step});

  final RoutineStep step;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final h = step.hour!;
    final m = step.minute!.toString().padLeft(2, '0');
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    final clock = '$hour12:$m ${h < 12 ? 'AM' : 'PM'}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: hc.primary.withValues(alpha: hc.hc ? 0.28 : 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 16, color: hc.primary),
          const SizedBox(width: 6),
          Text(
            clock,
            style: AppTypography.labelMedium.copyWith(
              color: hc.textPrimary,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
