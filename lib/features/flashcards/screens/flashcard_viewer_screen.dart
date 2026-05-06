import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/local/seed_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/flashcard_image.dart';
import '../../../widgets/fsl_fullscreen_player.dart';
import '../../../widgets/shimmer_loading.dart';

class FlashcardViewerScreen extends ConsumerStatefulWidget {
  final FlashcardCategory category;

  /// When launched from a learning-path step, these fields allow the viewer
  /// to mark the step as completed when the user finishes.
  final String? learningPathId;
  final int? learningStepIndex;
  final int? learningTotalSteps;

  const FlashcardViewerScreen({
    super.key,
    required this.category,
    this.learningPathId,
    this.learningStepIndex,
    this.learningTotalSteps,
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

  void _autoAdvance() {
    if (!mounted) return;

    if (_isFlipped) {
      // If card is flipped, un-flip first then advance on next tick
      setState(() => _isFlipped = false);
      return;
    }

    // Speak the current word before moving on
    final ttsEnabled = ref.read(settingsProvider).ttsEnabled;
    if (ttsEnabled) {
      _speakEnglish(_cards[_currentIndex].wordEnglish);
    }

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
    ref.read(learningPathProvider.notifier).completeStep(
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
    final result = await context.push<bool>(
      '/flashcards/create',
      extra: card,
    );
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
      AppSnackBar.info(context, message: AppLocalizations.of(context)!.flashcardDeleted);
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
    // Watch settings for any dynamic theme changes
    ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: widget.category.color.withValues(alpha: 0.08),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: () => context.pop(),
        ),
        title: Text(widget.category.label),
        actions: [
          // Auto-play toggle
          IconButton(
            icon: Icon(
              _autoPlay
                  ? Icons.pause_circle_rounded
                  : Icons.play_circle_rounded,
              color: _autoPlay ? AppColors.accent : HCColor.of(context).textSecondary,
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
      body: Column(
        children: [
          // ─── Progress dots ──────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                              ? widget.category.color.withValues(alpha: 0.5)
                              : widget.category.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: widget.category.color.withValues(alpha: 0.4),
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
                        isFlipped: _isFlipped && index == _currentIndex,
                        reducedMotion: ref.watch(settingsProvider
                            .select((s) => s.reducedMotion)),
                        onFlip: () {
                          if (index == _currentIndex) {
                            setState(() => _isFlipped = !_isFlipped);
                          }
                        },
                        onSpeak: () => _speakEnglish(card.wordEnglish),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: HCColor.of(context).surface,
              border: Border(
                top: BorderSide(
                  color: widget.category.color.withValues(alpha: 0.15),
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
                // Edit / Delete row for custom cards
                if (_cards.isNotEmpty && _cards[_currentIndex].isCustom)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.12),
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
                        const SizedBox(width: 12),
                        _ActionButton(
                          icon: Icons.edit_rounded,
                          label: AppLocalizations.of(context)!.edit,
                          color: AppColors.info,
                          onTap: () => _editCard(_cards[_currentIndex]),
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          icon: Icons.delete_rounded,
                          label: AppLocalizations.of(context)!.delete,
                          color: AppColors.error,
                          onTap: () => _deleteCard(_cards[_currentIndex]),
                        ),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: Icons.arrow_back_rounded,
                      label: AppLocalizations.of(context)!.previous,
                      onTap: _prevCard,
                      enabled: _currentIndex > 0,
                    ),
                    _ActionButton(
                      icon: Icons.volume_up_rounded,
                      label: _isFlipped ? AppLocalizations.of(context)!.filipino : AppLocalizations.of(context)!.english,
                      color: _isFlipped ? AppColors.secondary : AppColors.info,
                      onTap: () => _isFlipped
                          ? _speakFilipino(_cards[_currentIndex].wordFilipino)
                          : _speakEnglish(_cards[_currentIndex].wordEnglish),
                    ),
                    _ActionButton(
                      icon: Icons.sign_language_rounded,
                      label: AppLocalizations.of(context)!.fsl,
                      color: AppColors.secondary,
                      onTap: () => _showFslVideo(_cards[_currentIndex]),
                    ),
                    _ActionButton(
                      icon: Icons.flip_rounded,
                      label: AppLocalizations.of(context)!.flip,
                      color: AppColors.accent,
                      onTap: () => setState(() => _isFlipped = !_isFlipped),
                    ),
                    _ActionButton(
                      icon: Icons.arrow_forward_rounded,
                      label: AppLocalizations.of(context)!.next,
                      onTap: _nextCard,
                      enabled: _currentIndex < _cards.length - 1,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the FSL video asset path from the card's category and English word.
  /// Example: assets/videos/fsl/Animals/dog.mp4
  String _fslVideoPath(Flashcard card) {
    final categoryFolder = card.category.label;
    final fileName = card.wordEnglish.toLowerCase();
    return 'assets/videos/fsl/$categoryFolder/$fileName.mp4';
  }

  /// Checks whether the asset exists at build-time bundle.
  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _showFslVideo(Flashcard card) async {
    final videoPath = _fslVideoPath(card);
    final exists = await _assetExists(videoPath);

    if (!mounted) return;

    if (!exists) {
      // No video available for this word — show a friendly message
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: HCColor.of(context).surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: HCColor.of(context).textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.secondaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sign_language_rounded,
                  size: 40,
                  color: AppColors.secondaryDark,
                ),
              ),
              const SizedBox(height: 20),
              Text(AppLocalizations.of(context)!.filipinoSignLanguage, style: AppTypography.titleLarge),
              const SizedBox(height: 8),
              Text(
                'No FSL video available yet for "${card.wordEnglish}".',
                style: AppTypography.bodyMedium.copyWith(
                  color: HCColor.of(context).textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.gotIt),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // Video exists — show it in a bottom sheet with a built-in player
    // Record the view for analytics
    final activeProfile = ref.read(profileProvider);
    if (activeProfile != null) {
      HiveService.recordFslVideoView(
        activeProfile.id,
        card.category.label,
        card.wordEnglish,
      );
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _FslVideoSheet(
        videoPath: videoPath,
        wordEnglish: card.wordEnglish,
      ),
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
                        color: category.color.withValues(alpha: 0.15 * flipProgress),
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
                                    Colors.white.withValues(alpha: 0.12 * flipProgress),
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
          Center(
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                      Icon(category.icon, size: 14, color: category.darkColor),
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
                // Per-word image
                FlashcardImage(card: card, size: 80),
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
                      size: 14,
                      color: HCColor.of(context).textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppLocalizations.of(context)!.tapToSeeMore,
                      style: AppTypography.bodySmall.copyWith(
                        color: HCColor.of(context).textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
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
          colors: [category.color.withValues(alpha: 0.10), HCColor.of(context).surface],
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
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Back label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                    Icon(category.icon, size: 14, color: category.darkColor),
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
                            size: 20,
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
                    child: Icon(category.icon, size: 14, color: Colors.white),
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
                    size: 14,
                    color: HCColor.of(context).textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context)!.tapToFlipBack,
                    style: AppTypography.bodySmall.copyWith(
                      color: HCColor.of(context).textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
              Icon(icon, size: 18, color: color),
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

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = enabled
        ? (color ?? AppColors.primary)
        : HCColor.of(context).textSecondary.withValues(alpha: 0.3);
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label button',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
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
              child: Icon(icon, color: c, size: 26),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTypography.labelSmall.copyWith(color: c)),
          ],
        ),
      ),
    );
  }
}

// ─── FSL Video Bottom Sheet ───────────────────────────
class _FslVideoSheet extends StatefulWidget {
  final String videoPath;
  final String wordEnglish;

  const _FslVideoSheet({
    required this.videoPath,
    required this.wordEnglish,
  });

  @override
  State<_FslVideoSheet> createState() => _FslVideoSheetState();
}

class _FslVideoSheetState extends State<_FslVideoSheet> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  double _playbackSpeed = 1.0;

  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5];

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoPath)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.setLooping(true);
          _controller.play();
        }
      }).catchError((_) {
        if (mounted) setState(() => _hasError = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: hc.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.sign_language_rounded,
                color: AppColors.secondaryDark,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'FSL — ${widget.wordEnglish}',
                style: AppTypography.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Video player
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: _initialized
                  ? _controller.value.aspectRatio
                  : 16 / 9,
              child: _hasError
                  ? Container(
                      color: AppColors.surfaceVariant,
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.unableToLoadVideo,
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : _initialized
                      ? GestureDetector(
                          onTap: () {
                            setState(() {
                              _controller.value.isPlaying
                                  ? _controller.pause()
                                  : _controller.play();
                            });
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(_controller),
                              if (!_controller.value.isPlaying)
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              // Fullscreen button
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: GestureDetector(
                                  onTap: () async {
                                    final wasPlaying = _controller.value.isPlaying;
                                    final pos = _controller.value.position;
                                    _controller.pause();
                                    final returnPos = await openFslFullscreenPlayer(
                                      context,
                                      videoPath: widget.videoPath,
                                      wordEnglish: widget.wordEnglish,
                                      startPosition: pos,
                                    );
                                    if (returnPos != null && mounted) {
                                      _controller.seekTo(returnPos);
                                    }
                                    if (wasPlaying && mounted) {
                                      _controller.play();
                                    }
                                  },
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.fullscreen_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceVariant,
                          child: ShimmerLoading(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_circle_outline_rounded,
                                    size: 48,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 8),
                                  const ShimmerBox(width: 100, height: 12),
                                ],
                              ),
                            ),
                          ),
                        ),
            ),
          ),
          const SizedBox(height: 12),
          // Playback speed selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.speed_rounded, size: 18,
                  color: hc.textSecondary),
              const SizedBox(width: 6),
              Text(AppLocalizations.of(context)!.speed, style: AppTypography.labelSmall.copyWith(
                  color: hc.textSecondary)),
              const SizedBox(width: 4),
              ..._speeds.map((speed) {
                final isActive = _playbackSpeed == speed;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _playbackSpeed = speed);
                      _controller.setPlaybackSpeed(speed);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.secondary
                            : hc.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${speed}x',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 10,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? Colors.white
                              : hc.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          // Replay & Close
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _controller.seekTo(Duration.zero);
                    _controller.play();
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(AppLocalizations.of(context)!.replay),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.close),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
