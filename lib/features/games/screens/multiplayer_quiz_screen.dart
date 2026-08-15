import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../timed_game_mixin.dart';
import '../game_pause_mixin.dart';
import '../widgets/pause_overlay.dart';
import '../../../navigation/nav_extensions.dart';

/// Turn-based multiplayer vocabulary quiz for two players on the same device.
///
/// Players alternate answering vocabulary questions. Each round shows a word
/// and 4 options. The player with the highest score wins.
class MultiplayerQuizScreen extends ConsumerStatefulWidget {
  final List<FlashcardCategory> categories;

  const MultiplayerQuizScreen({super.key, this.categories = const []});

  @override
  ConsumerState<MultiplayerQuizScreen> createState() =>
      _MultiplayerQuizScreenState();
}

class _MultiplayerQuizScreenState extends ConsumerState<MultiplayerQuizScreen>
    with TickerProviderStateMixin, TimedGameMixin, GamePauseMixin {
  // Game state
  _GamePhase _phase = _GamePhase.setup;
  final _player1Controller = TextEditingController(text: 'Player 1');
  final _player2Controller = TextEditingController(text: 'Player 2');
  int _roundsPerPlayer = 5;

  // In-game state
  int _currentRound = 0;
  int _currentPlayer = 1; // 1 or 2
  int _player1Score = 0;
  int _player2Score = 0;
  int _player1Correct = 0;
  int _player2Correct = 0;
  int _player1Streak = 0;
  int _player2Streak = 0;
  int _player1BestStreak = 0;
  int _player2BestStreak = 0;
  List<_QuizQuestion> _questions = [];
  int _questionIndex = 0;
  int? _selectedAnswer;
  bool _answered = false;
  Timer? _roundTimer;
  int _timeRemaining = 10;
  static const _timePerQuestion = 10;

  // Animations
  late AnimationController _shakeController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    initPause();
  }

  @override
  void dispose() {
    disposePause();
    disposeTimer();
    _player1Controller.dispose();
    _player2Controller.dispose();
    _roundTimer?.cancel();
    _shakeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void onTimeUp() {
    // Uses its own _roundTimer, not the mixin's countdown — never called.
  }

  @override
  void onPause() {
    _roundTimer?.cancel();
    _roundTimer = null;
  }

  @override
  void onResume() {
    if (_phase != _GamePhase.playing) return;
    if (_answered) return;
    if (_roundTimer != null) return;
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _timeRemaining--);
      if (_timeRemaining <= 0) {
        timer.cancel();
        _handleTimeout();
      }
    });
  }

  @override
  Future<void> savePartialProgress() async {
    if (_phase != _GamePhase.playing && _phase != _GamePhase.roundResult) {
      return;
    }
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    ref
        .read(progressProvider.notifier)
        .recordGameResult(
          gameType: GameType.flashcardQuiz,
          score: _player1Score > _player2Score
              ? _player1Correct
              : _player2Correct,
          total: _roundsPerPlayer,
          starsEarned: 0,
          categoriesPlayed: widget.categories,
        );
  }

  bool get _isMidGame =>
      _phase == _GamePhase.playing ||
      _phase == _GamePhase.roundResult ||
      _phase == _GamePhase.turnTransition;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isMidGame,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isMidGame) pauseGame();
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: switch (_phase) {
                  _GamePhase.setup => _buildSetup(),
                  _GamePhase.turnTransition => _buildTurnTransition(),
                  _GamePhase.playing => _buildPlaying(),
                  _GamePhase.roundResult => _buildRoundResult(),
                  _GamePhase.gameOver => _buildGameOver(),
                },
              ),
            ),
          ),
          if (isPaused && _isMidGame)
            PauseOverlay(
              onResume: resumeGame,
              onRestart: () {
                resumeGame();
                _rematch();
              },
              onQuit: () async {
                await savePartialProgress();
                if (context.mounted) context.popOrGo('/home');
              },
            ),
        ],
      ),
    );
  }

  // ─── Setup Phase ──────────────────────────────────────

  Widget _buildSetup() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => context.pop(),
                ),
                const Spacer(),
                Text(
                  'Multiplayer Quiz',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),

            const SizedBox(height: 32),

            // Player avatars
            Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PlayerSetupCard(
                      controller: _player1Controller,
                      playerNum: 1,
                      color: AppColors.info,
                      emoji: '🔵',
                    ),
                    const SizedBox(width: 24),
                    Text(
                      'VS',
                      style: AppTypography.displaySmall.copyWith(
                        fontWeight: FontWeight.w900,
                        color: HCColor.of(context).textSecondary,
                      ),
                    ),
                    const SizedBox(width: 24),
                    _PlayerSetupCard(
                      controller: _player2Controller,
                      playerNum: 2,
                      color: AppColors.error,
                      emoji: '🔴',
                    ),
                  ],
                )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),

            const SizedBox(height: 32),

            // Rounds selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HCColor.of(context).surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                children: [
                  Text(
                    'Rounds per Player',
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [3, 5, 7, 10].map((count) {
                      final isSelected = _roundsPerPlayer == count;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('$count'),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _roundsPerPlayer = count),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : HCColor.of(context).textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

            const SizedBox(height: 40),

            // Start button
            SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startGame,
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(
                      'Start Battle!',
                      style: AppTypography.buttonText.copyWith(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                )
                .animate(delay: 400.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── Turn Transition ──────────────────────────────────

  Widget _buildTurnTransition() {
    final isP1 = _currentPlayer == 1;
    final name = isP1 ? _player1Controller.text : _player2Controller.text;
    final color = isP1 ? AppColors.info : AppColors.error;
    final emoji = isP1 ? '🔵' : '🔴';

    return GestureDetector(
      onTap: _startQuestion,
      child: Container(
        color: color.withValues(alpha: 0.08),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 64))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.2, 1.2),
                    duration: 800.ms,
                  ),
              const SizedBox(height: 16),
              Text(
                '$name\'s Turn!',
                style: AppTypography.displayMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ).animate().fadeIn(duration: 500.ms),
              const SizedBox(height: 8),
              Text(
                'Round ${(_currentRound ~/ 2) + 1} of $_roundsPerPlayer',
                style: AppTypography.titleMedium.copyWith(
                  color: HCColor.of(context).textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Tap anywhere to start!',
                      style: AppTypography.titleMedium.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fadeIn()
                  .then()
                  .fade(begin: 1, end: 0.5, duration: 800.ms),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Playing Phase ────────────────────────────────────

  Widget _buildPlaying() {
    if (_questionIndex >= _questions.length) return const SizedBox.shrink();
    final question = _questions[_questionIndex];
    final isP1 = _currentPlayer == 1;
    final color = isP1 ? AppColors.info : AppColors.error;
    final playerName = isP1 ? _player1Controller.text : _player2Controller.text;

    return OverflowSafeBody(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Top bar: player, round, timer
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${isP1 ? "🔵" : "🔴"} $playerName',
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Timer — capped scale so 2-digit values shrink to fit the circle.
              Container(
                width: context.scaledHeightCapped(50),
                height: context.scaledHeightCapped(50),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _timeRemaining <= 3
                      ? AppColors.error.withValues(alpha: 0.15)
                      : HCColor.of(context).surfaceLight,
                  border: Border.all(
                    color: _timeRemaining <= 3
                        ? AppColors.error
                        : AppColors.border,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$_timeRemaining',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w900,
                      color: _timeRemaining <= 3
                          ? AppColors.error
                          : HCColor.of(context).textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Question
          Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: HCColor.of(context).surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppColors.softShadow,
                ),
                child: Column(
                  children: [
                    Text(
                      question.promptLabel,
                      style: AppTypography.labelMedium.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question.prompt,
                      style: AppTypography.displaySmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: HCColor.of(context).textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (question.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        question.subtitle!,
                        style: AppTypography.bodySmall.copyWith(
                          color: HCColor.of(context).textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms)
              .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),

          const SizedBox(height: 24),

          // Answer Options (responsive grid).
          // shrinkWrap + NeverScrollableScrollPhysics means the GridView sizes
          // itself to its content — no Expanded needed (and Expanded would
          // break the parent OverflowSafeBody's scroll wrapper at large scale).
          // childAspectRatio shrinks as text scales up so cells stay tall
          // enough to hold the scaled label text.
          GridView.count(
            crossAxisCount: context.responsiveTier<int>(
              phone: 2,
              tablet: 2,
              large: 3,
              xl: 4,
            ),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio:
                (2.2 / MediaQuery.textScalerOf(context).scale(1.0)).clamp(
                  1.2,
                  2.2,
                ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(question.options.length, (idx) {
              final option = question.options[idx];
              final isCorrect = idx == question.correctIndex;
              final isSelected = _selectedAnswer == idx;

              Color bgColor = HCColor.of(context).surface;
              Color borderColor = AppColors.border;
              Color textColor = HCColor.of(context).textPrimary;

              if (_answered) {
                if (isCorrect) {
                  bgColor = AppColors.success.withValues(alpha: 0.15);
                  borderColor = AppColors.success;
                  textColor = AppColors.success;
                } else if (isSelected && !isCorrect) {
                  bgColor = AppColors.error.withValues(alpha: 0.15);
                  borderColor = AppColors.error;
                  textColor = AppColors.error;
                }
              } else if (isSelected) {
                bgColor = color.withValues(alpha: 0.1);
                borderColor = color;
              }

              return GestureDetector(
                onTap: _answered ? null : () => _selectAnswer(idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: borderColor.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    option,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ).animate(delay: (100 * idx).ms).fadeIn().slideY(begin: 0.1);
            }),
          ),

          // Score bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: HCColor.of(context).surfaceLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🔵 ${_player1Controller.text}: $_player1Score',
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.info,
                  ),
                ),
                Text(
                  '🔴 ${_player2Controller.text}: $_player2Score',
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Round Result ─────────────────────────────────────

  Widget _buildRoundResult() {
    final question = _questions[_questionIndex];
    final isCorrect = _selectedAnswer == question.correctIndex;
    final isP1 = _currentPlayer == 1;
    final color = isP1 ? AppColors.info : AppColors.error;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: context.scaleIcon(80),
            color: isCorrect ? AppColors.success : AppColors.error,
          ).animate().scale(
            begin: const Offset(0, 0),
            end: const Offset(1, 1),
            duration: 400.ms,
            curve: Curves.elasticOut,
          ),
          const SizedBox(height: 16),
          Text(
            isCorrect ? 'Correct! 🎉' : 'Wrong! 😅',
            style: AppTypography.displaySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: isCorrect ? AppColors.success : AppColors.error,
            ),
          ),
          const SizedBox(height: 8),
          if (!isCorrect)
            Text(
              'Answer: ${question.options[question.correctIndex]}',
              style: AppTypography.titleMedium.copyWith(
                color: HCColor.of(context).textSecondary,
              ),
            ),
          const SizedBox(height: 8),
          if (isCorrect)
            Text(
              '+${_calculatePoints()} points!',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  // ─── Game Over ────────────────────────────────────────

  Widget _buildGameOver() {
    final p1Name = _player1Controller.text;
    final p2Name = _player2Controller.text;
    final isDraw = _player1Score == _player2Score;
    final p1Wins = _player1Score > _player2Score;
    final winnerName = isDraw ? 'Draw!' : (p1Wins ? p1Name : p2Name);
    final winnerEmoji = isDraw ? '🤝' : (p1Wins ? '🔵' : '🔴');
    final winnerColor = isDraw
        ? AppColors.warning
        : (p1Wins ? AppColors.info : AppColors.error);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),

            Text(
              winnerEmoji,
              style: const TextStyle(fontSize: 72),
            ).animate().scale(
              begin: const Offset(0, 0),
              end: const Offset(1, 1),
              duration: 600.ms,
              curve: Curves.elasticOut,
            ),
            const SizedBox(height: 16),
            Text(
              isDraw ? 'It\'s a Draw!' : '$winnerName Wins!',
              style: AppTypography.displayMedium.copyWith(
                fontWeight: FontWeight.w900,
                color: winnerColor,
              ),
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 32),

            // Score cards
            Row(
              children: [
                _PlayerResultCard(
                  name: p1Name,
                  emoji: '🔵',
                  score: _player1Score,
                  correct: _player1Correct,
                  total: _roundsPerPlayer,
                  bestStreak: _player1BestStreak,
                  color: AppColors.info,
                  isWinner: !isDraw && p1Wins,
                ),
                const SizedBox(width: 16),
                _PlayerResultCard(
                  name: p2Name,
                  emoji: '🔴',
                  score: _player2Score,
                  correct: _player2Correct,
                  total: _roundsPerPlayer,
                  bestStreak: _player2BestStreak,
                  color: AppColors.error,
                  isWinner: !isDraw && !p1Wins,
                ),
              ],
            ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.15),

            const SizedBox(height: 40),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Home'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _rematch,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Rematch!'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ).animate(delay: 700.ms).fadeIn(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── Game Logic ───────────────────────────────────────

  void _startGame() {
    // Generate questions
    final allCards = ref.read(allFlashcardsProvider);
    List<Flashcard> pool;
    if (widget.categories.isEmpty) {
      pool = List.of(allCards);
    } else {
      pool = allCards
          .where((c) => widget.categories.contains(c.category))
          .toList();
    }

    if (pool.length < 4) {
      AppSnackBar.warning(context, message: 'Not enough flashcards to play!');
      return;
    }

    final rng = Random();
    pool.shuffle(rng);

    _questions = [];
    final totalQuestions = _roundsPerPlayer * 2;

    for (int i = 0; i < totalQuestions; i++) {
      final card = pool[i % pool.length];
      final questionType = rng.nextBool()
          ? _QuestionType.englishToFilipino
          : _QuestionType.filipinoToEnglish;

      // Generate wrong options
      final wrongCards = pool.where((c) => c.id != card.id).toList();
      wrongCards.shuffle(rng);
      final wrongOptions = wrongCards
          .take(3)
          .map(
            (c) => questionType == _QuestionType.englishToFilipino
                ? c.wordFilipino
                : c.wordEnglish,
          )
          .toList();

      final correctAnswer = questionType == _QuestionType.englishToFilipino
          ? card.wordFilipino
          : card.wordEnglish;

      final options = [...wrongOptions, correctAnswer];
      options.shuffle(rng);

      _questions.add(
        _QuizQuestion(
          card: card,
          type: questionType,
          prompt: questionType == _QuestionType.englishToFilipino
              ? card.wordEnglish
              : card.wordFilipino,
          promptLabel: questionType == _QuestionType.englishToFilipino
              ? 'What is this in Filipino?'
              : 'What is this in English?',
          subtitle: card.exampleSentence,
          options: options,
          correctIndex: options.indexOf(correctAnswer),
        ),
      );
    }

    setState(() {
      _phase = _GamePhase.turnTransition;
      _currentRound = 0;
      _currentPlayer = 1;
      _player1Score = 0;
      _player2Score = 0;
      _player1Correct = 0;
      _player2Correct = 0;
      _player1Streak = 0;
      _player2Streak = 0;
      _player1BestStreak = 0;
      _player2BestStreak = 0;
      _questionIndex = 0;
    });
  }

  void _startQuestion() {
    setState(() {
      _phase = _GamePhase.playing;
      _selectedAnswer = null;
      _answered = false;
      _timeRemaining = _timePerQuestion;
    });

    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _timeRemaining--);
      if (_timeRemaining <= 0) {
        timer.cancel();
        _handleTimeout();
      }
    });
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    _roundTimer?.cancel();

    final question = _questions[_questionIndex];
    final isCorrect = index == question.correctIndex;
    final points = _calculatePoints();

    setState(() {
      _selectedAnswer = index;
      _answered = true;

      if (isCorrect) {
        if (_currentPlayer == 1) {
          _player1Score += points;
          _player1Correct++;
          _player1Streak++;
          if (_player1Streak > _player1BestStreak) {
            _player1BestStreak = _player1Streak;
          }
        } else {
          _player2Score += points;
          _player2Correct++;
          _player2Streak++;
          if (_player2Streak > _player2BestStreak) {
            _player2BestStreak = _player2Streak;
          }
        }
      } else {
        if (_currentPlayer == 1) {
          _player1Streak = 0;
        } else {
          _player2Streak = 0;
        }
      }
    });

    // Show result briefly then advance
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _advanceToNext();
    });
  }

  void _handleTimeout() {
    setState(() {
      _answered = true;
      if (_currentPlayer == 1) {
        _player1Streak = 0;
      } else {
        _player2Streak = 0;
      }
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      _advanceToNext();
    });
  }

  int _calculatePoints() {
    // Base 100 + time bonus + streak bonus
    final timeBonus = _timeRemaining * 10;
    final streakBonus = _currentPlayer == 1
        ? _player1Streak * 20
        : _player2Streak * 20;
    return 100 + timeBonus + streakBonus;
  }

  void _advanceToNext() {
    _currentRound++;
    _questionIndex++;

    if (_questionIndex >= _questions.length) {
      // Game is over
      // Record game result for the active profile
      final profile = ref.read(profileProvider);
      if (profile != null) {
        ref
            .read(progressProvider.notifier)
            .recordGameResult(
              gameType: GameType.flashcardQuiz,
              score: _player1Score > _player2Score
                  ? _player1Correct
                  : _player2Correct,
              total: _roundsPerPlayer,
              starsEarned: 1,
              categoriesPlayed: widget.categories,
            );
      }

      setState(() => _phase = _GamePhase.gameOver);
      return;
    }

    // Alternate players
    _currentPlayer = _currentPlayer == 1 ? 2 : 1;
    setState(() => _phase = _GamePhase.turnTransition);
  }

  void _rematch() {
    setState(() {
      _phase = _GamePhase.setup;
      _currentRound = 0;
      _questionIndex = 0;
      _player1Score = 0;
      _player2Score = 0;
      _player1Correct = 0;
      _player2Correct = 0;
      _player1Streak = 0;
      _player2Streak = 0;
      _player1BestStreak = 0;
      _player2BestStreak = 0;
    });
  }
}

// ─── Supporting Widgets ─────────────────────────────────

class _PlayerSetupCard extends StatelessWidget {
  final TextEditingController controller;
  final int playerNum;
  final Color color;
  final String emoji;

  const _PlayerSetupCard({
    required this.controller,
    required this.playerNum,
    required this.color,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerResultCard extends StatelessWidget {
  final String name;
  final String emoji;
  final int score;
  final int correct;
  final int total;
  final int bestStreak;
  final Color color;
  final bool isWinner;

  const _PlayerResultCard({
    required this.name,
    required this.emoji,
    required this.score,
    required this.correct,
    required this.total,
    required this.bestStreak,
    required this.color,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isWinner
              ? color.withValues(alpha: 0.1)
              : HCColor.of(context).surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isWinner ? color : AppColors.border,
            width: isWinner ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (isWinner) const Text('👑', style: TextStyle(fontSize: 28)),
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(
              name,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$score',
              style: AppTypography.displayMedium.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              'points',
              style: AppTypography.labelSmall.copyWith(
                color: HCColor.of(context).textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 4),
            _resultRow(context, '✅', 'Correct', '$correct/$total'),
            _resultRow(
              context,
              '🎯',
              'Accuracy',
              '${total > 0 ? (correct / total * 100).toStringAsFixed(0) : 0}%',
            ),
            _resultRow(context, '🔥', 'Best Streak', '$bestStreak'),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(
    BuildContext context,
    String emoji,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$emoji $label',
            style: AppTypography.bodySmall.copyWith(
              color: HCColor.of(context).textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Models ─────────────────────────────────────────────

enum _GamePhase { setup, turnTransition, playing, roundResult, gameOver }

enum _QuestionType { englishToFilipino, filipinoToEnglish }

class _QuizQuestion {
  final Flashcard card;
  final _QuestionType type;
  final String prompt;
  final String promptLabel;
  final String? subtitle;
  final List<String> options;
  final int correctIndex;

  const _QuizQuestion({
    required this.card,
    required this.type,
    required this.prompt,
    required this.promptLabel,
    this.subtitle,
    required this.options,
    required this.correctIndex,
  });
}
