import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/models.dart';
import '../../../../l10n/app_localizations.dart';

/// A GitHub-style heatmap showing spaced repetition review activity.
///
/// Displays the last 12 weeks of daily activity, with color intensity
/// based on the number of reviews/sessions per day.
class SpacedRepetitionHeatmap extends StatelessWidget {
  final List<GameScore> recentScores;
  final Map<String, int> dailyStudyMinutes;
  final int daysToShow;

  const SpacedRepetitionHeatmap({
    super.key,
    required this.recentScores,
    required this.dailyStudyMinutes,
    this.daysToShow = 84, // 12 weeks
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activityMap = _buildActivityMap();
    final now = DateTime.now();
    final weeks = (daysToShow / 7).ceil();
    final hc = HCColor.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  color: AppColors.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.chartReviewHeatmap,
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Total active days badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${activityMap.values.where((v) => v > 0).length} active days',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Last ${daysToShow ~/ 7} weeks of learning activity',
            style: AppTypography.bodySmall.copyWith(
              color: hc.textSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // Month labels
          _buildMonthLabels(context, now, weeks),
          const SizedBox(height: 4),

          // Day labels + Heatmap grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weekday labels
              Column(
                children: [
                  const SizedBox(height: 2),
                  _dayLabel(context, 'Mon'),
                  _dayLabel(context, ''),
                  _dayLabel(context, 'Wed'),
                  _dayLabel(context, ''),
                  _dayLabel(context, 'Fri'),
                  _dayLabel(context, ''),
                  _dayLabel(context, 'Sun'),
                ],
              ),
              const SizedBox(width: 6),

              // Heatmap grid
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true, // Most recent on the right
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(weeks, (weekIndex) {
                      final weekStart = now.subtract(
                        Duration(days: (weeks - 1 - weekIndex) * 7 + (now.weekday - 1)),
                      );
                      return Column(
                        children: List.generate(7, (dayIndex) {
                          final date = weekStart.add(Duration(days: dayIndex));
                          if (date.isAfter(now)) {
                            return _cell(context, 0, null, isFuture: true);
                          }
                          final key = _dateKey(date);
                          final activity = activityMap[key] ?? 0;
                          return _cell(context, activity, date);
                        }),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.chartLess, style: AppTypography.labelSmall.copyWith(
                fontSize: 9, color: hc.textSecondary)),
              const SizedBox(width: 4),
              _legendCell(context, 0),
              _legendCell(context, 1),
              _legendCell(context, 2),
              _legendCell(context, 3),
              _legendCell(context, 4),
              const SizedBox(width: 4),
              Text(l10n.chartMore, style: AppTypography.labelSmall.copyWith(
                fontSize: 9, color: hc.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, int> _buildActivityMap() {
    final map = <String, int>{};

    // Count game sessions per day
    for (final score in recentScores) {
      final key = _dateKey(score.date);
      map[key] = (map[key] ?? 0) + 1;
    }

    // Also merge study minutes (1 session = at least 1 activity point)
    for (final entry in dailyStudyMinutes.entries) {
      if (entry.value > 0 && !map.containsKey(entry.key)) {
        map[entry.key] = 1;
      }
    }

    return map;
  }

  Widget _buildMonthLabels(BuildContext context, DateTime now, int weeks) {
    final labels = <Widget>[];
    String? lastMonth;

    for (int w = 0; w < weeks; w++) {
      final weekStart = now.subtract(
        Duration(days: (weeks - 1 - w) * 7 + (now.weekday - 1)),
      );
      final monthName = _monthName(weekStart.month);
      if (monthName != lastMonth) {
        labels.add(Padding(
          padding: EdgeInsets.only(left: w == 0 ? 26 : 0),
          child: Text(
            monthName,
            style: AppTypography.labelSmall.copyWith(
              fontSize: 9,
              color: HCColor.of(context).textSecondary,
            ),
          ),
        ));
        lastMonth = monthName;
      }
      if (labels.length > 4) break; // Don't overflow
    }

    return Row(
      children: [
        const SizedBox(width: 26),
        ...labels.map((l) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: l,
        )),
        const Spacer(),
      ],
    );
  }

  Widget _dayLabel(BuildContext context, String text) {
    return SizedBox(
      height: 16,
      child: text.isEmpty
          ? const SizedBox.shrink()
          : Text(
              text,
              style: AppTypography.labelSmall.copyWith(
                fontSize: 8,
                color: HCColor.of(context).textSecondary,
              ),
            ),
    );
  }

  Widget _cell(BuildContext context, int activity, DateTime? date, {bool isFuture = false}) {
    return Tooltip(
      message: date != null
          ? '${_formatCellDate(date)}: $activity ${activity == 1 ? "session" : "sessions"}'
          : '',
      child: Container(
        width: 14,
        height: 14,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isFuture
              ? Colors.transparent
              : _activityColor(context, activity),
          borderRadius: BorderRadius.circular(3),
          border: isFuture
              ? null
              : Border.all(
                  color: _activityBorderColor(activity),
                  width: 0.5,
                ),
        ),
      ),
    );
  }

  Widget _legendCell(BuildContext context, int level) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: _activityColor(context, level),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: _activityBorderColor(level), width: 0.5),
      ),
    );
  }

  Color _activityColor(BuildContext context, int level) {
    const baseColor = AppColors.success;
    if (level == 0) return HCColor.of(context).surfaceLight;
    if (level == 1) return baseColor.withValues(alpha: 0.25);
    if (level == 2) return baseColor.withValues(alpha: 0.5);
    if (level == 3) return baseColor.withValues(alpha: 0.75);
    return baseColor;
  }

  Color _activityBorderColor(int level) {
    if (level == 0) return AppColors.border;
    return AppColors.success.withValues(alpha: 0.3);
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _monthName(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month - 1];
  }

  static String _formatCellDate(DateTime date) {
    return '${_monthName(date.month)} ${date.day}';
  }
}
