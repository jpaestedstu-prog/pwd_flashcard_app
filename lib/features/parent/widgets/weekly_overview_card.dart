import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../providers/parent_provider.dart';

/// Shows a weekly summary card comparing study times across all children.
class WeeklyOverviewCard extends StatelessWidget {
  final List<ChildSummary> children;
  final HCColor hc;

  const WeeklyOverviewCard({
    super.key,
    required this.children,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    // Day labels
    final now = DateTime.now();
    final dayLabels = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      return _shortDay(date.weekday);
    });

    // Collect total minutes per day across all children
    final dailyTotals = <String, int>{};
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: 6 - i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      int total = 0;
      for (final child in children) {
        total += child.dailyStudyMinutes[key] ?? 0;
      }
      dailyTotals[key] = total;
    }

    final maxMinutes =
        dailyTotals.values.fold<int>(1, (a, b) => a > b ? a : b);

    final totalThisWeek =
        children.fold<int>(0, (sum, c) => sum + c.studyMinutesThisWeek);
    final avgPerChild =
        children.isEmpty ? 0 : (totalThisWeek / children.length).round();

    // Professional panel chrome (flat hairline, theme-aware) to match the
    // other parent-dashboard panels; the bespoke bar chart stays as-is.
    return ProPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary header — enhanced with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bar_chart_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              _WeekStatChip(
                label: 'Total',
                value: '${totalThisWeek}m',
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              _WeekStatChip(
                label: 'Avg/child',
                value: '${avgPerChild}m',
                color: AppColors.secondary,
              ),
              const Spacer(),
              Text(
                'Study minutes',
                style: AppTypography.labelSmall
                    .copyWith(color: hc.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Mini bar chart
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final date = now.subtract(Duration(days: 6 - i));
                final key =
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                final minutes = dailyTotals[key] ?? 0;
                final ratio = minutes / maxMinutes;
                final isToday = i == 6;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (minutes > 0)
                          Text(
                            '${minutes}m',
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isToday
                                  ? AppColors.primary
                                  : hc.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          height: (ratio * 60).clamp(4.0, 60.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isToday
                                  ? [
                                      AppColors.primary,
                                      AppColors.primary.withValues(alpha: 0.7),
                                    ]
                                  : [
                                      AppColors.primary
                                          .withValues(alpha: 0.4),
                                      AppColors.primary
                                          .withValues(alpha: 0.2),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isToday
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                        )
                            .animate()
                            .scaleY(
                              begin: 0,
                              end: 1,
                              alignment: Alignment.bottomCenter,
                              duration: 400.ms,
                              delay: (200 + i * 60).ms,
                              curve: Curves.easeOutCubic,
                            ),
                        const SizedBox(height: 6),
                        Text(
                          dayLabels[i],
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight:
                                isToday ? FontWeight.w800 : FontWeight.w500,
                            color:
                                isToday ? AppColors.primary : hc.textSecondary,
                          ),
                        ),
                        if (isToday)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 14),

          // Per-child breakdown
          if (children.length > 1) ...[
            Divider(color: hc.border.withValues(alpha: 0.4), height: 1),
            const SizedBox(height: 12),
            ...children.asMap().entries.map((entry) {
              final idx = entry.key;
              final child = entry.value;
              return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(child.avatarEmoji,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          child.name,
                          style: AppTypography.labelMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${child.studyMinutesThisWeek}m',
                          style: AppTypography.labelMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: totalThisWeek > 0
                                ? child.studyMinutesThisWeek / totalThisWeek
                                : 0,
                            backgroundColor: hc.border.withValues(alpha: 0.3),
                            valueColor: AlwaysStoppedAnimation(
                                AppColors.primary.withValues(alpha: 0.6)),
                            minHeight: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 250.ms, delay: (400 + idx * 60).ms)
                    .slideX(begin: 0.02, end: 0);
            }),
          ],
        ],
      ),
    );
  }

  String _shortDay(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1) % 7];
  }
}

class _WeekStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _WeekStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: HCColor.of(context).textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
