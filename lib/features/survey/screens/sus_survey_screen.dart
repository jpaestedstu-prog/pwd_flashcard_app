import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../widgets/app_snack_bar.dart';
import '../../../providers/app_providers.dart';
import '../models/survey_models.dart';
import '../services/survey_service.dart';

/// Full SUS (System Usability Scale) survey screen.
///
/// Presents the standard 10 SUS questions with a 5-point Likert scale
/// and an optional free-text feedback field.
class SusSurveyScreen extends ConsumerStatefulWidget {
  const SusSurveyScreen({super.key});

  @override
  ConsumerState<SusSurveyScreen> createState() => _SusSurveyScreenState();
}

class _SusSurveyScreenState extends ConsumerState<SusSurveyScreen> {
  /// Responses for each of the 10 questions (0 = unanswered, 1–5 = Likert).
  final List<int> _responses = List.filled(10, 0);
  final _feedbackController = TextEditingController();
  final _scrollController = ScrollController();
  bool _saving = false;
  int _currentPage = 0; // 0 = questions, 1 = review & submit

  @override
  void dispose() {
    _feedbackController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _allAnswered => _responses.every((r) => r > 0);

  Future<void> _submit() async {
    if (!_allAnswered) return;
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    setState(() => _saving = true);

    final result = SurveyService.createResult(
      profileId: profile.id,
      responses: List.from(_responses),
      feedback: _feedbackController.text.trim().isNotEmpty
          ? _feedbackController.text.trim()
          : null,
    );

    await SurveyService.saveSurveyResult(result);
    ref.read(hapticServiceProvider).success();

    if (mounted) {
      AppSnackBar.success(context,
          message: 'Survey submitted! Thank you for your feedback.');
      context.pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final padding = context.pagePadding;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final questions =
        isFilipino ? SusQuestions.filipino : SusQuestions.english;
    final scaleLabels = isFilipino
        ? SusQuestions.scaleLabelsFilipino
        : SusQuestions.scaleLabelsEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Sarbey ng Kakayahang-gamit' : 'Usability Survey'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.06),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: _currentPage == 0
              ? _buildQuestionsPage(
                  questions, scaleLabels, padding, isFilipino, colorScheme)
              : _buildReviewPage(
                  questions, padding, isFilipino, colorScheme),
        ),
      ),
    );
  }

  Widget _buildQuestionsPage(
    List<String> questions,
    List<String> scaleLabels,
    double padding,
    bool isFilipino,
    ColorScheme colorScheme,
  ) {
    final answeredCount = _responses.where((r) => r > 0).length;

    return Column(
      children: [
        // Progress indicator
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isFilipino
                        ? '$answeredCount / 10 na tanong ang nasagot'
                        : '$answeredCount / 10 questions answered',
                    style: AppTypography.bodySmall.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${(answeredCount * 10)}%',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: answeredCount / 10,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: AppColors.primary,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 8),
        // Questions list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(horizontal: padding),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              return _buildQuestionCard(
                index: index,
                question: questions[index],
                scaleLabels: scaleLabels,
                colorScheme: colorScheme,
                isFilipino: isFilipino,
              ).animate().fadeIn(
                    duration: 300.ms,
                    delay: Duration(milliseconds: 50 * index),
                  );
            },
          ),
        ),
        // Next button
        Padding(
          padding: EdgeInsets.all(padding),
          child: Semantics(
            button: true,
            enabled: _allAnswered,
            label: isFilipino ? 'Susunod sa pagsusuri' : 'Next to review',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _allAnswered
                    ? () => setState(() => _currentPage = 1)
                    : null,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(isFilipino ? 'Susunod' : 'Review & Submit'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard({
    required int index,
    required String question,
    required List<String> scaleLabels,
    required ColorScheme colorScheme,
    required bool isFilipino,
  }) {
    final selected = _responses[index];
    final isPositive = index.isEven; // Odd SUS questions are positive-phrased

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected > 0
              ? AppColors.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant,
          width: selected > 0 ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question number & text
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected > 0
                        ? AppColors.primary
                        : colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: AppTypography.labelMedium.copyWith(
                        color: selected > 0
                            ? Colors.white
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Likert scale (1–5)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) {
                final value = i + 1;
                final isSelected = selected == value;
                return Expanded(
                  child: Semantics(
                    selected: isSelected,
                    label: '${scaleLabels[i]}, ${isFilipino ? "tanong" : "question"} ${index + 1}',
                    child: GestureDetector(
                      onTap: () {
                        ref.read(hapticServiceProvider).lightTap();
                        setState(() => _responses[index] = value);
                      },
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _likertColor(value, isPositive)
                                  : colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? _likertColor(value, isPositive)
                                    : colorScheme.outlineVariant,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$value',
                                style: AppTypography.labelLarge.copyWith(
                                  color: isSelected
                                      ? Colors.white
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            scaleLabels[i],
                            style: AppTypography.labelSmall.copyWith(
                              color: isSelected
                                  ? _likertColor(value, isPositive)
                                  : colorScheme.onSurfaceVariant,
                              fontSize: 9,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewPage(
    List<String> questions,
    double padding,
    bool isFilipino,
    ColorScheme colorScheme,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFilipino ? 'Suriin ang iyong mga sagot' : 'Review Your Answers',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 8),
          Text(
            isFilipino
                ? 'Tiyaking tama ang lahat ng sagot bago mag-submit.'
                : 'Make sure all answers are correct before submitting.',
            style: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          // Summary list
          ...List.generate(10, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Q${i + 1}. ',
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      questions[i],
                      style: AppTypography.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _likertColor(_responses[i], i.isEven)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_responses[i]}/5',
                      style: AppTypography.labelMedium.copyWith(
                        color: _likertColor(_responses[i], i.isEven),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          // Feedback field
          Text(
            isFilipino
                ? 'Karagdagang komento (opsyonal)'
                : 'Additional Comments (Optional)',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: isFilipino
                ? 'Karagdagang komento sa app'
                : 'Additional comments about the app',
            child: TextField(
              controller: _feedbackController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: isFilipino
                    ? 'May gusto ka bang idagdag?...'
                    : 'Anything else you want to share?...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _currentPage = 0),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(isFilipino ? 'Bumalik' : 'Go Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Semantics(
                  button: true,
                  label: isFilipino ? 'I-submit ang sarbey' : 'Submit survey',
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(isFilipino ? 'I-submit' : 'Submit Survey'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Color gradient for Likert scale values.
  Color _likertColor(int value, bool isPositiveQuestion) {
    // For positive questions: 5 = green, 1 = red
    // For negative questions: 1 = green, 5 = red (inverted UX cue)
    final effectiveValue = isPositiveQuestion ? value : 6 - value;
    return switch (effectiveValue) {
      1 => Colors.red.shade600,
      2 => Colors.orange.shade600,
      3 => Colors.amber.shade600,
      4 => Colors.lightGreen.shade600,
      5 => Colors.green.shade600,
      _ => Colors.grey,
    };
  }
}
