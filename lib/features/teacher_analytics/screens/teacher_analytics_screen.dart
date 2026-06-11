import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../notifications/services/alert_service.dart';
import '../models/teacher_analytics_models.dart';

class TeacherAnalyticsScreen extends ConsumerWidget {
  const TeacherAnalyticsScreen({super.key});

  bool _hasUnreadAlerts() {
    try {
      return AlertService.getAlerts().where((a) => !a.isRead).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  ClassAnalytics _analyticsFrom(
      List<(dynamic, dynamic)> pairs) {
    final studentData = pairs
        .where((d) => d.$1.role == UserRole.student && !d.$1.isGuestPlayer)
        .toList();
    final studentAnalytics = studentData
        .map((d) => StudentAnalytics.from(d.$1, d.$2))
        .toList();
    return ClassAnalytics.fromStudents(studentAnalytics);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProfile = ref.watch(profileProvider);
    final isEducator = activeProfile != null &&
        activeProfile.role != UserRole.student;

    // Educators read from Firestore (cross-device); everyone else reads
    // local Hive.
    final rosterAsync = isEducator
        ? ref.watch(educatorRosterProvider(activeProfile.id))
        : AsyncData(ref.watch(allProfilesWithProgressProvider));

    final analytics = rosterAsync.maybeWhen(
      data: (pairs) => _analyticsFrom(pairs),
      orElse: () => ClassAnalytics.fromStudents(const []),
    );
    final loading = rosterAsync.isLoading;
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final padding = context.pagePadding;
    final hc = HCColor.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Analytics ng Klase' : 'Class Analytics'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (analytics.totalStudents >= 2)
            IconButton(
              icon: const Icon(Icons.compare_arrows_rounded),
              tooltip: isFilipino ? 'Ihambing' : 'Compare Students',
              onPressed: () => context.push('/student-comparison'),
            ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_rounded),
                tooltip: isFilipino ? 'Alerto' : 'Alerts',
                onPressed: () => context.push('/alert-settings'),
              ),
              if (_hasUnreadAlerts())
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : analytics.totalStudents == 0
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📊', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text(
                      isFilipino
                          ? 'Walang mga estudyante'
                          : 'No students yet',
                      style: AppTypography.titleMedium
                          .copyWith(color: hc.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isFilipino
                          ? 'Magbahagi ng class code para sumali ang mga estudyante. Lalabas dito ang analytics kapag aktibo na sila.'
                          : 'Share your class code so students can join. Analytics will appear here once they\'re active.',
                      style: AppTypography.bodyMedium
                          .copyWith(color: hc.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => context.push('/classroom-manage'),
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: Text(isFilipino
                          ? 'Ibahagi ang Class Code'
                          : 'Share Class Code'),
                    ),
                  ],
                ),
              )
            : CustomScrollView(
                slivers: [
                  // ─── Overview Cards ──────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padding, 8, padding, 0),
                      child: _OverviewCards(
                        analytics: analytics,
                        isFilipino: isFilipino,
                      ).animate().fadeIn(duration: 400.ms),
                    ),
                  ),

                  // ─── Students Needing Help Alert ──────────
                  if (analytics.studentsNeedingHelp.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            EdgeInsets.fromLTRB(padding, 16, padding, 0),
                        child: _NeedHelpAlert(
                          students: analytics.studentsNeedingHelp,
                          isFilipino: isFilipino,
                        )
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 100.ms),
                      ),
                    ),

                  // ─── Category Progress Chart ──────────
                  if (analytics.categoryAverages.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            EdgeInsets.fromLTRB(padding, 16, padding, 0),
                        child: _CategoryChart(
                          averages: analytics.categoryAverages,
                          strongest: analytics.classStrongestCategory,
                          weakest: analytics.classWeakestCategory,
                          isFilipino: isFilipino,
                        )
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 150.ms),
                      ),
                    ),

                  // ─── Student Performance Table ──────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          EdgeInsets.fromLTRB(padding, 20, padding, 8),
                      child: Text(
                        isFilipino
                            ? 'Performance ng mga Estudyante'
                            : 'Student Performance',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: hc.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding:
                        EdgeInsets.symmetric(horizontal: padding),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final student =
                              analytics.students[index];
                          return _StudentRow(
                            student: student,
                            rank: index + 1,
                            isFilipino: isFilipino,
                            index: index,
                          );
                        },
                        childCount: analytics.students.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 32),
                  ),
                ],
              ),
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final ClassAnalytics analytics;
  final bool isFilipino;

  const _OverviewCards({required this.analytics, required this.isFilipino});

  @override
  Widget build(BuildContext context) {
    final accuracy = analytics.classAverageAccuracy;
    // Professional dashboard kit instead of playful gradient cards: a
    // structured, overflow-safe grid that reads as class analytics.
    return ProStatGrid(
      tiles: [
        ProStatTile(
          icon: Icons.people_rounded,
          label: isFilipino ? 'Estudyante' : 'Students',
          value: '${analytics.totalStudents}',
          caption: '${analytics.activeStudents} ${isFilipino ? 'aktibo' : 'active'}',
          accent: AppColors.primary,
        ),
        ProStatTile(
          icon: Icons.trending_up_rounded,
          label: 'Avg Accuracy',
          value: '${(accuracy * 100).round()}%',
          trend: accuracy >= 0.7 ? ProTrend.up : ProTrend.flat,
          accent: accuracy >= 0.7 ? AppColors.success : AppColors.warning,
        ),
        ProStatTile(
          icon: Icons.auto_stories_rounded,
          label: isFilipino ? 'Salitang Natutunan' : 'Words Learned',
          value: '${analytics.classWordsLearned}',
          accent: AppColors.secondary,
        ),
        ProStatTile(
          icon: Icons.videogame_asset_rounded,
          label: isFilipino ? 'Laro' : 'Games',
          value: '${analytics.classGamesPlayed}',
          accent: AppColors.accent,
        ),
      ],
    );
  }
}

class _NeedHelpAlert extends StatelessWidget {
  final List<StudentAnalytics> students;
  final bool isFilipino;

  const _NeedHelpAlert({required this.students, required this.isFilipino});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFilipino
                      ? 'Nangangailangan ng Tulong'
                      : 'Students Needing Help',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                Text(
                  students.map((s) => s.name).join(', '),
                  style: AppTypography.bodySmall
                      .copyWith(color: hc.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isFilipino
                      ? 'Accuracy na mas mababa sa 50%'
                      : 'Accuracy below 50%',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChart extends StatelessWidget {
  final Map<String, double> averages;
  final String? strongest;
  final String? weakest;
  final bool isFilipino;

  const _CategoryChart({
    required this.averages,
    this.strongest,
    this.weakest,
    required this.isFilipino,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final sortedEntries = averages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFilipino ? 'Mga Kategorya' : 'Category Mastery',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          if (strongest != null || weakest != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (strongest != null) ...[
                  const Icon(Icons.arrow_upward_rounded,
                      size: 14, color: AppColors.success),
                  Text(
                    ' $strongest',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.success, fontSize: 11),
                  ),
                  const SizedBox(width: 12),
                ],
                if (weakest != null) ...[
                  const Icon(Icons.arrow_downward_rounded,
                      size: 14, color: AppColors.error),
                  Text(
                    ' $weakest',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.error, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          ...sortedEntries.map((entry) {
            final isStrong = entry.key == strongest;
            final isWeak = entry.key == weakest;
            final color = isStrong
                ? AppColors.success
                : isWeak
                    ? AppColors.error
                    : AppColors.primary;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key,
                          style: AppTypography.bodySmall
                              .copyWith(color: hc.textPrimary)),
                      Text(
                        '${(entry.value * 100).round()}%',
                        style: AppTypography.labelSmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearPercentIndicator(
                    padding: EdgeInsets.zero,
                    lineHeight: 6,
                    percent: entry.value.clamp(0.0, 1.0),
                    backgroundColor: color.withValues(alpha: 0.15),
                    progressColor: color,
                    barRadius: const Radius.circular(3),
                    animation: true,
                    animationDuration: 600,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final StudentAnalytics student;
  final int rank;
  final bool isFilipino;
  final int index;

  const _StudentRow({
    required this.student,
    required this.rank,
    required this.isFilipino,
    this.index = 0,
  });

  static const _medalEmojis = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final accuracyPct = (student.averageAccuracy * 100).round();
    final accuracyColor = student.averageAccuracy >= 0.7
        ? AppColors.success
        : student.averageAccuracy >= 0.5
            ? AppColors.warning
            : AppColors.error;
    final isTopThree = rank <= 3;

    return GestureDetector(
      onTap: () => context.push(
        '/progress-timeline/${student.profileId}?name=${Uri.encodeComponent(student.name)}',
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTopThree
                ? AppColors.primary.withValues(alpha: 0.25)
                : hc.border,
          ),
          boxShadow: isTopThree
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Rank — medal for top 3, number for rest
            SizedBox(
              width: 30,
              child: isTopThree
                  ? Text(
                      _medalEmojis[rank - 1],
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    )
                  : Text(
                      '#$rank',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(width: 10),
            // Avatar with mini accuracy ring
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      value: student.averageAccuracy,
                      strokeWidth: 2.5,
                      backgroundColor: hc.border.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(accuracyColor),
                    ),
                  ),
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      student.name.isNotEmpty
                          ? student.name[0].toUpperCase()
                          : '?',
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.auto_stories_rounded,
                        text: '${student.wordsLearned}',
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      _StatChip(
                        icon: Icons.star_rounded,
                        text: '${student.totalStars}',
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      _StatChip(
                        icon: Icons.local_fire_department_rounded,
                        text: '${student.streakDays}',
                        color: AppColors.error,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Accuracy badge — enhanced
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accuracyColor.withValues(alpha: 0.15),
                    accuracyColor.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accuracyColor.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                '$accuracyPct%',
                style: AppTypography.labelSmall.copyWith(
                  color: accuracyColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: hc.textHint),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (80 + index * 60).ms)
        .slideX(
          begin: 0.03,
          end: 0,
          delay: (80 + index * 60).ms,
          duration: 300.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            text,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
