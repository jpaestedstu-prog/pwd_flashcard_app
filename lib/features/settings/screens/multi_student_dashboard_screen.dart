import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/constants/avatar_data.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/models/achievements.dart';
import '../../../data/models/shop_data.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/student_list_provider.dart';
import '../../../widgets/student_filter_bar.dart';
import '../../../widgets/app_back_button.dart';

/// Multi-student dashboard for teachers and parents.
///
/// Displays a filterable, sortable list of student profiles with
/// key learning metrics at a glance. Tap a card to switch to that
/// profile's detailed dashboard.
class MultiStudentDashboardScreen extends ConsumerWidget {
  const MultiStudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredStudents = ref.watch(filteredStudentsProvider);
    final filter = ref.watch(studentFilterProvider);
    // Use the same roster source as the filter pipeline so educators see
    // their Firestore-backed student count.
    final activeProfile = ref.watch(profileProvider);
    final isEducator = activeProfile != null && activeProfile.role.isEducator;
    final rosterAsync = isEducator
        ? ref.watch(educatorRosterProvider(activeProfile.id))
        : AsyncData(ref.watch(allProfilesWithProgressProvider));
    final allData = rosterAsync.value ?? const [];
    final totalStudents = allData
        .where((d) => d.$1.role.isEnrollableLearner && !d.$1.isGuestPlayer)
        .length;
    final totalWords = ref.watch(allFlashcardsProvider).length;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(
          'All Students',
          style: AppTypography.titleMedium
              .copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (filter.hasActiveFilters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Badge(
                label: Text('${filter.activeFilterCount}'),
                isLabelVisible: filter.activeFilterCount > 0,
                child: IconButton(
                  icon: const Icon(Icons.filter_list_off_rounded),
                  tooltip: 'Clear filters',
                  onPressed: () =>
                      ref.read(studentFilterProvider.notifier).clearFilters(),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Filter Bar ─────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: StudentFilterBar(),
          ),

          // ─── Student List ───────────────────
          Expanded(
            child: filteredStudents.isEmpty
                ? _EmptyState(
                    hasFilters: filter.hasActiveFilters,
                    totalStudents: totalStudents,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    itemCount: filteredStudents.length,
                    itemBuilder: (context, index) {
                      final (profile, progress) = filteredStudents[index];
                      return _StudentCard(
                            profile: profile,
                            progress: progress,
                            totalWords: totalWords,
                            onTap: () {
                              ref
                                  .read(profileProvider.notifier)
                                  .viewAsStudent(profile);
                              context.push('/dashboard');
                            },
                          )
                          .animate()
                          .fadeIn(
                            duration: 350.ms,
                            delay: Duration(
                                milliseconds: 80 * index.clamp(0, 10)),
                          )
                          .slideY(begin: 0.08, end: 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final int totalStudents;

  const _EmptyState({required this.hasFilters, required this.totalStudents});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters ? Icons.search_off_rounded : Icons.person_off_rounded,
            size: context.scaleIcon(64),
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No students match your filters'
                : 'No student profiles yet',
            style: AppTypography.titleMedium
                .copyWith(color: HCColor.of(context).textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? '$totalStudents total students — try adjusting your filters.'
                : 'Students will appear here once they create\na profile in the app.',
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Student Summary Card ──────────────────────────────

class _StudentCard extends StatelessWidget {
  final UserProfile profile;
  final LearningProgress progress;
  final int totalWords;
  final VoidCallback onTap;

  const _StudentCard({
    required this.profile,
    required this.progress,
    required this.totalWords,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final masteryPct =
        totalWords > 0 ? (progress.wordsLearned / totalWords).clamp(0.0, 1.0) : 0.0;
    final recentAvg = progress.recentScores.isNotEmpty
        ? progress.recentScores
                .map((s) => s.total > 0 ? s.score / s.total : 0.0)
                .reduce((a, b) => a + b) /
            progress.recentScores.length
        : 0.0;
    final unlockedCount = Achievements.unlockedIds(progress).length;

    // Resolve avatar: check for equipped shop avatar first
    final equippedAvatarId = HiveService.getEquippedItem(profile.id, 'avatar');
    final equippedAvatar = equippedAvatarId != null
        ? ShopData.findById(equippedAvatarId)
        : null;
    final emoji = equippedAvatar?.emoji
        ?? AvatarData.getAvatar(profile.avatarIndex).emoji;

    // Build subtitle parts
    final subtitleParts = <String>[
      if (profile.gradeLevel != null) profile.gradeLevel!.label,
      if (profile.section != null) profile.section!,
      if (profile.gradeLevel == null && profile.section == null) profile.role.label,
    ];

    return Semantics(
      button: true,
      label:
          '${profile.name}, ${progress.wordsLearned} words learned, ${progress.totalStars} stars, ${progress.streakDays} day streak',
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
            children: [
              // Avatar + mastery ring
              CircularPercentIndicator(
                radius: 36,
                percent: masteryPct,
                backgroundColor: AppColors.border,
                progressColor: AppColors.primary,
                center: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 16),

              // Name + stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: HCColor.of(context).textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleParts.join(' · '),
                      style: AppTypography.labelSmall.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    ),

                    // Tags row
                    if (profile.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: profile.tags
                            .take(3)
                            .map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tag,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Mini stat chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MiniStat(
                          icon: Icons.auto_stories_rounded,
                          label: '${progress.wordsLearned}',
                          color: AppColors.secondary,
                        ),
                        _MiniStat(
                          icon: Icons.star_rounded,
                          label: '${progress.totalStars}',
                          color: AppColors.warning,
                        ),
                        _MiniStat(
                          icon: Icons.local_fire_department_rounded,
                          label: '${progress.streakDays}d',
                          color: AppColors.error,
                        ),
                        _MiniStat(
                          icon: Icons.emoji_events_rounded,
                          label: '$unlockedCount',
                          color: AppColors.info,
                        ),
                        if (progress.recentScores.isNotEmpty)
                          _MiniStat(
                            icon: Icons.trending_up_rounded,
                            label: '${(recentAvg * 100).round()}%',
                            color: AppColors.success,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: AppColors.textHint,
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

// ─── Mini Stat Chip ─────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
