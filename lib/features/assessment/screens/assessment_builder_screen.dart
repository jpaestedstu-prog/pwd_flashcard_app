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
import '../models/assessment_models.dart';
import '../providers/assessment_provider.dart';

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

  @override
  void dispose() {
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
                    child: Text(
                      'Create Assessment',
                      style: AppTypography.headlineLarge
                          .copyWith(color: hc.textPrimary),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _questions.isEmpty ? null : _saveAssessment,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Save'),
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
                      _buildSectionHeader('Assessment Details', Icons.info_outline_rounded),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: _inputDecor(hc, 'Assessment Title'),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Title is required' : null,
                        style: AppTypography.bodyLarge.copyWith(color: hc.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: _inputDecor(hc, 'Description (optional)'),
                        maxLines: 2,
                        style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
                      ),

                      const SizedBox(height: 24),

                      // ─── Difficulty ─────────────────
                      _buildSectionHeader('Difficulty', Icons.speed_rounded),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: GameDifficulty.values.map((d) {
                          final selected = d == _difficulty;
                          return ChoiceChip(
                            label: Text(d.label),
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
                      _buildSectionHeader('Time Limit', Icons.timer_rounded),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _timeLimitMinutes.toDouble(),
                              min: 3,
                              max: 30,
                              divisions: 9,
                              label: '$_timeLimitMinutes min',
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
                              '$_timeLimitMinutes min',
                              style: AppTypography.labelLarge
                                  .copyWith(color: hc.textPrimary),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ─── Questions ─────────────────
                      _buildSectionHeader(
                        'Questions (${_questions.length})',
                        Icons.quiz_rounded,
                      ),
                      const SizedBox(height: 8),

                      if (_questions.isEmpty)
                        RichEmptyState(
                          emoji: '📝',
                          title: 'No Questions Yet',
                          description: 'Add your first question to build the assessment.',
                          actionLabel: 'Add First Question',
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
                            onDelete: () => setState(() {
                              _questions.removeAt(i);
                            }),
                            onEdit: () => _showEditQuestionDialog(i),
                          );
                        }),

                      if (_questions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: OutlinedButton.icon(
                            onPressed: () => _showAddQuestionDialog(),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add Question'),
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
        Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            color: hc.textPrimary,
            fontWeight: FontWeight.w700,
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
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _QuestionEditorSheet(),
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
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _QuestionEditorSheet(existing: _questions[index]),
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
      AppSnackBar.warning(context, message: 'Add at least one question');
      return;
    }

    final assessment = Assessment(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? 'Custom teacher assessment'
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

    ref.read(customAssessmentsProvider.notifier).saveAssessment(assessment);

    AppSnackBar.success(context, message: 'Assessment "${assessment.title}" saved!');

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
        title: const Text('Discard Assessment?'),
        content: const Text(
          'You have unsaved questions. Are you sure you want to go back?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Discard'),
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
                    label: question.format.name, color: AppColors.info),
                _MiniChip(
                    label: 'Answer: ${question.correctAnswer}',
                    color: AppColors.success),
                if (question.category != null)
                  _MiniChip(
                      label: question.category!.label, color: AppColors.accent),
              ],
            ),
            if (question.choices.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Choices: ${question.choices.join(", ")}',
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
  const _QuestionEditorSheet({this.existing});

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
                  widget.existing != null ? 'Edit Question' : 'Add Question',
                  style: AppTypography.titleLarge
                      .copyWith(color: hc.textPrimary),
                ),
                const SizedBox(height: 16),

                // Question format selector
                Text('Question Type',
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
                      label: Text(_formatLabel(f)),
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
                  decoration: _inputDecor(hc, 'Question Text *'),
                  style: AppTypography.bodyLarge
                      .copyWith(color: hc.textPrimary),
                ),

                const SizedBox(height: 12),

                // Correct answer
                TextField(
                  controller: _correctAnswerController,
                  decoration: _inputDecor(hc, 'Correct Answer *'),
                  style: AppTypography.bodyMedium
                      .copyWith(color: hc.textPrimary),
                ),

                // Choices (for MC and T/F)
                if (_format != QuestionFormat.fillInBlank) ...[
                  const SizedBox(height: 16),
                  Text('Choices',
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
                                  hc, 'Choice ${String.fromCharCode(65 + i)}'),
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
                      label: const Text('Add Choice'),
                    ),
                ],

                const SizedBox(height: 12),

                // Category
                DropdownButtonFormField<FlashcardCategory>(
                  initialValue: _selectedCategory,
                  decoration: _inputDecor(hc, 'Category (optional)'),
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
                  decoration: _inputDecor(hc, 'Hint (optional)'),
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
                        ? 'Update Question'
                        : 'Add Question',
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

  String _formatLabel(QuestionFormat f) {
    switch (f) {
      case QuestionFormat.multipleChoice:
        return 'Multiple Choice';
      case QuestionFormat.trueFalse:
        return 'True / False';
      case QuestionFormat.fillInBlank:
        return 'Fill in Blank';
      case QuestionFormat.matchPairs:
        return 'Match Pairs';
    }
  }

  void _saveQuestion() {
    final qText = _questionTextController.text.trim();
    final answer = _correctAnswerController.text.trim();

    if (qText.isEmpty || answer.isEmpty) {
      AppSnackBar.warning(context, message: 'Question text and answer are required');
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
        AppSnackBar.warning(context, message: 'Correct answer must match one of the choices');
        return;
      }
    }

    final question = AssessmentQuestion(
      id: widget.existing?.id ??
          'q_${DateTime.now().millisecondsSinceEpoch}',
      questionText: qText,
      correctAnswer: answer,
      choices: choices,
      format: _format,
      category: _selectedCategory,
      hint: _hintController.text.trim().isEmpty
          ? null
          : _hintController.text.trim(),
    );

    Navigator.pop(context, question);
  }
}
