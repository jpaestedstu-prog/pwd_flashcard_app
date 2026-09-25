import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../widgets/rich_empty_states.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../models/assessment_media.dart';
import '../models/assessment_models.dart';
import '../models/question_prompt.dart';
import '../providers/assessment_provider.dart';
import '../services/assessment_media_store.dart';
import '../services/assessment_service.dart';
import '../widgets/assessment_media_editor.dart';
import '../widgets/assessment_media_panel.dart';
import '../../../core/widgets/fit_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../l10n/app_localizations_fil.dart';

/// Screen for teachers to create custom assessments manually — or, given
/// [editId], to change one they already saved.
class AssessmentBuilderScreen extends ConsumerStatefulWidget {
  /// The id of one of this educator's own custom assessments to edit. Null,
  /// or an id that is not theirs, builds a new one.
  final String? editId;

  const AssessmentBuilderScreen({super.key, this.editId});

  @override
  ConsumerState<AssessmentBuilderScreen> createState() =>
      _AssessmentBuilderScreenState();
}

class _AssessmentBuilderScreenState
    extends ConsumerState<AssessmentBuilderScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  GameDifficulty _difficulty = GameDifficulty.easy;
  int _timeLimitMinutes = 10;
  final List<AssessmentQuestion> _questions = [];
  final Set<FlashcardCategory> _selectedCategories = {};

  /// Set once the assessment is stored.
  bool _saved = false;

  /// The saved assessment being edited, as it was when the editor opened.
  /// Null when building a new one.
  Assessment? _original;

  /// Learners this device knows have already sat [_original].
  int _alreadyTaken = 0;

  /// Every file picked while this builder is open, by any question sheet.
  ///
  /// Cleanup happens here, once, not in each sheet: a sheet that deleted the
  /// file it replaced would delete one the *stored* assessment still uses
  /// the moment the educator then left without saving. So nothing is
  /// deleted until the assessment is saved (files picked and not kept) or
  /// abandoned (files picked this session).
  final AssessmentMediaLedger _ledger = AssessmentMediaLedger();

  /// What the form held when it opened, to tell a real change from none.
  late final String _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _load();
    _initialSnapshot = _snapshot();
  }

  /// Fills the form from the assessment being edited, if there is one.
  void _load() {
    final id = widget.editId;
    if (id == null || id.isEmpty) return;
    // Only their own custom assessments: the study's pre/post tests are the
    // instrument and must read the same for every learner who sits them.
    Assessment? found;
    for (final a in ref.read(customAssessmentsProvider)) {
      if (a.id == id && a.type == AssessmentType.custom) found = a;
    }
    if (found == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppSnackBar.warning(context, message: _t(context).assessEditNotFound);
        }
      });
      return;
    }
    _original = found;
    _titleController.text = found.title;
    final description = found.description?.trim() ?? '';
    // The placeholder the builder writes for an empty field is not the
    // educator's words; editing it would save it as if it were.
    if (description.isNotEmpty &&
        description != AppLocalizationsEn().abCustomDesc &&
        description != AppLocalizationsFil().abCustomDesc) {
      _descriptionController.text = description;
    }
    _difficulty = found.difficulty;
    _timeLimitMinutes = (found.timeLimitMinutes ?? _timeLimitMinutes).clamp(
      3,
      30,
    );
    _questions.addAll(found.questions);
    _selectedCategories.addAll(found.categories);
    try {
      _alreadyTaken = AssessmentService.learnersWhoTook(found.id).length;
    } catch (_) {
      // No box (a test harness): nothing known to have been taken.
    }
  }

  bool get _isEditing => _original != null;

  String _snapshot() => jsonEncode({
    'title': _titleController.text.trim(),
    'description': _descriptionController.text.trim(),
    'difficulty': _difficulty.index,
    'minutes': _timeLimitMinutes,
    'questions': [for (final q in _questions) q.toJson()],
  });

  /// Whether leaving now would lose anything.
  bool get _hasChanges => _snapshot() != _initialSnapshot;

  @override
  void dispose() {
    if (!_saved) {
      const AssessmentMediaStore().discard(_ledger.adoptedValues);
    }
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final padding = context.pagePadding;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ═══ Header ═══
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 12, padding, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _confirmDiscard(),
                    icon: Icon(Icons.close_rounded, color: hc.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    // A headline sharing its row with a close button and a
                    // Save button: "Assessmen / t".
                    child: FitText(
                      _isEditing
                          ? _t(context).assessEditTitle
                          : _t(context).abCreate,
                      style: AppTypography.headlineLarge
                          .copyWith(color: hc.textPrimary),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _questions.isEmpty ? null : _saveAssessment,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(_t(context).gmSave),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),
            ),
            const Divider(),

            // ═══ Content ═══
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scores already earned stay as they were; say so
                      // before the educator changes what they were earned on.
                      if (_isEditing && _alreadyTaken > 0) ...[
                        _AlreadyTakenNotice(count: _alreadyTaken),
                        const SizedBox(height: 16),
                      ],
                      // ─── Title & Description ───────
                      _buildSectionHeader(_t(context).abDetails, Icons.info_outline_rounded),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: _inputDecor(hc, _t(context).abTitleField),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? _t(context).abTitleRequired : null,
                        style: AppTypography.bodyLarge.copyWith(color: hc.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: _inputDecor(hc, _t(context).abDescription),
                        maxLines: 2,
                        style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
                      ),

                      const SizedBox(height: 24),

                      // ─── Difficulty ─────────────────
                      _buildSectionHeader(_t(context).abDifficulty, Icons.speed_rounded),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: GameDifficulty.values.map((d) {
                          final selected = d == _difficulty;
                          return ChoiceChip(
                            label: Text(d.labelOf(_t(context))),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _difficulty = d),
                            // Dark words on the pale tint: the pastel
                            // primary on its own tint was near unreadable.
                            selectedColor:
                                AppColors.primary.withValues(alpha: 0.2),
                            checkmarkColor: hc.textPrimary,
                            side: BorderSide(
                              color: selected ? AppColors.primary : hc.border,
                              width: selected ? 2 : 1,
                            ),
                            labelStyle: AppTypography.labelMedium.copyWith(
                              color: selected
                                  ? hc.textPrimary
                                  : hc.textSecondary,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // ─── Time Limit ──────────────────
                      _buildSectionHeader(_t(context).abTimeLimit, Icons.timer_rounded),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _timeLimitMinutes.toDouble(),
                              min: 3,
                              max: 30,
                              divisions: 9,
                              label: _t(context).abMinutes(_timeLimitMinutes),
                              onChanged: (v) =>
                                  setState(() => _timeLimitMinutes = v.round()),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: hc.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _t(context).abMinutes(_timeLimitMinutes),
                              style: AppTypography.labelLarge
                                  .copyWith(color: hc.textPrimary),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ─── Questions ─────────────────
                      _buildSectionHeader(
                        _t(context).abQuestionsCount(_questions.length),
                        Icons.quiz_rounded,
                      ),
                      const SizedBox(height: 8),

                      if (_questions.isEmpty)
                        RichEmptyState(
                          emoji: '📝',
                          title: _t(context).abNoQuestions,
                          description: _t(context).abNoQuestionsBody,
                          actionLabel: _t(context).abAddFirst,
                          actionIcon: Icons.add_rounded,
                          onAction: () => _showAddQuestionDialog(),
                          compact: true,
                        )
                      else
                        ...List.generate(_questions.length, (i) {
                          final q = _questions[i];
                          return _QuestionCard(
                            index: i,
                            question: q,
                            // Its files go when the assessment is saved
                            // without it — see [_ledger].
                            onDelete: () =>
                                setState(() => _questions.removeAt(i)),
                            onEdit: () => _showEditQuestionDialog(i),
                          );
                        }),

                      if (_questions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: OutlinedButton.icon(
                            onPressed: () => _showAddQuestionDialog(),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(_t(context).abAddQuestion),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final hc = HCColor.of(context);
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        // Flexible, or a long section title beside the icon runs off the row.
        Flexible(
          // FitText, not Text: making it flexible stopped the overflow but let
          // the word wrap inside itself instead ("Crea / te").
          child: FitText(
            title,
            style: AppTypography.titleMedium.copyWith(
              color: hc.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecor(HCColor hc, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTypography.bodyMedium.copyWith(color: hc.textHint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: hc.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      filled: true,
      fillColor: hc.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ─── Add / Edit Dialogs ───────────────────────────

  Future<void> _showAddQuestionDialog() async {
    // The sheet hands focus back to whatever held it when it closes — the
    // title field, keyboard and all, over the list the educator just added
    // to. Let go of it first.
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showModalBottomSheet<AssessmentQuestion>(
      context: context,
      // Without this the dismiss barrier announces itself as "Scrim",
      // Material's untranslated default.
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _QuestionEditorSheet(
        ownerProfileId: ref.read(profileProvider)?.id,
        ledger: _ledger,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _questions.add(result);
        if (result.category != null) {
          _selectedCategories.add(result.category!);
        }
      });
    }
  }

  Future<void> _showEditQuestionDialog(int index) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showModalBottomSheet<AssessmentQuestion>(
      context: context,
      // Without this the dismiss barrier announces itself as "Scrim",
      // Material's untranslated default.
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _QuestionEditorSheet(
        existing: _questions[index],
        ownerProfileId: ref.read(profileProvider)?.id,
        ledger: _ledger,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _questions[index] = result;
      });
    }
  }

  // ─── Save ─────────────────────────────────────────

  void _saveAssessment() {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      AppSnackBar.warning(context, message: _t(context).abNeedOne);
      return;
    }

    final original = _original;
    final now = DateTime.now();
    final assessment = Assessment(
      // An edit keeps its id, so every tablet and assignment holding it gets
      // this version in place of the old one.
      id: original?.id ?? 'custom_${now.millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? _t(context).abCustomDesc
          : _descriptionController.text.trim(),
      type: AssessmentType.custom,
      questions: _questions,
      categories: _selectedCategories.toList(),
      difficulty: _difficulty,
      timeLimitMinutes: _timeLimitMinutes,
      // The educator's profile id, matching QuizBuilder and the field's own
      // doc comment. Legacy rows hold the literal 'teacher', which is why the
      // cloud mirror stamps `created_by_profile_id` separately rather than
      // trusting this.
      createdBy: original?.createdBy ?? ref.read(profileProvider)?.id ?? '',
      createdAt: original?.createdAt ?? now,
      updatedAt: original == null ? null : now,
    );

    _saved = true;
    ref.read(customAssessmentsProvider.notifier).saveAssessment(assessment);
    // Files picked and then replaced, removed, or left in a cancelled sheet —
    // and, on an edit, the saved version's files it no longer uses. Each is
    // deleted only if nothing else still points at it.
    final kept = {for (final q in assessment.questions) ...q.storedValues};
    final before = {
      for (final q in original?.questions ?? const <AssessmentQuestion>[])
        ...q.storedValues,
    };
    const AssessmentMediaStore().discardUnreferenced(
      {..._ledger.adoptedValues, ...before}.difference(kept),
    );

    final t = _t(context);
    if (original == null) {
      AppSnackBar.success(context, message: t.abSaved(assessment.title));
    } else {
      // Every assignment of it: its title, and a stamp that makes each
      // learner's tablet fetch the new version.
      final assigned = [
        for (final a in ref.read(assignmentsProvider))
          if (a.assessmentId == assessment.id) a,
      ];
      final notifier = ref.read(assignmentsProvider.notifier);
      unawaited(() async {
        for (final a in assigned) {
          await notifier.saveAssignment(
            a.withEditedAssessment(title: assessment.title, editedAt: now),
          );
        }
      }());
      AppSnackBar.success(
        context,
        message: assigned.isEmpty
            ? t.assessEditSaved(assessment.title)
            : t.assessEditSavedSent(assessment.title),
      );
    }

    context.pop();
  }

  // ─── Discard Confirmation ──────────────────────────

  void _confirmDiscard() {
    if (!_hasChanges) {
      context.pop();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _isEditing
              ? _t(context).assessEditDiscardTitle
              : _t(context).abDiscardTitle,
        ),
        content: Text(
          _isEditing
              ? _t(context).assessEditDiscardBody
              : _t(context).abDiscardBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t(context).abKeepEditing),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            child: Text(_t(context).abDiscard),
          ),
        ],
      ),
    );
  }
}

/// "3 learners have already taken this…" — shown above an edit.
class _AlreadyTakenNotice extends StatelessWidget {
  final int count;

  const _AlreadyTakenNotice({required this.count});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t(context).assessEditAlreadyTaken(count),
              style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Question Card ─────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final int index;
  final AssessmentQuestion question;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hc.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    '${index + 1}',
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    question.questionText,
                    style: AppTypography.bodyMedium
                        .copyWith(color: hc.textPrimary),
                  ),
                ),
                IconButton(
                  tooltip: _t(context).abEditQuestion,
                  icon: Icon(Icons.edit_rounded,
                      size: 18, color: hc.textSecondary),
                  onPressed: onEdit,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: _t(context).hubDelete,
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.error),
                  onPressed: onDelete,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                _MiniChip(
                    label: question.format.labelOf(_t(context)), color: AppColors.info),
                _MiniChip(
                    label: _t(context).abAnswer(
                        QuestionPrompt.answer(question.correctAnswer, _t(context))),
                    color: AppColors.success),
                if (question.category != null)
                  _MiniChip(
                      label: question.category!.labelOf(_t(context)), color: AppColors.accent),
              ],
            ),
            if (question.media.hasAny) ...[
              const SizedBox(height: 6),
              AssessmentMediaBadges(kinds: question.media.supplied),
            ],
            if (question.hasPictureChoices) ...[
              const SizedBox(height: 6),
              _MiniChip(
                label: _t(context).assessPictureAnswers,
                color: AppColors.info,
              ),
            ],
            if (question.choices.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _t(context).abChoices(question.choices.join(', ')),
                style: AppTypography.bodySmall
                    .copyWith(color: hc.textHint, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Question Editor Bottom Sheet ──────────────────────

class _QuestionEditorSheet extends StatefulWidget {
  final AssessmentQuestion? existing;

  /// The educator a picked file is shared as.
  final String? ownerProfileId;

  /// The builder's ledger: this sheet records what it picks there, and the
  /// builder decides what to delete when the assessment is saved or left.
  final AssessmentMediaLedger ledger;

  const _QuestionEditorSheet({
    this.existing,
    this.ownerProfileId,
    required this.ledger,
  });

  @override
  State<_QuestionEditorSheet> createState() => _QuestionEditorSheetState();
}

class _QuestionEditorSheetState extends State<_QuestionEditorSheet> {
  final _questionTextController = TextEditingController();
  final _correctAnswerController = TextEditingController();
  final _hintController = TextEditingController();
  FlashcardCategory? _selectedCategory;
  QuestionFormat _format = QuestionFormat.multipleChoice;
  final List<TextEditingController> _choiceControllers = [];

  /// Fixed when the sheet opens, not when it saves: a file picked for a new
  /// question is named after the question it will belong to.
  late final String _questionId =
      widget.existing?.id ?? 'q_${DateTime.now().millisecondsSinceEpoch}';
  late AssessmentMedia _media = widget.existing?.media ?? AssessmentMedia.none;

  /// A picture per choice, parallel to [_choiceControllers] ('' = none).
  /// Kept by position while editing, because the choice's words can change
  /// under it; turned into a map keyed by text only when the question saves.
  final List<String> _choicePictures = [];

  /// The choice whose picture is being picked or shared right now.
  int? _pictureBusy;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _questionTextController.text = e.questionText;
      _correctAnswerController.text = e.correctAnswer;
      _hintController.text = e.hint ?? '';
      _selectedCategory = e.category;
      _format = e.format;
      for (final c in e.choices) {
        _choiceControllers.add(TextEditingController(text: c));
        _choicePictures.add(e.choiceImages[c] ?? '');
      }
    } else {
      // Default 4 choices for multiple choice
      for (int i = 0; i < 4; i++) {
        _choiceControllers.add(TextEditingController());
        _choicePictures.add('');
      }
    }
  }

  Future<void> _pickChoicePicture(int index) async {
    setState(() => _pictureBusy = index);
    try {
      final value = await pickAssessmentPicture(
        context,
        ownerKey: '${_questionId}_choice$index',
        ledger: widget.ledger,
        ownerProfileId: widget.ownerProfileId,
      );
      if (value != null && mounted && index < _choicePictures.length) {
        setState(() => _choicePictures[index] = value);
      }
    } finally {
      if (mounted) setState(() => _pictureBusy = null);
    }
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    _correctAnswerController.dispose();
    _hintController.dispose();
    for (final c in _choiceControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: hc.background,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: hc.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  widget.existing != null ? _t(context).abEditQuestion : _t(context).abAddQuestion,
                  style: AppTypography.titleLarge
                      .copyWith(color: hc.textPrimary),
                ),
                const SizedBox(height: 16),

                // Question format selector
                Text(_t(context).abQuestionType,
                    style: AppTypography.labelLarge
                        .copyWith(color: hc.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    QuestionFormat.multipleChoice,
                    QuestionFormat.trueFalse,
                    QuestionFormat.fillInBlank,
                    // The learner signs or says the answer on camera, and
                    // you mark it — see QuestionAnswer.needsReview.
                    QuestionFormat.videoResponse,
                  ].map((f) {
                    final selected = f == _format;
                    return ChoiceChip(
                      label: Text(f.labelOf(_t(context))),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _format = f;
                        if (f == QuestionFormat.trueFalse) {
                          _choiceControllers.clear();
                          _choiceControllers.add(
                              TextEditingController(text: 'True'));
                          _choiceControllers.add(
                              TextEditingController(text: 'False'));
                        } else if (f == QuestionFormat.fillInBlank ||
                            f == QuestionFormat.videoResponse) {
                          _choiceControllers.clear();
                        } else {
                          while (_choiceControllers.length < 4) {
                            _choiceControllers.add(TextEditingController());
                          }
                        }
                        // Pictures belong to multiple-choice answers only.
                        _choicePictures
                          ..clear()
                          ..addAll(List.filled(_choiceControllers.length, ''));
                      }),
                      // The theme's light label vanished on this tint;
                      // dark words and a border say which one is chosen.
                      selectedColor:
                          AppColors.primary.withValues(alpha: 0.2),
                      checkmarkColor: hc.textPrimary,
                      side: BorderSide(
                        color: selected ? AppColors.primary : hc.border,
                        width: selected ? 2 : 1,
                      ),
                      labelStyle: AppTypography.labelMedium.copyWith(
                        color: selected ? hc.textPrimary : hc.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Question text
                TextField(
                  controller: _questionTextController,
                  maxLines: 3,
                  decoration: _inputDecor(hc, _t(context).abQuestionText),
                  style: AppTypography.bodyLarge
                      .copyWith(color: hc.textPrimary),
                ),

                const SizedBox(height: 16),

                // Pictures, video, sound and a signed version — beside the
                // words they belong to, before the answer fields.
                AssessmentMediaEditor(
                  value: _media,
                  onChanged: (m) => setState(() => _media = m),
                  ownerKey: _questionId,
                  ledger: widget.ledger,
                  forQuestion: true,
                  ownerProfileId: widget.ownerProfileId,
                ),

                const SizedBox(height: 12),

                // Correct answer
                TextField(
                  controller: _correctAnswerController,
                  decoration: _inputDecor(
                    hc,
                    _format == QuestionFormat.videoResponse
                        ? _t(context).assessWhatToLookFor
                        : _t(context).abCorrectAnswer,
                  ),
                  style: AppTypography.bodyMedium
                      .copyWith(color: hc.textPrimary),
                ),

                // Choices (for MC and T/F)
                if (_format != QuestionFormat.fillInBlank &&
                    _format != QuestionFormat.videoResponse) ...[
                  const SizedBox(height: 16),
                  Text(_t(context).abChoicesTitle,
                      style: AppTypography.labelLarge
                          .copyWith(color: hc.textSecondary)),
                  if (_format == QuestionFormat.multipleChoice) ...[
                    const SizedBox(height: 4),
                    Text(
                      _t(context).assessPictureChoicesHelp,
                      style: AppTypography.bodySmall
                          .copyWith(color: hc.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ...List.generate(_choiceControllers.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: hc.surfaceVariant,
                            child: Text(
                              String.fromCharCode(65 + i),
                              style: AppTypography.labelSmall
                                  .copyWith(color: hc.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _choiceControllers[i],
                              decoration: _inputDecor(
                                  hc, _t(context).abChoiceN(String.fromCharCode(65 + i))),
                              style: AppTypography.bodyMedium
                                  .copyWith(color: hc.textPrimary),
                            ),
                          ),
                          if (_format == QuestionFormat.multipleChoice) ...[
                            const SizedBox(width: 6),
                            _ChoicePictureButton(
                              value: _choicePictures[i],
                              letter: String.fromCharCode(65 + i),
                              busy: _pictureBusy == i,
                              onPick: _pictureBusy == null
                                  ? () => _pickChoicePicture(i)
                                  : null,
                              onRemove: () =>
                                  setState(() => _choicePictures[i] = ''),
                            ),
                          ],
                          if (_format == QuestionFormat.multipleChoice &&
                              _choiceControllers.length > 2)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: AppColors.error, size: 20),
                              onPressed: () {
                                setState(() {
                                  _choiceControllers[i].dispose();
                                  _choiceControllers.removeAt(i);
                                  _choicePictures.removeAt(i);
                                });
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                  if (_format == QuestionFormat.multipleChoice &&
                      _choiceControllers.length < 6)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _choiceControllers.add(TextEditingController());
                          _choicePictures.add('');
                        });
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(_t(context).abAddChoice),
                    ),
                ],

                const SizedBox(height: 12),

                // Category
                DropdownButtonFormField<FlashcardCategory>(
                  initialValue: _selectedCategory,
                  decoration: _inputDecor(hc, _t(context).abCategory),
                  dropdownColor: hc.surface,
                  items: FlashcardCategory.values.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(
                        cat.label,
                        style: AppTypography.bodyMedium
                            .copyWith(color: hc.textPrimary),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),

                const SizedBox(height: 12),

                // Hint
                TextField(
                  controller: _hintController,
                  decoration: _inputDecor(hc, _t(context).abHint),
                  style: AppTypography.bodyMedium
                      .copyWith(color: hc.textPrimary),
                ),

                const SizedBox(height: 24),

                // Save button
                FilledButton(
                  onPressed: _saveQuestion,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    widget.existing != null
                        ? _t(context).abUpdateQuestion
                        : _t(context).abAddQuestion,
                    style: AppTypography.titleMedium
                        .copyWith(color: Colors.white),
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecor(HCColor hc, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTypography.bodyMedium.copyWith(color: hc.textHint),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: hc.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      filled: true,
      fillColor: hc.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  void _saveQuestion() {
    final qText = _questionTextController.text.trim();
    final answer = _correctAnswerController.text.trim();

    // A video answer is marked by a person, so "what a good answer shows"
    // is a note to them, not something the app checks — it may be left out.
    if (qText.isEmpty ||
        (answer.isEmpty && _format != QuestionFormat.videoResponse)) {
      AppSnackBar.warning(context, message: _t(context).abTextRequired);
      return;
    }

    final choices = _choiceControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Ensure correct answer is among choices for MC/TF
    if (_format == QuestionFormat.multipleChoice ||
        _format == QuestionFormat.trueFalse) {
      if (!choices.contains(answer)) {
        AppSnackBar.warning(context, message: _t(context).abAnswerInChoices);
        return;
      }
    }

    final question = AssessmentQuestion(
      id: _questionId,
      questionText: qText,
      correctAnswer: answer,
      choices: choices,
      format: _format,
      category: _selectedCategory,
      hint: _hintController.text.trim().isEmpty
          ? null
          : _hintController.text.trim(),
      imageAsset: widget.existing?.imageAsset,
      signCardId: widget.existing?.signCardId,
      media: _media,
      choiceImages: _format == QuestionFormat.multipleChoice
          ? {
              for (var i = 0; i < _choiceControllers.length; i++)
                if (_choiceControllers[i].text.trim().isNotEmpty &&
                    _choicePictures[i].trim().isNotEmpty)
                  _choiceControllers[i].text.trim(): _choicePictures[i],
            }
          : const {},
    );

    Navigator.pop(context, question);
  }
}

/// The picture for one answer choice: an "add a picture" button, or the
/// picture itself with Replace / Remove behind it.
class _ChoicePictureButton extends StatelessWidget {
  final String value;
  final String letter;
  final bool busy;
  final VoidCallback? onPick;
  final VoidCallback onRemove;

  const _ChoicePictureButton({
    required this.value,
    required this.letter,
    required this.busy,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    if (busy) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (value.trim().isEmpty) {
      return IconButton.outlined(
        tooltip: t.assessChoicePictureAdd(letter),
        onPressed: onPick,
        icon: const Icon(Icons.add_photo_alternate_rounded),
      );
    }
    return PopupMenuButton<String>(
      tooltip: t.assessChoicePicture(letter),
      onSelected: (v) {
        if (v == 'replace') onPick?.call();
        if (v == 'remove') onRemove();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'replace',
          child: Text(t.assessChoicePictureReplace),
        ),
        PopupMenuItem(
          value: 'remove',
          child: Text(t.assessChoicePictureRemove),
        ),
      ],
      child: SizedBox(
        width: 48,
        height: 48,
        child: AssessmentPicture(value: value, maxHeight: 48),
      ),
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
