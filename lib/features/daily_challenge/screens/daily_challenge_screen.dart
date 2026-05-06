import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/services/celebration_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/constants/flashcard_emojis.dart';
import '../../../data/local/daily_challenge.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/experiment_provider.dart';
import '../../experiment/models/experiment_models.dart';
import '../../../widgets/accessible_celebration_overlay.dart';

/// Full-screen Daily Challenge with calendar, streak tracker, and quiz.
class DailyChallengeScreen extends ConsumerStatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  ConsumerState<DailyChallengeScreen> createState() =>
      _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends ConsumerState<DailyChallengeScreen> {
  late Flashcard _todaysWord;
  late List<String> _choices;
  int? _selectedIndex;
  bool _answered = false;
  bool _isCorrect = false;
  bool _alreadyCompleted = false;
  int _streak = 0;

  // Calendar state
  late DateTime _calendarMonth;
  late Set<String> _completedDates;

  @override
  void initState() {
    super.initState();
    _todaysWord = DailyChallenge.todaysWord();
    _choices = DailyChallenge.generateChoices(_todaysWord);
    _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _completedDates = {};
    _loadData();
  }

  void _loadData() {
    final profile = ref.read(profileProvider);
    if (profile != null) {
      _alreadyCompleted = DailyChallenge.hasCompletedToday(profile.id);
      _streak = DailyChallenge.getStreak(profile.id);
      _completedDates = HiveService.getDailyChallengeHistory(profile.id);
    }
  }

  void _selectChoice(int index) async {
    if (_answered || _alreadyCompleted) return;
    final correct = _choices[index] == _todaysWord.wordFilipino;
    final haptic = ref.read(hapticServiceProvider);

    setState(() {
      _selectedIndex = index;
      _answered = true;
      _isCorrect = correct;
    });

    if (correct) {
      AccessibleCelebrationOverlay.show(
        context: context, ref: ref, type: CelebrationType.correctAnswer,
      );
    } else {
      haptic.error();
    }

    final profile = ref.read(profileProvider);
    if (profile != null) {
      await DailyChallenge.markCompleted(profile.id, correct);
      if (!mounted) return;
      if (correct) {
        final starsEnabled = ref.read(
          gamificationFeatureProvider(GamificationFeature.stars),
        );
        if (starsEnabled) {
          ref.read(progressProvider.notifier).addStars(2);
        }
      }
      setState(() {
        _alreadyCompleted = true;
        _streak = DailyChallenge.getStreak(profile.id);
        _completedDates = HiveService.getDailyChallengeHistory(profile.id);
      });
    }
  }

  Future<void> _speakWord() async {
    final tts = ref.read(ttsServiceProvider);
    await tts.speakEnglish(_todaysWord.wordEnglish);
  }

  Future<void> _speakFilipino() async {
    final tts = ref.read(ttsServiceProvider);
    await tts.speakFilipino(_todaysWord.wordFilipino);
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final padding = context.pagePadding;

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        title: Text(
          '🏆 Daily Challenge',
          style: AppTypography.titleLarge.copyWith(color: hc.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
        child: Column(
          children: [
            // ─── Streak Banner ─────────────────────
            _StreakBanner(streak: _streak)
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: -0.1, end: 0),

            const SizedBox(height: 20),

            // ─── Today's Word Card ─────────────────
            _TodaysWordCard(
              word: _todaysWord,
              choices: _choices,
              selectedIndex: _selectedIndex,
              answered: _answered,
              isCorrect: _isCorrect,
              alreadyCompleted: _alreadyCompleted,
              onSelectChoice: _selectChoice,
              onSpeakEnglish: _speakWord,
              onSpeakFilipino: _speakFilipino,
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 100.ms)
                .slideY(begin: 0.05, end: 0),

            const SizedBox(height: 24),

            // ─── Calendar View ─────────────────────
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
                // Don't allow going past current month
                if (!nextMonth.isAfter(DateTime.now())) {
                  setState(() => _calendarMonth = nextMonth);
                }
              },
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 200.ms)
                .slideY(begin: 0.05, end: 0),

            const SizedBox(height: 24),

            // ─── Stats Row ─────────────────────────
            _StatsRow(
              streak: _streak,
              totalCompleted: _completedDates.length,
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 300.ms),

            const SizedBox(height: 32),
          ],
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
          colors: [
            Color(0xFFFF6B35),
            Color(0xFFFF8E53),
            Color(0xFFFFB74D),
          ],
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
                  'Complete the daily quiz to extend your streak',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          // Big streak number
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

// ─── Today's Word Card with Quiz ────────────────────────

class _TodaysWordCard extends StatelessWidget {
  final Flashcard word;
  final List<String> choices;
  final int? selectedIndex;
  final bool answered;
  final bool isCorrect;
  final bool alreadyCompleted;
  final ValueChanged<int> onSelectChoice;
  final VoidCallback onSpeakEnglish;
  final VoidCallback onSpeakFilipino;

  const _TodaysWordCard({
    required this.word,
    required this.choices,
    required this.selectedIndex,
    required this.answered,
    required this.isCorrect,
    required this.alreadyCompleted,
    required this.onSelectChoice,
    required this.onSpeakEnglish,
    required this.onSpeakFilipino,
  });

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "✨ Today's Word",
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formattedDate(),
                style: AppTypography.labelSmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Word display
          Row(
            children: [
              Text(
                FlashcardEmojis.forId(word.id),
                style: const TextStyle(fontSize: 52),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            word.wordEnglish,
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
                            onTap: onSpeakEnglish,
                            child: Icon(
                              Icons.volume_up_rounded,
                              size: 24,
                              color: hc.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (word.exampleSentence != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        word.exampleSentence!,
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

          // Quiz section
          if (alreadyCompleted && !answered) ...[
            _buildCompletedBanner(context),
          ] else ...[
            Text(
              'What is this in Filipino?',
              style: AppTypography.titleSmall.copyWith(
                color: hc.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(choices.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ChoiceButton(
                  text: choices[i],
                  index: i,
                  isSelected: i == selectedIndex,
                  isCorrectAnswer: choices[i] == word.wordFilipino,
                  answered: answered,
                  onTap: () => onSelectChoice(i),
                ),
              );
            }),
            // Result
            if (answered) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCorrect ? AppColors.success : AppColors.error,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCorrect
                          ? Icons.celebration_rounded
                          : Icons.lightbulb_rounded,
                      color: isCorrect ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCorrect
                                ? 'Correct! +2 bonus stars ⭐'
                                : 'Not quite!',
                            style: AppTypography.titleSmall.copyWith(
                              color: isCorrect
                                  ? AppColors.success
                                  : AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!isCorrect) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'The answer is: ${word.wordFilipino}',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: hc.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: onSpeakFilipino,
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
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedBanner(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's challenge completed! ✨",
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Come back tomorrow for a new word',
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[now.month]} ${now.day}, ${now.year}';
  }
}

// ─── Choice Button ──────────────────────────────────────

class _ChoiceButton extends StatelessWidget {
  final String text;
  final int index;
  final bool isSelected;
  final bool isCorrectAnswer;
  final bool answered;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.text,
    required this.index,
    required this.isSelected,
    required this.isCorrectAnswer,
    required this.answered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    Color bgColor;
    Color borderColor;
    IconData? trailingIcon;
    Color? iconColor;

    if (!answered) {
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

    return Semantics(
      button: true,
      label: text,
      child: GestureDetector(
        onTap: answered ? null : onTap,
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
              // Letter indicator
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
                    String.fromCharCode(65 + index), // A, B, C
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
                  ),
                ),
              ),
              if (trailingIcon != null)
                Icon(trailingIcon, color: iconColor, size: 24),
            ],
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
    // Monday = 1, Sunday = 7 in Dart
    final startWeekday = firstDay.weekday; // 1-7 (Mon-Sun)

    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
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
          // Month navigation
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
                  icon: Icon(Icons.chevron_right_rounded, color: hc.textPrimary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Weekday headers
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

          // Day grid
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
                  final isToday = month.year == now.year &&
                      month.month == now.month &&
                      dayIndex == now.day;
                  final isFuture = DateTime(month.year, month.month, dayIndex)
                      .isAfter(now);

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
                                  color: AppColors.success.withValues(alpha: 0.15),
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

    // Determine milestone badges
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
        // Stats cards
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

        // Badges section
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
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
            style: AppTypography.labelSmall.copyWith(
              color: hc.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
