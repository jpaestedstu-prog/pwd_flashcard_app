import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';

import '../../../providers/app_providers.dart';
import '../models/assessment_models.dart';
import '../models/custom_quiz_models.dart';
import '../providers/quiz_builder_provider.dart';

class QuizBuilderScreen extends ConsumerStatefulWidget {
  const QuizBuilderScreen({super.key});

  @override
  ConsumerState<QuizBuilderScreen> createState() => _QuizBuilderScreenState();
}

class _QuizBuilderScreenState extends ConsumerState<QuizBuilderScreen> {
  final _titleController = TextEditingController(text: 'My Quiz');
  FlashcardCategory? _selectedCategory;
  GameDifficulty _difficulty = GameDifficulty.medium;
  final Set<String> _selectedCardIds = {};
  final Set<QuestionFormat> _selectedFormats = {QuestionFormat.multipleChoice};
  int? _timeLimit;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allCards = ref.watch(allFlashcardsProvider);
    final savedQuizzes = ref.watch(quizBuilderProvider);
    final hc = HCColor.of(context);

    final filteredCards = _selectedCategory == null
        ? allCards
        : allCards.where((c) => c.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/assessment');
            }
          },
        ),
        title: Text(
          'Quiz Builder',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _selectedCardIds.length >= 3 ? _saveQuiz : null,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Quiz Title ───────────────────────
            TextField(
              controller: _titleController,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Quiz Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),

            // ─── Difficulty ───────────────────────
            Text(
              'Difficulty',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<GameDifficulty>(
              segments: GameDifficulty.values
                  .map((d) => ButtonSegment(
                        value: d,
                        label: Text(d.label),
                      ))
                  .toList(),
              selected: {_difficulty},
              onSelectionChanged: (s) =>
                  setState(() => _difficulty = s.first),
            ),
            const SizedBox(height: 20),

            // ─── Question Formats ─────────────────
            Text(
              'Question Types',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: QuestionFormat.values.map((fmt) {
                return FilterChip(
                  label: Text(fmt.label),
                  selected: _selectedFormats.contains(fmt),
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _selectedFormats.add(fmt);
                      } else if (_selectedFormats.length > 1) {
                        _selectedFormats.remove(fmt);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ─── Time Limit ───────────────────────
            Text(
              'Time Limit (optional)',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [null, 5, 10, 15, 20].map((mins) {
                return ChoiceChip(
                  label: Text(mins == null ? 'No limit' : '$mins min'),
                  selected: _timeLimit == mins,
                  onSelected: (_) => setState(() => _timeLimit = mins),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ─── Category Filter ──────────────────
            Text(
              'Select Words (${_selectedCardIds.length} selected)',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _selectedCategory == null,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = null),
                    ),
                  ),
                  ...FlashcardCategory.values.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat.label),
                          selected: _selectedCategory == cat,
                          onSelected: (_) => setState(() =>
                              _selectedCategory =
                                  _selectedCategory == cat ? null : cat),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Select/deselect all
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() =>
                      _selectedCardIds
                          .addAll(filteredCards.map((c) => c.id))),
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: () => setState(() =>
                      _selectedCardIds.removeWhere(
                          (id) => filteredCards.any((c) => c.id == id))),
                  child: const Text('Deselect All'),
                ),
              ],
            ),

            // ─── Word Selection Grid ──────────────
            ...filteredCards.asMap().entries.map((entry) {
              final card = entry.value;
              final selected = _selectedCardIds.contains(card.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: CheckboxListTile(
                  value: selected,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedCardIds.add(card.id);
                      } else {
                        _selectedCardIds.remove(card.id);
                      }
                    });
                  },
                  title: Text(
                    '${card.wordEnglish} / ${card.wordFilipino}',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: hc.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    card.category.label,
                    style: AppTypography.labelSmall.copyWith(
                      color: card.category.color,
                    ),
                  ),
                  secondary: Icon(card.category.icon,
                      color: card.category.color, size: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: selected
                      ? hc.primary.withValues(alpha: 0.06)
                      : hc.surface,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              );
            }),

            if (_selectedCardIds.length < 3)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Select at least 3 words to create a quiz',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // ─── Saved Quizzes ────────────────────
            if (savedQuizzes.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Saved Quizzes',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ...savedQuizzes.asMap().entries.map((entry) {
                final quiz = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Text('📝', style: TextStyle(fontSize: 24)),
                    title: Text(
                      quiz.title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hc.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${quiz.flashcardIds.length} words • '
                      '${quiz.difficulty.label} • '
                      '${quiz.questionFormats.map((f) => f.label).join(', ')}',
                      style: AppTypography.labelSmall.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_arrow_rounded,
                              color: AppColors.success),
                          tooltip: 'Start Quiz',
                          onPressed: () => _startQuiz(quiz),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.error),
                          tooltip: 'Delete',
                          onPressed: () => _confirmDeleteQuiz(quiz),
                        ),
                      ],
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    tileColor: hc.surface,
                  ),
                ).animate().fadeIn(
                      duration: 300.ms,
                      delay: Duration(milliseconds: 50 * entry.key),
                    );
              }),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _saveQuiz() {
    final title = _titleController.text.trim();
    if (title.isEmpty || _selectedCardIds.length < 3) return;

    final profile = ref.read(profileProvider);
    final quiz = CustomQuiz(
      id: 'quiz_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      flashcardIds: _selectedCardIds.toList(),
      questionFormats: _selectedFormats.toList(),
      difficulty: _difficulty,
      timeLimitMinutes: _timeLimit,
      createdBy: profile?.id ?? '',
      createdAt: DateTime.now(),
    );

    ref.read(quizBuilderProvider.notifier).addQuiz(quiz);

    AppSnackBar.success(context, message: 'Quiz "$title" saved!');

    // Reset selection
    setState(() {
      _selectedCardIds.clear();
      _titleController.text = 'My Quiz';
    });
  }

  void _startQuiz(CustomQuiz quiz) {
    final allCards = ref.read(allFlashcardsProvider);
    final quizCards = allCards
        .where((c) => quiz.flashcardIds.contains(c.id))
        .toList();

    if (quizCards.isEmpty) {
      AppSnackBar.warning(context, message: 'No valid cards found for this quiz');
      return;
    }

    // Build an Assessment from the quiz and navigate
    final random = Random();
    final questions = quizCards.map((card) {
      final format = quiz.questionFormats[
          random.nextInt(quiz.questionFormats.length)];
      return _buildQuestion(card, format, allCards);
    }).toList();

    final assessment = Assessment(
      id: quiz.id,
      title: quiz.title,
      type: AssessmentType.custom,
      questions: questions,
      difficulty: quiz.difficulty,
      timeLimitMinutes: quiz.timeLimitMinutes,
      createdBy: quiz.createdBy,
      createdAt: quiz.createdAt,
    );

    context.push('/assessment/take/${quiz.id}', extra: assessment);
  }

  AssessmentQuestion _buildQuestion(
    Flashcard card,
    QuestionFormat format,
    List<Flashcard> allCards,
  ) {
    final random = Random();
    switch (format) {
      case QuestionFormat.multipleChoice:
        final others = allCards
            .where((c) => c.id != card.id)
            .toList()
          ..shuffle(random);
        final wrongChoices =
            others.take(3).map((c) => c.wordFilipino).toList();
        final choices = [card.wordFilipino, ...wrongChoices]
          ..shuffle(random);
        return AssessmentQuestion(
          id: 'q_${card.id}',
          questionText:
              'What is the Filipino word for "${card.wordEnglish}"?',
          correctAnswer: card.wordFilipino,
          choices: choices,
          category: card.category,
        );

      case QuestionFormat.fillInBlank:
        return AssessmentQuestion(
          id: 'q_${card.id}',
          questionText:
              'Fill in the blank: The Filipino translation of '
              '"${card.wordEnglish}" is _____.',
          correctAnswer: card.wordFilipino,
          choices: [],
          format: QuestionFormat.fillInBlank,
          category: card.category,
        );

      case QuestionFormat.trueFalse:
        final isTrue = random.nextBool();
        final displayWord = isTrue
            ? card.wordFilipino
            : (allCards
                    .where((c) => c.id != card.id)
                    .toList()
                  ..shuffle(random))
                .first
                .wordFilipino;
        return AssessmentQuestion(
          id: 'q_${card.id}',
          questionText:
              'True or False: "${card.wordEnglish}" is "$displayWord" in Filipino.',
          correctAnswer: isTrue ? 'True' : 'False',
          choices: ['True', 'False'],
          format: QuestionFormat.trueFalse,
          category: card.category,
        );

      case QuestionFormat.matchPairs:
        // Falls back to multiple choice for matching
        final others = allCards
            .where((c) => c.id != card.id)
            .toList()
          ..shuffle(random);
        final wrongChoices =
            others.take(3).map((c) => c.wordFilipino).toList();
        final choices = [card.wordFilipino, ...wrongChoices]
          ..shuffle(random);
        return AssessmentQuestion(
          id: 'q_${card.id}',
          questionText:
              'Match: "${card.wordEnglish}" → ?',
          correctAnswer: card.wordFilipino,
          choices: choices,
          category: card.category,
        );
    }
  }

  Future<void> _confirmDeleteQuiz(CustomQuiz quiz) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quiz?'),
        content: Text('Delete "${quiz.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(quizBuilderProvider.notifier).deleteQuiz(quiz.id);
    }
  }
}
