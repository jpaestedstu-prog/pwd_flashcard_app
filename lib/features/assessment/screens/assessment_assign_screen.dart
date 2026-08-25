import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/student_list_provider.dart';
import '../models/assessment_models.dart';
import '../models/custom_quiz_models.dart';
import '../providers/assessment_provider.dart';
import '../providers/quiz_builder_provider.dart';
import '../services/assessment_cloud_service.dart';
import '../services/assessment_service.dart';
import '../../../widgets/app_back_button.dart';

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

  AssignableItem.fromAssessment(Assessment this.assessment)
    : id = assessment.id,
      title = assessment.title,
      questionCount = assessment.questions.length,
      difficulty = assessment.difficulty,
      createdAt = assessment.createdAt,
      quiz = null;

  AssignableItem.fromQuiz(CustomQuiz this.quiz)
    : id = quiz.id,
      title = quiz.title,
      questionCount = quiz.flashcardIds.length,
      difficulty = quiz.difficulty,
      createdAt = quiz.createdAt,
      assessment = null;

  bool get isQuiz => quiz != null;
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

  /// Assessments this educator may hand out, and the learners they may hand
  /// them to. Both are read in `build`, never cached in `initState`: each is
  /// backed by a Firestore pull that can land *after* this screen opens.
  ///
  /// The roster in particular spans classroom students *and* home-group
  /// children — the old local `role == UserRole.student` read showed a Parent
  /// "No students found" and hid cross-device students from teachers.
  List<AssignableItem> _assignables = const [];
  List<AssignableItem> _quizzes = const [];
  List<AssignableItem> _saved = const [];
  List<({String id, String name})> _students = const [];

  @override
  void dispose() {
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
    Assessment target;
    if (selected.isQuiz) {
      target = AssessmentService.materialiseQuiz(
        selected.quiz!,
        ref.read(allFlashcardsProvider),
      );
      if (target.questions.isEmpty) {
        setState(() => _saving = false);
        AppSnackBar.warning(
          context,
          message: 'That quiz has no cards left to ask about.',
        );
        return;
      }
      await ref.read(customAssessmentsProvider.notifier).saveAssessment(target);
    } else {
      target = selected.assessment!;
    }

    final assignment = AssessmentAssignment(
      id: const Uuid().v4(),
      assessmentId: target.id,
      assessmentTitle: target.title,
      assignedBy: profile!.id,
      studentIds: _selectedStudentIds.toList(),
      assignedAt: DateTime.now(),
      deadline: _deadline,
      instructions: _instructionsController.text.trim().isEmpty
          ? null
          : _instructionsController.text.trim(),
    );

    final outcome = await ref
        .read(assignmentsProvider.notifier)
        .saveAssignment(assignment);

    if (mounted) {
      final count = _selectedStudentIds.length;
      final learners = '$count ${count == 1 ? "learner" : "learners"}';
      switch (outcome) {
        case CloudSyncOutcome.synced:
          AppSnackBar.success(
            context,
            message: 'Assessment assigned to $learners!',
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
            message: 'Saved for $learners on this device — not sent yet. '
                'It will upload when syncing is working.',
          );
        case CloudSyncOutcome.notOwner:
          // This one is never going out, so saying "not yet" would be a lie
          // that costs a teacher a lesson. Names the cause because there is a
          // cause, and it is something they did and can undo.
          AppSnackBar.warning(
            context,
            message: 'Saved on this device only. This profile was restored on '
                'another device, so that one now handles syncing. Restore it '
                'back here to send work to your learners.',
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
    _assignables = [..._quizzes, ..._saved];

    _students = ref
        .watch(educatorLearnerRosterProvider)
        .map((d) => (id: d.$1.id, name: d.$1.name))
        .toList();
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
          'Assign Assessment',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _assignables.isEmpty
          ? _EmptyAssessments(hc: hc)
          : _students.isEmpty
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
                    ..._section(
                      hc: hc,
                      label: 'Quizzes',
                      caption: 'Makes a fresh test each time you assign it',
                      items: _quizzes,
                    ),
                    ..._section(
                      hc: hc,
                      label: 'Saved assessments',
                      caption: 'A fixed set of questions',
                      items: _saved,
                    ),

                    const SizedBox(height: 24),

                    // ─── Select Students ──────────────
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Select Students (${_selectedStudentIds.length}/${_students.length})',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: hc.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _toggleSelectAll,
                          child: Text(
                            _selectedStudentIds.isNotEmpty &&
                                    _selectedStudentIds.length ==
                                        _students.length
                                ? 'Deselect All'
                                : 'Select All',
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
                              color: AppColors.primary,
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
                      'Deadline (optional)',
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
                            : 'Set Deadline',
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
                          child: const Text('Remove deadline'),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ─── Instructions (optional) ──────
                    Text(
                      'Instructions (optional)',
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
                        hintText: 'Add instructions for students...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
                        _saving ? 'Assigning...' : 'Assign Assessment',
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

  /// Day and month is enough to separate this week's copy from last week's,
  /// and short enough not to wrap on a phone.
  static String _shortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

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
              Text(item.isQuiz ? '🧩' : AssessmentType.custom.emoji,
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.questionCount} questions  •  '
                      '${item.difficulty.name}  •  '
                      '${_shortDate(item.createdAt)}',
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

class _EmptyAssessments extends StatelessWidget {
  final HCColor hc;
  const _EmptyAssessments({required this.hc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📋', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'No assessments yet',
            style: AppTypography.titleMedium.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Build one in the Assessment Builder, or make a Quiz — both can '
            'be assigned.',
            style:
                AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/assessment/builder'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Assessment'),
          ),
        ],
      ),
    );
  }
}

/// Shown when the educator has nobody to assign to. The way out of this is to
/// share the join code, not to mint a learner profile from the role picker —
/// so it points at the group the educator actually owns.
class _EmptyStudents extends StatelessWidget {
  final HCColor hc;
  final bool isParent;
  const _EmptyStudents({required this.hc, required this.isParent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
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
              isParent ? 'No children yet' : 'No students yet',
              style:
                  AppTypography.titleMedium.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              isParent
                  ? 'Share your home group code so your child can join, then '
                        'assign them work here.'
                  : 'Share your class code so students can join, then assign '
                        'them work here.',
              style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.push(
                isParent ? '/home-group-manage' : '/classroom-manage',
              ),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: Text(isParent ? 'Share Group Code' : 'Share Class Code'),
            ),
          ],
        ),
      ),
    );
  }
}
