import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
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

/// FSL Word → Sign game.
///
/// The student sees a word (English + Filipino) and must pick the correct
/// FSL video from multiple choices. Each choice plays a small video preview.
/// Earns stars and records progress exactly like the other games.
class FslWordToSignScreen extends ConsumerStatefulWidget {
  final List<FlashcardCategory> categories;

  const FslWordToSignScreen({super.key, this.categories = const []});

  @override
  ConsumerState<FslWordToSignScreen> createState() =>
      _FslWordToSignScreenState();
}

class _FslWordToSignScreenState extends ConsumerState<FslWordToSignScreen>
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

  /// One controller per choice in the current round
  List<VideoPlayerController> _choiceControllers = [];
  List<bool> _choiceReady = [];

  /// Pre-initialized controllers for the next round (ready to swap in)
  List<VideoPlayerController> _nextControllers = [];
  List<bool> _nextReady = [];
  bool _nextPrefetched = false;

  /// True while a fullscreen FSL video is being opened. Blocks repeat taps on
  /// the expand buttons so only one fullscreen player can open at a time (so
  /// several videos can't open simultaneously), and drives the loading overlay.
  bool _openingFullscreen = false;

  static const int _numChoices = 3;
  static const int _maxRounds = 8;

  // Cached colors to avoid recomputing on every build
  static final _borderDefault = AppColors.primary.withValues(alpha: 0.2);
  static final _progressBg = AppColors.primaryLight.withValues(alpha: 0.3);
  static final _promptBg = const Color(0xFF00BFA5).withValues(alpha: 0.08);
  static final _promptBorder = const Color(0xFF00BFA5).withValues(alpha: 0.3);
  static final _scoreBadgeBg = AppColors.warning.withValues(alpha: 0.15);
  static final _expandBtnBg = Colors.black.withValues(alpha: 0.5);

  /// Per-choice "was playing" snapshot for pause/resume of the multi-video grid.
  List<bool> _wasPlayingBeforePause = const [];

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
    _wasPlayingBeforePause = _choiceControllers
        .map((c) => c.value.isInitialized && c.value.isPlaying)
        .toList();
    for (final c in _choiceControllers) {
      if (c.value.isInitialized) c.pause();
    }
  }

  @override
  void onResume() {
    for (var i = 0; i < _choiceControllers.length; i++) {
      if (i >= _wasPlayingBeforePause.length) break;
      if (_wasPlayingBeforePause[i] &&
          _choiceControllers[i].value.isInitialized) {
        _choiceControllers[i].play();
      }
    }
    _wasPlayingBeforePause = const [];
  }

  @override
  Future<void> savePartialProgress() async {
    if (!mounted) return;
    if (_loading) return;
    _saveProgress();
  }

  Future<void> _initCards() async {
    // Real asset-manifest check (the previous static set was built from
    // the seed data, so it always claimed every word had a video — and
    // most rounds would fail at video init time).
    final availability = await FslAssetsService.load();
    var source = List.of(availability.cardsWithVideo);
    if (widget.categories.isNotEmpty) {
      source = source
          .where((c) => widget.categories.contains(c.category))
          .toList();
    }

    final available = source;

    if (available.length < _numChoices) {
      if (mounted) {
        setState(() {
          _loading = false;
          _cardsWithVideo = [];
          _rounds = [];
        });
      }
      return;
    }

    _cardsWithVideo = available..shuffle(_random);
    _generateRounds();
    await _prepareChoiceVideos();
    if (mounted) setState(() => _loading = false);
  }

  void _generateRounds() {
    _rounds = [];
    final shuffled = List.of(_cardsWithVideo)..shuffle(_random);
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

  Future<void> _prepareChoiceVideos() async {
    // If next round was pre-fetched, swap in directly
    if (_nextPrefetched) {
      for (final c in _choiceControllers) {
        c.dispose();
      }
      _choiceControllers = _nextControllers;
      _choiceReady = _nextReady;
      _nextControllers = [];
      _nextReady = [];
      _nextPrefetched = false;
      if (mounted) setState(() {});
      return;
    }

    // Dispose old controllers
    for (final c in _choiceControllers) {
      c.dispose();
    }
    _choiceControllers = [];
    _choiceReady = [];

    if (_currentRound >= _rounds.length) return;

    _choiceControllers = await _initControllersForRound(_currentRound);
    _choiceReady = List.filled(_choiceControllers.length, false);

    await _initializeControllers(_choiceControllers, _choiceReady);
    // Single batched setState after all controllers are ready
    if (mounted) setState(() {});
  }

  /// Creates VideoPlayerControllers for a given round index (does NOT init).
  /// Resolves each choice's [VideoSource] (which may download from the cloud
  /// on first play); choices without an available source are skipped so the
  /// rest of the pipeline can keep going without crashing.
  Future<List<VideoPlayerController>> _initControllersForRound(
    int roundIndex,
  ) async {
    final round = _rounds[roundIndex];
    final sources = await Future.wait(
      round.choices.map(FslAssetsService.videoSourceFor),
    );
    final controllers = <VideoPlayerController>[];
    for (final source in sources) {
      if (source != null) {
        controllers.add(source.createController());
      }
    }
    return controllers;
  }

  /// Initializes, loops, mutes, and plays a list of controllers in parallel.
  Future<void> _initializeControllers(
    List<VideoPlayerController> controllers,
    List<bool> readyFlags,
  ) async {
    await Future.wait(
      List.generate(controllers.length, (i) async {
        try {
          await controllers[i].initialize();
          controllers[i].setLooping(true);
          controllers[i].setVolume(0);
          controllers[i].play();
          readyFlags[i] = true;
        } catch (_) {
          // leave as not ready
        }
      }),
    );
  }

  /// Pre-initialize the next round's video controllers in the background.
  Future<void> _prefetchNextRound() async {
    final nextIndex = _currentRound + 1;
    if (nextIndex >= _rounds.length) return;

    // Dispose any stale prefetch
    for (final c in _nextControllers) {
      c.dispose();
    }
    _nextControllers = await _initControllersForRound(nextIndex);
    _nextReady = List.filled(_nextControllers.length, false);
    _nextPrefetched = false;

    await _initializeControllers(_nextControllers, _nextReady);
    _nextPrefetched = true;
  }

  /// Opens [card]'s sign video (played by [ctrl]) in the fullscreen player,
  /// guarding against repeated taps and restoring inline playback on return.
  Future<void> _openFullscreen(
    Flashcard card,
    VideoPlayerController ctrl,
  ) async {
    if (_openingFullscreen) return;
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
      wordFilipino: card.wordFilipino,
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
    for (final c in _choiceControllers) {
      c.dispose();
    }
    for (final c in _nextControllers) {
      c.dispose();
    }
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

    // Start pre-fetching next round's videos immediately while user sees feedback
    _prefetchNextRound();

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_currentRound < _rounds.length - 1) {
        setState(() {
          _currentRound++;
          _selectedIndex = null;
          _answered = false;
        });
        _prepareChoiceVideos();
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
    });
    _prepareChoiceVideos();
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
          title: const Text('Word → Sign'),
        ),
        body: const ShimmerPageSkeleton(),
      );
    }

    final hc = HCColor.of(context);

    // ─── Not enough cards with video ─────────
    if (_rounds.isEmpty) {
      return FslEmptyStateScaffold(
        title: 'Word → Sign',
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
                    gameTitle: 'FSL Word → Sign',
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
                'Word → Sign  •  ${_currentRound + 1}/${_rounds.length}',
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
                        color: _scoreBadgeBg,
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
              padding: EdgeInsets.all(context.pagePadding),
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
                        backgroundColor: _progressBg,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── Word prompt ─────────────────
                  Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          color: _promptBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _promptBorder, width: 2),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Which sign means…',
                              style: AppTypography.bodyMedium.copyWith(
                                color: hc.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              round.correctCard.wordEnglish,
                              style: AppTypography.headlineMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF00695C),
                              ),
                            ),
                            Text(
                              round.correctCard.wordFilipino,
                              style: AppTypography.titleMedium.copyWith(
                                color: const Color(0xFF00897B),
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate(key: ValueKey(_currentRound))
                      .fadeIn(duration: 250.ms)
                      .slideX(begin: 0.1, end: 0),
                  const SizedBox(height: 20),

                  // ─── Video choice grid ───────────
                  Expanded(
                    child: ListView.separated(
                      itemCount: round.choices.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final choice = round.choices[index];
                        final isSelected = _selectedIndex == index;
                        final isCorrect = index == round.correctIndex;
                        final showCorrect = _answered && isCorrect;
                        final showWrong = _answered && isSelected && !isCorrect;

                        Color borderColor = _borderDefault;
                        Color bgColor = hc.surface;

                        if (showCorrect) {
                          borderColor = AppColors.success;
                          bgColor = AppColors.successLight;
                        } else if (showWrong) {
                          borderColor = AppColors.error;
                          bgColor = AppColors.errorLight;
                        }

                        final hasController =
                            index < _choiceControllers.length &&
                            index < _choiceReady.length &&
                            _choiceReady[index];

                        // Responsive tile dimensions for tablet
                        final tileHeight = context.responsive(
                          phone: 120.0,
                          tablet: 160.0,
                        );
                        final videoWidth = context.responsive(
                          phone: 140.0,
                          tablet: 220.0,
                        );
                        final iconSize = context.responsiveSize(28);
                        final expandBtnSize = context.responsive(
                          phone: 28.0,
                          tablet: 36.0,
                        );
                        final expandIconSize = context.responsive(
                          phone: 18.0,
                          tablet: 24.0,
                        );

                        Widget videoTile = Semantics(
                          button: true,
                          label:
                              'Video choice ${index + 1}${showCorrect ? ', correct' : ''}${showWrong ? ', wrong' : ''}',
                          child: GestureDetector(
                            onTap: () => _selectAnswer(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              height: tileHeight,
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: borderColor,
                                  width: 2.5,
                                ),
                                boxShadow: AppColors.softShadow,
                              ),
                              child: Row(
                                children: [
                                  // Video preview
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(14),
                                      bottomLeft: Radius.circular(14),
                                    ),
                                    child: SizedBox(
                                      width: videoWidth,
                                      height: tileHeight,
                                      child: hasController
                                          ? Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: RepaintBoundary(
                                                    child: VideoPlayer(
                                                      _choiceControllers[index],
                                                    ),
                                                  ),
                                                ),
                                                // Fullscreen expand icon
                                                Positioned(
                                                  right: 4,
                                                  bottom: 4,
                                                  child: GestureDetector(
                                                    onTap: () => _openFullscreen(
                                                      choice,
                                                      _choiceControllers[index],
                                                    ),
                                                    child: Container(
                                                      width: expandBtnSize,
                                                      height: expandBtnSize,
                                                      decoration: BoxDecoration(
                                                        color: _expandBtnBg,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        Icons
                                                            .fullscreen_rounded,
                                                        color: Colors.white,
                                                        size: expandIconSize,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Container(
                                              color: AppColors.surfaceVariant,
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  // Label area
                                  Expanded(
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.sign_language_rounded,
                                            size: iconSize,
                                            color: showCorrect
                                                ? AppColors.success
                                                : showWrong
                                                ? AppColors.error
                                                : hc.textSecondary,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Sign ${index + 1}',
                                            style: AppTypography.labelLarge
                                                .copyWith(
                                                  color: showCorrect
                                                      ? AppColors.successDark
                                                      : showWrong
                                                      ? AppColors.errorDark
                                                      : hc.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          // Show the actual word when answered
                                          if (_answered)
                                            Text(
                                              choice.wordEnglish,
                                              style: AppTypography.bodySmall
                                                  .copyWith(
                                                    color: showCorrect
                                                        ? AppColors.successDark
                                                        : showWrong
                                                        ? AppColors.errorDark
                                                        : AppColors.textHint,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Correct / Wrong icon
                                  if (showCorrect || showWrong)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Icon(
                                        showCorrect
                                            ? Icons.check_circle_rounded
                                            : Icons.cancel_rounded,
                                        color: showCorrect
                                            ? AppColors.success
                                            : AppColors.error,
                                        size: iconSize,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );

                        if (showWrong) {
                          videoTile = videoTile.animate().shakeX(
                            hz: 6,
                            amount: 4,
                            duration: 350.ms,
                          );
                        }
                        if (showCorrect) {
                          videoTile = videoTile
                              .animate()
                              .scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.02, 1.02),
                                duration: 250.ms,
                              )
                              .then()
                              .scale(
                                begin: const Offset(1.02, 1.02),
                                end: const Offset(1, 1),
                                duration: 150.ms,
                              );
                        }

                        return videoTile
                            .animate(key: ValueKey('$_currentRound-$index'))
                            .fadeIn(duration: 250.ms, delay: (index * 80).ms)
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
