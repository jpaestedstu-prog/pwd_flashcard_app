import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../core/accessibility/haptic_service.dart' show hapticServiceProvider;
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../models/guided_practice_models.dart';
import '../services/guided_practice_service.dart';

class GuidedPracticeScreen extends ConsumerStatefulWidget {
  final FlashcardCategory category;

  const GuidedPracticeScreen({super.key, required this.category});

  @override
  ConsumerState<GuidedPracticeScreen> createState() =>
      _GuidedPracticeScreenState();
}

class _GuidedPracticeScreenState extends ConsumerState<GuidedPracticeScreen> {
  GuidedPracticeSession? _session;
  String? _selectedAnswer;
  bool _showResult = false;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _startSession() {
    final cards =
        ref.read(flashcardsByCategoryProvider(widget.category));
    setState(() {
      _session = GuidedPracticeService.generateSession(
        category: widget.category,
        availableCards: cards,
      );
      _selectedAnswer = null;
      _showResult = false;
      _textController.clear();
    });
  }

  void _checkAnswer() {
    if (_session == null || _session!.isComplete) return;
    final step = _session!.currentStep;
    bool correct = false;

    switch (step.type) {
      case PracticeStepType.flashcardReview:
      case PracticeStepType.listenAndRepeat:
        // These are auto-correct (just review)
        correct = true;
      case PracticeStepType.fillInBlank:
        final answer = _textController.text.trim().toLowerCase();
        final expected = step.targetCard.wordEnglish.toLowerCase();
        correct = answer == expected;
      case PracticeStepType.matchPair:
      case PracticeStepType.miniQuiz:
        correct = _selectedAnswer == step.targetCard.wordFilipino;
    }

    final updatedSteps = List<PracticeStep>.from(_session!.steps);
    updatedSteps[_session!.currentStepIndex] =
        step.copyWith(isCompleted: true, wasCorrect: correct);

    setState(() {
      _showResult = true;
      _session = _session!.copyWith(
        steps: updatedSteps,
        correctCount:
            correct ? _session!.correctCount + 1 : _session!.correctCount,
      );
    });

    if (correct) {
      ref.read(hapticServiceProvider).success();
    } else {
      ref.read(hapticServiceProvider).error();
    }
  }

  void _nextStep() {
    if (_session == null) return;
    final nextIndex = _session!.currentStepIndex + 1;

    if (nextIndex >= _session!.totalSteps) {
      // Session complete — record result
      _completeSession();
      return;
    }

    setState(() {
      _session = _session!.copyWith(currentStepIndex: nextIndex);
      _selectedAnswer = null;
      _showResult = false;
      _textController.clear();
    });
  }

  void _completeSession() {
    if (_session == null) return;
    // A card counts as learned once any step targeting it was answered
    // correctly — several steps can drill the same card.
    final correctWordIds = _session!.steps
        .where((s) => s.wasCorrect == true)
        .map((s) => s.targetCard.id)
        .toSet();
    ref.read(progressProvider.notifier).recordGameResult(
          gameType: GameType.flashcardQuiz,
          score: _session!.correctCount,
          total: _session!.totalSteps,
          starsEarned: _session!.starsEarned,
          categoriesPlayed: [widget.category],
          correctWordIds: correctWordIds,
        );

    setState(() {
      _session = _session!.copyWith(
        currentStepIndex: _session!.totalSteps,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.pagePadding;
    final hc = HCColor.of(context);
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';

    if (_session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Guided Practice')),
        body: const ShimmerPageSkeleton(),
      );
    }

    if (_session!.isComplete) {
      return _CompletionScreen(
        session: _session!,
        isFilipino: isFilipino,
        onRestart: _startSession,
        onClose: () => context.pop(),
      );
    }

    final step = _session!.currentStep;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFilipino ? 'Guided Practice' : 'Guided Practice',
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress bar
              LinearPercentIndicator(
                padding: EdgeInsets.zero,
                lineHeight: 8,
                percent: _session!.progress.clamp(0.0, 1.0),
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                progressColor: AppColors.primary,
                barRadius: const Radius.circular(4),
                animation: true,
                animationDuration: 300,
              ),
              const SizedBox(height: 4),
              Text(
                '${isFilipino ? 'Hakbang' : 'Step'} ${_session!.currentStepIndex + 1} / ${_session!.totalSteps}',
                style: AppTypography.bodySmall
                    .copyWith(color: hc.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Step type badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.12),
                        AppColors.primary.withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(step.type.emoji,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        isFilipino
                            ? step.type.labelFilipino
                            : step.type.label,
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 24),

              // Step content
              Expanded(
                child: _buildStepContent(step, isFilipino, hc),
              ),

              // Action button
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _showResult ? _nextStep : _checkAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showResult
                        ? AppColors.primary
                        : AppColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _showResult
                        ? (_session!.currentStepIndex + 1 >=
                                _session!.totalSteps
                            ? (isFilipino ? 'Tapusin' : 'Finish')
                            : (isFilipino ? 'Susunod' : 'Next'))
                        : step.type == PracticeStepType.flashcardReview ||
                                step.type ==
                                    PracticeStepType.listenAndRepeat
                            ? (isFilipino ? 'Tapos Na' : 'Done')
                            : (isFilipino ? 'I-check' : 'Check'),
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(PracticeStep step, bool isFilipino, HCColor hc) {
    switch (step.type) {
      case PracticeStepType.flashcardReview:
        return _ReviewContent(card: step.targetCard, isFilipino: isFilipino);
      case PracticeStepType.listenAndRepeat:
        return _ListenContent(card: step.targetCard, isFilipino: isFilipino);
      case PracticeStepType.fillInBlank:
        return _FillBlankContent(
          card: step.targetCard,
          hint: step.hint,
          controller: _textController,
          showResult: _showResult,
          wasCorrect: step.wasCorrect,
          isFilipino: isFilipino,
        );
      case PracticeStepType.matchPair:
      case PracticeStepType.miniQuiz:
        return _QuizContent(
          card: step.targetCard,
          options: step.options ?? [],
          selectedAnswer: _selectedAnswer,
          showResult: _showResult,
          wasCorrect: step.wasCorrect,
          isFilipino: isFilipino,
          onSelect: (answer) => setState(() => _selectedAnswer = answer),
        );
    }
  }
}

class _ReviewContent extends StatelessWidget {
  final Flashcard card;
  final bool isFilipino;

  const _ReviewContent({required this.card, required this.isFilipino});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: hc.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isFilipino ? 'Suriin ang salita:' : 'Review this word:',
                style:
                    AppTypography.bodyMedium.copyWith(color: hc.textSecondary)),
            const SizedBox(height: 16),
            Text(card.wordEnglish,
                style: AppTypography.headlineLarge.copyWith(
                    fontWeight: FontWeight.w800, color: hc.textPrimary)),
            const SizedBox(height: 8),
            Text(card.wordFilipino,
                style: AppTypography.titleLarge.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
            if (card.exampleSentence != null) ...[
              const SizedBox(height: 16),
              Text(card.exampleSentence!,
                  style: AppTypography.bodyMedium
                      .copyWith(color: hc.textSecondary, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
    );
  }
}

class _ListenContent extends StatelessWidget {
  final Flashcard card;
  final bool isFilipino;

  const _ListenContent({required this.card, required this.isFilipino});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              isFilipino
                  ? 'Pakinggan at ulitin:'
                  : 'Listen and repeat:',
              style: AppTypography.bodyMedium
                  .copyWith(color: hc.textSecondary)),
          const SizedBox(height: 24),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.volume_up_rounded,
                size: 48, color: AppColors.secondary),
          ),
          const SizedBox(height: 20),
          Text(card.wordEnglish,
              style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800, color: hc.textPrimary)),
          const SizedBox(height: 8),
          Text(card.wordFilipino,
              style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primary)),
          const SizedBox(height: 16),
          Text(
            isFilipino
                ? 'Sabihin ang salita nang malakas'
                : 'Say the word out loud',
            style:
                AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}

class _FillBlankContent extends StatelessWidget {
  final Flashcard card;
  final String? hint;
  final TextEditingController controller;
  final bool showResult;
  final bool? wasCorrect;
  final bool isFilipino;

  const _FillBlankContent({
    required this.card,
    this.hint,
    required this.controller,
    required this.showResult,
    this.wasCorrect,
    required this.isFilipino,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              isFilipino
                  ? 'I-type ang English na salita para sa:'
                  : 'Type the English word for:',
              style: AppTypography.bodyMedium
                  .copyWith(color: hc.textSecondary)),
          const SizedBox(height: 16),
          Text(card.wordFilipino,
              style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800, color: AppColors.primary)),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text('${isFilipino ? 'Pahiwatig' : 'Hint'}: $hint',
                style: AppTypography.bodySmall
                    .copyWith(color: hc.textSecondary)),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            enabled: !showResult,
            textAlign: TextAlign.center,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: showResult
                  ? (wasCorrect == true ? AppColors.success : AppColors.error)
                  : hc.textPrimary,
            ),
            decoration: InputDecoration(
              hintText:
                  isFilipino ? 'I-type dito...' : 'Type here...',
              filled: true,
              fillColor: hc.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: hc.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: hc.border),
              ),
            ),
          ),
          if (showResult && wasCorrect == false) ...[
            const SizedBox(height: 12),
            Text(
              '${isFilipino ? 'Tamang sagot' : 'Correct answer'}: ${card.wordEnglish}',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (showResult)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Icon(
                wasCorrect == true
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 48,
                color: wasCorrect == true
                    ? AppColors.success
                    : AppColors.error,
              ),
            ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}

class _QuizContent extends StatelessWidget {
  final Flashcard card;
  final List<String> options;
  final String? selectedAnswer;
  final bool showResult;
  final bool? wasCorrect;
  final bool isFilipino;
  final ValueChanged<String> onSelect;

  const _QuizContent({
    required this.card,
    required this.options,
    this.selectedAnswer,
    required this.showResult,
    this.wasCorrect,
    required this.isFilipino,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
            isFilipino
                ? 'Ano ang Filipino ng:'
                : 'What is the Filipino for:',
            style:
                AppTypography.bodyMedium.copyWith(color: hc.textSecondary)),
        const SizedBox(height: 12),
        Text(card.wordEnglish,
            style: AppTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.w800, color: hc.textPrimary)),
        const SizedBox(height: 24),
        ...options.map((option) {
          final isSelected = selectedAnswer == option;
          final isCorrect = option == card.wordFilipino;

          Color bgColor = hc.surface;
          Color borderColor = hc.border;
          if (showResult) {
            if (isCorrect) {
              bgColor = AppColors.success.withValues(alpha: 0.1);
              borderColor = AppColors.success;
            } else if (isSelected) {
              bgColor = AppColors.error.withValues(alpha: 0.1);
              borderColor = AppColors.error;
            }
          } else if (isSelected) {
            bgColor = AppColors.primary.withValues(alpha: 0.1);
            borderColor = AppColors.primary;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              button: true,
              selected: isSelected,
              label: option,
              child: GestureDetector(
                onTap: showResult ? null : () => onSelect(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: hc.textPrimary,
                          ),
                        ),
                      ),
                      if (showResult && isCorrect)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 22),
                      if (showResult && isSelected && !isCorrect)
                        const Icon(Icons.cancel_rounded,
                            color: AppColors.error, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _CompletionScreen extends StatelessWidget {
  final GuidedPracticeSession session;
  final bool isFilipino;
  final VoidCallback onRestart;
  final VoidCallback onClose;

  const _CompletionScreen({
    required this.session,
    required this.isFilipino,
    required this.onRestart,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final pct = session.totalSteps > 0
        ? (session.correctCount / session.totalSteps * 100).round()
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Tapos Na!' : 'Complete!'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(context.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                isFilipino ? 'Magaling!' : 'Great Job!',
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: hc.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$pct% ${isFilipino ? 'Tama' : 'Correct'} • ${session.correctCount}/${session.totalSteps}',
                style: AppTypography.titleMedium
                    .copyWith(color: hc.textSecondary),
              ),
              const SizedBox(height: 12),
              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Icon(
                    i < session.starsEarned
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 40,
                    color: i < session.starsEarned
                        ? const Color(0xFFFFB300)
                        : hc.textSecondary,
                  );
                }),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textOnPrimary),
                  label: Text(
                    isFilipino ? 'Subukan Muli' : 'Try Again',
                    style: AppTypography.titleSmall
                        .copyWith(color: AppColors.textOnPrimary, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onClose,
                child: Text(isFilipino ? 'Bumalik sa Home' : 'Back to Home'),
              ),
            ],
          ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9)),
        ),
      ),
    );
  }
}
