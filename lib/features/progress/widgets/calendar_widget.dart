import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// A visual calendar widget showing daily study activity.
class StudyCalendarWidget extends StatefulWidget {
  final Set<String> completedDates; // 'yyyy-MM-dd' format
  final int currentStreak;
  final DateTime? initialMonth;

  const StudyCalendarWidget({
    super.key,
    required this.completedDates,
    required this.currentStreak,
    this.initialMonth,
  });

  @override
  State<StudyCalendarWidget> createState() => _StudyCalendarWidgetState();
}

class _StudyCalendarWidgetState extends State<StudyCalendarWidget> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.initialMonth ?? DateTime.now();
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month);
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final now = DateTime.now();
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month).weekday;
    // Monday = 1, so offset is firstWeekday - 1 for Mon-start grid
    final offset = firstWeekday - 1;

    return Column(
      children: [
        // ─── Month Navigation ──────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => setState(() {
                _currentMonth = DateTime(
                    _currentMonth.year, _currentMonth.month - 1);
              }),
              icon: Icon(Icons.chevron_left_rounded, color: hc.textPrimary),
            ),
            Text(
              _monthLabel(_currentMonth),
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
            IconButton(
              onPressed: _currentMonth.year == now.year &&
                      _currentMonth.month == now.month
                  ? null
                  : () => setState(() {
                        _currentMonth = DateTime(
                            _currentMonth.year, _currentMonth.month + 1);
                      }),
              icon: Icon(Icons.chevron_right_rounded,
                  color: _currentMonth.year == now.year &&
                          _currentMonth.month == now.month
                      ? hc.textHint
                      : hc.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ─── Weekday Headers ────────────────────
        Row(
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: AppTypography.labelSmall.copyWith(
                          color: hc.textHint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),

        // ─── Day Grid ───────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: offset + daysInMonth,
          itemBuilder: (context, index) {
            if (index < offset) return const SizedBox.shrink();
            final day = index - offset + 1;
            final date = DateTime(
                _currentMonth.year, _currentMonth.month, day);
            final dateKey =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final isCompleted = widget.completedDates.contains(dateKey);
            final isToday = date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
            final isFuture = date.isAfter(now);

            return _DayCell(
              day: day,
              isCompleted: isCompleted,
              isToday: isToday,
              isFuture: isFuture,
            );
          },
        ),
      ],
    );
  }

  String _monthLabel(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isCompleted;
  final bool isToday;
  final bool isFuture;

  const _DayCell({
    required this.day,
    required this.isCompleted,
    required this.isToday,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    Color bgColor;
    Color textColor;
    if (isCompleted) {
      bgColor = AppColors.success.withValues(alpha: 0.8);
      textColor = Colors.white;
    } else if (isToday) {
      bgColor = hc.primary.withValues(alpha: 0.15);
      textColor = hc.primary;
    } else if (isFuture) {
      bgColor = Colors.transparent;
      textColor = hc.textHint;
    } else {
      bgColor = hc.surfaceLight;
      textColor = hc.textSecondary;
    }

    return Semantics(
      label: 'Day $day${isCompleted ? ", studied" : ""}${isToday ? ", today" : ""}',
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: hc.primary, width: 2)
              : null,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCompleted)
                const Text('🔥', style: TextStyle(fontSize: 10)),
              Text(
                '$day',
                style: AppTypography.labelSmall.copyWith(
                  color: textColor,
                  fontWeight:
                      isToday || isCompleted ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Milestone badges shown below the calendar.
///
/// Ticks are scored against the learner's **best** streak, not the run they
/// happen to be on. These are records of something reached; a missed day
/// resets the flame above them, and used to un-tick every badge here with it.
class StreakMilestoneBadges extends StatelessWidget {
  final int bestStreak;

  const StreakMilestoneBadges({super.key, required this.bestStreak});

  static const _milestones = [
    (days: 3, emoji: '🌟', label: '3 Days'),
    (days: 7, emoji: '⭐', label: '1 Week'),
    (days: 14, emoji: '🏆', label: '2 Weeks'),
    (days: 30, emoji: '👑', label: '1 Month'),
    (days: 60, emoji: '💎', label: '2 Months'),
    (days: 100, emoji: '🎯', label: '100 Days'),
  ];

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _milestones.map((m) {
        final achieved = bestStreak >= m.days;
        return Semantics(
          label: '${m.label} streak milestone${achieved ? ", achieved" : ", not yet achieved"}',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: achieved
                  ? AppColors.success.withValues(alpha: 0.12)
                  : hc.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: achieved
                    ? AppColors.success.withValues(alpha: 0.4)
                    : hc.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  m.emoji,
                  style: TextStyle(
                    fontSize: 18,
                    color: achieved ? null : hc.textHint,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  m.label,
                  style: AppTypography.labelSmall.copyWith(
                    color: achieved ? AppColors.success : hc.textHint,
                    fontWeight: achieved ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (achieved) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: AppColors.success),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
