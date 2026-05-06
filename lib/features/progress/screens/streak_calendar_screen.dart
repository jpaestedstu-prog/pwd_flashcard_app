import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/enhanced_streak_display.dart';
import '../widgets/calendar_widget.dart';

class StreakCalendarScreen extends ConsumerWidget {
  const StreakCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final progress = ref.watch(progressProvider);
    final hc = HCColor.of(context);
    final profileId = profile?.id ?? '';

    final completedDates = HiveService.getDailyChallengeHistory(profileId);
    final streak = progress.streakDays;

    // Also include dates from session logs as study activity
    final sessionDates = <String>{};
    final sessions = HiveService.getSessionLogs(profileId);
    for (final s in sessions) {
      final date = s['date'] as String?;
      if (date != null && date.length >= 10) {
        sessionDates.add(date.substring(0, 10));
      }
    }
    // Also include game score dates
    for (final score in progress.recentScores) {
      final d = score.date;
      sessionDates.add(
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      );
    }

    final allActivityDates = {...completedDates, ...sessionDates};

    // Calculate longest streak from activity dates
    final longestStreak = _calculateLongestStreak(allActivityDates);
    final thisMonthActive = allActivityDates.where((d) {
      final now = DateTime.now();
      return d.startsWith(
          '${now.year}-${now.month.toString().padLeft(2, '0')}');
    }).length;

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/progress');
            }
          },
        ),
        title: Text(
          'Streak Calendar',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Current Streak Hero ──────────────
            EnhancedStreakHero(
              streakDays: streak,
              longestStreak: longestStreak,
            ).animate().fadeIn(duration: 500.ms).scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1, 1),
                ),

            const SizedBox(height: 20),

            // ─── Stats Row ────────────────────────
            Row(
              children: [
                _MiniStat(
                  label: 'Best Streak',
                  value: '$longestStreak days',
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 12),
                _MiniStat(
                  label: 'This Month',
                  value: '$thisMonthActive days',
                  icon: Icons.calendar_month_rounded,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 12),
                _MiniStat(
                  label: 'Total Active',
                  value: '${allActivityDates.length}',
                  icon: Icons.bar_chart_rounded,
                  color: AppColors.success,
                ),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

            const SizedBox(height: 28),

            // ─── Calendar ─────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hc.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: StudyCalendarWidget(
                completedDates: allActivityDates,
                currentStreak: streak,
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

            const SizedBox(height: 28),

            // ─── Milestones ───────────────────────
            Text(
              'Streak Milestones',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            StreakMilestoneBadges(currentStreak: streak)
                .animate()
                .fadeIn(duration: 400.ms, delay: 400.ms),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  int _calculateLongestStreak(Set<String> dates) {
    if (dates.isEmpty) return 0;
    final sorted = dates.toList()..sort();
    int longest = 1;
    int current = 1;
    for (int i = 1; i < sorted.length; i++) {
      final prev = DateTime.tryParse(sorted[i - 1]);
      final curr = DateTime.tryParse(sorted[i]);
      if (prev != null &&
          curr != null &&
          curr.difference(prev).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: hc.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
