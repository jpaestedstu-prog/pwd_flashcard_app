import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/localized_date.dart';
import '../../../../core/widgets/beside_or_below.dart';
import '../../../../core/widgets/fit_text.dart';

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

    final titleStyle = AppTypography.labelMedium.copyWith(
      fontWeight: FontWeight.w700,
    );

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
          // The count of active days under the title when the two do not
          // fit on one line: in Filipino on a phone at the largest Font
          // Size the title had a third of the card and lost its end.
          BesideOrBelow(
            fits: FitText.measurer(context, l10n.chartReviewHeatmap,
                style: titleStyle),
            drop: BesideOrBelowSlot.trailing,
            gap: 8,
            trailingGap: 8,
            spacing: 6,
            leading: Icon(Icons.calendar_month_rounded,
                color: HCColor.of(context).graphic(AppColors.accent), size: 22),
            title: FitText(l10n.chartReviewHeatmap, style: titleStyle),
            // Total active days badge
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.chartActiveDays(
                  activityMap.values.where((v) => v > 0).length,
                ),
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: HCColor.of(context).successText,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.chartReviewHeatmapSubtitle(daysToShow ~/ 7),
            style: AppTypography.bodySmall.copyWith(
              color: hc.textSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // The grid is for the eye. Its 84 days were 84 stops for a screen
          // reader, with the months, weekdays and legend read as a list of
          // words besides; the title, the count of active days and the line
          // under it say what it shows (3 Nov).
          ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  _dayLabel(context, LocalizedDate.weekdayShort(1, l10n)),
                  _dayLabel(context, ''),
                  _dayLabel(context, LocalizedDate.weekdayShort(3, l10n)),
                  _dayLabel(context, ''),
                  _dayLabel(context, LocalizedDate.weekdayShort(5, l10n)),
                  _dayLabel(context, ''),
                  _dayLabel(context, LocalizedDate.weekdayShort(7, l10n)),
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
                fontSize: 11, color: hc.textSecondary)),
              const SizedBox(width: 4),
              _legendCell(context, 0),
              _legendCell(context, 1),
              _legendCell(context, 2),
              _legendCell(context, 3),
              _legendCell(context, 4),
              const SizedBox(width: 4),
              Text(l10n.chartMore, style: AppTypography.labelSmall.copyWith(
                fontSize: 11, color: hc.textSecondary)),
            ],
          ),
              ],
            ),
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
      final monthName = LocalizedDate.monthShort(
        weekStart.month,
        AppLocalizations.of(context),
      );
      if (monthName != lastMonth) {
        labels.add(Padding(
          padding: EdgeInsets.only(left: w == 0 ? 26 : 0),
          child: Text(
            monthName,
            style: AppTypography.labelSmall.copyWith(
              fontSize: 11,
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
      // In rows that line up with the squares: drawn to fit the row at a
      // large text size rather than cut off at its bottom.
      child: text.isEmpty
          ? const SizedBox.shrink()
          : FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                text,
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 11,
                  color: HCColor.of(context).textSecondary,
                ),
              ),
            ),
    );
  }

  Widget _cell(BuildContext context, int activity, DateTime? date, {bool isFuture = false}) {
    return Tooltip(
      message: date != null
          ? AppLocalizations.of(context)!.chartCellSessions(
              LocalizedDate.monthDay(date, AppLocalizations.of(context)),
              activity,
            )
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

}
