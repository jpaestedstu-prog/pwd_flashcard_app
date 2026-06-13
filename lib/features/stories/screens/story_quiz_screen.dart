import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/accessibility/haptic_service.dart' show hapticServiceProvider;
import '../../../core/services/celebration_service.dart';
import '../../../widgets/accessible_celebration_overlay.dart';
import '../../../data/local/seed_stories.dart' show SeedStories, Story, StoryQuestion;
import '../../../data/models/enums.dart';
import '../../../data/models/achievements.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/game_widgets.dart';
import '../../../widgets/achievement_overlay.dart';
import '../../../widgets/language_replay_bar.dart';

/// Reading-comprehension quiz — 3 multiple-choice questions per story.
class StoryQuizScreen extends ConsumerStatefulWidget {
  final String storyId;
  const StoryQuizScreen({super.key, required this.storyId});

  @override
  ConsumerState<StoryQuizScreen> createState() => _StoryQuizScreenState();
}

class _StoryQuizScreenState extends ConsumerState<StoryQuizScreen> {
  Story? _story;
  int _currentQ = 0;
  int _correctCount = 0;
  int? _selectedIndex;
  bool _answered = false;
  bool _showResult = false;
  List<Achievement> _newAchievements = [];
  TtsService? _ttsRef;

  @override
  void initState() {
    super.initState();
    _story = SeedStories.all.where((s) => s.id == widget.storyId).firstOrNull;
  }

  @override
  void dispose() {
    _ttsRef?.stop();
    super.dispose();
  }

  /// Reads the current question aloud in one language — a read-aloud
  /// accommodation for the comprehension quiz. Independent of the displayed
  /// language so a learner can hear it in whichever they understand.
  void _speakLang(String text, {required bool filipino}) {
    if (text.trim().isEmpty) return;
    final tts = ref.read(ttsServiceProvider);
    _ttsRef = tts; // cache for safe dispose
    if (filipino) {
      tts.speakFilipino(text);
    } else {
      tts.speakEnglish(text);
    }
  }

  StoryQuestion? get _question => _story?.questions[_currentQ];

  bool get _isLastQuestion {
    final story = _story;
    if (story == null) return true;
    return _currentQ >= story.questions.length - 1;
  }

  int get _starsEarned {
    // 1 star per correct answer (max 3)
    return _correctCount.clamp(0, 3);
  }

  void _selectAnswer(int index) {
    if (_answered || _question == null) return;
    final correct = index == _question!.correctIndex;

    setState(() {
      _selectedIndex = index;
      _answered = true;
    });

    if (correct) {
      _correctCount++;
      ref.read(soundServiceProvider).playCorrect();
      ref.read(hapticServiceProvider).success();
    } else {
      ref.read(soundServiceProvider).playWrong();
      ref.read(hapticServiceProvider).error();
    }
  }

  void _next() {
    if (_isLastQuestion) {
      _saveProgress();
      setState(() => _showResult = true);
    } else {
      setState(() {
        _currentQ++;
        _selectedIndex = null;
        _answered = false;
      });
    }
  }

  void _saveProgress() {
    ref.read(progressProvider.notifier).recordGameResult(
      gameType: GameType.storyQuiz,
      score: _correctCount,
      total: _story!.questions.length,
      starsEarned: _starsEarned,
      categoriesPlayed: [_story!.category],
    );
    // Track the best star score for this specific story (drives the ★ badge
    // on the story card). Reaching the quiz also implies the story was read.
    ref.read(progressProvider.notifier)
      ..recordStoryRead(_story!.id)
      ..recordStoryQuizStars(_story!.id, _starsEarned);
    _newAchievements = ref.read(progressProvider.notifier).checkAchievements();
    AccessibleCelebrationOverlay.show(
      context: context, ref: ref, type: CelebrationType.gameComplete,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_story == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.quizNotFound)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 64, color: HCColor.of(context).textSecondary),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.storyNotFoundMsg, style: AppTypography.headlineSmall),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: Text(AppLocalizations.of(context)!.goBack),
              ),
            ],
          ),
        ),
      );
    }

    if (_showResult) {
      return Stack(
        children: [
          CelebrationOverlay(
            show: true,
            child: Scaffold(
              body: Center(
                child: GameResultDialog(
                  score: _correctCount,
                  total: _story!.questions.length,
                  starsEarned: _starsEarned,
                  onPlayAgain: () {
                    setState(() {
                      _currentQ = 0;
                      _correctCount = 0;
                      _selectedIndex = null;
                      _answered = false;
                      _showResult = false;
                    });
                  },
                  onExit: () => context.go('/stories'),
                ),
              ),
            ),
          ),
          if (_newAchievements.isNotEmpty)
            AchievementUnlockedOverlay(
              achievements: _newAchievements,
              onDismiss: () => setState(() => _newAchievements = []),
            ),
        ],
      );
    }

    final hc = HCColor.of(context);
    final settings = ref.watch(settingsProvider);
    final showFil = settings.locale == 'fil';
    // Read-aloud buttons hidden when Text-to-Speech is off.
    final ttsEnabled = settings.ttsEnabled;
    final question = _question!;
    final questionText =
        showFil ? question.questionFil : question.questionEn;
    final options = showFil ? question.optionsFil : question.optionsEn;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => context.pop(),
        ),
        title: Text('Quiz: ${_story!.titleEn}'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.maxContentWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.pagePadding,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress (fixed at top)
                  Semantics(
                    label:
                        'Question ${_currentQ + 1} of ${_story!.questions.length}',
                    child: LinearProgressIndicator(
                      value: (_currentQ + 1) / _story!.questions.length,
                      backgroundColor: AppColors.border,
                      color: _story!.category.color,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Question ${_currentQ + 1} of ${_story!.questions.length}',
                    style: AppTypography.labelSmall
                        .copyWith(color: hc.textSecondary),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // ─── Question + options (scrolls when too tall) ──────────
                  // Expanded + SingleChildScrollView keeps long questions and
                  // 4-option sets (plus large Font Size settings) from ever
                  // forcing a bottom RenderFlex overflow.
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Question
                          Container(
                            padding: EdgeInsets.all(
                              context.responsiveTier(
                                phone: 20.0,
                                tablet: 24.0,
                                large: 28.0,
                              ),
                            ),
                            decoration: BoxDecoration(
                              color: hc.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: hc.hc
                                  ? Border.all(color: AppColors.hcPrimary, width: 2)
                                  : null,
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: Text(
                              questionText,
                              style: AppTypography.headlineSmall
                                  .copyWith(fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: 0.05, end: 0),

                          // Read the question aloud in either language — a
                          // read-aloud accommodation for learners who find the
                          // text hard to read or understand one language better.
                          if (ttsEnabled) ...[
                            const SizedBox(height: 16),
                            LanguageReplayBar(
                              onEnglish: () => _speakLang(
                                question.questionEn,
                                filipino: false,
                              ),
                              onFilipino: () => _speakLang(
                                question.questionFil,
                                filipino: true,
                              ),
                            ),
                          ],

                          const SizedBox(height: 28),

                          // Options
                          ...options.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final text = entry.value;
                            final isSelected = _selectedIndex == idx;
                            final isCorrect = idx == question.correctIndex;

                            Color bgColor;
                            Color borderColor;
                            Color textColor = hc.textPrimary;

                            if (!_answered) {
                              bgColor = hc.surface;
                              borderColor = isSelected
                                  ? _story!.category.color
                                  : AppColors.border;
                            } else if (isCorrect) {
                              bgColor = AppColors.success.withValues(alpha: 0.12);
                              borderColor = AppColors.success;
                              textColor = AppColors.success;
                            } else if (isSelected && !isCorrect) {
                              bgColor = AppColors.error.withValues(alpha: 0.12);
                              borderColor = AppColors.error;
                              textColor = AppColors.error;
                            } else {
                              bgColor = hc.surface;
                              borderColor = AppColors.border;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Semantics(
                                label: text,
                                selected: isSelected,
                                child: InkWell(
                                  onTap: _answered ? null : () => _selectAnswer(idx),
                                  borderRadius: BorderRadius.circular(16),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 16),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: borderColor, width: 2),
                                    ),
                                    child: Row(
                                      children: [
                                        // Option letter
                                        Container(
                                          width: context.scaleIcon(36),
                                          height: context.scaleIcon(36),
                                          decoration: BoxDecoration(
                                            color: borderColor.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              String.fromCharCode(65 + idx), // A, B, C
                                              style: AppTypography.titleSmall
                                                  .copyWith(color: textColor),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            text,
                                            style: AppTypography.bodyLarge
                                                .copyWith(color: textColor),
                                          ),
                                        ),
                                        if (_answered && isCorrect)
                                          Icon(Icons.check_circle_rounded,
                                              color: AppColors.success,
                                              size: context.scaleIcon(24)),
                                        if (_answered && isSelected && !isCorrect)
                                          Icon(Icons.cancel_rounded,
                                              color: AppColors.error,
                                              size: context.scaleIcon(24)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 300.ms, delay: (100 * idx).ms)
                                .slideX(begin: 0.03, end: 0);
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Next / Finish button (fixed at bottom)
                  if (_answered)
                    ElevatedButton.icon(
                      onPressed: _next,
                      icon: Icon(_isLastQuestion
                          ? Icons.emoji_events_rounded
                          : Icons.arrow_forward_rounded),
                      label: Text(
                        _isLastQuestion ? 'See Results' : 'Next Question',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _story!.category.color,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
