import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/accessibility_content_policy.dart';
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
import '../widgets/story_fsl_button.dart';
import '../widgets/story_image_flip.dart';

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
    // Read-aloud buttons hidden when Text-to-Speech is off.
    final ttsEnabled = settings.ttsEnabled;
    // FSL "watch signed" buttons hidden for non-signing accessibility
    // categories (e.g. visual / cognitive), per the content policy.
    final showFsl = ref.watch(
      accessibilityContentPolicyProvider.select((p) => p.showFsl),
    );
    // Drives the cartoon ⇄ real-life flip animation speed (accessibility).
    final reducedMotion = settings.reducedMotion;
    final question = _question!;

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
                            // Both languages are shown together — English as
                            // the main line with the Tagalog translation
                            // beneath it, mirroring the Flashcards → Cards
                            // layout (large English word over a smaller
                            // Filipino word).
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  question.questionEn,
                                  style: AppTypography.headlineSmall
                                      .copyWith(fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  question.questionFil,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: _story!.category.darkColor,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: 0.05, end: 0),

                          // Cartoon ⇄ real-life tap-to-flip picture for the
                          // question. Tap the cartoon to reveal the real photo
                          // (and back); the caption updates to match the face.
                          if (question.image != null) ...[
                            const SizedBox(height: 20),
                            Center(
                              child: StoryImageFlip(
                                key: ValueKey(
                                  'story_${_story!.id}_q$_currentQ',
                                ),
                                pair: question.image!,
                                cacheKey: '${_story!.id}_q$_currentQ',
                                color: _story!.category.color,
                                semanticLabel: question.questionEn,
                                reducedMotion: reducedMotion,
                                maxWidth: context.responsiveTier(
                                  phone: 300.0,
                                  tablet: 380.0,
                                  large: 420.0,
                                ),
                              ),
                            ),
                          ],

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

                          // Watch the question signed. Always available when
                          // the story has an FSL track — independent of TTS so
                          // Deaf learners can sign-read the prompt.
                          if (showFsl && question.fslVideoUrl != null) ...[
                            const SizedBox(height: 12),
                            StoryFslButton(
                              pageUrl: question.fslVideoUrl!,
                              cacheKey: 'story_${_story!.id}_q$_currentQ',
                              label: question.questionEn,
                              secondaryLabel: question.questionFil,
                              color: _story!.category.color,
                            ),
                          ],

                          const SizedBox(height: 28),

                          // Options
                          ...question.optionsEn.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final text = entry.value; // English — main line
                            final textFil =
                                question.optionsFil[idx]; // Tagalog — below
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

                            // Tagalog line keeps the category accent normally,
                            // but adopts the green/red state colour once this
                            // option is marked correct or wrongly selected, so
                            // both lines read as one piece of feedback.
                            final subColor =
                                (_answered && (isCorrect || isSelected))
                                    ? textColor
                                    : _story!.category.darkColor;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Semantics(
                                label: '$text, $textFil',
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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Cartoon ⇄ real-life tap-to-flip
                                        // picture for this choice. Its own tap
                                        // target (it flips the picture); it
                                        // never selects the answer.
                                        if (question.imageForOption(idx) !=
                                            null) ...[
                                          Center(
                                            child: StoryImageFlip(
                                              key: ValueKey(
                                                'story_${_story!.id}_q${_currentQ}_o$idx',
                                              ),
                                              pair:
                                                  question.imageForOption(idx)!,
                                              cacheKey:
                                                  '${_story!.id}_q${_currentQ}_o$idx',
                                              color: _story!.category.color,
                                              semanticLabel: text,
                                              reducedMotion: reducedMotion,
                                              compact: true,
                                              maxWidth: 220,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                        ],
                                        Row(
                                          children: [
                                            // Option letter
                                            Container(
                                              width: context.scaleIcon(36),
                                              height: context.scaleIcon(36),
                                              decoration: BoxDecoration(
                                                color: borderColor
                                                    .withValues(alpha: 0.15),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  String.fromCharCode(
                                                      65 + idx), // A, B, C
                                                  style: AppTypography.titleSmall
                                                      .copyWith(
                                                          color: textColor),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // English — the main line.
                                                  Text(
                                                    text,
                                                    style: AppTypography
                                                        .bodyLarge
                                                        .copyWith(
                                                            color: textColor),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  // Tagalog translation beneath,
                                                  // smaller, like the flashcard
                                                  // card's Filipino word.
                                                  Text(
                                                    textFil,
                                                    style: AppTypography
                                                        .bodyMedium
                                                        .copyWith(
                                                      color: subColor,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (_answered && isCorrect)
                                              Icon(Icons.check_circle_rounded,
                                                  color: AppColors.success,
                                                  size: context.scaleIcon(24)),
                                            if (_answered &&
                                                isSelected &&
                                                !isCorrect)
                                              Icon(Icons.cancel_rounded,
                                                  color: AppColors.error,
                                                  size: context.scaleIcon(24)),
                                          ],
                                        ),
                                        // Per-choice helpers: hear this choice in
                                        // English and in Tagalog (mirroring the
                                        // question's two-language read-aloud) and
                                        // watch it signed. Each is its own tap
                                        // target, so they never select the
                                        // answer; the surrounding empty space
                                        // still selects. A Wrap lets the controls
                                        // flow onto another line instead of
                                        // overflowing on a narrow phone at a
                                        // large font scale.
                                        if (ttsEnabled ||
                                            question.fslForOption(idx) != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 12, left: 50),
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                if (ttsEnabled) ...[
                                                  _ChoiceListenButton(
                                                    label: 'English',
                                                    semanticLabel:
                                                        'Listen to this choice in English',
                                                    color: AppColors.info,
                                                    onTap: () => _speakLang(
                                                      question.optionsEn[idx],
                                                      filipino: false,
                                                    ),
                                                  ),
                                                  _ChoiceListenButton(
                                                    label: 'Tagalog',
                                                    semanticLabel:
                                                        'Listen to this choice in Tagalog',
                                                    color: AppColors.secondary,
                                                    onTap: () => _speakLang(
                                                      question.optionsFil[idx],
                                                      filipino: true,
                                                    ),
                                                  ),
                                                ],
                                                // Watch this choice signed (when
                                                // the story has an FSL track).
                                                if (showFsl &&
                                                    question.fslForOption(idx) !=
                                                        null)
                                                  StoryFslButton(
                                                    pageUrl: question
                                                        .fslForOption(idx)!,
                                                    cacheKey:
                                                        'story_${_story!.id}_q${_currentQ}_o$idx',
                                                    label:
                                                        question.optionsEn[idx],
                                                    secondaryLabel: question
                                                        .optionsFil[idx],
                                                    color:
                                                        _story!.category.color,
                                                    compact: true,
                                                  ),
                                              ],
                                            ),
                                          ),
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

/// A compact, single-language "listen" pill for one quiz answer choice.
///
/// Two of these sit beneath each choice — English and Tagalog — echoing the
/// question's [LanguageReplayBar] so a learner can hear any individual choice
/// in either language. The caller lays them out in a [Wrap], so the pills flow
/// onto a new line rather than overflowing on a narrow phone at a large font
/// scale. It is its own button, so a tap reads the choice aloud without
/// selecting the answer.
class _ChoiceListenButton extends StatelessWidget {
  /// Visible language label (e.g. "English", "Tagalog").
  final String label;

  /// Full spoken description for screen readers.
  final String semanticLabel;

  /// Accent colour — blue for English, teal for Tagalog, matching the
  /// question's two-language read-aloud bar.
  final Color color;

  final VoidCallback onTap;

  const _ChoiceListenButton({
    required this.label,
    required this.semanticLabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(Icons.volume_up_rounded, size: context.scaleIcon(18)),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            // 44dp floor keeps the target above the accessibility minimum while
            // staying compact enough to sit two-up beside the FSL button.
            minimumSize: const Size(0, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle:
                AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
