import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/localized_date.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../widgets/app_snack_bar.dart';
import '../models/assessment_media.dart';
import '../models/assessment_media_presentation.dart';
import '../models/assessment_models.dart';
import '../models/question_prompt.dart';
import '../services/assessment_media_store.dart';
import 'assessment_media_editor.dart';
import 'assessment_media_panel.dart';

AppLocalizations _tr(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();

/// Whether an assignment has something to *show* before the test starts.
///
/// Media only. Written instructions alone already sit on the tile a learner
/// taps, as they always have — an extra sheet for them would be one more tap
/// for every learner, the ones who find tapping hardest included, for words
/// they have just read. A signed or spoken version is different: it cannot
/// fit on a tile, and watching it must not eat into the test's clock.
bool assignmentHasBriefing(
  AssessmentAssignment assignment,
  AssessmentMediaPresentation presentation,
) => presentation.showsAnything(assignment.media);

/// The assignment's instructions — words, pictures, sound, a signed version —
/// shown *before* the test, so the clock is not running while a learner
/// watches their teacher sign what to do. Returns true to start.
///
/// The instructions used to be one italic line, cut at two lines, on the tile
/// a learner taps to begin. Nothing a Deaf or a non-reading learner could use.
Future<bool> showAssignmentBriefing(
  BuildContext context, {
  required AssessmentAssignment assignment,
  required Assessment assessment,
  required AssessmentMediaPresentation presentation,
}) async {
  final start = await showModalBottomSheet<bool>(
    context: context,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BriefingSheet(
      assignment: assignment,
      assessment: assessment,
      presentation: presentation,
    ),
  );
  return start ?? false;
}

class _BriefingSheet extends ConsumerWidget {
  final AssessmentAssignment assignment;
  final Assessment assessment;
  final AssessmentMediaPresentation presentation;

  const _BriefingSheet({
    required this.assignment,
    required this.assessment,
    required this.presentation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final t = _tr(context);
    final title = QuestionPrompt.title(
      assignment.assessmentTitle.isEmpty
          ? assessment.title
          : assignment.assessmentTitle,
      AppLocalizations.of(context),
    );
    final instructions = curlyQuotes(assignment.instructions?.trim() ?? '');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              t.assessBriefingTitle,
              style: AppTypography.headlineSmall.copyWith(
                color: hc.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$title • ${t.hubQuestionCount(assessment.questions.length)}',
            style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
          ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SpokenText(
              text: instructions,
              readAloud: presentation.offerReadAloud,
              large: presentation.largeControls,
            ),
          ],
          const SizedBox(height: 16),
          AssessmentMediaPanel(
            media: assignment.media,
            presentation: presentation,
            fallbackLabel: t.assessBriefingTitle,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(t.assessBriefingStart),
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(presentation.largeControls ? 60 : 52),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.assessBriefingLater),
          ),
        ],
      ),
    );
  }
}

/// Words in a calm panel, with a read-aloud button when the learner's
/// presentation offers one.
class _SpokenText extends ConsumerWidget {
  final String text;
  final bool readAloud;
  final bool large;

  const _SpokenText({
    required this.text,
    required this.readAloud,
    required this.large,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hc.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: AppTypography.bodyLarge.copyWith(color: hc.textPrimary),
          ),
          if (readAloud) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await ref.read(ttsServiceProvider).speak(text);
                } catch (_) {
                  // The words are on screen and in semantics regardless.
                }
              },
              icon: const Icon(Icons.record_voice_over_rounded),
              label: Text(_tr(context).assessMediaReadAloud),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, large ? 56 : 44),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Feedback, as the learner reads it ────────────────────

/// One piece of feedback, opened from the learner's Assessment Center.
Future<void> showFeedbackForLearner(
  BuildContext context, {
  required String assignmentTitle,
  required AssessmentFeedback feedback,
  required AssessmentMediaPresentation presentation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) {
      final hc = HCColor.of(sheet);
      final t = _tr(sheet);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                t.assessFeedbackOn(
                  QuestionPrompt.title(assignmentTitle, AppLocalizations.of(sheet)),
                ),
                style: AppTypography.titleLarge.copyWith(
                  color: hc.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${t.assessFeedbackFromEducator} • '
              '${LocalizedDate.monthDayYear(feedback.updatedAt, AppLocalizations.of(sheet))}',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
            if (feedback.note.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _SpokenText(
                text: curlyQuotes(feedback.note.trim()),
                readAloud: presentation.offerReadAloud,
                large: presentation.largeControls,
              ),
            ],
            const SizedBox(height: 16),
            AssessmentMediaPanel(
              media: feedback.media,
              presentation: presentation,
              fallbackLabel: t.assessFeedbackFromEducator,
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(sheet).maybePop(),
              icon: const Icon(Icons.close_rounded),
              label: Text(t.assessMediaClose),
            ),
          ],
        ),
      );
    },
  );
}

// ─── Feedback, as the educator writes it ──────────────────

/// What the educator decided in the feedback editor. [feedback] is null when
/// they removed it. [ledger] says which picked files to let go of once the
/// change is stored.
typedef FeedbackEdit = ({
  AssessmentFeedback? feedback,
  AssessmentMediaLedger ledger,
});

/// Write, show or sign feedback on one learner's work. Null when cancelled —
/// in which case any file picked meanwhile has already been cleaned up.
Future<FeedbackEdit?> showFeedbackEditor(
  BuildContext context, {
  required String learnerName,
  required String assignmentTitle,
  required String ownerKey,
  AssessmentFeedback? existing,
  AssessmentResult? result,
  List<String> tips = const [],
}) {
  return showModalBottomSheet<FeedbackEdit>(
    context: context,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FeedbackEditorSheet(
      learnerName: learnerName,
      assignmentTitle: assignmentTitle,
      ownerKey: ownerKey,
      existing: existing,
      result: result,
      tips: tips,
    ),
  );
}

class _FeedbackEditorSheet extends StatefulWidget {
  final String learnerName;
  final String assignmentTitle;
  final String ownerKey;
  final AssessmentFeedback? existing;
  final AssessmentResult? result;
  final List<String> tips;

  const _FeedbackEditorSheet({
    required this.learnerName,
    required this.assignmentTitle,
    required this.ownerKey,
    required this.existing,
    required this.result,
    required this.tips,
  });

  @override
  State<_FeedbackEditorSheet> createState() => _FeedbackEditorSheetState();
}

class _FeedbackEditorSheetState extends State<_FeedbackEditorSheet> {
  late final TextEditingController _note = TextEditingController(
    text: widget.existing?.note ?? '',
  );
  late AssessmentMedia _media = widget.existing?.media ?? AssessmentMedia.none;
  late final AssessmentMediaLedger _ledger = AssessmentMediaLedger(_media);
  bool _committed = false;

  @override
  void dispose() {
    // Swiped away or cancelled: whatever was picked belongs to nothing.
    if (!_committed) {
      const AssessmentMediaStore().discard(_ledger.toDiscardOnCancel());
    }
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final entry = AssessmentFeedback(
      note: _note.text.trim(),
      media: _media,
      updatedAt: DateTime.now(),
    );
    if (entry.isEmpty) {
      AppSnackBar.warning(context, message: _tr(context).assessFeedbackEmpty);
      return;
    }
    _committed = true;
    Navigator.of(context).pop((feedback: entry, ledger: _ledger));
  }

  void _remove() {
    _committed = true;
    Navigator.of(context).pop((feedback: null, ledger: _ledger));
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final t = _tr(context);
    final result = widget.result;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                t.assessFeedbackFor(widget.learnerName),
                style: AppTypography.titleLarge.copyWith(
                  color: hc.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              QuestionPrompt.title(
                widget.assignmentTitle,
                AppLocalizations.of(context),
              ),
              style: AppTypography.bodyMedium.copyWith(
                color: hc.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result == null
                  ? t.assessFeedbackNotFinished
                  : t.assessFeedbackScore((result.percentage * 100).round()),
              style: AppTypography.labelLarge.copyWith(
                color: result == null ? hc.textSecondary : AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLines: 5,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: assessmentFieldDecoration(
                context,
                label: t.assessFeedbackNote,
                hint: t.assessFeedbackNoteHint,
              ),
            ),
            const SizedBox(height: 20),
            AssessmentMediaEditor(
              value: _media,
              onChanged: (m) => setState(() => _media = m),
              ownerKey: widget.ownerKey,
              ledger: _ledger,
              tips: widget.tips,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.send_rounded),
              label: Text(t.assessFeedbackSave),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (widget.existing != null)
              TextButton.icon(
                onPressed: _remove,
                style: TextButton.styleFrom(foregroundColor: hc.error),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(t.assessFeedbackRemove),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(t.hubCancel),
            ),
          ],
        ),
      ),
    );
  }
}
