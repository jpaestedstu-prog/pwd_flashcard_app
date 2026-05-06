import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/parent_provider.dart';
import '../../notifications/services/alert_service.dart';
import '../widgets/child_detail_sheet.dart';
import '../widgets/parent_recommendation_card.dart';
import '../widgets/weekly_overview_card.dart';

/// Parent Dashboard — overview of all children's learning progress.
///
/// Shows aggregate family stats, per-child cards with weekly trends,
/// and actionable recommendations for parents.
class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() =>
      _ParentDashboardScreenState();
}

class _ParentDashboardScreenState
    extends ConsumerState<ParentDashboardScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 60 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      ref.read(parentDashboardProvider.notifier).refresh();
    });
    // Refresh data when returning from a student dashboard (profile switch)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listen(profileProvider, (_, _) {
        ref.read(parentDashboardProvider.notifier).refresh();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool _hasUnreadAlerts() {
    try {
      return AlertService.getAlerts().where((a) => !a.isRead).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(parentDashboardProvider);
    final hc = HCColor.of(context);

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Parent Dashboard',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        actions: [
          // Alert bell with unread badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_rounded,
                    color: hc.textSecondary),
                tooltip: 'Alert Settings',
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
                      border: Border.all(color: hc.background, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: hc.textSecondary),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(parentDashboardProvider.notifier).refresh(),
          ),
        ],
      ),
      body: snapshot.children.isEmpty
          ? _EmptyState(hc: hc)
          : RefreshIndicator(
              onRefresh: () async {
                ref.read(parentDashboardProvider.notifier).refresh();
              },
              child: Builder(builder: (context) {
                final recommendations =
                    _generateRecommendations(snapshot.children);
                return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ─── Family Overview Stats ────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: _FamilyStatsCard(snapshot: snapshot, hc: hc),
                    ),
                  ),

                  // ─── Section: Your Children ───────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Icon(Icons.child_care_rounded,
                              color: hc.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Your Children',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: hc.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${snapshot.activeChildren} active / ${snapshot.totalChildren} total',
                            style: AppTypography.labelSmall.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 300.ms),
                    ),
                  ),

                  // ─── Child Cards ──────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final child = snapshot.children[index];
                          return _ChildCard(
                            child: child,
                            hc: hc,
                            onTap: () => _showChildDetail(context, child),
                            index: index,
                          );
                        },
                        childCount: snapshot.children.length,
                      ),
                    ),
                  ),

                  // ─── Weekly Overview ──────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              color: hc.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'This Week',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: hc.textPrimary,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: WeeklyOverviewCard(
                        children: snapshot.children,
                        hc: hc,
                      ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
                    ),
                  ),

                  // ─── Recommendations ──────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_rounded,
                              color: AppColors.warning, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Recommendations',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: hc.textPrimary,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 300.ms, delay: 300.ms),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ParentRecommendationCard(
                              recommendation: recommendations[index],
                              hc: hc,
                              index: index,
                            ),
                          );
                        },
                        childCount: recommendations.length,
                      ),
                    ),
                  ),

                  // ─── Last Updated ─────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Center(
                        child: Text(
                          'Last updated: ${_formatTime(snapshot.timestamp)}',
                          style: AppTypography.labelSmall.copyWith(
                            color: hc.textHint,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
              }),
            ),
    );
  }

  void _showChildDetail(BuildContext context, ChildSummary child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChildDetailSheet(
        child: child,
        onViewFullDashboard: () async {
          // Find the full UserProfile for this child. Try Firestore-backed
          // roster first (cross-device), fall back to local Hive.
          final active = ref.read(profileProvider);
          List<(UserProfile, LearningProgress)> allData = const [];
          if (active != null && active.role != UserRole.student) {
            try {
              allData =
                  await ref.read(educatorRosterProvider(active.id).future);
            } catch (_) {}
          }
          if (allData.isEmpty) {
            allData = HiveService.getAllProfilesWithProgress();
          }
          final match = allData.where((d) => d.$1.id == child.profileId);
          if (match.isNotEmpty && context.mounted) {
            ref
                .read(profileProvider.notifier)
                .viewAsStudent(match.first.$1);
            context.push('/dashboard');
          }
        },
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─── Family Stats Card ───────────────────────────────

class _FamilyStatsCard extends StatelessWidget {
  final ParentDashboardSnapshot snapshot;
  final HCColor hc;

  const _FamilyStatsCard({required this.snapshot, required this.hc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.secondary.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border:
            hc.hc ? Border.all(color: AppColors.hcPrimary, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          ...AppColors.cardShadow,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hc.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.family_restroom_rounded,
                    color: hc.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Family Overview',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    Text(
                      '${snapshot.activeChildren} of ${snapshot.totalChildren} children active',
                      style: AppTypography.labelSmall.copyWith(
                        color: hc.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _FamilyStatTile(
                icon: Icons.school_rounded,
                label: 'Words',
                value: '${snapshot.totalWordsLearned}',
                color: AppColors.primary,
              ),
              _FamilyStatTile(
                icon: Icons.star_rounded,
                label: 'Stars',
                value: '${snapshot.totalStarsEarned}',
                color: AppColors.warning,
                delay: 80,
              ),
              _FamilyStatTile(
                icon: Icons.timer_rounded,
                label: 'Minutes',
                value: '${snapshot.totalStudyMinutes}',
                color: AppColors.success,
                delay: 160,
              ),
              _FamilyStatTile(
                icon: Icons.sports_esports_rounded,
                label: 'Games',
                value: '${snapshot.totalGamesPlayed}',
                color: AppColors.info,
                delay: 240,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }
}

class _FamilyStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final int delay;

  const _FamilyStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(value,
                style: AppTypography.titleMedium
                    .copyWith(fontWeight: FontWeight.w800)),
            Text(label,
                style: AppTypography.labelSmall
                    .copyWith(color: HCColor.of(context).textSecondary, fontSize: 10)),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 350.ms, delay: (200 + delay).ms)
          .scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1, 1),
            delay: (200 + delay).ms,
            duration: 350.ms,
            curve: Curves.easeOutBack,
          ),
    );
  }
}

// ─── Child Card ──────────────────────────────────────

class _ChildCard extends StatelessWidget {
  final ChildSummary child;
  final HCColor hc;
  final VoidCallback onTap;
  final int index;

  const _ChildCard({
    required this.child,
    required this.hc,
    required this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final accuracy = (child.averageAccuracy * 100).round();
    final weekChange = child.weekOverWeekChange;
    final accentColor = child.isRecentlyActive ? AppColors.success : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: child.isRecentlyActive
                ? AppColors.success.withValues(alpha: 0.4)
                : hc.border,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top row: avatar with accuracy ring, name, streak
            Row(
              children: [
                // Avatar with circular accuracy ring
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: CircularProgressIndicator(
                          value: child.averageAccuracy,
                          strokeWidth: 3,
                          backgroundColor: hc.border.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation(
                            accuracy >= 70
                                ? AppColors.success
                                : accuracy >= 40
                                    ? AppColors.warning
                                    : AppColors.error,
                          ),
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            child.avatarEmoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Name + disability tag + active indicator
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              child.name,
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: hc.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (child.isRecentlyActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Active',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.success,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (child.disabilityType != DisabilityType.none)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: hc.textSecondary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(child.disabilityType.icon,
                                  size: 12, color: hc.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                child.disabilityType.label,
                                style: AppTypography.labelSmall.copyWith(
                                  color: hc.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Streak badge - enhanced
                if (child.streakDays > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.warning.withValues(alpha: 0.2),
                          AppColors.warning.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          '${child.streakDays}',
                          style: AppTypography.labelMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // Stats row — enhanced with backgrounds
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: hc.border.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _MiniStat(
                    icon: Icons.school_rounded,
                    value: '${child.wordsLearned}',
                    label: 'Words',
                    color: AppColors.primary,
                  ),
                  _MiniStat(
                    icon: Icons.star_rounded,
                    value: '${child.totalStars}',
                    label: 'Stars',
                    color: AppColors.warning,
                  ),
                  _MiniStat(
                    icon: Icons.percent_rounded,
                    value: '$accuracy%',
                    label: 'Accuracy',
                    color: AppColors.info,
                  ),
                  _MiniStat(
                    icon: Icons.timer_rounded,
                    value: '${child.studyMinutesThisWeek}m',
                    label: 'This Week',
                    color: AppColors.success,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Weekly trend bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: child.averageAccuracy,
                      backgroundColor: hc.border.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation(
                        accuracy >= 70
                            ? AppColors.success
                            : accuracy >= 40
                                ? AppColors.warning
                                : AppColors.error,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Week-over-week change indicator — enhanced
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: weekChange >= 0
                          ? [
                              AppColors.success.withValues(alpha: 0.18),
                              AppColors.success.withValues(alpha: 0.08),
                            ]
                          : [
                              AppColors.error.withValues(alpha: 0.18),
                              AppColors.error.withValues(alpha: 0.08),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (weekChange >= 0 ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        weekChange >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 14,
                        color: weekChange >= 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${weekChange >= 0 ? '+' : ''}${weekChange.round()}%',
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: weekChange >= 0
                              ? AppColors.success
                              : AppColors.error,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.timeline_rounded,
                      size: 20, color: AppColors.primary),
                  tooltip: 'View Timeline',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => context.push(
                    '/progress-timeline/${child.profileId}?name=${Uri.encodeComponent(child.name)}',
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: hc.textHint),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms, delay: (150 + index * 80).ms)
        .slideY(
          begin: 0.05,
          end: 0,
          delay: (150 + index * 80).ms,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: HCColor.of(context).textSecondary,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final HCColor hc;
  const _EmptyState({required this.hc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.family_restroom_rounded,
              size: 64, color: hc.textHint),
          const SizedBox(height: 16),
          Text(
            'No student profiles found',
            style: AppTypography.titleMedium.copyWith(
              color: hc.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create student profiles for your children\nto see their learning progress here.',
            style: AppTypography.bodyMedium.copyWith(
              color: hc.textHint,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/create-student'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Student Profile'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recommendations Generator ───────────────────────

/// Recommendation data class.
class ParentRecommendation {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String childName;

  const ParentRecommendation({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.childName,
  });
}

List<ParentRecommendation> _generateRecommendations(
    List<ChildSummary> children) {
  final recs = <ParentRecommendation>[];

  for (final child in children) {
    // Low activity warning
    if (!child.isRecentlyActive &&
        DateTime.now().difference(child.lastActivityDate).inDays > 2) {
      recs.add(ParentRecommendation(
        title: 'Encourage ${child.name} to practice',
        description:
            '${child.name} hasn\'t studied in ${DateTime.now().difference(child.lastActivityDate).inDays} days. '
            'A quick 5-minute session can help maintain their progress!',
        icon: Icons.notifications_active_rounded,
        color: AppColors.warning,
        childName: child.name,
      ));
    }

    // Low accuracy suggestion
    if (child.averageAccuracy > 0 && child.averageAccuracy < 0.5) {
      recs.add(ParentRecommendation(
        title: '${child.name} may need easier activities',
        description:
            'With ${(child.averageAccuracy * 100).round()}% accuracy, '
            '${child.name} might benefit from reviewing flashcards before playing games.',
        icon: Icons.lightbulb_outline_rounded,
        color: AppColors.info,
        childName: child.name,
      ));
    }

    // Unexplored categories
    final unexplored = child.unexploredCategories;
    if (unexplored.isNotEmpty && unexplored.length <= 6) {
      recs.add(ParentRecommendation(
        title: 'New categories for ${child.name}',
        description:
            '${child.name} hasn\'t explored ${unexplored.take(3).join(', ')} yet. '
            'Try introducing a new topic to keep learning fresh!',
        icon: Icons.explore_rounded,
        color: AppColors.secondary,
        childName: child.name,
      ));
    }

    // Great streak celebration
    if (child.streakDays >= 5) {
      recs.add(ParentRecommendation(
        title: '${child.name} is on a roll! 🎉',
        description:
            '${child.streakDays}-day streak! Celebrate and encourage ${child.name} '
            'to keep up the amazing consistency.',
        icon: Icons.emoji_events_rounded,
        color: AppColors.success,
        childName: child.name,
      ));
    }

    // Study time declining
    if (child.weekOverWeekChange < -30) {
      recs.add(ParentRecommendation(
        title: '${child.name}\'s study time dropped',
        description:
            'Study time decreased by ${child.weekOverWeekChange.abs().round()}% compared to last week. '
            'Consider setting a daily learning reminder together.',
        icon: Icons.trending_down_rounded,
        color: AppColors.error,
        childName: child.name,
      ));
    }

    // High mastery celebration
    if (child.masteredCategories >= 3) {
      recs.add(ParentRecommendation(
        title: '${child.name} mastered ${ child.masteredCategories} categories!',
        description:
            'Outstanding progress! ${child.name} has achieved 80%+ mastery in '
            '${child.masteredCategories} vocabulary categories.',
        icon: Icons.workspace_premium_rounded,
        color: AppColors.primary,
        childName: child.name,
      ));
    }
  }

  // Cap at 6 recommendations to avoid overwhelming
  if (recs.length > 6) recs.length = 6;

  // If no specific recommendations, give a general one
  if (recs.isEmpty) {
    recs.add(const ParentRecommendation(
      title: 'Keep up the great work!',
      description:
          'Your children are learning at a healthy pace. '
          'Encourage them to explore new categories and try different games.',
      icon: Icons.thumb_up_rounded,
      color: AppColors.success,
      childName: '',
    ));
  }

  return recs;
}
