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
import '../widgets/assessment_media_editor.dart';
import '../widgets/assessment_media_panel.dart';
import '../../../core/widgets/fit_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Screen for teachers to create custom assessments manually.
class AssessmentBuilderScreen extends ConsumerStatefulWidget {
  const AssessmentBuilderScreen({super.key});

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

  /// Set once the assessment is stored. Until then the files picked for its
  /// questions belong to nothing, and leaving — by the close button or by the
  /// system back gesture — removes them.
  bool _saved = false;

  @override
  void dispose() {
    if (!_saved) {
      const AssessmentMediaStore().discard({
        for (final q in _questions) ...q.media.storedValues,
      });
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
                      _t(context).abCreate,
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
                            selectedColor:
                                AppColors.primary.withValues(alpha: 0.2),
                            labelStyle: AppTypography.labelMedium.copyWith(
                              color: selected
                                  ? AppColors.primary
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
                            onDelete: () {
                              const AssessmentMediaStore().discard(
                                q.media.storedValues,
                              );
                              setState(() => _questions.removeAt(i));
                            },
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

    final assessment = Assessment(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
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
      createdBy: ref.read(profileProvider)?.id ?? '',
      createdAt: DateTime.now(),
    );

    _saved = true;
    ref.read(customAssessmentsProvider.notifier).saveAssessment(assessment);

    AppSnackBar.success(context, message: _t(context).abSaved(assessment.title));

    context.pop();
  }

  // ─── Discard Confirmation ──────────────────────────

  void _confirmDiscard() {
    if (_questions.isEmpty && _titleController.text.isEmpty) {
      context.pop();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(context).abDiscardTitle),
        content: Text(
          _t(context).abDiscardBody,
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
                  icon: Icon(Icons.edit_rounded,
                      size: 18, color: hc.textSecondary),
                  onPressed: onEdit,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                IconButton(
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

  const _QuestionEditorSheet({this.existing, this.ownerProfileId});

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
  late final AssessmentMediaLedger _ledger = AssessmentMediaLedger(_media);
  bool _committed = false;

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
      }
    } else {
      // Default 4 choices for multiple choice
      for (int i = 0; i < 4; i++) {
        _choiceControllers.add(TextEditingController());
      }
    }
  }

  @override
  void dispose() {
    if (!_committed) {
      const AssessmentMediaStore().discard(_ledger.toDiscardOnCancel());
    }
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
                  children: [
                    QuestionFormat.multipleChoice,
                    QuestionFormat.trueFalse,
                    QuestionFormat.fillInBlank,
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
                        } else if (f == QuestionFormat.fillInBlank) {
                          _choiceControllers.clear();
                        } else {
                          while (_choiceControllers.length < 4) {
                            _choiceControllers.add(TextEditingController());
                          }
                        }
                      }),
                      selectedColor:
                          AppColors.primary.withValues(alpha: 0.2),
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
                  ledger: _ledger,
                  forQuestion: true,
                  ownerProfileId: widget.ownerProfileId,
                ),

                const SizedBox(height: 12),

                // Correct answer
                TextField(
                  controller: _correctAnswerController,
                  decoration: _inputDecor(hc, _t(context).abCorrectAnswer),
                  style: AppTypography.bodyMedium
                      .copyWith(color: hc.textPrimary),
                ),

                // Choices (for MC and T/F)
                if (_format != QuestionFormat.fillInBlank) ...[
                  const SizedBox(height: 16),
                  Text(_t(context).abChoicesTitle,
                      style: AppTypography.labelLarge
                          .copyWith(color: hc.textSecondary)),
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
                          if (_format == QuestionFormat.multipleChoice &&
                              _choiceControllers.length > 2)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: AppColors.error, size: 20),
                              onPressed: () {
                                setState(() {
                                  _choiceControllers[i].dispose();
                                  _choiceControllers.removeAt(i);
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

    if (qText.isEmpty || answer.isEmpty) {
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
    );

    // Nothing is stored yet, so a file this edit replaced or removed is
    // referred to by nothing at all.
    _committed = true;
    const AssessmentMediaStore().discard(_ledger.toDiscardOnSave(_media));
    Navigator.pop(context, question);
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
