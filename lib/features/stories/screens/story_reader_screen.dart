import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../data/local/seed_stories.dart' show SeedStories, Story;
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_action_bar.dart';
import '../../../widgets/app_icon_button.dart';
import '../../../widgets/language_replay_bar.dart';
import '../../../widgets/page_turn_switcher.dart';
import '../../../widgets/square_action_button.dart';
import '../widgets/story_fsl_button.dart';
import '../widgets/story_image_flip.dart';

/// Paginated story reader with TTS and vocabulary highlights.
class StoryReaderScreen extends ConsumerStatefulWidget {
  final String storyId;
  const StoryReaderScreen({super.key, required this.storyId});

  @override
  ConsumerState<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends ConsumerState<StoryReaderScreen> {
  Story? _story;
  int _currentSentence = 0;
  TtsService? _ttsRef;

  /// Direction of the latest page move — drives which way the page-turn
  /// transition rotates (Next turns forward, Back turns backward).
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _story = SeedStories.all.where((s) => s.id == widget.storyId).firstOrNull;
    // Mark single-sentence stories read as soon as they open (the one
    // sentence is already on screen). Multi-sentence stories are marked
    // when the learner reaches the last sentence.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isLastSentence) _markStoryRead();
    });
  }

  @override
  void dispose() {
    _ttsRef?.stop();
    super.dispose();
  }

  bool get _isLastSentence {
    final story = _story;
    if (story == null) return true;
    return _currentSentence >= story.sentencesEn.length - 1;
  }

  /// Speaks an explicit string in one language. Backs the two-language Replay
  /// buttons, which let a learner hear the current page in whichever language
  /// they understand — independent of the EN/FIL display toggle.
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

  void _markStoryRead() {
    final story = _story;
    if (story == null) return;
    ref.read(progressProvider.notifier).recordStoryRead(story.id);
  }

  void _nextSentence() {
    if (_isLastSentence) return;
    setState(() {
      _forward = true; // turn the page forward
      _currentSentence++;
    });
    if (_isLastSentence) _markStoryRead();
  }

  void _prevSentence() {
    if (_currentSentence <= 0) return;
    setState(() {
      _forward = false; // turn the page backward
      _currentSentence--;
    });
  }

  void _goToQuiz() {
    final story = _story;
    if (story == null) return;
    _markStoryRead();
    context.push('/stories/quiz/${story.id}');
  }

  @override
  Widget build(BuildContext context) {
    if (_story == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.storyNotFound),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: HCColor.of(context).textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.storyNotFoundMsg,
                style: AppTypography.headlineSmall,
              ),
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
    final hc = HCColor.of(context);
    final kidMode = ref.watch(profileProvider)?.role == UserRole.child;
    // Replay buttons are hidden when Text-to-Speech is off (e.g. the hearing
    // preset, which leans on the visual story instead of audio).
    final ttsEnabled = ref.watch(settingsProvider).ttsEnabled;
    final sentenceEn = _story!.sentencesEn[_currentSentence];
    final sentenceFil = _story!.sentencesFil[_currentSentence];
    // Sign-language clip for this page, if the story has one. Shown
    // independently of the TTS setting so Deaf learners always have it.
    final sentenceFslUrl = _story!.fslForSentence(_currentSentence);
    // Cartoon ⇄ real-life flip picture for this page, if the story has one.
    // Visual aid — shown regardless of the TTS / audio settings.
    final sentenceImage = _story!.imageForSentence(_currentSentence);
    final reducedMotion = ref.watch(
      settingsProvider.select((s) => s.reducedMotion),
    );

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          icon: Icons.close_rounded,
          tooltip: 'Close',
          onPressed: () => context.pop(),
        ),
        title: Text(_story!.titleEn),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Story content (page indicator + card) ───────────────
            // The whole page sits in one scroll view so it can never force an
            // overflow: when the bottom bar grows tall (small landscape / XL
            // font) the content scrolls, and it stays vertically centered
            // whenever there is room. The English / Filipino / FSL controls
            // used to live on the card below the sentence; they now sit in the
            // fixed bottom bar (see [_buildBottomBar]), mirroring how
            // Flashcards → Cards groups its controls.
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.maxContentWidth,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.pagePadding,
                            vertical: 16,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Storybook page-dot indicator. Horizontally
                              // scrollable so any sentence count stays on one
                              // row and can never overflow.
                              Semantics(
                                label:
                                    'Page ${_currentSentence + 1} of ${_story!.sentencesEn.length}',
                                child: SizedBox(
                                  height: 8,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        _story!.sentencesEn.length,
                                        (i) => AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          width: i == _currentSentence ? 20 : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: i <= _currentSentence
                                                ? _story!.category.color
                                                : _story!.category.color
                                                      .withValues(alpha: 0.22),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Page ${_currentSentence + 1} of ${_story!.sentencesEn.length}',
                                style: AppTypography.labelSmall.copyWith(
                                  color: hc.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ─── Story Card ───────────────────────────
                              // The whole card turns like a storybook page on
                              // navigation — Next turns it forward, Back turns
                              // it backward. The per-sentence KeyedSubtree is
                              // what triggers each turn.
                              PageTurnSwitcher(
                                forward: _forward,
                                reducedMotion: reducedMotion,
                                child: KeyedSubtree(
                                  key: ValueKey(_currentSentence),
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(
                                      context.responsiveTier(
                                        phone: 20.0,
                                        tablet: 28.0,
                                        large: 32.0,
                                      ),
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          hc.surface,
                                          _story!.category.color.withValues(
                                            alpha: 0.04,
                                          ),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                      border: hc.hc
                                          ? Border.all(
                                              color: AppColors.hcPrimary,
                                              width: 2,
                                            )
                                          : Border.all(
                                              color: _story!.category.color
                                                  .withValues(alpha: 0.3),
                                            ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _story!.category.color
                                              .withValues(alpha: 0.08),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Emoji
                                        Container(
                                          padding: EdgeInsets.all(
                                            context.scaledHeightCapped(16),
                                          ),
                                          decoration: BoxDecoration(
                                            color: _story!.category.color
                                                .withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: _story!.category.color
                                                    .withValues(alpha: 0.2),
                                                blurRadius: 12,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            _story!.emoji,
                                            style: TextStyle(
                                              fontSize: context
                                                  .scaledHeightCapped(
                                                    kidMode
                                                        ? (context.isTablet
                                                              ? 72
                                                              : 60)
                                                        : (context.isTablet
                                                              ? 56
                                                              : 48),
                                                  ),
                                            ),
                                          ),
                                        ).animate().scale(
                                          begin: const Offset(0.8, 0.8),
                                          end: const Offset(1, 1),
                                          duration: 400.ms,
                                          curve: Curves.easeOutBack,
                                        ),
                                        const SizedBox(height: 24),
                                        // Both languages stacked (English as the
                                        // main line, the Tagalog translation
                                        // beneath). The page-turn transition now
                                        // animates the whole card on navigation, so
                                        // this no longer needs its own per-sentence
                                        // switcher.
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // English — the main, large line.
                                            Text(
                                              sentenceEn,
                                              style:
                                                  (kidMode
                                                          ? AppTypography
                                                                .headlineMedium
                                                          : AppTypography
                                                                .headlineSmall)
                                                      .copyWith(
                                                        height: 1.6,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 10),
                                            // Tagalog translation — secondary, in
                                            // the category accent colour, like the
                                            // flashcard card's Filipino word.
                                            Text(
                                              sentenceFil,
                                              style:
                                                  (kidMode
                                                          ? AppTypography
                                                                .titleMedium
                                                          : AppTypography
                                                                .bodyLarge)
                                                      .copyWith(
                                                        color: _story!
                                                            .category
                                                            .darkColor,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        height: 1.5,
                                                      ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                        // Cartoon ⇄ real-life tap-to-flip picture
                                        // for this page. Tap the cartoon to reveal
                                        // the real photograph (and back), with a
                                        // caption that updates to match the face.
                                        if (sentenceImage != null) ...[
                                          const SizedBox(height: 24),
                                          StoryImageFlip(
                                            key: ValueKey(
                                              'story_${_story!.id}_page$_currentSentence',
                                            ),
                                            pair: sentenceImage,
                                            cacheKey:
                                                '${_story!.id}_page$_currentSentence',
                                            color: _story!.category.color,
                                            semanticLabel: sentenceEn,
                                            reducedMotion: reducedMotion,
                                            maxWidth: context.responsiveTier(
                                              phone: 320.0,
                                              tablet: 420.0,
                                              large: 480.0,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ─── Bottom navigation bar (mirrors Flashcards → Cards) ────
            // English / Filipino read-aloud + Watch-in-FSL live here now,
            // stacked above the Back / Next-or-Quiz row, instead of on the
            // story card.
            _buildBottomBar(
              context,
              hc,
              ttsEnabled: ttsEnabled,
              sentenceEn: sentenceEn,
              sentenceFil: sentenceFil,
              sentenceFslUrl: sentenceFslUrl,
            ),
          ],
        ),
      ),
    );
  }

  /// The fixed bottom navigation bar.
  ///
  /// Mirroring Flashcards → Cards, the English / Filipino read-aloud pair and
  /// the Watch-in-FSL control sit here (not on the card), stacked above the
  /// Back / Next-or-Quiz row. Overflow-safe at every size and font scale: the
  /// replay bar and nav row use [AppActionBar]'s equal-width wrapping, the FSL
  /// chip is a single full-width button, and the bar is constrained to the
  /// content width so the controls never stretch awkwardly on a wide tablet.
  Widget _buildBottomBar(
    BuildContext context,
    HCColor hc, {
    required bool ttsEnabled,
    required String sentenceEn,
    required String sentenceFil,
    required String? sentenceFslUrl,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        12,
        context.pagePadding,
        12,
      ),
      decoration: BoxDecoration(
        color: hc.surface,
        border: Border(
          top: BorderSide(
            color: _story!.category.color.withValues(alpha: 0.15),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.maxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Two-language read-aloud — hear this page in either language
              // with one tap. Hidden when Text-to-Speech is off (e.g. the
              // hearing preset, which leans on FSL instead of audio).
              if (ttsEnabled) ...[
                LanguageReplayBar(
                  onEnglish: () => _speakLang(sentenceEn, filipino: false),
                  onFilipino: () => _speakLang(sentenceFil, filipino: true),
                ),
                const SizedBox(height: 12),
              ],
              // Bottom nav row — square icon-over-label buttons
              // (Back · FSL · Next/Quiz), matching the Flashcards → Cards
              // bottom bar. Laid out with AppActionBar's wrap so they flow onto
              // a second line instead of overflowing on a narrow width / XL
              // font scale.
              AppActionBar(
                alignment: WrapAlignment.spaceEvenly,
                children: [
                  // Back (←)
                  SquareActionButton(
                    icon: Icons.arrow_back_rounded,
                    label: AppLocalizations.of(context)!.back,
                    color: _story!.category.color,
                    enabled: _currentSentence > 0,
                    onTap: _prevSentence,
                  ),
                  // Watch this page signed — shown when available, independent
                  // of TTS so Deaf learners always have it.
                  if (sentenceFslUrl != null)
                    StoryFslButton(
                      square: true,
                      pageUrl: sentenceFslUrl,
                      cacheKey: 'story_${_story!.id}_s$_currentSentence',
                      label: sentenceEn,
                      secondaryLabel: sentenceFil,
                      color: _story!.category.color,
                    ),
                  // Next (→) or, on the last page, Take Quiz.
                  if (_isLastSentence)
                    SquareActionButton(
                      icon: Icons.quiz_rounded,
                      label: AppLocalizations.of(context)!.takeQuiz,
                      color: _story!.category.color,
                      onTap: _goToQuiz,
                    )
                  else
                    SquareActionButton(
                      icon: Icons.arrow_forward_rounded,
                      label: AppLocalizations.of(context)!.next,
                      color: _story!.category.color,
                      onTap: _nextSentence,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
