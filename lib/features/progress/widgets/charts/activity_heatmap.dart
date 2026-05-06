import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/services/session_tracker.dart';

/// GitHub-style activity heat-map grid (7 rows × N columns) showing
/// daily study activity over the last 8 weeks (56 days).
class ActivityHeatmap extends StatelessWidget {
  final String profileId;

  const ActivityHeatmap({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    const totalDays = 56; // 8 weeks
    final dailyMinutes =
        SessionTracker.dailyStudyMinutes(profileId, days: totalDays);

    // Build a list of (date, minutes) – oldest first
    final now = DateTime.now();
    final cells = List.generate(totalDays, (i) {
      final date = now.subtract(Duration(days: totalDays - 1 - i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return (date, dailyMinutes[key] ?? 0);
    });

    final maxMinutes =
        cells.fold<int>(1, (a, b) => b.$2 > a ? b.$2 : a);

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
          Text(
            'Activity Map 📅',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Daily study activity — last 8 weeks',
            style: AppTypography.bodySmall.copyWith(
              color: hc.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          // Day labels + grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day-of-week labels
              Column(
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((l) => SizedBox(
                          height: 14,
                          child: Text(
                            l,
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 8,
                              color: hc.textSecondary,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(width: 4),
              // Grid
              Expanded(
                child: _buildGrid(cells, maxMinutes),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Less ',
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 9,
                  color: hc.textSecondary,
                ),
              ),
              ...[0.0, 0.25, 0.5, 0.75, 1.0].map((v) => Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: _cellColor(v),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )),
              Text(
                ' More',
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 9,
                  color: hc.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<(DateTime, int)> cells, int maxMinutes) {
    // Arrange into columns (weeks). Each column has 7 rows (Mon-Sun).
    // Pad the first column so that the last cell falls on today's weekday.
    final numCols = (cells.length / 7).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = (constraints.maxWidth / numCols).clamp(8.0, 14.0);

        return Wrap(
          direction: Axis.vertical,
          spacing: 2,
          runSpacing: 2,
          children: cells.map((entry) {
            final fraction =
                maxMinutes > 0 ? (entry.$2 / maxMinutes).clamp(0.0, 1.0) : 0.0;
            return Tooltip(
              message:
                  '${entry.$1.month}/${entry.$1.day}: ${entry.$2} min',
              child: Container(
                width: cellSize,
                height: cellSize,
                decoration: BoxDecoration(
                  color: _cellColor(fraction),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Color _cellColor(double fraction) {
    if (fraction <= 0) return AppColors.border.withValues(alpha: 0.3);
    if (fraction < 0.25) return AppColors.success.withValues(alpha: 0.3);
    if (fraction < 0.5) return AppColors.success.withValues(alpha: 0.55);
    if (fraction < 0.75) return AppColors.success.withValues(alpha: 0.8);
    return AppColors.success;
  }
}
