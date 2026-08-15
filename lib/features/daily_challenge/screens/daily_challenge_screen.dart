import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/services/celebration_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../widgets/flashcard_image.dart';
import '../../../data/local/daily_challenge.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/experiment_provider.dart';
import '../../experiment/models/experiment_models.dart';
import '../../../widgets/accessible_celebration_overlay.dart';
import '../../../widgets/app_back_button.dart';

/// Full-screen Daily Mission — a bite-sized session of 3–5 quiz items
/// (size configurable via [AppSettings.dailyMissionSize]) with calendar,
/// streak tracker, gentle error feedback, and an optional 50/50 hint.
class DailyChallengeScreen extends ConsumerStatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  ConsumerState<DailyChallengeScreen> createState() =>
      _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends ConsumerState<DailyChallengeScreen> {
  // ── Mission session ─────────────────────────────────────
  late List<Flashcard> _missionWords;
  int _currentIndex = 0;
  late List<bool?> _itemResults; // per-item: null pending / true / false
  int _correctCount = 0;
  bool _missionComplete = false; // finished all items in *this* session
  int _starsEarned = 0;

  // ── Current item ────────────────────────────────────────
  late List<String> _choices;
  int? _selectedIndex;
  bool _answered = false;
  bool _isCorrect = false;
  final Set<int> _eliminated = {}; // indices removed by a 50/50 hint

  // ── Learning Assist ─────────────────────────────────────
  bool _assistEnabled = true;
  int _hintsRemaining = 0;

  // ── Day-level state ─────────────────────────────────────
  bool _alreadyCompleted = false; // completed earlier today (prior session)
  int _streak = 0;
  late DateTime _calendarMonth;
  late Set<String> _completedDates;

  Flashcard get _word => _missionWords[_currentIndex];
  bool get _isLastItem => _currentIndex >= _missionWords.length - 1;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    final size = settings.dailyMissionSize.clamp(3, 5);
    _assistEnabled = settings.learningAssistEnabled;
    _missionWords = DailyChallenge.todaysWords(size);
    _itemResults = List<bool?>.filled(_missionWords.length, null);
    // Hint budget ≈ half the questions (min 1) when assist is on.
    _hintsRemaining = _assistEnabled ? ((_missionWords.length + 1) ~/ 2) : 0;
    _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _completedDates = {};
    _loadCurrentChoices();
    _loadData();
  }

  void _loadCurrentChoices() {
    if (_missionWords.isEmpty) {
      _choices = const [];
      return;
    }
    // Four options so a 50/50 hint can remove two and still leave a choice.
    _choices = DailyChallenge.generateChoices(_word, count: 4);
    _eliminated.clear();
  }

  void _loadData() {
    final profile = ref.read(profileProvider);
    if (profile != null) {
      _alreadyCompleted = DailyChallenge.hasCompletedToday(profile.id);
      _streak = DailyChallenge.getStreak(profile.id);
      _completedDates = HiveService.getDailyChallengeHistory(profile.id);
    }
  }

  void _selectChoice(int index) {
    if (_answered || _alreadyCompleted) return;
    if (_eliminated.contains(index)) return;
    final correct = _choices[index] == _word.wordFilipino;
    final haptic = ref.read(hapticServiceProvider);

    setState(() {
      _selectedIndex = index;
      _answered = true;
      _isCorrect = correct;
      _itemResults[_currentIndex] = correct;
      if (correct) _correctCount++;
    });

    if (correct) {
      AccessibleCelebrationOverlay.show(
        context: context,
        ref: ref,
        type: CelebrationType.correctAnswer,
      );
    } else {
      haptic.error();
    }
  }

  /// 50/50 hint — removes up to two still-visible wrong options for the
  /// current item. Limited by [_hintsRemaining]; only when Learning Assist
  /// is on and the item is unanswered.
  void _useFiftyFifty() {
    if (!_assistEnabled || _answered || _alreadyCompleted) return;
    if (_hintsRemaining <= 0) return;
    final wrong = <int>[
      for (var i = 0; i < _choices.length; i++)
        if (_choices[i] != _word.wordFilipino && !_eliminated.contains(i)) i,
    ];
    // Need at least two wrong options still showing for a meaningful 50/50.
    if (wrong.length < 2) return;
    wrong.shuffle();
    setState(() {
      _eliminated.addAll(wrong.take(2));
      _hintsRemaining--;
    });
    ref.read(hapticServiceProvider).lightTap();
  }

  void _nextItem() {
    if (!_isLastItem) {
      setState(() {
        _currentIndex++;
        _selectedIndex = null;
        _answered = false;
        _isCorrect = false;
        _loadCurrentChoices();
      });
    } else {
      _finishMission();
    }
  }

  Future<void> _finishMission() async {
    final profile = ref.read(profileProvider);
    if (profile == null) {
      setState(() => _missionComplete = true);
      return;
    }
    // "Passed" = a majority of items correct. Advances the daily-challenge
    // streak; otherwise it resets — the original single-word rule, applied
    // forgivingly across the whole mission instead of on one wrong tap.
    final passThreshold = (_missionWords.length + 1) ~/ 2;
    final passed = _correctCount >= passThreshold;
    // Idempotent: `counted` is false if today was already completed elsewhere
    // (e.g. the home-screen quick card), so we don't double-award stars.
    final counted = await DailyChallenge.markCompleted(profile.id, passed);
    if (!mounted) return;
    // Finishing the mission is a learning activity — keep the global streak
    // alive (calendar-day math is gated by experiment config inside).
    ref.read(progressProvider.notifier).recordDailyActivity();

    final starsEnabled = ref.read(
      gamificationFeatureProvider(GamificationFeature.stars),
    );
    final earned = (counted && starsEnabled)
        ? _correctCount
        : 0; // 1 star per correct
    if (earned > 0) {
      ref.read(progressProvider.notifier).addStars(earned);
    }
    ref.read(hapticServiceProvider).gameComplete();

    setState(() {
      _missionComplete = true;
      _alreadyCompleted = true;
      _starsEarned = earned;
      _streak = DailyChallenge.getStreak(profile.id);
      _completedDates = HiveService.getDailyChallengeHistory(profile.id);
    });
  }

  Future<void> _speakWord() async {
    final tts = ref.read(ttsServiceProvider);
    await tts.speakEnglish(_word.wordEnglish);
  }

  Future<void> _speakFilipino() async {
    final tts = ref.read(ttsServiceProvider);
    await tts.speakFilipino(_word.wordFilipino);
  }

  /// Short, kid-friendly explanation of the correct answer for the result
  /// panel. Prefers the card's definition, then its example, then a fallback.
  String _explanationFor(Flashcard card) {
    final def = card.definition?.trim();
    if (def != null && def.isNotEmpty) return def;
    final ex = card.exampleSentence?.trim();
    if (ex != null && ex.isNotEmpty) return ex;
    return '"${card.wordEnglish}" is "${card.wordFilipino}" in Filipino.';
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final padding = context.pagePadding;

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        title: Text(
          '🎯 Daily Mission',
          style: AppTypography.titleLarge.copyWith(color: hc.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const AppBackButton(),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
        child: Column(
          children: [
            _StreakBanner(
              streak: _streak,
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),

            const SizedBox(height: 20),

            _buildMissionCard(context)
                .animate()
                .fadeIn(duration: 400.ms, delay: 100.ms)
                .slideY(begin: 0.05, end: 0),

            const SizedBox(height: 24),

            _ChallengeCalendar(
                  month: _calendarMonth,
                  completedDates: _completedDates,
                  onPreviousMonth: () {
                    setState(() {
                      _calendarMonth = DateTime(
                        _calendarMonth.year,
                        _calendarMonth.month - 1,
                      );
                    });
                  },
                  onNextMonth: () {
                    final nextMonth = DateTime(
                      _calendarMonth.year,
                      _calendarMonth.month + 1,
                    );
                    if (!nextMonth.isAfter(DateTime.now())) {
                      setState(() => _calendarMonth = nextMonth);
                    }
                  },
                )
                .animate()
                .fadeIn(duration: 400.ms, delay: 200.ms)
                .slideY(begin: 0.05, end: 0),

            const SizedBox(height: 24),

            _StatsRow(
              streak: _streak,
              totalCompleted: _completedDates.length,
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Mission card ────────────────────────────────────────

  Widget _buildMissionCard(BuildContext context) {
    final hc = HCColor.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: hc.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: _missionWords.isEmpty
          ? _buildEmpty(context)
          : _missionComplete
          ? _buildSummary(context)
          : (_alreadyCompleted
                ? _buildCompletedBanner(context)
                : _buildActiveItem(context)),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final hc = HCColor.of(context);
    return Text(
      'No words available for today’s mission yet.',
      style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
    );
  }

  Widget _buildActiveItem(BuildContext context) {
    final hc = HCColor.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: badge + progress count
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '✨ Daily Mission',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Word ${_currentIndex + 1} of ${_missionWords.length}',
              style: AppTypography.labelSmall.copyWith(
                color: hc.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        _buildProgressDots(context),
        const SizedBox(height: 20),

        // Word display
        Row(
          children: [
            FlashcardPicture(card: _word, extent: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _word.wordEnglish,
                          style: AppTypography.displaySmall.copyWith(
                            color: hc.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: 'Listen to English pronunciation',
                        child: GestureDetector(
                          onTap: _speakWord,
                          child: Icon(
                            Icons.volume_up_rounded,
                            size: 24,
                            color: hc.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_word.exampleSentence != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _word.exampleSentence!,
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: Text(
                'What is this in Filipino?',
                style: AppTypography.titleSmall.copyWith(
                  color: hc.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // One 50/50 per question (hidden once used on this item so it
            // never becomes a dead button), and only while hints remain.
            if (_assistEnabled &&
                !_answered &&
                _hintsRemaining > 0 &&
                _eliminated.isEmpty)
              _FiftyFiftyButton(
                remaining: _hintsRemaining,
                onTap: _useFiftyFifty,
              ),
          ],
        ),
        const SizedBox(height: 12),

        ...List.generate(_choices.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChoiceButton(
              text: _choices[i],
              index: i,
              isSelected: i == _selectedIndex,
              isCorrectAnswer: _choices[i] == _word.wordFilipino,
              answered: _answered,
              eliminated: _eliminated.contains(i),
              onTap: () => _selectChoice(i),
            ),
          );
        }),

        if (_answered) ...[
          const SizedBox(height: 8),
          _buildResultPanel(context),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _nextItem,
              icon: Icon(
                _isLastItem ? Icons.flag_rounded : Icons.arrow_forward_rounded,
              ),
              label: Text(_isLastItem ? 'Finish Mission' : 'Next Word'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressDots(BuildContext context) {
    final hc = HCColor.of(context);
    return Row(
      children: List.generate(_missionWords.length, (i) {
        final result = _itemResults[i];
        final isCurrent = i == _currentIndex;
        Color color;
        IconData? icon;
        if (result == true) {
          color = AppColors.success;
          icon = Icons.check_rounded;
        } else if (result == false) {
          color = AppColors.error;
          icon = Icons.close_rounded;
        } else if (isCurrent) {
          color = hc.primary;
        } else {
          color = hc.border;
        }
        return Expanded(
          child: Container(
            height: 8,
            margin: EdgeInsets.only(
              right: i == _missionWords.length - 1 ? 0 : 6,
            ),
            decoration: BoxDecoration(
              color: result == null && !isCurrent
                  ? color.withValues(alpha: 0.4)
                  : color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: icon != null
                ? Icon(icon, size: 8, color: Colors.white)
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildResultPanel(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isCorrect
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isCorrect ? AppColors.success : AppColors.error,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isCorrect
                    ? Icons.celebration_rounded
                    : Icons.lightbulb_rounded,
                color: _isCorrect ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCorrect ? 'Correct! +1 star ⭐' : 'Not quite!',
                      style: AppTypography.titleSmall.copyWith(
                        color: _isCorrect ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!_isCorrect) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'The answer is: ${_word.wordFilipino}',
                              style: AppTypography.bodyMedium.copyWith(
                                color: hc.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _speakFilipino,
                            child: Icon(
                              Icons.volume_up_rounded,
                              size: 20,
                              color: hc.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // "Why" explanation — only when Learning Assist is on.
          if (_assistEnabled) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hc.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _explanationFor(_word),
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final hc = HCColor.of(context);
    final total = _missionWords.length;
    final allCorrect = _correctCount == total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              allCorrect
                  ? Icons.emoji_events_rounded
                  : Icons.check_circle_rounded,
              color: AppColors.success,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                allCorrect ? 'Perfect mission! 🎉' : 'Mission complete! ✨',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'You got $_correctCount of $total correct'
          '${_starsEarned > 0 ? ' and earned $_starsEarned ⭐' : ''}.',
          style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'Come back tomorrow for a new mission',
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
        ),
      ],
    );
  }

  Widget _buildCompletedBanner(BuildContext context) {
    final hc = HCColor.of(context);
    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's mission completed! ✨",
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Come back tomorrow for a new mission',
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 50/50 Hint Button ──────────────────────────────────

class _FiftyFiftyButton extends StatelessWidget {
  final int remaining;
  final VoidCallback onTap;

  const _FiftyFiftyButton({required this.remaining, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Semantics(
      button: true,
      label: 'Fifty-fifty hint, removes two wrong answers, $remaining left',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: hc.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hc.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_2_rounded, size: 16, color: hc.primary),
              const SizedBox(width: 4),
              Text(
                '50 / 50 ($remaining)',
                style: AppTypography.labelSmall.copyWith(
                  color: hc.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Streak Banner ──────────────────────────────────────

class _StreakBanner extends StatelessWidget {
  final int streak;
  const _StreakBanner({required this.streak});

  @override
  Widget build(BuildContext context) {
    String streakMessage;
    String streakEmoji;
    if (streak == 0) {
      streakMessage = 'Start your streak today!';
      streakEmoji = '🌱';
    } else if (streak < 3) {
      streakMessage = '$streak day streak — keep going!';
      streakEmoji = '🔥';
    } else if (streak < 7) {
      streakMessage = '$streak day streak — amazing!';
      streakEmoji = '🔥🔥';
    } else if (streak < 30) {
      streakMessage = '$streak day streak — on fire!';
      streakEmoji = '🔥🔥🔥';
    } else {
      streakMessage = '$streak day streak — legendary!';
      streakEmoji = '👑🔥';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8E53), Color(0xFFFFB74D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(streakEmoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streakMessage,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textOnPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete the daily mission to extend your streak',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.15),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$streak',
                style: AppTypography.headlineLarge.copyWith(
                  color: AppColors.textOnPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Choice Button ──────────────────────────────────────

class _ChoiceButton extends StatelessWidget {
  final String text;
  final int index;
  final bool isSelected;
  final bool isCorrectAnswer;
  final bool answered;
  final bool eliminated;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.text,
    required this.index,
    required this.isSelected,
    required this.isCorrectAnswer,
    required this.answered,
    required this.eliminated,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    Color bgColor;
    Color borderColor;
    IconData? trailingIcon;
    Color? iconColor;

    if (eliminated) {
      // Removed by a 50/50 hint — visibly struck out and not tappable.
      bgColor = hc.surfaceVariant.withValues(alpha: 0.4);
      borderColor = hc.border.withValues(alpha: 0.3);
      trailingIcon = Icons.block_rounded;
      iconColor = hc.textHint;
    } else if (!answered) {
      bgColor = hc.surface;
      borderColor = hc.border;
    } else if (isCorrectAnswer) {
      bgColor = AppColors.success.withValues(alpha: 0.12);
      borderColor = AppColors.success;
      trailingIcon = Icons.check_circle_rounded;
      iconColor = AppColors.success;
    } else if (isSelected && !isCorrectAnswer) {
      bgColor = AppColors.error.withValues(alpha: 0.12);
      borderColor = AppColors.error;
      trailingIcon = Icons.cancel_rounded;
      iconColor = AppColors.error;
    } else {
      bgColor = hc.surface;
      borderColor = hc.border.withValues(alpha: 0.5);
    }

    final disabled = answered || eliminated;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: eliminated ? '$text, removed by hint' : text,
      child: Opacity(
        opacity: eliminated ? 0.45 : 1,
        child: GestureDetector(
          onTap: disabled ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: answered && (isCorrectAnswer || isSelected)
                        ? borderColor.withValues(alpha: 0.2)
                        : hc.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index), // A, B, C, D
                      style: AppTypography.labelMedium.copyWith(
                        color: hc.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: AppTypography.titleMedium.copyWith(
                      color: hc.textPrimary,
                      fontWeight: FontWeight.w600,
                      decoration: eliminated
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                if (trailingIcon != null)
                  Icon(trailingIcon, color: iconColor, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Challenge Calendar ─────────────────────────────────

class _ChallengeCalendar extends StatelessWidget {
  final DateTime month;
  final Set<String> completedDates;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _ChallengeCalendar({
    required this.month,
    required this.completedDates,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final now = DateTime.now();
    final firstDay = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = firstDay.weekday; // 1-7 (Mon-Sun)

    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: hc.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                button: true,
                label: 'Previous month',
                child: IconButton(
                  onPressed: onPreviousMonth,
                  icon: Icon(Icons.chevron_left_rounded, color: hc.textPrimary),
                ),
              ),
              Text(
                '${months[month.month]} ${month.year}',
                style: AppTypography.titleMedium.copyWith(
                  color: hc.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Semantics(
                button: true,
                label: 'Next month',
                child: IconButton(
                  onPressed: onNextMonth,
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: hc.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          ...List.generate(6, (week) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: List.generate(7, (weekday) {
                  final dayIndex = week * 7 + weekday - (startWeekday - 1);
                  if (dayIndex < 1 || dayIndex > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 36));
                  }

                  final dateKey =
                      '${month.year}-${month.month.toString().padLeft(2, '0')}-${dayIndex.toString().padLeft(2, '0')}';
                  final isCompleted = completedDates.contains(dateKey);
                  final isToday =
                      month.year == now.year &&
                      month.month == now.month &&
                      dayIndex == now.day;
                  final isFuture = DateTime(
                    month.year,
                    month.month,
                    dayIndex,
                  ).isAfter(now);

                  return Expanded(
                    child: Container(
                      height: 36,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        gradient: isCompleted
                            ? LinearGradient(
                                colors: [
                                  AppColors.success.withValues(alpha: 0.25),
                                  AppColors.success.withValues(alpha: 0.12),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: !isCompleted && isToday
                            ? hc.primary.withValues(alpha: 0.1)
                            : !isCompleted
                            ? Colors.transparent
                            : null,
                        shape: BoxShape.circle,
                        border: isToday
                            ? Border.all(color: hc.primary, width: 2)
                            : null,
                        boxShadow: isCompleted
                            ? [
                                BoxShadow(
                                  color: AppColors.success.withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 6,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Text('✅', style: TextStyle(fontSize: 14))
                            : Text(
                                '$dayIndex',
                                style: AppTypography.labelSmall.copyWith(
                                  color: isFuture
                                      ? hc.textHint
                                      : hc.textPrimary,
                                  fontWeight: isToday
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Stats Row ──────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int streak;
  final int totalCompleted;

  const _StatsRow({required this.streak, required this.totalCompleted});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    final badges = <({String emoji, String title})>[];
    if (streak >= 3) badges.add((emoji: '🔥', title: '3-Day Streak'));
    if (streak >= 7) badges.add((emoji: '⚡', title: 'Weekly Warrior'));
    if (streak >= 30) badges.add((emoji: '👑', title: 'Monthly Master'));
    if (totalCompleted >= 10) badges.add((emoji: '🌟', title: '10 Days Done'));
    if (totalCompleted >= 50) badges.add((emoji: '💎', title: '50 Days Done'));
    if (totalCompleted >= 100) badges.add((emoji: '🏅', title: 'Century Club'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                emoji: '🔥',
                value: '$streak',
                label: 'Current Streak',
                color: const Color(0xFFFF6B35),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                emoji: '📅',
                value: '$totalCompleted',
                label: 'Days Completed',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                emoji: '⭐',
                value: '${totalCompleted * 2}',
                label: 'Stars Earned',
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Badges Earned',
            style: AppTypography.titleSmall.copyWith(
              color: hc.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges.map((b) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: hc.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: hc.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(b.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      b.title,
                      style: AppTypography.labelMedium.copyWith(
                        color: hc.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8),
              ],
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.headlineMedium.copyWith(
              color: hc.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
          ),
        ],
      ),
    );
  }
}
