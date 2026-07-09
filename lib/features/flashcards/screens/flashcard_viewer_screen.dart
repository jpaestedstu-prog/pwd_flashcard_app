import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/action_clip_service.dart';
import '../../../core/services/flashcard_photo_service.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_action_bar.dart';
import '../../../core/accessibility/accessibility_content_policy.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/local/seed_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/flashcard_image.dart';
import '../../../widgets/language_replay_bar.dart';
import '../../../widgets/fsl_loading_overlay.dart';
import '../../../widgets/fsl_video_sheet.dart';
import '../../break_time/break_time.dart';
import '../widgets/show_me_button.dart';
import '../widgets/examples_gallery.dart';
import '../../gaze_control/widgets/gaze_dpad_scope.dart';

class FlashcardViewerScreen extends ConsumerStatefulWidget {
  final FlashcardCategory category;

  /// When launched from a learning-path step, these fields allow the viewer
  /// to mark the step as completed when the user finishes.
  final String? learningPathId;
  final int? learningStepIndex;
  final int? learningTotalSteps;

  /// Focus mode (Word Hunt): show only this one card instead of the whole
  /// category deck. Falls back to the full deck if the id doesn't resolve.
  final String? focusWordId;

  const FlashcardViewerScreen({
    super.key,
    required this.category,
    this.learningPathId,
    this.learningStepIndex,
    this.learningTotalSteps,
    this.focusWordId,
  });

  @override
  ConsumerState<FlashcardViewerScreen> createState() =>
      _FlashcardViewerScreenState();
}

class _FlashcardViewerScreenState extends ConsumerState<FlashcardViewerScreen> {
  late PageController _pageController;
  late List<Flashcard> _cards;
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _autoPlay = false;
  Timer? _autoPlayTimer;
  bool _stepCompleted = false;

  /// True while an FSL video is being resolved/downloaded for a card. Drives
  /// the full-screen loading overlay and blocks repeat taps so only one video
  /// loads at a time.
  bool _isLoadingFsl = false;

  /// Whether this viewer was launched from a learning-path step.
  bool get _isLearningPathMode =>
      widget.learningPathId != null &&
      widget.learningStepIndex != null &&
      widget.learningTotalSteps != null;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadCards();
  }

  void _loadCards() {
    final seed = SeedData.getByCategory(widget.category);
    final custom = HiveService.getCustomCards()
        .where((c) => c.category == widget.category)
        .toList();
    _cards = [...seed, ...custom];
    final focusId = widget.focusWordId;
    if (focusId != null) {
      final focused = _cards.where((c) => c.id == focusId).toList();
      if (focused.isNotEmpty) _cards = focused;
    }
  }

  @override
  void dispose() {
    _stopAutoPlay();
    _pageController.dispose();
    super.dispose();
  }

  void _toggleAutoPlay() {
    setState(() => _autoPlay = !_autoPlay);
    if (_autoPlay) {
      _startAutoPlay();
    } else {
      _stopAutoPlay();
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(
      const Duration(seconds: AppConstants.autoPlayIntervalSeconds),
      (_) => _autoAdvance(),
    );
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  // ─── "I Need a Break" pause / resume ──────────────────
  // Opening a calming break holds the lesson: any running auto-play slideshow
  // is paused while the break is open and restored afterwards, so the student
  // returns to the exact same card in the exact same state.
  bool _autoPlayBeforeBreak = false;

  void _onBreakStart() {
    _autoPlayBeforeBreak = _autoPlay;
    if (_autoPlay) {
      _stopAutoPlay();
      setState(() => _autoPlay = false);
    }
  }

  void _onBreakEnd() {
    if (!mounted) return;
    if (_autoPlayBeforeBreak) {
      setState(() => _autoPlay = true);
      _startAutoPlay();
    }
  }

  void _autoAdvance() {
    if (!mounted) return;

    if (_isFlipped) {
      // If card is flipped, un-flip first then advance on next tick
      setState(() => _isFlipped = false);
      return;
    }

    // Auto-play advances the slideshow silently — narration is opt-in via the
    // Replay buttons, so a learner is never startled by unexpected sound.
    if (_currentIndex < _cards.length - 1) {
      _nextCard();
    } else {
      // Reached the end — stop auto-play
      setState(() => _autoPlay = false);
      _stopAutoPlay();
      _markStepCompleteIfNeeded();
    }
  }

  /// Mark the learning-path step as completed (score 1.0 = viewed all cards).
  void _markStepCompleteIfNeeded() {
    if (!_isLearningPathMode || _stepCompleted) return;
    _stepCompleted = true;
    ref
        .read(learningPathProvider.notifier)
        .completeStep(
          widget.learningPathId!,
          widget.learningStepIndex!,
          1.0,
          widget.learningTotalSteps!,
        );
  }

  void _nextCard() {
    if (_currentIndex < _cards.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _prevCard() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _speakEnglish(String word) {
    final tts = ref.read(ttsServiceProvider);
    tts.speakEnglish(word);
  }

  void _speakFilipino(String word) {
    final tts = ref.read(ttsServiceProvider);
    tts.speakFilipino(word);
  }

  void _editCard(Flashcard card) async {
    _stopAutoPlay();
    setState(() => _autoPlay = false);
    final result = await context.push<bool>('/flashcards/create', extra: card);
    if (result == true && mounted) {
      setState(() {
        _loadCards();
        if (_currentIndex >= _cards.length) {
          _currentIndex = _cards.length - 1;
        }
      });
    }
  }

  void _deleteCard(Flashcard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteFlashcard),
        content: Text(
          'Are you sure you want to delete "${card.wordEnglish}"? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await HiveService.deleteCustomCard(card.id);
      if (!mounted) return;
      AppSnackBar.info(
        context,
        message: AppLocalizations.of(context)!.flashcardDeleted,
      );
      setState(() {
        _loadCards();
        if (_cards.isEmpty) {
          context.pop();
          return;
        }
        if (_currentIndex >= _cards.length) {
          _currentIndex = _cards.length - 1;
          _pageController.jumpToPage(_currentIndex);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch settings for dynamic theme changes, and for the audio-replay
    // affordance: the prominent Replay button is hidden when Text-to-Speech is
    // off (e.g. the hearing preset, which prioritises FSL video over audio).
    final ttsEnabled = ref.watch(settingsProvider).ttsEnabled;
    // FSL video is hidden for learners whose accessibility category doesn't
    // use signing (e.g. visual / cognitive), per the content policy.
    final showFsl = ref.watch(
      accessibilityContentPolicyProvider.select((p) => p.showFsl),
    );
    final l10n = AppLocalizations.of(context)!;
    final card = _cards.isNotEmpty ? _cards[_currentIndex] : null;

    // The bottom action bar as one hands-free D-pad row: look ◀ ▶ to move the
    // highlight across the controls, blink (or look-up) to open the focused one
    // — the same discrete D-pad as the navigation shell. Built once so the
    // visible buttons and the gaze cells can never disagree, and the focus ring
    // always lands on the right button.
    final actions = <_ViewerAction>[
      _ViewerAction(
        icon: Icons.arrow_back_rounded,
        label: l10n.previous,
        onTap: _prevCard,
        enabled: _currentIndex > 0,
      ),
      if (showFsl)
        _ViewerAction(
          icon: Icons.sign_language_rounded,
          label: l10n.fsl,
          color: AppColors.secondary,
          onTap: card != null ? () => _showFslVideo(card) : null,
        ),
      if (card != null && ActionClipService.hasClip(card))
        _ViewerAction(
          icon: Icons.play_circle_fill_rounded,
          label: 'Show Me',
          color: AppColors.secondaryDark,
          onTap: () => showActionClipSheet(context, card),
        ),
      if (card != null && FlashcardPhotoService.hasGallery(card))
        _ViewerAction(
          icon: Icons.photo_library_rounded,
          label: 'Examples',
          color: AppColors.accentDark,
          onTap: () => showExamplesGallery(context, card),
        ),
      _ViewerAction(
        icon: Icons.flip_rounded,
        label: l10n.flip,
        color: AppColors.accent,
        onTap: () => setState(() => _isFlipped = !_isFlipped),
      ),
      _ViewerAction(
        icon: Icons.arrow_forward_rounded,
        label: l10n.next,
        onTap: _nextCard,
        enabled: _currentIndex < _cards.length - 1,
      ),
    ];
    final dpadRows = [
      [
        for (final a in actions)
          GazeDpadCell(
            label: a.label,
            enabled: a.enabled && a.onTap != null,
            onActivate: a.onTap ?? () {},
          ),
      ],
    ];

    return GazeDpadScope(
      rows: dpadRows,
      builder: (context, gaze) => Stack(
        children: [
          Scaffold(
            // Opaque base so nothing composites over black on root-level routes
            // (e.g. opened from Word Hunt). The colourful depth lives in the
            // _CardsBackdrop layered behind the body; this just guarantees an
            // opaque floor that follows the real light/dark setting.
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/flashcards'),
              title: Text(widget.category.label),
              actions: [
                // "I Need a Break" — always visible so a student who feels
                // overwhelmed can pause the lesson and choose a calming activity,
                // then return to this exact card. Pauses/restores auto-play.
                BreakButton(
                  color: AppColors.secondary,
                  onBreakStart: _onBreakStart,
                  onBreakEnd: _onBreakEnd,
                ),
                // Auto-play toggle
                IconButton(
                  icon: Icon(
                    _autoPlay
                        ? Icons.pause_circle_rounded
                        : Icons.play_circle_rounded,
                    color: _autoPlay
                        ? AppColors.accent
                        : HCColor.of(context).textSecondary,
                  ),
                  onPressed: _toggleAutoPlay,
                  tooltip: _autoPlay ? 'Pause auto-play' : 'Start auto-play',
                ),
                // Card counter
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: widget.category.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${_cards.length}',
                        style: AppTypography.labelMedium.copyWith(
                          color: widget.category.darkColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Stack(
              children: [
                // Colourful, lit, depth-rich background behind everything.
                _CardsBackdrop(category: widget.category),
                Column(
                  children: [
                    // ─── Progress dots ──────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Row(
                        children: List.generate(_cards.length, (i) {
                          final isActive = i == _currentIndex;
                          final isPast = i < _currentIndex;
                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: isActive ? 6 : 4,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? widget.category.color
                                    : isPast
                                    ? widget.category.color.withValues(
                                        alpha: 0.5,
                                      )
                                    : widget.category.color.withValues(
                                        alpha: 0.15,
                                      ),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: widget.category.color
                                              .withValues(alpha: 0.4),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : [],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // ─── Card Area ──────────────────────────
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _cards.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                            _isFlipped = false;
                          });
                        },
                        itemBuilder: (context, index) {
                          final card = _cards[index];
                          // When the user reaches the last card, mark step complete
                          if (_isLearningPathMode &&
                              index == _cards.length - 1 &&
                              _currentIndex == index) {
                            _markStepCompleteIfNeeded();
                          }
                          return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                child: _FlipCard(
                                  card: card,
                                  category: widget.category,
                                  isFlipped:
                                      _isFlipped && index == _currentIndex,
                                  reducedMotion: ref.watch(
                                    settingsProvider.select(
                                      (s) => s.reducedMotion,
                                    ),
                                  ),
                                  onFlip: () {
                                    if (index == _currentIndex) {
                                      setState(() => _isFlipped = !_isFlipped);
                                    }
                                  },
                                  onSpeak: () =>
                                      _speakEnglish(card.wordEnglish),
                                  onSpeakFilipino: () =>
                                      _speakFilipino(card.wordFilipino),
                                ),
                              )
                              .animate()
                              .scale(
                                begin: const Offset(0.92, 0.92),
                                end: const Offset(1, 1),
                                duration: 400.ms,
                                curve: Curves.easeOutBack,
                              )
                              .fadeIn(duration: 300.ms);
                        },
                      ),
                    ),

                    // ─── Bottom Action Bar ──────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: HCColor.of(context).surface,
                        border: Border(
                          top: BorderSide(
                            color: widget.category.color.withValues(
                              alpha: 0.15,
                            ),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Hands-free hint, shown only while gaze is driving.
                          if (gaze.active)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _GazeViewerHint(
                                ready: gaze.ready,
                                faceVisible: gaze.faceVisible,
                              ),
                            ),
                          // Prominent, single-tap audio replay — the accessible
                          // alternative to a shake/motion gesture (motion actuation is
                          // unreliable for motor-impaired learners and discouraged by
                          // WCAG 2.1 SC 2.5.4). Both languages are shown explicitly so
                          // a student who only understands one can hear it directly.
                          if (ttsEnabled && _cards.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: LanguageReplayBar(
                                onEnglish: () => _speakEnglish(
                                  _cards[_currentIndex].wordEnglish,
                                ),
                                onFilipino: () => _speakFilipino(
                                  _cards[_currentIndex].wordFilipino,
                                ),
                              ),
                            ),
                          // Edit / Delete row for custom cards
                          if (_cards.isNotEmpty &&
                              _cards[_currentIndex].isCustom)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppActionBar(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.info.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      AppLocalizations.of(context)!.customCard,
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.info,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  _ActionButton(
                                    icon: Icons.edit_rounded,
                                    label: AppLocalizations.of(context)!.edit,
                                    color: AppColors.info,
                                    onTap: () =>
                                        _editCard(_cards[_currentIndex]),
                                  ),
                                  _ActionButton(
                                    icon: Icons.delete_rounded,
                                    label: AppLocalizations.of(context)!.delete,
                                    color: AppColors.error,
                                    onTap: () =>
                                        _deleteCard(_cards[_currentIndex]),
                                  ),
                                ],
                              ),
                            ),
                          // Main controls — also the hands-free D-pad row. Each
                          // button shows a bright ring while the head-driven
                          // highlight rests on it (blink / look-up opens it).
                          AppActionBar(
                            alignment: WrapAlignment.spaceEvenly,
                            children: [
                              for (final (i, a) in actions.indexed)
                                _ActionButton(
                                  icon: a.icon,
                                  label: a.label,
                                  color: a.color,
                                  onTap: a.onTap,
                                  enabled: a.enabled,
                                  focused: gaze.isFocused(0, i),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isLoadingFsl) const FslLoadingOverlay(),
        ],
      ),
    );
  }

  void _showFslVideo(Flashcard card) async {
    // Ignore taps while a video is already being resolved. This guards
    // against multiple simultaneous downloads / stacked player sheets when
    // the FSL button (on this or any other card) is tapped repeatedly.
    if (_isLoadingFsl) return;
    setState(() => _isLoadingFsl = true);

    await FslAssetsService.load();
    final videoSource = await FslAssetsService.videoSourceFor(card);

    if (!mounted) return;
    // Source resolved — dismiss the loading overlay before presenting a
    // sheet. The sheet then handles its own player-init loading UI, and its
    // modal barrier blocks further taps while open.
    setState(() => _isLoadingFsl = false);

    if (videoSource == null) {
      // No video available for this word — show a friendly message.
      showFslUnavailableSheet(context, wordEnglish: card.wordEnglish);
      return;
    }

    // Video exists — show it in a bottom sheet with a built-in player.
    // Record the view for analytics.
    final activeProfile = ref.read(profileProvider);
    if (activeProfile != null) {
      HiveService.recordFslVideoView(
        activeProfile.id,
        card.category.label,
        card.wordEnglish,
      );
    }
    showFslVideoSheet(
      context,
      videoSource: videoSource,
      wordEnglish: card.wordEnglish,
    );
  }
}

// ─── Enhanced 3D Flip Card ────────────────────────────
class _FlipCard extends StatelessWidget {
  final Flashcard card;
  final FlashcardCategory category;
  final bool isFlipped;
  final bool reducedMotion;
  final VoidCallback onFlip;
  final VoidCallback onSpeak;
  final VoidCallback onSpeakFilipino;

  const _FlipCard({
    required this.card,
    required this.category,
    required this.isFlipped,
    required this.onFlip,
    required this.onSpeak,
    required this.onSpeakFilipino,
    this.reducedMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isFlipped
          ? '${card.wordEnglish} in Filipino is ${card.wordFilipino}. Tap to flip back.'
          : '${card.wordEnglish}, ${category.label} category. Tap to see details.',
      child: GestureDetector(
        onTap: onFlip,
        behavior: HitTestBehavior.deferToChild,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: isFlipped ? math.pi : 0),
          duration: reducedMotion
              ? const Duration(milliseconds: 80)
              : const Duration(milliseconds: 650),
          curve: reducedMotion ? Curves.linear : Curves.easeOutBack,
          builder: (context, value, child) {
            final isFront = value < math.pi / 2;
            // Dynamic perspective depth — stronger in the middle of flip
            final flipProgress = (math.sin(value)).abs(); // 0→1→0
            final perspective = 0.001 + 0.0005 * flipProgress;

            // Dynamic shadow that shifts with rotation
            final shadowOffsetX = math.sin(value) * 12;
            final shadowBlur = 16.0 + 12.0 * flipProgress;
            final shadowOpacity = 0.15 + 0.1 * flipProgress;

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, perspective)
                ..rotateY(value),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: category.color.withValues(alpha: shadowOpacity),
                      blurRadius: shadowBlur,
                      offset: Offset(shadowOffsetX, 8 + 4 * flipProgress),
                    ),
                    // Edge glow during flip
                    if (flipProgress > 0.2)
                      BoxShadow(
                        color: category.color.withValues(
                          alpha: 0.15 * flipProgress,
                        ),
                        blurRadius: 24 * flipProgress,
                        spreadRadius: 2 * flipProgress,
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      isFront
                          ? _buildFront(context)
                          : Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(math.pi),
                              child: _buildBack(context),
                            ),
                      // Glossy shimmer highlight during flip
                      if (flipProgress > 0.1)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: LinearGradient(
                                  begin: Alignment(
                                    -1.0 + 2.0 * (value / math.pi),
                                    -0.5,
                                  ),
                                  end: Alignment(
                                    0.0 + 2.0 * (value / math.pi),
                                    0.5,
                                  ),
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(
                                      alpha: 0.12 * flipProgress,
                                    ),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFront(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: HCColor.of(context).surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          // ── Decorative gradient accent (top) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 80,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    category.color.withValues(alpha: 0.12),
                    category.color.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
            ),
          ),

          // ── Decorative blob (top-right) ──
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: category.color.withValues(alpha: 0.08),
              ),
            ),
          ),

          // ── Decorative blob (bottom-left) ──
          Positioned(
            bottom: -15,
            left: -15,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: category.color.withValues(alpha: 0.06),
              ),
            ),
          ),

          // ── Main content ──
          // Scale the face down to fit a short card / large font scale rather
          // than overflowing the fixed card height.
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Category color strip
                    Container(
                      height: 6,
                      width: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [category.darkColor, category.color],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: category.color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: category.color.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            category.icon,
                            size: context.scaleIcon(14),
                            color: category.darkColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            category.label,
                            style: AppTypography.labelSmall.copyWith(
                              color: category.darkColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Per-word image — tap to switch between the emoji and the
                    // real photograph (smooth 3D flip), with a black outline on
                    // both faces. Instruction shown beneath.
                    FlashcardImage(
                      card: card,
                      size: 160,
                      interactive: true,
                      outlined: true,
                      reducedMotion: reducedMotion,
                    ),
                    const SizedBox(height: 32),
                    // Word
                    Text(
                      card.wordEnglish,
                      style: AppTypography.flashcardWord.copyWith(
                        color: HCColor.of(context).textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      card.wordFilipino,
                      style: AppTypography.titleLarge.copyWith(
                        color: category.darkColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Tap hint
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: context.scaleIcon(14),
                          color: HCColor.of(
                            context,
                          ).textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)!.tapToSeeMore,
                          style: AppTypography.bodySmall.copyWith(
                            color: HCColor.of(
                              context,
                            ).textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            category.color.withValues(alpha: 0.10),
            HCColor.of(context).surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          // Decorative accent blob (bottom-right)
          Positioned(
            bottom: -20,
            right: -20,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: category.color.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Center the details, but let them scroll instead of overflowing
          // the fixed card height on a short card / large font scale.
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Back label
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            category.darkColor.withValues(alpha: 0.15),
                            category.color.withValues(alpha: 0.10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: category.color.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            category.icon,
                            size: context.scaleIcon(14),
                            color: category.darkColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context)!.details,
                            style: AppTypography.labelMedium.copyWith(
                              color: category.darkColor,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Word pair
                    Text(
                      '${card.wordEnglish} — ${card.wordFilipino}',
                      style: AppTypography.headlineMedium.copyWith(
                        color: HCColor.of(context).textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Listen buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MiniListenButton(
                          label: AppLocalizations.of(context)!.english,
                          icon: Icons.volume_up_rounded,
                          color: AppColors.info,
                          onTap: onSpeak,
                        ),
                        const SizedBox(width: 12),
                        _MiniListenButton(
                          label: AppLocalizations.of(context)!.filipino,
                          icon: Icons.volume_up_rounded,
                          color: AppColors.secondary,
                          onTap: onSpeakFilipino,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Example sentence
                    if (card.exampleSentence != null)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: category.color.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: category.color.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.format_quote_rounded,
                                  size: context.scaleIcon(20),
                                  color: category.darkColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context)!.example,
                                  style: AppTypography.labelMedium.copyWith(
                                    color: category.darkColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              card.exampleSentence!,
                              style: AppTypography.bodyLarge.copyWith(
                                fontStyle: FontStyle.italic,
                                color: HCColor.of(context).textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Category badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [category.darkColor, category.color],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            category.icon,
                            size: context.scaleIcon(14),
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category.label,
                          style: AppTypography.labelMedium.copyWith(
                            color: category.darkColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: context.scaleIcon(14),
                          color: HCColor.of(
                            context,
                          ).textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)!.tapToFlipBack,
                          style: AppTypography.bodySmall.copyWith(
                            color: HCColor.of(
                              context,
                            ).textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Colourful 3D Backdrop (Cards screen) ─────────────
// Replaces the old flat 8%-tint wash that read as merely "bright". This
// layers a diagonal, category-tinted gradient (lit from the top-left) with
// soft glowing orbs that give the screen real depth and saturation while the
// white flip cards still float clearly on top. Fully static — no motion — so
// it stays calm for reduced-motion / sensory-sensitive learners, and blends
// every tint onto the opaque surface so it never composites over black.
class _CardsBackdrop extends StatelessWidget {
  final FlashcardCategory category;

  const _CardsBackdrop({required this.category});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final light = category.color; // pale pastel
    final deep = category.darkColor; // rich, saturated tone

    Color tint(Color c, double a) =>
        Color.alphaBlend(c.withValues(alpha: a), base);

    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // Brighter, more saturated than the old 0.08 wash, and shaded
            // corner-to-corner so the surface reads as lit rather than flat.
            colors: isDark
                ? [tint(light, 0.16), base, tint(deep, 0.20)]
                : [tint(light, 0.30), tint(light, 0.08), tint(deep, 0.22)],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Top-left glow — the implied light source.
            Positioned(
              top: -90,
              left: -70,
              child: _GlowOrb(
                color: light,
                size: 280,
                intensity: isDark ? 0.22 : 0.45,
              ),
            ),
            // Bottom-right deep accent — grounds the screen with depth.
            Positioned(
              bottom: -110,
              right: -80,
              child: _GlowOrb(
                color: deep,
                size: 320,
                intensity: isDark ? 0.20 : 0.34,
              ),
            ),
            // Smaller mid-right accent for extra dimension.
            Positioned(
              top: 160,
              right: -60,
              child: _GlowOrb(
                color: light,
                size: 170,
                intensity: isDark ? 0.14 : 0.26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A soft circular glow built from a radial gradient — cheaper than a blur
// filter and produces the same diffuse, dimensional "orb" effect.
class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double intensity;

  const _GlowOrb({
    required this.color,
    required this.size,
    required this.intensity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: intensity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mini Listen Button (card back) ───────────────────
class _MiniListenButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniListenButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: context.scaleIcon(18), color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Action Button ────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool enabled;

  /// True while the hands-free gaze D-pad highlight rests on this button — draws
  /// a bright accent ring (the same affordance as the navigation shell) so the
  /// learner can see what a blink / look-up would open.
  final bool focused;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.enabled = true,
    this.focused = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = enabled
        ? (color ?? AppColors.primary)
        : HCColor.of(context).textSecondary.withValues(alpha: 0.3);
    // The tap target grows with the Font Size setting but stays capped so the
    // strip never balloons; a 54dp base keeps it comfortably above the 48dp
    // accessibility floor for child / motor-impaired users.
    final box = context.scaledHeightCapped(54, max: 1.3);
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label button',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: box,
                  height: box,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.withValues(alpha: 0.15)),
                    boxShadow: enabled
                        ? [
                            BoxShadow(
                              color: c.withValues(alpha: 0.15),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  // Icon scales with the box (text-scale aware) so it never
                  // clips, and never grows past the box at XL font sizes.
                  child: Icon(icon, color: c, size: box * 0.48),
                ),
                if (focused)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.accent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Fixed-width label that scales DOWN to fit (FittedBox) instead of
            // wrapping or pushing the button wider than its cell — so the strip
            // can never overflow horizontally at any font scale or translation.
            SizedBox(
              width: box + 24,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppTypography.labelSmall.copyWith(color: c),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Viewer action spec ───────────────────────────────
/// One bottom-bar control, used to build both the visible [_ActionButton] and
/// its matching [GazeDpadCell] from a single source so the focus ring can never
/// land on the wrong button.
class _ViewerAction {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  final bool enabled;

  const _ViewerAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.enabled = true,
  });
}

// ─── Gaze hint chip (viewer) ──────────────────────────
/// A small instructional chip shown above the action bar while the head D-pad
/// is driving the viewer — mirrors the navigation shell's hint. Purely
/// informational ([IgnorePointer]); touch falls straight through.
class _GazeViewerHint extends StatelessWidget {
  final bool ready;
  final bool faceVisible;

  const _GazeViewerHint({required this.ready, required this.faceVisible});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String text) = !ready
        ? (Icons.hourglass_top_rounded, 'Starting gaze…')
        : !faceVisible
            ? (Icons.face_retouching_natural_rounded, 'Look at the screen')
            : (
                Icons.visibility_rounded,
                'Look ◀ ▶ to choose · blink to open',
              );
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
