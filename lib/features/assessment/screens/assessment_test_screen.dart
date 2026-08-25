import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/experiment_provider.dart';
import '../../experiment/models/experiment_models.dart';
import '../models/assessment_models.dart';
import '../providers/assessment_provider.dart';

/// Screen that runs an assessment quiz — supports multiple choice,
/// true/false, and fill-in-the-blank question formats. Fully accessible
/// with Semantics, TTS-ready, and high-contrast support.
class AssessmentTestScreen extends ConsumerStatefulWidget {
  final Assessment assessment;

  /// Source of "now" for every time this screen measures — question response
  /// times, total duration, and the countdown on a timed assessment.
  ///
  /// A seam, not a feature: the countdown is derived from the wall clock so a
  /// tablet that slept cannot hand the learner extra minutes, but `DateTime.now`
  /// is exactly what a widget test's fake-async cannot advance. Production
  /// leaves this alone and gets the real clock.
  final DateTime Function()? clock;

  const AssessmentTestScreen({
    super.key,
    required this.assessment,
    this.clock,
  });

  @override
  ConsumerState<AssessmentTestScreen> createState() =>
      _AssessmentTestScreenState();
}

class _AssessmentTestScreenState extends ConsumerState<AssessmentTestScreen> {
  late List<AssessmentQuestion> _questions;
  int _currentIndex = 0;
  final List<QuestionAnswer> _answers = [];
  String? _selectedAnswer;
  bool _answered = false;
  bool _isCorrect = false;
  final _fillController = TextEditingController();
  late DateTime _questionStartTime;
  late DateTime _assessmentStartTime;
  bool _showHint = false;

  /// Countdown for assessments the educator gave a time limit. Null when the
  /// assessment is untimed, which is the common case — the field was written
  /// by the builder and the quiz generator but never read by anything, so
  /// "10 min" on a teacher's assessment meant nothing at all until now.
  Timer? _timer;
  Duration? _remaining;

  /// Guards the single submission. The timer expiring and the learner
  /// answering the last question can otherwise both fire [_finishAssessment],
  /// saving the result twice and pushing two summary screens.
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _questions = widget.assessment.questions;
    _assessmentStartTime = _now();
    _questionStartTime = _now();

    final limit = widget.assessment.timeLimitMinutes;
    if (limit != null && limit > 0) {
      _remaining = Duration(minutes: limit);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fillController.dispose();
    super.dispose();
  }

  /// Recomputes the remaining time from the wall clock rather than counting
  /// ticks, so a tablet that slept or throttled timers does not hand back
  /// extra minutes. Runs out of time → submit what has been answered.
  void _tick() {
    if (!mounted || _finished) return;
    final limit = widget.assessment.timeLimitMinutes;
    if (limit == null) return;
    final left =
        Duration(minutes: limit) -
        _now().difference(_assessmentStartTime);
    if (left <= Duration.zero) {
      _timer?.cancel();
      setState(() => _remaining = Duration.zero);
      _finishAssessment();
      return;
    }
    setState(() => _remaining = left);
  }

  /// The screen's clock: the injected one in tests, the real one in the app.
  DateTime _now() => (widget.clock ?? DateTime.now)();

  AssessmentQuestion get _currentQuestion => _questions[_currentIndex];
  bool get _isLastQuestion => _currentIndex >= _questions.length - 1;
  double get _progress => (_currentIndex + 1) / _questions.length;

  void _selectAnswer(String answer) {
    if (_answered) return;
    final haptic = ref.read(hapticServiceProvider);
    final responseTime =
        _now().difference(_questionStartTime).inMilliseconds;
    final correct =
        answer.trim().toLowerCase() == _currentQuestion.correctAnswer.trim().toLowerCase();

    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      _isCorrect = correct;
    });

    if (correct) {
      haptic.celebration();
    } else {
      haptic.error();
    }

    _answers.add(QuestionAnswer(
      questionId: _currentQuestion.id,
      givenAnswer: answer,
      isCorrect: correct,
      responseTimeMs: responseTime,
    ));
  }

  void _submitFillIn() {
    final text = _fillController.text.trim();
    if (text.isEmpty) return;
    _selectAnswer(text);
  }

  void _nextQuestion() {
    if (_isLastQuestion) {
      _finishAssessment();
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedAnswer = null;
      _answered = false;
      _isCorrect = false;
      _showHint = false;
      _fillController.clear();
      _questionStartTime = _now();
    });
  }

  void _finishAssessment() {
    if (_finished) return;
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    _finished = true;
    _timer?.cancel();

    final score = _answers.where((a) => a.isCorrect).length;
    final durationSeconds =
        _now().difference(_assessmentStartTime).inSeconds;

    // Calculate per-category scores
    final categoryScores = <String, double>{};
    final categoryCorrect = <String, int>{};
    final categoryTotal = <String, int>{};
    for (int i = 0; i < _questions.length; i++) {
      final cat = _questions[i].category;
      if (cat == null) continue;
      final key = cat.label;
      categoryTotal[key] = (categoryTotal[key] ?? 0) + 1;
      if (i < _answers.length && _answers[i].isCorrect) {
        categoryCorrect[key] = (categoryCorrect[key] ?? 0) + 1;
      }
    }
    for (final key in categoryTotal.keys) {
      categoryScores[key] = (categoryCorrect[key] ?? 0) / categoryTotal[key]!;
    }

    final result = AssessmentResult(
      id: const Uuid().v4(),
      assessmentId: widget.assessment.id,
      profileId: profile.id,
      type: widget.assessment.type,
      score: score,
      totalQuestions: _questions.length,
      answers: _answers,
      completedAt: _now(),
      durationSeconds: durationSeconds,
      categories: widget.assessment.categories,
      categoryScores: categoryScores,
    );

    // Save result
    ref.read(assessmentResultsProvider.notifier).saveResult(result);

    // Award stars based on performance
    final pct = score / _questions.length;
    int stars = 0;
    if (pct >= 0.9) {
      stars = 5;
    } else if (pct >= 0.75) {
      stars = 3;
    } else if (pct >= 0.5) {
      stars = 2;
    } else if (pct > 0) {
      stars = 1;
    }
    if (stars > 0) {
      final starsEnabled = ref.read(
        gamificationFeatureProvider(GamificationFeature.stars),
      );
      if (starsEnabled) {
        ref.read(progressProvider.notifier).addStars(stars);
      }
    }

    // Navigate to result summary
    if (context.mounted) {
      context.pushReplacement(
        '/assessment/summary',
        extra: result,
      );
    }
  }

  void _confirmQuit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit Assessment?'),
        content: const Text(
            'Your progress will be lost. Are you sure you want to quit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final padding = context.pagePadding;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // ─── Top Bar ──────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(padding, 12, padding, 0),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Quit assessment',
                      child: IconButton(
                        onPressed: _confirmQuit,
                        icon: Icon(Icons.close_rounded,
                            color: hc.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            widget.assessment.type.label,
                            style: AppTypography.labelMedium.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                          Text(
                            'Question ${_currentIndex + 1} of ${_questions.length}',
                            style: AppTypography.titleSmall.copyWith(
                              color: hc.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Score so far
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: hc.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_answers.where((a) => a.isCorrect).length}/${_answers.length}',
                        style: AppTypography.labelLarge.copyWith(
                          color: hc.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Progress Bar (+ countdown, when timed) ───
              // The countdown shares this row rather than the top bar: the
              // bar can give up width, whereas a third chip up there overflows
              // at large text scales on a small phone.
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: padding, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label:
                            'Progress: ${(_progress * 100).round()} percent complete',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 8,
                            backgroundColor: hc.border,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(hc.primary),
                          ),
                        ),
                      ),
                    ),
                    if (_remaining != null) ...[
                      const SizedBox(width: 12),
                      _TimeRemainingChip(remaining: _remaining!, hc: hc),
                    ],
                  ],
                ),
              ),

              // ─── Question Content ─────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Category chip
                      if (_currentQuestion.category != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _currentQuestion.category!.color
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _currentQuestion.category!.label,
                              style: AppTypography.labelSmall.copyWith(
                                color: _currentQuestion.category!.darkColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Format badge
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: hc.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _currentQuestion.format.label,
                            style: AppTypography.labelSmall.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Question text
                      Semantics(
                        header: true,
                        child: Text(
                          _currentQuestion.questionText,
                          style: AppTypography.headlineMedium.copyWith(
                            color: hc.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                          .animate(key: ValueKey(_currentIndex))
                          .fadeIn(duration: 400.ms)
                          .slideX(begin: 0.05, end: 0),

                      const SizedBox(height: 24),

                      // Answer area based on format
                      if (_currentQuestion.format ==
                          QuestionFormat.fillInBlank)
                        _buildFillInBlank(hc)
                      else
                        _buildChoices(hc),

                      // Hint toggle
                      if (_currentQuestion.hint != null &&
                          _currentQuestion.hint!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showHint = !_showHint),
                          child: Semantics(
                            button: true,
                            label: _showHint ? 'Hide hint' : 'Show hint',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showHint
                                      ? Icons.lightbulb_rounded
                                      : Icons.lightbulb_outline_rounded,
                                  color: hc.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _showHint ? 'Hide Hint' : 'Show Hint',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: hc.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showHint)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    hc.warning.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                  color: hc.warning
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                _currentQuestion.hint!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: hc.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .slideY(begin: -0.1, end: 0),
                          ),
                      ],

                      // Feedback after answering
                      if (_answered) ...[
                        const SizedBox(height: 20),
                        _buildFeedback(hc),
                      ],
                    ],
                  ),
                ),
              ),

              // ─── Bottom Action ────────────────────────────
              if (_answered)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      padding, 0, padding, padding),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hc.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _isLastQuestion ? 'Finish Assessment' : 'Next Question',
                        style: AppTypography.buttonText,
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoices(HCColor hc) {
    return Column(
      children: List.generate(_currentQuestion.choices.length, (i) {
        final choice = _currentQuestion.choices[i];
        final isSelected = _selectedAnswer == choice;
        final isCorrectAnswer =
            choice.toLowerCase() ==
            _currentQuestion.correctAnswer.toLowerCase();

        Color bgColor;
        Color borderColor;
        Color textColor;

        if (!_answered) {
          bgColor = hc.surface;
          borderColor = hc.border;
          textColor = hc.textPrimary;
        } else if (isSelected && _isCorrect) {
          bgColor = AppColors.success.withValues(alpha: 0.15);
          borderColor = AppColors.success;
          textColor = AppColors.success;
        } else if (isSelected && !_isCorrect) {
          bgColor = AppColors.error.withValues(alpha: 0.15);
          borderColor = AppColors.error;
          textColor = AppColors.error;
        } else if (isCorrectAnswer) {
          bgColor = AppColors.success.withValues(alpha: 0.1);
          borderColor = AppColors.success.withValues(alpha: 0.5);
          textColor = AppColors.success;
        } else {
          bgColor = hc.surface;
          borderColor = hc.border;
          textColor = hc.textHint;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(
            button: !_answered,
            label: choice,
            selected: isSelected,
            child: GestureDetector(
              onTap: () => _selectAnswer(choice),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: borderColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + i), // A, B, C, D
                          style: AppTypography.labelLarge.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        choice,
                        style: AppTypography.titleSmall.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_answered && isCorrectAnswer)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 22),
                    if (_answered && isSelected && !_isCorrect)
                      const Icon(Icons.cancel_rounded,
                          color: AppColors.error, size: 22),
                  ],
                ),
              ),
            ),
          ),
        )
            .animate(key: ValueKey('choice_${_currentIndex}_$i'))
            .fadeIn(duration: 300.ms, delay: (100 + i * 80).ms)
            .slideY(begin: 0.1, end: 0);
      }),
    );
  }

  Widget _buildFillInBlank(HCColor hc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _fillController,
          enabled: !_answered,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Type your answer here...',
            hintStyle: AppTypography.bodyMedium.copyWith(color: hc.textHint),
            filled: true,
            fillColor: hc.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: hc.border, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: hc.border, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: hc.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            suffixIcon: _answered
                ? Icon(
                    _isCorrect
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: _isCorrect ? AppColors.success : AppColors.error,
                  )
                : null,
          ),
          style: AppTypography.titleMedium.copyWith(
            color: _answered
                ? (_isCorrect ? AppColors.success : AppColors.error)
                : hc.textPrimary,
          ),
          onSubmitted: (_) => _submitFillIn(),
        ),
        if (!_answered) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitFillIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: hc.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text('Submit Answer', style: AppTypography.buttonText),
            ),
          ),
        ],
        if (_answered && !_isCorrect) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Correct answer: ${_currentQuestion.correctAnswer}',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
        ],
      ],
    ).animate(key: ValueKey('fill_$_currentIndex')).fadeIn(duration: 400.ms);
  }

  Widget _buildFeedback(HCColor hc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (_isCorrect ? AppColors.success : AppColors.error)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (_isCorrect ? AppColors.success : AppColors.error)
              .withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Text(
            _isCorrect ? '🎉' : '💡',
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCorrect ? 'Correct!' : 'Not quite right',
                  style: AppTypography.titleSmall.copyWith(
                    color:
                        _isCorrect ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!_isCorrect)
                  Text(
                    'The correct answer is: ${_currentQuestion.correctAnswer}',
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.0, 1.0),
          duration: 300.ms,
        );
  }
}

// ─── Time Remaining Chip ───────────────────────────────

/// Calm countdown for a timed assessment.
///
/// Deliberately not animated, and it does not flash: this app's learners
/// include children with cognitive and attention disabilities, for whom a
/// pulsing clock is a reason to stop trying. It changes colour once, in the
/// last minute, and reads its remaining time to a screen reader as words
/// rather than as a bare "4:07".
class _TimeRemainingChip extends StatelessWidget {
  final Duration remaining;
  final HCColor hc;

  const _TimeRemainingChip({required this.remaining, required this.hc});

  @override
  Widget build(BuildContext context) {
    final urgent = remaining.inSeconds <= 60;
    final color = urgent ? hc.error : hc.textSecondary;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    return Semantics(
      liveRegion: urgent,
      label: minutes > 0
          ? '$minutes minute${minutes == 1 ? '' : 's'} remaining'
          : '$seconds second${seconds == 1 ? '' : 's'} remaining',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              '$minutes:${seconds.toString().padLeft(2, '0')}',
              style: AppTypography.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
