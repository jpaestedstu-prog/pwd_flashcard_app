import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/active_time_provider.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/child_time_limit_provider.dart';
import '../../../providers/parent_provider.dart';
import '../../mood_tracker/models/mood_context.dart';
import '../../mood_tracker/models/mood_models.dart';
import '../../mood_tracker/models/mood_summary.dart';
import '../../notifications/services/alert_service.dart';
import '../../routine/widgets/educator_routine_section.dart';
import '../models/educator_audience.dart';
import '../services/educator_recommendations.dart';
import '../widgets/child_detail_sheet.dart';
import '../widgets/parent_recommendation_card.dart';
import '../widgets/weekly_overview_card.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/rich_empty_states.dart';
import '../../../l10n/app_localizations.dart';

export '../models/educator_audience.dart' show EducatorAudience;
export '../services/educator_recommendations.dart'
    show
        EducatorRecommendationKind,
        ParentRecommendation,
        generateEducatorRecommendations;

/// Educator dashboard — overview of every learner on the active profile's
/// roster.
///
/// Shows aggregate stats, per-learner cards with weekly trends, and
/// actionable recommendations. Live: the underlying [parentDashboardProvider]
/// watches [educatorRosterProvider] (stream-backed) and a 10 s wall-clock
/// tick, so changes from any device surface without polling.
///
/// Rendered for parents as `ParentDashboardScreen` and for teachers as
/// `TeacherDashboardScreen`.
class EducatorDashboardScreen extends ConsumerStatefulWidget {
  final EducatorAudience audience;

  const EducatorDashboardScreen({super.key, required this.audience});

  @override
  ConsumerState<EducatorDashboardScreen> createState() =>
      _EducatorDashboardScreenState();
}

class _EducatorDashboardScreenState
    extends ConsumerState<EducatorDashboardScreen> {
  EducatorAudience get _audience => widget.audience;

  void _refresh() {
    final active = ref.read(profileProvider);
    if (active != null) {
      ref.invalidate(educatorRosterProvider(active.id));
    }
  }

  bool _hasUnreadAlerts() {
    try {
      return AlertService.getAlerts().where((a) => !a.isRead).isNotEmpty;
    } on Object catch (e) {
      // `Object`, not `Exception`: a closed or missing box throws `HiveError`,
      // which extends Error — the narrower catch let a bell badge take the
      // whole dashboard down.
      debugPrint('educator dashboard: alert read failed: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(parentDashboardProvider);
    final hc = HCColor.of(context);
    final l = ref.watch(settingsProvider).locale == 'fil';

    return AnimatedGradientBackground(
      intensity: 0.25,
      preset: _audience.gradientPreset,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          _audience.dashboardTitleOf(filipino: l),
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
                tooltip: l ? 'Mga Setting ng Alerto' : 'Alert Settings',
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
            icon: Icon(_audience.overviewIcon, color: hc.textSecondary),
            tooltip: _audience.manageTooltipOf(filipino: l),
            onPressed: () => context.push(_audience.manageRoute),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: hc.textSecondary),
            tooltip: l ? 'I-refresh' : 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: snapshot.children.isEmpty
          // Centre the empty state, but let it scroll instead of overflowing a
          // short viewport at a large font scale.
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: _EmptyState(audience: _audience, filipino: l),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                _refresh();
              },
              child: Builder(builder: (context) {
                final recommendations =
                    generateEducatorRecommendations(
                          snapshot.children,
                          audience: _audience,
                          filipino: l,
                        );
                return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ─── Roster Overview Stats ────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: _RosterStatsCard(
                        snapshot: snapshot,
                        hc: hc,
                        audience: _audience,
                        filipino: l,
                      ),
                    ),
                  ),

                  // ─── Recommendations ──────────────────
                  // Second, not last. On a six-learner roster the old order
                  // buried "Check in with Ana — 4 difficult check-ins this
                  // week" below six cards and a bar chart: the one thing that
                  // needed acting on today was the one thing an educator had
                  // to scroll to find.
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_rounded,
                              color: AppColors.warning, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            l ? 'Mga Rekomendasyon' : 'Recommendations',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: hc.textPrimary,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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

                  // ─── Section: Your Children / Students ─
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Icon(_audience.rosterIcon,
                              color: hc.primary, size: 22),
                          const SizedBox(width: 8),
                          // Expanded so a large font scale can't push the
                          // "N active / M total" counter off the row.
                          Expanded(
                            child: Text(
                              _audience.rosterTitleOf(filipino: l),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: hc.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l
                                ? '${snapshot.activeChildren} aktibo / ${snapshot.totalChildren} lahat'
                                : '${snapshot.activeChildren} active / ${snapshot.totalChildren} total',
                            style: AppTypography.labelSmall.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
                    ),
                  ),

                  // ─── Learner Cards ────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final child = snapshot.children[index];
                          return _ChildCard(
                            child: child,
                            hc: hc,
                            audience: _audience,
                            filipino: l,
                            onTap: () => _showChildDetail(context, child),
                            index: index,
                          );
                        },
                        childCount: snapshot.children.length,
                      ),
                    ),
                  ),

                  // ─── Today's Routines ─────────────────
                  // Above the weekly chart: a routine is about *today*, and
                  // an educator checking whether a child got through their
                  // morning should not have to scroll past a week of history
                  // to find out.
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: EducatorRoutineSection(
                        learners: [
                          for (final c in snapshot.children)
                            EducatorRoutineLearner(
                              profileId: c.profileId,
                              name: c.name,
                              avatarEmoji: c.avatarEmoji,
                              accessibility: c.disabilityType,
                            ),
                        ],
                        learnerNounPlural: _audience.learnerNounPlural,
                        learnerNoun: _audience.learnerNoun,
                        filipino: l,
                      ).animate().fadeIn(duration: 400.ms, delay: 220.ms),
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
                            l ? 'Ngayong Linggo' : 'This Week',
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
                        learnerNoun: _audience.learnerNoun,
                      ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
                    ),
                  ),


                  // ─── Last Updated ─────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Center(
                        child: Text(
                          l
                              ? 'Huling update: ${_formatTime(snapshot.timestamp)}'
                              : 'Last updated: ${_formatTime(snapshot.timestamp)}',
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
      ),
    );
  }

  void _showChildDetail(BuildContext context, ChildSummary child) {
    showModalBottomSheet(
      context: context,
      // Without this the dismiss barrier announces itself as "Scrim",
      // Material's untranslated default.
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChildDetailSheet(
        child: child,
        learnerNoun: _audience.learnerNoun,
        onViewFullDashboard: () async {
          // Find the full UserProfile for this learner. Try Firestore-backed
          // roster first (cross-device), fall back to local Hive.
          final active = ref.read(profileProvider);
          List<(UserProfile, LearningProgress)> allData = const [];
          if (active != null && active.role.isEducator) {
            try {
              allData =
                  await ref.read(educatorRosterProvider(active.id).future);
            } on FirebaseException catch (e) {
              // Firestore unreachable / permission-denied — Hive
              // fallback below still renders the last-known roster.
              debugPrint('educator dashboard: roster fetch failed '
                  '(${e.code}): ${e.message}');
            }
          }
          if (allData.isEmpty) {
            allData = HiveService.getAllProfilesWithProgress();
          }
          final match = allData.where((d) => d.$1.id == child.profileId);
          if (match.isNotEmpty && context.mounted) {
            await ref
                .read(profileProvider.notifier)
                .viewAsStudent(match.first.$1);
            if (context.mounted) context.push('/dashboard');
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

// ─── Roster Stats Card ───────────────────────────────

class _RosterStatsCard extends StatelessWidget {
  final ParentDashboardSnapshot snapshot;
  final HCColor hc;
  final EducatorAudience audience;
  final bool filipino;

  const _RosterStatsCard({
    required this.snapshot,
    required this.hc,
    required this.audience,
    required this.filipino,
  });

  @override
  Widget build(BuildContext context) {
    // Professional dashboard kit: a structured overview panel with an
    // overflow-safe stat grid, instead of the playful gradient card.
    return ProPanel(
      title: audience.overviewTitleOf(filipino: filipino),
      subtitle: filipino
          ? '${snapshot.activeChildren} sa ${snapshot.totalChildren} ${audience.learnerNounOf(filipino: true)} ang aktibo'
          : '${snapshot.activeChildren} of ${snapshot.totalChildren} ${audience.learnerNounPlural} active',
      trailing: Icon(audience.overviewIcon, color: hc.primary),
      child: ProStatGrid(
        tiles: [
          ProStatTile(
            icon: Icons.school_rounded,
            label: filipino ? 'Mga Salita' : 'Words',
            value: '${snapshot.totalWordsLearned}',
            accent: AppColors.primary,
          ),
          ProStatTile(
            icon: Icons.star_rounded,
            label: filipino ? 'Mga Bituin' : 'Stars',
            value: '${snapshot.totalStarsEarned}',
            accent: AppColors.warning,
          ),
          ProStatTile(
            icon: Icons.timer_rounded,
            label: filipino ? 'Minuto' : 'Minutes',
            value: '${snapshot.totalStudyMinutes}',
            accent: AppColors.success,
          ),
          ProStatTile(
            icon: Icons.sports_esports_rounded,
            label: filipino ? 'Mga Laro' : 'Games',
            value: '${snapshot.totalGamesPlayed}',
            accent: AppColors.info,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }
}

// ─── Learner Card ────────────────────────────────────

class _ChildCard extends ConsumerWidget {
  final ChildSummary child;
  final HCColor hc;
  final EducatorAudience audience;
  final bool filipino;
  final VoidCallback onTap;
  final int index;

  const _ChildCard({
    required this.child,
    required this.hc,
    required this.audience,
    required this.filipino,
    required this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accuracy = (child.averageAccuracy * 100).round();
    final weekChange = child.weekOverWeekChange;

    // ── Today's minutes used vs configured limit ──
    final minutesToday = ref.watch(activeTimeProvider(child.profileId));
    final limit = ref.watch(childTimeLimitProvider(child.profileId)).valueOrNull;
    final showPill = limit != null &&
        limit.dailyLimitEnabled &&
        limit.dailyLimitMinutes > 0;
    final ratio = showPill
        ? (minutesToday / limit.dailyLimitMinutes).clamp(0.0, 2.0)
        : 0.0;
    final pillColor = ratio >= 1.0
        ? AppColors.error
        : ratio >= 0.8
            ? AppColors.warning
            : AppColors.success;

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 14),
      borderRadius: 20,
      borderColor: child.isRecentlyActive
          ? AppColors.success.withValues(alpha: 0.4)
          : hc.border,
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
                                    filipino ? 'Aktibo' : 'Active',
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
                              // Flexible: this tag shares the name column with
                              // the learner's name and the streak badge, and
                              // "Hearing Impairment" is already wider than the
                              // column on a phone at the Large font step —
                              // unflexed it burst the chip by 45–152 px.
                              Flexible(
                                child: Text(
                                  child.disabilityType
                                      .labelOf(AppLocalizations.of(context)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: hc.textSecondary,
                                  ),
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
                    label: filipino ? 'Salita' : 'Words',
                    color: AppColors.primary,
                  ),
                  _MiniStat(
                    icon: Icons.star_rounded,
                    value: '${child.totalStars}',
                    label: filipino ? 'Bituin' : 'Stars',
                    color: AppColors.warning,
                  ),
                  _MiniStat(
                    icon: Icons.percent_rounded,
                    value: '$accuracy%',
                    label: filipino ? 'Katumpakan' : 'Accuracy',
                    color: AppColors.info,
                  ),
                  _MiniStat(
                    icon: Icons.timer_rounded,
                    value: '${child.studyMinutesThisWeek}m',
                    label: filipino ? 'Linggong Ito' : 'This Week',
                    color: AppColors.success,
                  ),
                ],
              ),
            ),
            // ── Wellbeing ──
            // Only when the learner has actually checked in. An empty row
            // here would read as "no feelings", which is not what silence
            // means.
            if (child.moodSummary.hasData) ...[
              const SizedBox(height: 10),
              _MoodRow(summary: child.moodSummary, hc: hc),
            ],
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
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Quick actions — a Wrap reflows them onto a new line so they never
            // overflow on narrow tablets or at large font scales.
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                if (showPill)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: pillColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pillColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_top_rounded,
                            size: 12, color: pillColor),
                        const SizedBox(width: 3),
                        Text(
                          '$minutesToday/${limit.dailyLimitMinutes}m',
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: pillColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.timer_outlined,
                      size: 20, color: AppColors.primary),
                  tooltip: filipino ? 'Limitasyon sa oras' : 'Time limits',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => context.push(
                    '/child-time-limits/${child.profileId}'
                    '?name=${Uri.encodeQueryComponent(child.name)}',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.alarm_rounded,
                      size: 20, color: AppColors.primary),
                  tooltip: filipino ? 'Mga alarma' : 'Alarms',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => context.push(
                    '/child-alarms/${child.profileId}'
                    '?name=${Uri.encodeQueryComponent(child.name)}',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.timeline_rounded,
                      size: 20, color: AppColors.primary),
                  tooltip: filipino ? 'Tingnan ang timeline' : 'View Timeline',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => context.push(
                    '/progress-timeline/${child.profileId}'
                    '?name=${Uri.encodeQueryComponent(child.name)}',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.sticky_note_2_rounded,
                      size: 20, color: AppColors.primary),
                  tooltip: audience.notesTooltipOf(filipino: filipino),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => context.push(
                    '/parent-teacher-notes/${child.profileId}'
                    '?name=${Uri.encodeQueryComponent(child.name)}',
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: hc.textHint),
              ],
            ),
          ],
        ),
    );
    // No per-card entrance animation: learner cards live in a lazy sliver and
    // are rebuilt on every scroll-back, so a staggered `.animate()` replays
    // from opacity 0 each time and cards blink out mid-scroll.
  }
}

/// The learner's last week of wellbeing, on the roster card.
///
/// A pattern, never the entries: [MoodSummary] deliberately carries no notes,
/// so nothing a learner wrote privately reaches a caregiver's screen.
class _MoodRow extends ConsumerWidget {
  final MoodSummary summary;
  final HCColor hc;

  const _MoodRow({required this.summary, required this.hc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFilipino = ref.watch(settingsProvider).locale == 'fil';
    final attention = summary.needsAttention;
    final accent =
        attention ? AppColors.warning : summary.dominantMood?.darkColor;
    final label = summary.labelOf(isFilipino: isFilipino);
    final countLabel = isFilipino
        ? '${summary.entryCount} check-in'
        : '${summary.entryCount} check-in${summary.entryCount == 1 ? '' : 's'}';

    // How their day felt, and which part of it felt worst. The wellbeing
    // signals tied to something the educator themselves set — the routine —
    // so they are the ones they can act on. See [MoodSummary.routineLabelOf]
    // and [MoodSummary.hardestStepLabelOf].
    final routineLine = summary.routineLabelOf(isFilipino: isFilipino);
    final hardest = summary.hardestStepLabelOf(isFilipino: isFilipino);
    final routineLabel = routineLine == null
        ? null
        : (hardest == null ? routineLine : '$routineLine · $hardest');

    return Semantics(
      label: isFilipino
          ? 'Kalagayan nitong nakaraang linggo. $label, $countLabel.'
          '${routineLabel != null ? ' $routineLabel.' : ''}'
          '${attention ? ' Maaaring kailangan ng suporta.' : ''}'
          : 'Wellbeing this week. $label, $countLabel.'
              '${routineLabel != null ? ' $routineLabel.' : ''}'
              '${attention ? ' May need support.' : ''}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (accent ?? hc.border).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (accent ?? hc.border).withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(
          children: [
            Text(
              summary.dominantMood?.emoji ?? '🙂',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label · $countLabel',
                style: AppTypography.labelSmall.copyWith(
                  color: hc.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (attention) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.favorite_rounded,
                size: 14,
                color: AppColors.warning,
              ),
              const SizedBox(width: 4),
              Text(
                isFilipino ? 'Tingnan' : 'Check in',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
            if (routineLabel != null) ...[
              const SizedBox(height: 4),
              ExcludeSemantics(
                child: Row(
                  children: [
                    Icon(
                      MoodContext.afterRoutine.icon,
                      size: 13,
                      color: hc.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        routineLabel,
                        style: AppTypography.labelSmall.copyWith(
                          color: hc.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
  final EducatorAudience audience;
  final bool filipino;

  const _EmptyState({required this.audience, required this.filipino});

  @override
  Widget build(BuildContext context) {
    return RichEmptyState(
      emoji: audience.emptyEmoji,
      title: audience.analyticsEmptyTitle(filipino: filipino),
      description: audience.emptyDescriptionOf(filipino: filipino),
      actionLabel: audience.shareCodeLabel(filipino: filipino),
      actionIcon: audience.overviewIcon,
      onAction: () => context.push(audience.manageRoute),
    );
  }
}
