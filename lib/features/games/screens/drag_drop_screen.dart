import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/seed_data.dart';
import '../../../core/services/adaptive_difficulty_service.dart';
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
import '../timed_game_mixin.dart';
import '../game_pause_mixin.dart';
import '../widgets/pause_overlay.dart';
import '../../break_time/break_time.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/flashcard_image.dart';
import '../../../navigation/nav_extensions.dart';
import '../../../widgets/fullscreen_host.dart';
import '../../../core/widgets/fit_text.dart';
import '../../../widgets/gesture_edge_padding.dart';
import '../../../widgets/dpad_focusable.dart';
import '../../gaze_control/logic/gaze_focus_driver.dart';
import '../unfinished_round_stars.dart';
import '../../../core/widgets/app_bar_title.dart';

class DragDropScreen extends ConsumerStatefulWidget {
  final GameDifficulty difficulty;
  final List<FlashcardCategory> categories;
  final bool timedMode;
  const DragDropScreen({
    super.key,
    this.difficulty = GameDifficulty.medium,
    this.categories = const [],
    this.timedMode = false,
  });

  @override
  ConsumerState<DragDropScreen> createState() => _DragDropScreenState();
}

class _DragDropScreenState extends ConsumerState<DragDropScreen>
    with TickerProviderStateMixin, TimedGameMixin, GamePauseMixin {
  /// Difficulty-based item count
  int get _totalItems => switch (widget.difficulty) {
    GameDifficulty.easy => 3,
    GameDifficulty.medium => 5,
    GameDifficulty.hard => 7,
  };

  late List<Flashcard> _flashcards;
  late List<String> _draggables; // English words – shuffled
  late List<_DropTarget> _targets; // Filipino words – original order
  int _correctCount = 0;
  bool _showResult = false;
  List<Achievement> _newAchievements = [];
  final Map<String, String?> _matches = {}; // targetId → draggable word

  /// The word picked up by pressing it rather than dragging it — the way
  /// arrow keys, a switch box, a controller, gaze and a screen reader play
  /// this game, none of which can drag. Pressing a Filipino row then puts it
  /// there, through the same [_onAccept] a drop runs.
  String? _picked;

  /// Each word's focus, so a placement can hand focus on to the next word
  /// still to place. Kept until dispose: a word can come round again.
  final Map<String, FocusNode> _wordFocus = {};

  FocusNode _focusOf(String word) =>
      _wordFocus.putIfAbsent(word, () => FocusNode(debugLabel: 'word $word'));

  @override
  void initState() {
    super.initState();
    _startGame();
    initPause();
  }

  void _startGame() {
    var all = List.of(SeedData.allFlashcards);
    if (widget.categories.isNotEmpty) {
      all = all.where((c) => widget.categories.contains(c.category)).toList();
    }
    // Shuffled first, so neither twin is always the one left out.
    _flashcards = AdaptiveDifficultyService.pickGameCards(
      profileId: ref.read(profileProvider)?.id,
      cards: distinctDragDropCards(all..shuffle()),
      count: _totalItems,
    );
    _targets = _flashcards
        .map(
          (f) => _DropTarget(
            id: f.id,
            filipino: f.wordFilipino,
            englishAnswer: f.wordEnglish,
            card: f,
            icon: f.category.icon,
            color: f.category.color,
          ),
        )
        .toList();
    _draggables = _flashcards.map((f) => f.wordEnglish).toList()..shuffle();
    _matches.clear();
    _picked = null;
    _correctCount = 0;
    _showResult = false;
    startTimerIfNeeded(widget.timedMode);
  }

  @override
  void dispose() {
    for (final node in _wordFocus.values) {
      node.dispose();
    }
    disposePause();
    disposeTimer();
    super.dispose();
  }

  @override
  Future<void> savePartialProgress() async {
    if (_flashcards.isEmpty) return;
    _saveProgress(completed: false);
  }

  @override
  void onTimeUp() {
    _saveProgress();
    AccessibleCelebrationOverlay.show(
      context: context,
      ref: ref,
      type: CelebrationType.gameComplete,
    );
    setState(() => _showResult = true);
  }

  void _onAccept(String targetId, String englishWord) {
    final idx = _targets.indexWhere((t) => t.id == targetId);
    if (idx == -1) return; // target not found — ignore
    final target = _targets[idx];
    final sound = ref.read(soundServiceProvider);

    // Remove from previous target if already placed
    _matches.forEach((key, value) {
      if (value == englishWord) _matches[key] = null;
    });

    setState(() {
      _matches[targetId] = englishWord;
      if (englishWord == target.englishAnswer) {
        target.isCorrect = true;
        _correctCount = _targets.where((t) => t.isCorrect).length;
        sound.playCorrect();
        ref.read(hapticServiceProvider).success();

        if (_correctCount == _totalItems) {
          _saveProgress();
          AccessibleCelebrationOverlay.show(
            context: context,
            ref: ref,
            type: CelebrationType.gameComplete,
          );
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) setState(() => _showResult = true);
          });
        }
      } else {
        sound.playWrong();
        ref.read(hapticServiceProvider).error();
      }
    });
  }

  /// Picks [word] up, or puts it back down when it is already picked up.
  void _pick(String word) {
    if (_isPlaced(word)) return;
    setState(() => _picked = _picked == word ? null : word);
    ref.read(hapticServiceProvider).selectionClick();
  }

  /// Puts the picked-up word on [targetId], then focuses the next word to
  /// place — this one again after a miss, so the learner can try it
  /// elsewhere straight away instead of hunting back up the board.
  void _placePicked(String targetId) {
    final word = _picked;
    if (word == null) return;
    _picked = null;
    _onAccept(targetId, word);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final next = _isPlaced(word)
          ? _draggables.where((w) => !_isPlaced(w)).firstOrNull
          : word;
      final node = next == null ? null : _wordFocus[next];
      if (node == null || node.context == null) return;
      GazeFocusDriver.focusChosen(node);
    });
  }

  bool _isPlaced(String word) {
    return _matches.containsValue(word) &&
        _targets.any((t) => t.isCorrect && _matches[t.id] == word);
  }

  // 3 for a completed puzzle; a quit or the clock running out is scored on
  // the words actually placed (it used to pay 3 whatever happened).
  int get _starsEarned => _correctCount >= _totalItems
      ? 3
      : unfinishedRoundStars(_correctCount, _totalItems);

  /// [completed] is false only on the "Quit to Games" path. The score counts
  /// toward stats exactly as before either way, but a run abandoned after two
  /// of ten rounds is not fed to the adaptive engine as 20 % accuracy — that
  /// reads as a struggling learner and would drop the suggested difficulty
  /// for quitting rather than for missing.
  void _saveProgress({bool completed = true}) {
    final categories = _flashcards.map((c) => c.category).toSet().toList();
    // Per-word results — feeds both wordsLearned and spaced repetition.
    final srResults = <String, bool>{};
    for (final c in _flashcards) {
      srResults[c.id] = true;
    }

    ref
        .read(progressProvider.notifier)
        .recordGameResult(
          gameType: GameType.dragAndDrop,
          score: _correctCount,
          total: _totalItems,
          starsEarned: _starsEarned,
          categoriesPlayed: categories,
          correctWordIds: srResults.correctWordIds,
          durationSeconds: elapsedSeconds,
          playedDifficulty: completed ? widget.difficulty : null,
        );
    _newAchievements = ref.read(progressProvider.notifier).checkAchievements();

    // Record per-word accuracy for spaced repetition
    final profile = ref.read(profileProvider);
    if (profile != null) {
      SpacedRepetitionService.recordBatch(
        profileId: profile.id,
        results: srResults,
      );
    }
  }

  List<GameReviewItem> get _reviewItems => _flashcards
      .map(
        (c) => GameReviewItem(
          wordEnglish: c.wordEnglish,
          wordFilipino: c.wordFilipino,
          category: c.category,
          isCorrect: true,
        ),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_showResult) {
      return Stack(
        children: [
          CelebrationOverlay(
            show: true,
            child: Scaffold(
              body: Center(
                child: GameResultDialog(
                  score: _correctCount,
                  total: _totalItems,
                  starsEarned: _starsEarned,
                  onPlayAgain: () => setState(() => _startGame()),
                  onExit: () => context.popOrGo('/games'),
                  onReview: () => showGameReview(
                    context,
                    items: _reviewItems,
                    gameTitle: GameType.dragAndDrop.labelOf(l10n),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) pauseGame();
      },
      child: Stack(
        children: [
          Scaffold(
            bottomNavigationBar: GameBreakBar(onHold: holdForBreak, onResume: resumeFromBreak),
            appBar: fullscreenBar(
              ref,
              AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: l10n.close,
                  onPressed: pauseGame,
                ),
                title: AppBarTitle(AppLocalizations.of(context)!.dragAndDrop),
                actions: [
                  GameBreakAction(onHold: holdForBreak, onResume: resumeFromBreak),
                  IconButton(
                    icon: const Icon(Icons.pause_circle_outline_rounded),
                    tooltip: l10n.pauseLabel,
                    onPressed: pauseGame,
                  ),
                  if (isTimedMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GameTimerWidget(
                        remainingSeconds: remainingSeconds,
                        totalSeconds: totalTimerSeconds,
                        size: 44,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text(
                        '$_correctCount / $_totalItems',
                        semanticsLabel: AppLocalizations.of(context)!
                            .ddMatchedOf(_correctCount, _totalItems),
                        style: AppTypography.titleMedium.copyWith(
                          color: HCColor.of(context).primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            body: Padding(
              // Clear of the back-gesture strips: a word dragged from the
              // screen's edge went "back" on a phone with gesture navigation.
              padding: gestureSafeHorizontal(context, minimum: 20)
                  .copyWith(top: 20, bottom: 20),
              // Scroll the whole board so a short (landscape) viewport or large font
              // scale never overflows — on a tablet it all fits without scrolling.
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Instructions
                    // Never cut short: the board scrolls, and the second
                    // half is the only way to play without dragging.
                    Text(
                          AppLocalizations.of(context)!.dragInstruction,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            color: HCColor.of(context).textSecondary,
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: -0.2, end: 0),

                    const SizedBox(height: 20),

                    // ─── Draggable Words (top) ────────────
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: _draggables.map((word) {
                        final placed = _isPlaced(word);
                        if (placed) {
                          // Placeholder for placed word — IgnorePointer
                          // so faded chips don't block taps on items behind them
                          return IgnorePointer(
                            child: Opacity(
                              opacity: 0.3,
                              child: Chip(
                                label: Text(
                                  word,
                                  style: AppTypography.labelMedium.copyWith(
                                    color: HCColor.of(context).textSecondary,
                                  ),
                                ),
                                backgroundColor: HCColor.of(
                                  context,
                                ).surfaceLight,
                                side: BorderSide.none,
                              ),
                            ),
                          );
                        }
                        final picked = _picked == word;
                        // One node: the label, and the press and focus of
                        // the detector below. Pressing picks the word up, so
                        // every input plays — a finger can still drag it.
                        return Semantics(
                          container: true,
                          button: true,
                          selected: picked,
                          label: picked
                              ? l10n.draggableWordPicked(word)
                              : l10n.draggableWordSemantics(word),
                          child: DpadGestureDetector(
                            focusNode: _focusOf(word),
                            onTap: () => _pick(word),
                            child: Draggable<String>(
                              data: word,
                              // A drag is an answer of its own: whatever was
                              // picked up by a press is put down.
                              onDragStarted: () {
                                if (_picked != null) {
                                  setState(() => _picked = null);
                                }
                              },
                              feedback: Material(
                                elevation: 8,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.accentGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    word,
                                    style: AppTypography.labelLarge.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.3,
                                child: ExcludeSemantics(
                                  child: _WordChip(word: word),
                                ),
                              ),
                              child: ExcludeSemantics(
                                child: _WordChip(word: word, picked: picked),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 12),

                    // ─── Drop Targets (bottom list) ───────
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _targets.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final target = _targets[index];
                        return _DropTargetRow(
                              target: target,
                              matchedWord: _matches[target.id],
                              onAccept: (word) => _onAccept(target.id, word),
                              picked: _picked,
                              onPlace: () => _placePicked(target.id),
                            )
                            .animate()
                            .fadeIn(
                              duration: 400.ms,
                              delay: Duration(milliseconds: 80 * index),
                            )
                            .slideX(begin: 0.15, end: 0);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isPaused)
            PauseOverlay(
              onResume: resumeGame,
              onRestart: () {
                resumeGame();
                setState(_startGame);
              },
              onQuit: () async {
                await savePartialProgress();
                if (context.mounted) context.popOrGo('/games');
              },
            ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────
// Supporting types & widgets
// ────────────────────────────────────────

/// [cards] with one card per word, either way round, keeping the first of
/// each.
///
/// "Walk" and "Chicken" are two seed cards each, and a round that dealt both
/// had two chips nobody could tell apart: placing one read as placing both,
/// so the last row could never be filled and the round never ended. Two
/// rows saying "Manok", or "Gabi" (night, and taro), were no better.
@visibleForTesting
List<Flashcard> distinctDragDropCards(Iterable<Flashcard> cards) {
  final english = <String>{};
  final filipino = <String>{};
  final distinct = <Flashcard>[];
  for (final c in cards) {
    final en = c.wordEnglish.toLowerCase();
    final fil = c.wordFilipino.toLowerCase();
    if (english.contains(en) || filipino.contains(fil)) continue;
    english.add(en);
    filipino.add(fil);
    distinct.add(c);
  }
  return distinct;
}

class _DropTarget {
  final String id;
  final String filipino;
  final String englishAnswer;
  final Flashcard card;
  final IconData icon;
  final Color color;
  bool isCorrect = false;

  _DropTarget({
    required this.id,
    required this.filipino,
    required this.englishAnswer,
    required this.card,
    required this.icon,
    required this.color,
  });
}

class _WordChip extends StatelessWidget {
  final String word;

  /// Picked up by a press, and waiting for its row: lifted and ringed, so it
  /// reads as "in hand" from across a room as well as up close.
  final bool picked;

  const _WordChip({required this.word, this.picked = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: picked
              ? HCColor.of(context).primary
              : AppColors.primary.withValues(alpha: 0.4),
          width: picked ? 3 : 1,
        ),
        boxShadow: picked ? AppColors.softShadow : null,
      ),
      child: Text(
        word,
        // The chip is the soft primary in every theme; its words are the
        // same hue, deepened until they read on it.
        style: AppTypography.labelLarge.copyWith(
          color: HCColor.of(context).readableOver(
            AppColors.primary,
            AppColors.primaryLight,
          ),
        ),
      ),
    );
  }
}

class _DropTargetRow extends StatelessWidget {
  final _DropTarget target;
  final String? matchedWord;
  final ValueChanged<String> onAccept;

  /// The word the learner picked up by pressing it, or null.
  final String? picked;

  /// Puts [picked] here.
  final VoidCallback onPlace;

  const _DropTargetRow({
    required this.target,
    required this.matchedWord,
    required this.onAccept,
    required this.picked,
    required this.onPlace,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // A row takes a press only while a word is in hand, and never once it
    // is matched — the same rule [DragTarget] applies to a drop.
    final word = picked;
    final canPlace = word != null && !target.isCorrect;
    return Semantics(
      container: true,
      button: canPlace,
      label: canPlace
          ? l10n.dropTargetPlace(target.filipino, word)
          : target.isCorrect
          ? l10n.dropTargetMatched(target.filipino, target.englishAnswer)
          : (matchedWord != null
                ? l10n.dropTargetHolding(target.filipino, matchedWord!)
                : l10n.dropTargetEmptyHint(target.filipino)),
      child: DpadGestureDetector(
        onTap: canPlace ? onPlace : null,
        child: DragTarget<String>(
          onWillAcceptWithDetails: (_) => !target.isCorrect,
          onAcceptWithDetails: (details) => onAccept(details.data),
          builder: (context, candidateData, rejectedData) {
            // A word in hand lights its possible rows as a drag over them
            // does.
            final isHovering = candidateData.isNotEmpty || canPlace;
            // The row in the theme's own colours: it was always white, and
            // in dark and high contrast its word (the theme's light text)
            // was white on white (8 Nov).
            final hc = HCColor.of(context);
            return ExcludeSemantics(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: target.isCorrect
                      ? (hc.isDark
                            ? Color.alphaBlend(
                                hc.success.withValues(alpha: 0.22),
                                hc.surface,
                              )
                            : AppColors.successLight)
                      : isHovering
                      ? target.color.withValues(alpha: 0.15)
                      : (hc.isDark ? hc.surface : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: target.isCorrect
                        ? AppColors.success
                        : isHovering
                        ? target.color
                        : AppColors.border,
                    width: target.isCorrect || isHovering ? 2 : 1,
                  ),
                  boxShadow: isHovering ? AppColors.softShadow : [],
                ),
                child: Row(
                  children: [
                    // Per-word emoji
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: target.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: FlashcardPicture(
                        card: target.card,
                        extent: 26,
                        borderRadius: 13,
                        // The target shows its Filipino word and the learner drags
                        // the English one onto it; a picture that names both pairs
                        // them up for free.
                        revealsAnswer: false,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Filipino word
                    Expanded(
                      // The vocabulary word itself, so it must never be split down
                      // the middle: this row rendered "Kuman / ta" and "Matulo / g"
                      // on a narrow screen, on the game built to teach those words.
                      child: FitText(
                        target.filipino,
                        style: AppTypography.titleMedium.copyWith(
                          color: HCColor.of(context).textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                      ),
                    ),

                    // Drop zone / matched word
                    if (target.isCorrect) ...[
                      Icon(
                        Icons.check_circle_rounded,
                        color: HCColor.of(context).graphic(AppColors.success),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        matchedWord ?? '',
                        style: AppTypography.labelLarge.copyWith(
                          color: HCColor.of(context).successText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: HCColor.of(context).surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isHovering
                                ? target.color
                                : HCColor.of(context).border,
                          ),
                        ),
                        child: Text(
                          matchedWord ?? '???',
                          style: AppTypography.labelMedium.copyWith(
                            color: matchedWord != null
                                ? HCColor.of(context).errorText
                                : HCColor.of(context).textHint,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
