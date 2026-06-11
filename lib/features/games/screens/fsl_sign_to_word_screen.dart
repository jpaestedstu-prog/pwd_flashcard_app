import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/services/adaptive_difficulty_service.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../data/models/models.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/game_widgets.dart';
import '../../../widgets/achievement_overlay.dart';
import '../../../widgets/game_review_sheet.dart';
import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/services/celebration_service.dart';
import '../../../widgets/accessible_celebration_overlay.dart';
import '../../../data/models/achievements.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../../widgets/fsl_fullscreen_player.dart';
import '../../../widgets/fsl_loading_overlay.dart';
import '../widgets/fsl_empty_state.dart';
import '../timed_game_mixin.dart';
import '../game_pause_mixin.dart';
import '../widgets/pause_overlay.dart';

/// FSL Sign → Word game.
///
/// The student watches an FSL video showing a sign, then picks the correct
/// English word from multiple choices. Earns stars and records progress
/// exactly like the other games.
class FslSignToWordScreen extends ConsumerStatefulWidget {
  final List<FlashcardCategory> categories;

  const FslSignToWordScreen({super.key, this.categories = const []});

  @override
  ConsumerState<FslSignToWordScreen> createState() =>
      _FslSignToWordScreenState();
}

class _FslSignToWordScreenState extends ConsumerState<FslSignToWordScreen>
    with TimedGameMixin, GamePauseMixin {
  late List<Flashcard> _cardsWithVideo;
  late List<_FslRound> _rounds;
  int _currentRound = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _answered = false;
  bool _showResult = false;
  bool _loading = true;
  List<Achievement> _newAchievements = [];
  final List<GameReviewItem> _reviewItems = [];
  final _random = Random();

  VideoPlayerController? _videoController;
  bool _videoReady = false;

  /// True while a fullscreen FSL video is being opened. Blocks repeat taps on
  /// the expand button so only one fullscreen player can open at a time, and
  /// drives the loading overlay during the (usually cached) resolve.
  bool _openingFullscreen = false;

  static const int _numChoices = 4;
  static const int _maxRounds = 10;

  /// Tracks whether the video was playing pre-pause so resume can restore.
  bool _wasPlayingBeforePause = false;

  @override
  void initState() {
    super.initState();
    _initCards();
    initPause();
  }

  @override
  void onTimeUp() {
    // FSL is untimed — never called.
  }

  @override
  void onPause() {
    final c = _videoController;
    if (c != null && c.value.isInitialized) {
      _wasPlayingBeforePause = c.value.isPlaying;
      c.pause();
    }
  }

  @override
  void onResume() {
    final c = _videoController;
    if (c != null && c.value.isInitialized && _wasPlayingBeforePause) {
      c.play();
    }
  }

  @override
  Future<void> savePartialProgress() async {
    if (!mounted) return;
    if (_loading) return;
    _saveProgress();
  }

  Future<void> _initCards() async {
    // Asset-manifest lookup — single bundle parse, then a synchronous set
    // membership check per card (the old loop was awaiting one rootBundle
    // probe per card and ran for ~1s on cold boot).
    final availability = await FslAssetsService.load();
    var source = List.of(availability.cardsWithVideo);
    if (widget.categories.isNotEmpty) {
      source = source
          .where((c) => widget.categories.contains(c.category))
          .toList();
    }

    if (source.length < 2) {
      // Not enough cards with videos
      if (mounted) {
        setState(() {
          _loading = false;
          _cardsWithVideo = [];
          _rounds = [];
        });
      }
      return;
    }

    _cardsWithVideo = source..shuffle(_random);
    _generateRounds();
    await _prepareVideo();
    if (mounted) setState(() => _loading = false);
  }

  void _generateRounds() {
    _rounds = [];
    final shuffled = AdaptiveDifficultyService.pickGameCards(
      profileId: ref.read(profileProvider)?.id,
      cards: _cardsWithVideo,
      count: _maxRounds,
      random: _random,
    );
    final count = min(_maxRounds, shuffled.length);
    for (int i = 0; i < count; i++) {
      final correct = shuffled[i];
      final others = _cardsWithVideo.where((c) => c.id != correct.id).toList()
        ..shuffle(_random);
      final choices = [correct, ...others.take(_numChoices - 1)]
        ..shuffle(_random);
      _rounds.add(
        _FslRound(
          correctCard: correct,
          choices: choices,
          correctIndex: choices.indexOf(correct),
        ),
      );
    }
  }

  Future<void> _prepareVideo() async {
    _videoController?.dispose();
    _videoReady = false;

    if (_currentRound >= _rounds.length) return;
    final card = _rounds[_currentRound].correctCard;
    final source = await FslAssetsService.videoSourceFor(card);
    if (source == null) {
      if (mounted) setState(() => _videoReady = false);
      return;
    }

    _videoController = source.createController();
    try {
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.play();
      if (mounted) setState(() => _videoReady = true);
    } catch (_) {
      if (mounted) setState(() => _videoReady = false);
    }
  }

  /// Opens the current sign video in the fullscreen player, guarding against
  /// repeated taps and restoring inline playback on return.
  Future<void> _openFullscreen(Flashcard card) async {
    if (_openingFullscreen) return;
    final ctrl = _videoController;
    if (ctrl == null) return;
    setState(() => _openingFullscreen = true);
    final fsSource = await FslAssetsService.videoSourceFor(card);
    if (!mounted) return;
    if (fsSource == null) {
      setState(() => _openingFullscreen = false);
      return;
    }
    final wasPlaying = ctrl.value.isPlaying;
    final pos = ctrl.value.position;
    ctrl.pause();
    final returnPos = await openFslFullscreenPlayer(
      context,
      videoSource: fsSource,
      wordEnglish: card.wordEnglish,
      startPosition: pos,
    );
    if (!mounted) return;
    if (returnPos != null) ctrl.seekTo(returnPos);
    if (wasPlaying) ctrl.play();
    setState(() => _openingFullscreen = false);
  }

  @override
  void dispose() {
    disposePause();
    disposeTimer();
    _videoController?.dispose();
    super.dispose();
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    final sound = ref.read(soundServiceProvider);
    setState(() {
      _selectedIndex = index;
      _answered = true;
      final round = _rounds[_currentRound];
      final isCorrect = index == round.correctIndex;
      _reviewItems.add(
        GameReviewItem(
          wordEnglish: round.correctCard.wordEnglish,
          wordFilipino: round.correctCard.wordFilipino,
          category: round.correctCard.category,
          isCorrect: isCorrect,
          userAnswer: isCorrect ? null : round.choices[index].wordEnglish,
        ),
      );
      if (isCorrect) {
        _score++;
        sound.playCorrect();
        ref.read(hapticServiceProvider).success();
      } else {
        sound.playWrong();
        ref.read(hapticServiceProvider).error();
      }
    });

    // Record FSL video view
    final profile = ref.read(profileProvider);
    final card = _rounds[_currentRound].correctCard;
    if (profile != null) {
      HiveService.recordFslVideoView(
        profile.id,
        card.category.label,
        card.wordEnglish,
      );
    }

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_currentRound < _rounds.length - 1) {
        setState(() {
          _currentRound++;
          _selectedIndex = null;
          _answered = false;
          _videoReady = false;
        });
        _prepareVideo();
      } else {
        _saveProgress();
        AccessibleCelebrationOverlay.show(
          context: context,
          ref: ref,
          type: CelebrationType.gameComplete,
        );
        setState(() => _showResult = true);
      }
    });
  }

  void _restart() {
    setState(() {
      _currentRound = 0;
      _score = 0;
      _selectedIndex = null;
      _answered = false;
      _showResult = false;
      _reviewItems.clear();
      _cardsWithVideo.shuffle();
      _generateRounds();
      _videoReady = false;
    });
    _prepareVideo();
  }

  int get _starsEarned {
    if (_rounds.isEmpty) return 0;
    final pct = _score / _rounds.length;
    if (pct >= 0.9) return 3;
    if (pct >= 0.7) return 2;
    if (pct >= 0.5) return 1;
    return 0;
  }

  void _saveProgress() {
    final categories = _rounds
        .map((r) => r.correctCard.category)
        .toSet()
        .toList();
    ref
        .read(progressProvider.notifier)
        .recordGameResult(
          gameType: GameType.fslPractice,
          score: _score,
          total: _rounds.length,
          starsEarned: _starsEarned,
          categoriesPlayed: categories,
        );
    _newAchievements = ref.read(progressProvider.notifier).checkAchievements();

    // Record per-word accuracy for spaced repetition
    final profile = ref.read(profileProvider);
    if (profile != null) {
      final srResults = <String, bool>{};
      for (final r in _reviewItems) {
        final card = _cardsWithVideo
            .where((c) => c.wordEnglish == r.wordEnglish)
            .firstOrNull;
        if (card != null) srResults[card.id] = r.isCorrect;
      }
      SpacedRepetitionService.recordBatch(
        profileId: profile.id,
        results: srResults,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ─── Loading ─────────────────────────────
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: () => context.go('/games/fsl-practice'),
          ),
          title: const Text('Sign → Word'),
        ),
        body: const ShimmerPageSkeleton(),
      );
    }

    final hc = HCColor.of(context);

    // ─── Not enough cards with video ─────────
    if (_rounds.isEmpty) {
      return FslEmptyStateScaffold(
        title: 'Sign → Word',
        onClose: () => context.go('/games/fsl-practice'),
      );
    }

    // ─── Result Screen ───────────────────────
    if (_showResult) {
      return Stack(
        children: [
          CelebrationOverlay(
            show: true,
            child: Scaffold(
              body: Center(
                child: GameResultDialog(
                  score: _score,
                  total: _rounds.length,
                  starsEarned: _starsEarned,
                  onPlayAgain: _restart,
                  onExit: () => context.go('/games/fsl-practice'),
                  onReview: () => showGameReview(
                    context,
                    items: _reviewItems,
                    gameTitle: 'FSL Sign → Word',
                  ),
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

    // ─── Game Play ───────────────────────────
    final round = _rounds[_currentRound];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) pauseGame();
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
                onPressed: pauseGame,
              ),
              title: Text(
                'Sign → Word  •  ${_currentRound + 1}/${_rounds.length}',
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.pause_circle_outline_rounded),
                  tooltip: 'Pause',
                  onPressed: pauseGame,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 20,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_score',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Progress bar
                  Semantics(
                    label: 'Round ${_currentRound + 1} of ${_rounds.length}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentRound + 1) / _rounds.length,
                        minHeight: 6,
                        backgroundColor: AppColors.primaryLight.withValues(
                          alpha: 0.3,
                        ),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Video Area ──────────────────
                  Expanded(
                    flex: 5,
                    child: Semantics(
                      label:
                          'Watch the sign language video and choose the correct word',
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFB388FF,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(
                              0xFFB388FF,
                            ).withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.sign_language_rounded,
                                  color: Color(0xFF7C4DFF),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'What word is this sign?',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: const Color(0xFF7C4DFF),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: _videoReady && _videoController != null
                                      ? GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _videoController!.value.isPlaying
                                                  ? _videoController!.pause()
                                                  : _videoController!.play();
                                            });
                                          },
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              AspectRatio(
                                                aspectRatio: _videoController!
                                                    .value
                                                    .aspectRatio,
                                                child: VideoPlayer(
                                                  _videoController!,
                                                ),
                                              ),
                                              if (!_videoController!
                                                  .value
                                                  .isPlaying)
                                                Container(
                                                  width: 56,
                                                  height: 56,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.5),
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
                                                right: 6,
                                                bottom: 6,
                                                child: GestureDetector(
                                                  onTap: () => _openFullscreen(
                                                    _rounds[_currentRound]
                                                        .correctCard,
                                                  ),
                                                  child: Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.fullscreen_rounded,
                                                      color: Colors.white,
                                                      size: 20,
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
                                                    Icons
                                                        .play_circle_outline_rounded,
                                                    size: 48,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const ShimmerBox(
                                                    width: 100,
                                                    height: 12,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            // Replay button
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TextButton.icon(
                                onPressed: () {
                                  _videoController?.seekTo(Duration.zero);
                                  _videoController?.play();
                                },
                                icon: const Icon(
                                  Icons.replay_rounded,
                                  size: 18,
                                ),
                                label: const Text('Replay'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF7C4DFF),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate(key: ValueKey(_currentRound)).fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0),
                  ),
                  const SizedBox(height: 16),

                  // ─── Answer choices ──────────────
                  Expanded(
                    flex: 3,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: context.responsiveTier<int>(
                          phone: 2,
                          tablet: 2,
                          large: 3,
                          xl: 4,
                        ),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        // Shrink aspect ratio as text scales up so answer cells
                        // stay tall enough to hold scaled label text.
                        childAspectRatio:
                            ((context.isLargeTablet ? 3.0 : 2.5) /
                                    MediaQuery.textScalerOf(context).scale(1.0))
                                .clamp(1.4, 3.0),
                      ),
                      itemCount: round.choices.length,
                      itemBuilder: (context, index) {
                        final choice = round.choices[index];
                        final isSelected = _selectedIndex == index;
                        final isCorrect = index == round.correctIndex;
                        final showCorrect = _answered && isCorrect;
                        final showWrong = _answered && isSelected && !isCorrect;

                        Color bgColor = hc.surface;
                        Color borderColor = AppColors.primary.withValues(
                          alpha: 0.2,
                        );
                        Color textColor = hc.textPrimary;

                        if (showCorrect) {
                          bgColor = AppColors.successLight;
                          borderColor = AppColors.success;
                          textColor = AppColors.successDark;
                        } else if (showWrong) {
                          bgColor = AppColors.errorLight;
                          borderColor = AppColors.error;
                          textColor = AppColors.errorDark;
                        }

                        Widget card = Semantics(
                          button: true,
                          label:
                              'Answer choice: ${choice.wordEnglish}'
                              '${showCorrect ? ', correct answer' : ''}'
                              '${showWrong ? ', wrong answer' : ''}',
                          child: GestureDetector(
                            onTap: () => _selectAnswer(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: borderColor,
                                  width: 2,
                                ),
                                boxShadow: AppColors.softShadow,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      choice.wordEnglish,
                                      style: AppTypography.titleMedium.copyWith(
                                        color: textColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      choice.wordFilipino,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: textColor.withValues(alpha: 0.7),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );

                        if (showWrong) {
                          card = card.animate().shakeX(
                            hz: 6,
                            amount: 4,
                            duration: 400.ms,
                          );
                        }
                        if (showCorrect) {
                          card = card
                              .animate()
                              .scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.05, 1.05),
                                duration: 300.ms,
                              )
                              .then()
                              .scale(
                                begin: const Offset(1.05, 1.05),
                                end: const Offset(1, 1),
                                duration: 200.ms,
                              );
                        }

                        return card
                            .animate(key: ValueKey('$_currentRound-$index'))
                            .fadeIn(duration: 300.ms, delay: (index * 80).ms)
                            .slideY(begin: 0.1, end: 0);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_openingFullscreen) const FslLoadingOverlay(),
          if (isPaused)
            PauseOverlay(
              onResume: resumeGame,
              onRestart: () {
                resumeGame();
                _restart();
              },
              onQuit: () async {
                await savePartialProgress();
                if (context.mounted) context.go('/games/fsl-practice');
              },
            ),
        ],
      ),
    );
  }
}

class _FslRound {
  final Flashcard correctCard;
  final List<Flashcard> choices;
  final int correctIndex;

  _FslRound({
    required this.correctCard,
    required this.choices,
    required this.correctIndex,
  });
}
