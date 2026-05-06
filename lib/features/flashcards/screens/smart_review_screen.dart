import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/services/celebration_service.dart';
import '../../../widgets/accessible_celebration_overlay.dart';
import '../../../data/models/models.dart';
import '../../../data/models/enums.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/flashcard_image.dart';
import '../../../l10n/app_localizations.dart';

/// Smart Review screen that uses spaced repetition to present
/// the words the student struggles with most.
class SmartReviewScreen extends ConsumerStatefulWidget {
  const SmartReviewScreen({super.key});

  @override
  ConsumerState<SmartReviewScreen> createState() => _SmartReviewScreenState();
}

class _SmartReviewScreenState extends ConsumerState<SmartReviewScreen> {
  List<Flashcard> _reviewCards = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  int _correctCount = 0;
  int _totalAnswered = 0;
  bool _finished = false;
  final Map<String, bool> _results = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReviewWords());
  }

  void _loadReviewWords() {
    final profile = ref.read(profileProvider);
    final allCards = ref.read(allFlashcardsProvider);
    if (profile == null) return;

    final cards = SpacedRepetitionService.getReviewWords(
      profileId: profile.id,
      allCards: allCards,
    );

    setState(() {
      _reviewCards = cards;
    });
  }

  void _revealAnswer() {
    setState(() => _showAnswer = true);
    // Speak the word
    final settings = ref.read(settingsProvider);
    if (settings.ttsEnabled) {
      final card = _reviewCards[_currentIndex];
      ref.read(ttsServiceProvider).speakEnglish(card.wordEnglish);
    }
  }

  void _answerKnow() {
    final card = _reviewCards[_currentIndex];
    _results[card.id] = true;
    ref.read(hapticServiceProvider).success();
    ref.read(soundServiceProvider).playCorrect();
    setState(() {
      _correctCount++;
      _totalAnswered++;
    });
    _advance();
  }

  void _answerDontKnow() {
    final card = _reviewCards[_currentIndex];
    _results[card.id] = false;
    ref.read(hapticServiceProvider).error();
    ref.read(soundServiceProvider).playWrong();
    setState(() {
      _totalAnswered++;
    });
    _advance();
  }

  void _advance() {
    if (_currentIndex >= _reviewCards.length - 1) {
      _finishReview();
    } else {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
    }
  }

  Future<void> _finishReview() async {
    // Record all word attempts
    final profile = ref.read(profileProvider);
    if (profile != null && _results.isNotEmpty) {
      await SpacedRepetitionService.recordBatch(
        profileId: profile.id,
        results: _results,
      );
    }
    if (mounted) {
      AccessibleCelebrationOverlay.show(
        context: context, ref: ref, type: CelebrationType.gameComplete,
      );
    }
    setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    if (_finished) return _buildResultScreen();

    if (_reviewCards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Go back',
            onPressed: () => context.pop(),
          ),
          title: Text(AppLocalizations.of(context)!.smartReview),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 80,
                  color: AppColors.success,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.noWordsToReview,
                  style: AppTypography.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.playGamesFirst,
                  style: AppTypography.bodyMedium.copyWith(
                    color: hc.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final card = _reviewCards[_currentIndex];
    final progressPct = (_currentIndex + 1) / _reviewCards.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => context.pop(),
        ),
        title: Text(
          '${AppLocalizations.of(context)!.smartReview}  ${_currentIndex + 1}/${_reviewCards.length}',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progressPct,
            backgroundColor: AppColors.border,
            color: AppColors.primary,
            minHeight: 4,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),

            // ─── Card ──────────────────
            Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
                  decoration: BoxDecoration(
                    color: hc.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppColors.softShadow,
                    border: Border.all(
                      color: _showAnswer
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.border,
                      width: _showAnswer ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Category chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: card.category.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          card.category.label,
                          style: AppTypography.labelSmall.copyWith(
                            color: card.category.darkColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Per-word image
                      FlashcardImage(
                        card: card,
                        size: 52,
                        borderRadius: 16,
                      ),
                      const SizedBox(height: 16),

                      // English word
                      Semantics(
                        label: 'English word: ${card.wordEnglish}',
                        child: Text(
                          card.wordEnglish,
                          style: AppTypography.flashcardWord.copyWith(
                            color: hc.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (card.exampleSentence != null)
                        Text(
                          card.exampleSentence!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),

                      if (_showAnswer) ...[
                        const SizedBox(height: 24),
                        Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(
                                  alpha: 0.3,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Filipino',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Semantics(
                                    label:
                                        'Filipino translation: ${card.wordFilipino}',
                                    child: Text(
                                      card.wordFilipino,
                                      style: AppTypography.headlineMedium
                                          .copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.1, end: 0),
                      ],
                    ],
                  ),
                )
                .animate(key: ValueKey(_currentIndex))
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.05, end: 0),

            const Spacer(),

            // ─── Action Buttons ────────
            if (!_showAnswer)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _revealAnswer,
                  icon: const Icon(Icons.visibility_rounded),
                  label: Text(
                    AppLocalizations.of(context)!.showAnswer,
                    style: AppTypography.buttonText.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms)
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _answerDontKnow,
                        icon: const Icon(Icons.close_rounded, color: AppColors.error),
                        label: Text(
                          AppLocalizations.of(context)!.stillLearning,
                          style: AppTypography.buttonText.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _answerKnow,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          AppLocalizations.of(context)!.iKnowIt,
                          style: AppTypography.buttonText.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final pct = _totalAnswered > 0 ? _correctCount / _totalAnswered : 0.0;
    final stars = pct >= 0.8 ? 3 : (pct >= 0.5 ? 2 : 1);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                pct >= 0.7 ? Icons.emoji_events_rounded : Icons.refresh_rounded,
                size: 80,
                color: pct >= 0.7 ? AppColors.warning : AppColors.primary,
              ).animate().scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.0, 1.0),
                duration: 500.ms,
                curve: Curves.elasticOut,
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.reviewComplete,
                style: AppTypography.headlineLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pct >= 0.7
                    ? 'Great recall! Keep it up!'
                    : 'Keep practicing — you\'ll get there!',
                style: AppTypography.bodyLarge.copyWith(
                  color: HCColor.of(context).textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final earned = i < stars;
                  return Icon(
                        earned ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 48,
                        color: earned ? AppColors.warning : AppColors.border,
                      )
                      .animate(delay: Duration(milliseconds: 200 + i * 150))
                      .scale(
                        begin: const Offset(0.0, 0.0),
                        end: const Offset(1.0, 1.0),
                        duration: 400.ms,
                        curve: Curves.elasticOut,
                      );
                }),
              ),
              const SizedBox(height: 24),

              // Score
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: HCColor.of(context).surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.softShadow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ResultStat(
                      label: 'Correct',
                      value: '$_correctCount',
                      color: AppColors.success,
                    ),
                    Container(width: 1, height: 40, color: AppColors.border),
                    _ResultStat(
                      label: 'Total',
                      value: '$_totalAnswered',
                      color: AppColors.primary,
                    ),
                    Container(width: 1, height: 40, color: AppColors.border),
                    _ResultStat(
                      label: 'Accuracy',
                      value: '${(pct * 100).round()}%',
                      color: pct >= 0.7 ? AppColors.success : AppColors.warning,
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

              const SizedBox(height: 32),

              // Buttons
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 0;
                      _showAnswer = false;
                      _correctCount = 0;
                      _totalAnswered = 0;
                      _finished = false;
                      _results.clear();
                    });
                    _loadReviewWords();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.reviewAgain,
                    style: AppTypography.buttonText.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)!.done, style: AppTypography.buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ResultStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: HCColor.of(context).textSecondary,
          ),
        ),
      ],
    );
  }
}
