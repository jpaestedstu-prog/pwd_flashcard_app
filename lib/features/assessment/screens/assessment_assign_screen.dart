import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/models.dart';
import '../../../core/accessibility/accessibility_content_policy.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/student_list_provider.dart';
import '../models/assessment_media.dart';
import '../models/assessment_models.dart';
import '../models/custom_quiz_models.dart';
import '../providers/assessment_provider.dart';
import '../providers/quiz_builder_provider.dart';
import '../services/assessment_cloud_service.dart';
import '../services/assessment_media_store.dart';
import '../services/assessment_service.dart';
import '../widgets/assessment_media_editor.dart';
import '../../../widgets/app_back_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../core/utils/localized_date.dart';
import '../models/question_prompt.dart';

/// Something an educator can hand out.
///
/// Two things qualify and they are not the same shape. A saved [Assessment]
/// already *is* a fixed set of questions. A [CustomQuiz] is only a recipe —
/// card ids plus permitted formats — that re-rolls its questions on every play.
/// Handing a recipe out directly would give each learner a different test and
/// leave the educator's tracking with nothing stable to line up against, so a
/// quiz is materialised into an immutable Assessment at the moment it is
/// assigned. See [AssessmentService.materialiseQuiz].
class AssignableItem {
  /// Selection key only — the quiz id or the assessment id. The assessment
  /// that actually gets assigned may have a different, freshly minted id.
  final String id;
  final String title;
  final int questionCount;
  final GameDifficulty difficulty;

  /// When this was made. Two assignments of one quiz produce two assessments
  /// with the same title, so the date is what tells them apart in the list.
  final DateTime createdAt;
  final Assessment? assessment;
  final CustomQuiz? quiz;

  /// Set for the two halves of the study instrument, which are minted fresh
  /// at assign time rather than picked from a saved list.
  final AssessmentType? instrument;

  AssignableItem.fromAssessment(Assessment this.assessment)
    : id = assessment.id,
      title = assessment.title,
      questionCount = assessment.questions.length,
      difficulty = assessment.difficulty,
      createdAt = assessment.createdAt,
      quiz = null,
      instrument = null;

  /// The class pre-test or post-test. [title] and [questionCount] describe
  /// what *will* be minted; nothing exists until the educator presses Assign.
  AssignableItem.instrument(
    AssessmentType this.instrument, {
    required this.title,
    required this.questionCount,
  }) : id = 'instrument:${instrument.name}',
       difficulty = GameDifficulty.medium,
       createdAt = DateTime.now(),
       assessment = null,
       quiz = null;

  AssignableItem.fromQuiz(CustomQuiz this.quiz)
    : id = quiz.id,
      title = quiz.title,
      questionCount = quiz.flashcardIds.length,
      difficulty = quiz.difficulty,
      createdAt = quiz.createdAt,
      assessment = null,
      instrument = null;

  bool get isQuiz => quiz != null;
  bool get isInstrument => instrument != null;

  /// Whether assigning this hands out a post-test — the Class Post-Test tile,
  /// or a class post-test already sitting under "Saved assessments". Both are
  /// minted afresh per learner group so each learner's post-test mirrors the
  /// pre-test *they* sat: re-sending a saved one as-is would give every
  /// selected learner that one form, whichever pre-test they took.
  bool get isPostTest =>
      instrument == AssessmentType.postTest ||
      assessment?.type == AssessmentType.postTest;
}

/// Screen for educators to assign an assessment to students.
class AssessmentAssignScreen extends ConsumerStatefulWidget {
  const AssessmentAssignScreen({super.key});

  @override
  ConsumerState<AssessmentAssignScreen> createState() =>
      _AssessmentAssignScreenState();
}

class _AssessmentAssignScreenState
    extends ConsumerState<AssessmentAssignScreen> {
  AssignableItem? _selected;
  final Set<String> _selectedStudentIds = {};
  DateTime? _deadline;
  final _instructionsController = TextEditingController();
  bool _saving = false;

  /// Pictures, video, sound or a signed version of the instructions. One
  /// value shared by every batch this screen mints — the files are referred
  /// to, not owned, so two post-test groups can point at the same clip.
  AssessmentMedia _instructionsMedia = AssessmentMedia.none;
  final _mediaLedger = AssessmentMediaLedger();
  final String _mediaOwnerKey = 'asg_${const Uuid().v4()}';

  /// Set once the work has gone out; until then a picked file belongs to
  /// nothing and is removed when the screen closes.
  bool _assigned = false;

  /// Assessments this educator may hand out, and the learners they may hand
  /// them to. Both are read in `build`, never cached in `initState`: each is
  /// backed by a Firestore pull that can land *after* this screen opens.
  ///
  /// The roster in particular spans classroom students *and* home-group
  /// children — the old local `role == UserRole.student` read showed a Parent
  /// "No students found" and hid cross-device students from teachers.
  List<AssignableItem> _quizzes = const [];
  List<AssignableItem> _saved = const [];
  List<({String id, String name})> _students = const [];

  /// Full profiles for the roster, keyed by id — the class instrument needs
  /// each selected learner's accessibility and supports to decide whether it
  /// may include sign items.
  Map<String, UserProfile> _profiles = const {};

  /// The two study-instrument tiles. Rebuilt every build, because the
  /// post-test only appears once a class pre-test exists to mirror.
  List<AssignableItem> _instruments = const [];

  @override
  void dispose() {
    if (!_assigned) {
      const AssessmentMediaStore().discard(_mediaLedger.toDiscardOnCancel());
    }
    _instructionsController.dispose();
    super.dispose();
  }

  bool get _isParent => ref.read(profileProvider)?.role == UserRole.parent;

  bool get _canAssign => _selected != null && _selectedStudentIds.isNotEmpty;

  Future<void> _assign() async {
    if (!_canAssign || _saving) return;
    setState(() => _saving = true);

    final profile = ref.read(profileProvider);
    final selected = _selected!;

    // A quiz becomes a real assessment here, with a fresh id, and is saved
    // through the same notifier as any other — so it syncs to the cloud and
    // the learner's device can resolve it by id like anything else. Assigning
    // the same quiz twice therefore mints two instruments, which is right:
    // they are two sittings and they are tracked separately.
    //
    // Each batch is one assessment and the learners it goes to. Only the
    // class post-test ever makes more than one: every learner's post-test
    // mirrors the class pre-test *they* sat — see classPostTestPlan.
    final batches = <(Assessment, List<String>)>[];
    if (selected.isPostTest) {
      // Pair against the results as they stand *now*: a learner who sat the
      // pre-test on their own tablet after this screen opened is only known
      // here once pulled, and without it they would be paired with the
      // newest class pre-test instead of their own.
      ref.invalidate(educatorAssessmentSyncProvider(profile!.id));
      try {
        await ref.read(educatorAssessmentSyncProvider(profile.id).future);
      } catch (_) {
        // Offline: pair with what this device already has.
      }
      if (!mounted) return;
      final plan = AssessmentService.classPostTestPlan(
        profile.id,
        _selectedStudentIds,
      );
      if (plan.isEmpty) {
        setState(() => _saving = false);
        AppSnackBar.warning(
          context,
          message: _tr(context).asgPreFirst,
        );
        return;
      }
      for (final group in plan) {
        final post = AssessmentService.createClassPostTest(group.pre);
        await ref.read(customAssessmentsProvider.notifier).saveAssessment(post);
        batches.add((post, group.learners));
      }
    } else if (selected.isInstrument) {
      final pre = _mintClassPreTest(profile!.id);
      await ref.read(customAssessmentsProvider.notifier).saveAssessment(pre);
      batches.add((pre, _selectedStudentIds.toList()));
    } else if (selected.isQuiz) {
      final target = AssessmentService.materialiseQuiz(
        selected.quiz!,
        ref.read(allFlashcardsProvider),
      );
      if (target.questions.isEmpty) {
        setState(() => _saving = false);
        AppSnackBar.warning(
          context,
          message: _tr(context).asgQuizEmpty,
        );
        return;
      }
      await ref.read(customAssessmentsProvider.notifier).saveAssessment(target);
      batches.add((target, _selectedStudentIds.toList()));
    } else {
      batches.add((selected.assessment!, _selectedStudentIds.toList()));
    }

    // The enum runs best to worst, so the snackbar reports the worst batch.
    var outcome = CloudSyncOutcome.synced;
    for (final (target, learners) in batches) {
      final assignment = AssessmentAssignment(
        id: const Uuid().v4(),
        assessmentId: target.id,
        assessmentTitle: target.title,
        assignedBy: profile!.id,
        studentIds: learners,
        assignedAt: DateTime.now(),
        deadline: _deadline,
        instructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
        media: _instructionsMedia,
      );
      final result = await ref
          .read(assignmentsProvider.notifier)
          .saveAssignment(assignment);
      if (result.index > outcome.index) outcome = result;
    }
    _assigned = true;
    // A file picked and then removed before assigning belongs to nothing.
    await const AssessmentMediaStore().discardUnreferenced(
      _mediaLedger.toDiscardOnSave(_instructionsMedia),
    );

    if (mounted) {
      final count = _selectedStudentIds.length;
      final t = _tr(context);
      switch (outcome) {
        case CloudSyncOutcome.synced:
          AppSnackBar.success(
            context,
            message: t.asgAssigned(count),
          );
        case CloudSyncOutcome.localOnly:
          // Never claim it went out when it didn't: the row is safe locally
          // and re-uploads on the next connected open, but nobody else has it
          // yet. Deliberately doesn't name a cause — offline and "rules not
          // deployed" both land here, and telling a teacher to check their
          // wifi when the real problem is a missing deploy sends them the
          // wrong way.
          AppSnackBar.warning(
            context,
            message: t.asgLocalOnly(count),
          );
        case CloudSyncOutcome.notOwner:
          // This one is never going out, so saying "not yet" would be a lie
          // that costs a teacher a lesson. Names the cause because there is a
          // cause, and it is something they did and can undo.
          AppSnackBar.warning(
            context,
            message: t.asgNotOwner,
          );
      }
      context.pop();
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedStudentIds.length == _students.length) {
        _selectedStudentIds.clear();
      } else {
        _selectedStudentIds
          ..clear()
          ..addAll(_students.map((s) => s.id));
      }
    });
  }

  /// Build the class pre-test for the learners now selected: one common set
  /// of questions for everyone, with sign items only if every selected
  /// learner signs. (Each post-test is the parallel form of the pre-test its
  /// learners sat, so it inherits whatever that one had.)
  Assessment _mintClassPreTest(String educatorId) {
    final available =
        ref.read(fslAvailabilityProvider).valueOrNull?.cardsWithVideo ??
        const <Flashcard>[];
    final signCards = AssessmentService.signCardsForGroup<String>(
      _selectedStudentIds,
      (id) {
        final learner = _profiles[id];
        return learner != null &&
            AccessibilityContentPolicy.forLearner(
              learner.disabilityType,
              learner.supportOptions,
            ).showFsl;
      },
      available,
    );
    return AssessmentService.createClassPreTest(
      educatorId: educatorId,
      signCards: signCards,
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 23, minute: 59),
      );
      setState(() {
        _deadline = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time?.hour ?? 23,
          time?.minute ?? 59,
        );
      });
    }
  }

  /// One labelled block of assignable items. Returns nothing at all when the
  /// block is empty, so a teacher who has never made a quiz never sees an
  /// empty "Quizzes" heading.
  List<Widget> _section({
    required HCColor hc,
    required String label,
    required String caption,
    required List<AssignableItem> items,
  }) {
    if (items.isEmpty) return const [];
    return [
      Text(
        label,
        style: AppTypography.titleSmall.copyWith(
          fontWeight: FontWeight.w700,
          color: hc.textPrimary,
        ),
      ),
      Text(
        caption,
        style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
      ),
      const SizedBox(height: 8),
      ...List.generate(items.length, (i) {
        final item = items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _AssessmentTile(
            item: item,
            selected: _selected?.id == item.id,
            hc: hc,
            onTap: () => setState(() => _selected = item),
          ),
        ).animate().fadeIn(duration: 300.ms, delay: (50 * i).ms);
      }),
      const SizedBox(height: 16),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    final profileId = ref.watch(profileProvider)?.id ?? '';
    // Pull anything this educator built on another device before deciding
    // whether to show them the "no assessments yet" dead end.
    if (profileId.isNotEmpty) {
      ref.watch(educatorAssessmentSyncProvider(profileId));
    }
    // Newest first in both sections: the thing a teacher just made is the
    // thing they are most likely reaching for.
    _quizzes = [
      for (final q in ref.watch(quizBuilderProvider)) AssignableItem.fromQuiz(q),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _saved = [
      for (final a in ref.watch(customAssessmentsProvider))
        AssignableItem.fromAssessment(a),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // Warmed so a class pre-test for signing learners can include sign items
    // the moment it is minted.
    ref.watch(fslAvailabilityProvider);
    final classPre = AssessmentService.latestClassPreTest(profileId);
    _instruments = [
      AssignableItem.instrument(
        AssessmentType.preTest,
        title: _tr(context).asgClassPre,
        questionCount: 15,
      ),
      if (classPre != null)
        AssignableItem.instrument(
          AssessmentType.postTest,
          title: _tr(context).asgClassPost,
          questionCount: classPre.questions.length,
        ),
    ];

    final roster = ref.watch(educatorLearnerRosterProvider);
    _students = roster.map((d) => (id: d.$1.id, name: d.$1.name)).toList();
    _profiles = {for (final d in roster) d.$1.id: d.$1};
    // A learner removed from the roster while this screen is open must not
    // stay silently ticked, or "Select All" would flip to "Deselect All" on a
    // selection the educator can no longer see.
    final rosterIds = _students.map((s) => s.id).toSet();
    _selectedStudentIds.removeWhere((id) => !rosterIds.contains(id));

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/assessment-hub'),
        title: Text(
          _tr(context).asgTitle,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      // No "nothing to assign" state any more: the study pre-test is always
      // on offer, which is the point — an educator with no custom assessments
      // can still run the study procedure.
      body: _students.isEmpty
              ? _EmptyStudents(hc: hc, isParent: _isParent)
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ─── What to hand out ─────────────
                    // Split in two because they behave differently: a quiz is
                    // a reusable recipe that mints a fresh test each time it
                    // is assigned, while a saved assessment is one fixed set
                    // of questions. Assigning a quiz adds one of the latter,
                    // so this list grows every week — hence the dates and the
                    // newest-first order.
                    // The study instrument comes first: it is what the study
                    // procedure has an educator assign, and everything that
                    // reads a learning gain reads *these* two, not a custom
                    // assessment.
                    ..._section(
                      hc: hc,
                      label: _tr(context).asgStudyLabel,
                      caption: _tr(context).asgStudyCaption,
                      items: _instruments,
                    ),
                    ..._section(
                      hc: hc,
                      label: _tr(context).asgQuizzes,
                      caption: _tr(context).asgQuizzesCaption,
                      items: _quizzes,
                    ),
                    ..._section(
                      hc: hc,
                      label: _tr(context).asgSaved,
                      caption: _tr(context).asgSavedCaption,
                      items: _saved,
                    ),

                    const SizedBox(height: 24),

                    // ─── Select Students ──────────────
                    // A Wrap, not a Row: at a 2.0x font on a phone the
                    // "Deselect All" button took most of the width and left
                    // the title a sliver, which broke it inside the word —
                    // "S / elect". Now the button drops to its own line.
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          _tr(context).asgSelectStudents(
                            _selectedStudentIds.length,
                            _students.length,
                          ),
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: hc.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: _toggleSelectAll,
                          child: Text(
                            _selectedStudentIds.isNotEmpty &&
                                    _selectedStudentIds.length ==
                                        _students.length
                                ? _tr(context).asgDeselectAll
                                : _tr(context).asgSelectAll,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_students.length, (i) {
                      final s = _students[i];
                      final checked = _selectedStudentIds.contains(s.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedStudentIds.add(s.id);
                            } else {
                              _selectedStudentIds.remove(s.id);
                            }
                          });
                        },
                        title: Text(
                          s.name,
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textPrimary,
                          ),
                        ),
                        secondary: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                            style: AppTypography.titleSmall.copyWith(
                              color: HCColor.of(context).readableOver(
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.15),
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                      );
                    }),

                    const SizedBox(height: 24),

                    // ─── Deadline (optional) ──────────
                    Text(
                      _tr(context).asgDeadline,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickDeadline,
                      icon: const Icon(Icons.calendar_today_rounded),
                      label: Text(
                        _deadline != null
                            ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year} ${_deadline!.hour}:${_deadline!.minute.toString().padLeft(2, '0')}'
                            : _tr(context).asgSetDeadline,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (_deadline != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() => _deadline = null),
                          child: Text(_tr(context).asgRemoveDeadline),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ─── Instructions (optional) ──────
                    Text(
                      _tr(context).asgInstructions,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _instructionsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: _tr(context).asgInstructionsHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // A Deaf learner cannot use written instructions they do
                    // not read, and a learner with low vision cannot read them
                    // at all — so the instructions can be signed, shown or
                    // spoken too, with a tip for the learners picked above.
                    AssessmentMediaEditor(
                      value: _instructionsMedia,
                      onChanged: (m) => setState(() => _instructionsMedia = m),
                      ownerKey: _mediaOwnerKey,
                      ledger: _mediaLedger,
                      ownerProfileId: ref.read(profileProvider)?.id,
                      title: _tr(context).assessInstructionsMediaTitle,
                      tips: assessmentMediaTips(_tr(context), [
                        for (final id in _selectedStudentIds)
                          if (_profiles[id] case final p?)
                            (
                              name: p.name,
                              type: p.disabilityType,
                              supports: p.supports,
                            ),
                      ]),
                    ),

                    const SizedBox(height: 32),

                    // ─── Assign Button ────────────────
                    FilledButton.icon(
                      onPressed: _canAssign && !_saving ? _assign : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _saving
                            ? _tr(context).asgAssigning
                            : _tr(context).asgTitle,
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
    );
  }
}

// ─── Assessment Tile ──────────────────────────────────

class _AssessmentTile extends StatelessWidget {
  final AssignableItem item;
  final bool selected;
  final HCColor hc;
  final VoidCallback onTap;

  const _AssessmentTile({
    required this.item,
    required this.selected,
    required this.hc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : hc.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : hc.textSecondary.withValues(alpha: 0.15),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                item.isQuiz
                    ? '🧩'
                    : (item.instrument ?? item.assessment?.type ??
                              AssessmentType.custom)
                          .emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      QuestionPrompt.title(
                        item.title,
                        AppLocalizations.of(context),
                      ),
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.isInstrument
                          // Not saved yet, so a date would be a lie.
                          ? '${_tr(context).hubQuestionCount(item.questionCount)}  •  '
                                '${item.instrument == AssessmentType.preTest ? _tr(context).asgMadeFresh : _tr(context).asgMirrors}'
                          : '${_tr(context).hubQuestionCount(item.questionCount)}  •  '
                                '${item.difficulty.labelOf(_tr(context))}  •  '
                                '${LocalizedDate.dayMonth(item.createdAt, AppLocalizations.of(context))}',
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty States ─────────────────────────────────────

class _EmptyStudents extends StatelessWidget {
  final HCColor hc;
  final bool isParent;
  const _EmptyStudents({required this.hc, required this.isParent});

  @override
  Widget build(BuildContext context) {
    // Scrolls when it has to: at a 2.0x font on a 360×640 phone this ran 53px
    // off the bottom. It used to sit behind "No assessments yet", which took
    // precedence, so nobody reached it — until the study pre-test made that
    // state impossible and this one the thing an educator with no learners
    // actually sees.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isParent ? '👨‍👩‍👧' : '👩‍🎓',
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              isParent
                  ? _tr(context).asgNoChildren
                  : _tr(context).asgNoStudents,
              style:
                  AppTypography.titleMedium.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              isParent
                  ? _tr(context).asgShareHomeHint
                  : _tr(context).asgShareClassHint,
              style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.push(
                isParent ? '/home-group-manage' : '/classroom-manage',
              ),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: Text(
                isParent
                    ? _tr(context).asgShareGroupCode
                    : _tr(context).asgShareClassCode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// This file's strings: English when no delegate is present, which is how
/// widget tests build this screen.
AppLocalizations _tr(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
