import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';

import '../../../providers/app_providers.dart';
import '../models/assessment_models.dart';
import '../models/custom_quiz_models.dart';
import '../providers/quiz_builder_provider.dart';
import '../services/assessment_service.dart';
import '../../../widgets/app_back_button.dart';
import '../../../core/widgets/fit_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

class QuizBuilderScreen extends ConsumerStatefulWidget {
  const QuizBuilderScreen({super.key});

  @override
  ConsumerState<QuizBuilderScreen> createState() => _QuizBuilderScreenState();
}

class _QuizBuilderScreenState extends ConsumerState<QuizBuilderScreen> {
  final _titleController = TextEditingController();
  bool _titleSeeded = false;
  FlashcardCategory? _selectedCategory;
  GameDifficulty _difficulty = GameDifficulty.medium;
  final Set<String> _selectedCardIds = {};
  final Set<QuestionFormat> _selectedFormats = {QuestionFormat.multipleChoice};
  int? _timeLimit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The starting name follows the app language; what a teacher types is
    // kept exactly as typed.
    if (!_titleSeeded) {
      _titleSeeded = true;
      _titleController.text = _t(context).qbMyQuiz;
    }
  }

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
        leading: const AppBackButton(fallbackRoute: '/assessment-hub'),
        title: Text(
          _t(context).qbTitle,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _selectedCardIds.length >= 3 ? _saveQuiz : null,
            icon: const Icon(Icons.check_rounded),
            label: Text(_t(context).gmSave),
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
                labelText: _t(context).qbQuizTitle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),

            // ─── Difficulty ───────────────────────
            Text(
              _t(context).abDifficulty,
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
                        // Three labels share the control and it cannot wrap,
                        // so at a large text scale it ran 90 px off the right.
                        // `fittedStyle`, not `FitText`: a SegmentedButton
                        // measures its segments' intrinsic widths.
                        label: Text(
                          d.labelOf(_t(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: fittedStyle(
                            context,
                            d.labelOf(_t(context)),
                            Theme.of(context).textTheme.labelLarge,
                            longWord: 4,
                          ),
                        ),
                      ))
                  .toList(),
              selected: {_difficulty},
              onSelectionChanged: (s) =>
                  setState(() => _difficulty = s.first),
            ),
            const SizedBox(height: 20),

            // ─── Question Formats ─────────────────
            Text(
              _t(context).qbQuestionTypes,
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: authorableQuestionFormats.map((fmt) {
                return FilterChip(
                  label: Text(fmt.labelOf(_t(context))),
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
              _t(context).qbTimeLimit,
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
                  label: Text(mins == null
                      ? _t(context).qbNoLimit
                      : _t(context).abMinutes(mins)),
                  selected: _timeLimit == mins,
                  onSelected: (_) => setState(() => _timeLimit = mins),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ─── Category Filter ──────────────────
            Text(
              _t(context).qbSelectWords(_selectedCardIds.length),
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
                      label: Text(_t(context).all),
                      selected: _selectedCategory == null,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = null),
                    ),
                  ),
                  ...FlashcardCategory.values.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat.labelOf(_t(context))),
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
                // Two rigid text buttons side by side: "Select All" and
                // "Deselect All" together are wider than the row at 2x.
                Flexible(
                  child: TextButton(
                    onPressed: () => setState(() =>
                        _selectedCardIds
                            .addAll(filteredCards.map((c) => c.id))),
                    child: Text(
                      _t(context).qbSelectAll,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Flexible(
                  child: TextButton(
                    onPressed: () => setState(() =>
                        _selectedCardIds.removeWhere(
                            (id) => filteredCards.any((c) => c.id == id))),
                    child: Text(
                      _t(context).qbDeselectAll,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                  // The vocabulary pair being picked: it split
                  // "Grandmothe / r" and "Transportatio / n".
                  title: FitText(
                    '${card.wordEnglish} / ${card.wordFilipino}',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: hc.textPrimary,
                    ),
                  ),
                  subtitle: FitText(
                    card.category.labelOf(_t(context)),
                    maxLines: 1,
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
                  _t(context).qbAtLeast3,
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
                _t(context).qbSaved,
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
                    title: FitText(
                      quiz.title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hc.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _t(context).qbSummary(
                        quiz.flashcardIds.length,
                        quiz.difficulty.labelOf(_t(context)),
                        quiz.questionFormats
                            .map((f) => f.labelOf(_t(context)))
                            .join(', '),
                      ),
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
                          tooltip: _t(context).qbStart,
                          onPressed: () => _startQuiz(quiz),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.error),
                          tooltip: _t(context).delete,
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

    // The title is how a teacher finds this again in Assign Tasks, so two
    // quizzes may not share one. Refused rather than silently renamed: quietly
    // changing what somebody typed is worse in a tool where the name is the
    // handle. Easy to hit by accident because saving resets the field back to
    // "My Quiz" — which is exactly how a duplicate got made during testing.
    final clash = ref
        .read(quizBuilderProvider)
        .any((q) => q.title.toLowerCase() == title.toLowerCase());
    if (clash) {
      AppSnackBar.warning(
        context,
        message: _t(context).qbDuplicate(title),
      );
      return;
    }

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

    AppSnackBar.success(context, message: _t(context).qbSavedOne(title));

    // Reset selection
    setState(() {
      _selectedCardIds.clear();
      _titleController.text = _t(context).qbMyQuiz;
    });
  }

  void _startQuiz(CustomQuiz quiz) {
    final allCards = ref.read(allFlashcardsProvider);
    // Keeps the quiz's own id so a learner's practice history stays grouped
    // under it. Assigning takes the same path but mints a fresh id — see
    // [AssessmentService.materialiseQuiz].
    final assessment = AssessmentService.materialiseQuiz(
      quiz,
      allCards,
      id: quiz.id,
    );

    if (assessment.questions.isEmpty) {
      AppSnackBar.warning(context, message: _t(context).qbNoCards);
      return;
    }

    context.push('/assessment/take/${quiz.id}', extra: assessment);
  }

  Future<void> _confirmDeleteQuiz(CustomQuiz quiz) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(context).qbDeleteTitle),
        content: Text(_t(context).qbDeleteBody(quiz.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(_t(context).delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(quizBuilderProvider.notifier).deleteQuiz(quiz.id);
    }
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
