import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/connectivity_indicator.dart';
import '../../../providers/student_list_provider.dart';

/// Home screen shown to teachers and parents.
///
/// Focuses on student management, analytics, and progress monitoring
/// instead of the learning/gaming features shown to students.
class EducatorHomeScreen extends ConsumerWidget {
  const EducatorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final padding = context.pagePadding;
    final hc = HCColor.of(context);
    final isParent = profile?.role == UserRole.parent;
    final isEducator =
        profile != null && profile.role != UserRole.student;

    // Use Firestore-backed roster for educator views so cross-device joined
    // students appear consistently in Home/Students/Analytics/Reports.
    final fallback = ref.watch(allProfilesWithProgressProvider);
    final rosterAsync = isEducator
        ? ref.watch(educatorRosterProvider(profile.id))
        : null;
    final allData = rosterAsync?.valueOrNull ?? fallback;
    final students = allData
        .where((d) => d.$1.role == UserRole.student && !d.$1.isGuestPlayer)
        .toList();
    final showRosterLoading = rosterAsync != null &&
        rosterAsync.isLoading &&
        rosterAsync.valueOrNull == null;
    final totalStudents = students.length;
    final activeToday = students
        .where((d) =>
            DateTime.now().difference(d.$2.lastActivityDate).inHours < 24)
        .length;
    final avgWords = totalStudents > 0
        ? (students.fold<int>(0, (s, d) => s + d.$2.wordsLearned) /
                totalStudents)
            .round()
        : 0;

    return Scaffold(
      body: SafeArea(
        child: showRosterLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
            // ─── Header ───────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${profile?.name ?? 'Educator'}! ${isParent ? '👨‍👩‍👧' : '📚'}',
                            style: AppTypography.headlineLarge
                                .copyWith(color: hc.textPrimary),
                          )
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideX(begin: -0.05, end: 0),
                          const SizedBox(height: 4),
                          Text(
                            isParent
                                ? 'Monitor your children\'s learning'
                                : 'Manage your class progress',
                            style: AppTypography.bodyMedium.copyWith(
                              color: hc.textSecondary,
                            ),
                          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                        ],
                      ),
                    ),
                    const ConnectivityIndicator(),
                    Semantics(
                      button: true,
                      label: 'Switch profile',
                      child: IconButton(
                        onPressed: () => context.push('/profile-switcher'),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        iconSize: 28,
                        color: hc.textSecondary,
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                  ],
                ),
              ),
            ),

            // ─── Overview Stats ───────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: padding, vertical: 20),
                child: _OverviewStats(
                  totalStudents: totalStudents,
                  activeToday: activeToday,
                  avgWords: avgWords,
                  hc: hc,
                ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
              ),
            ),

            // ─── Quick Actions ────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: Text(
                  'Quick Actions',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 12, padding, 0),
                child: _QuickActions(isParent: isParent, hc: hc)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 200.ms),
              ),
            ),

            // ─── Recent Students ──────────────────
            if (students.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 24, padding, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isParent ? 'Your Children' : 'Recent Students',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: hc.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.go('/multi-dashboard'),
                            child: Text(
                              'View All',
                              style: AppTypography.labelMedium.copyWith(
                                color: hc.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Quick filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _QuickFilterChip(
                              label: 'Needs Help',
                              icon: Icons.warning_amber_rounded,
                              color: const Color(0xFFEF5350),
                              onTap: () {
                                final notifier = ref.read(studentFilterProvider.notifier);
                                notifier.clearFilters();
                                // Sort by accuracy ascending so struggling students appear first
                                notifier.setSortFieldWithDirection(
                                  StudentSortField.averageAccuracy,
                                  ascending: true,
                                );
                                context.push('/multi-dashboard');
                              },
                            ),
                            const SizedBox(width: 8),
                            _QuickFilterChip(
                              label: 'Inactive 7d+',
                              icon: Icons.schedule_rounded,
                              color: const Color(0xFFFFA726),
                              onTap: () {
                                final notifier = ref.read(studentFilterProvider.notifier);
                                notifier.clearFilters();
                                notifier.setActivityFilter(ActivityStatus.inactive7Days);
                                context.push('/multi-dashboard');
                              },
                            ),
                            const SizedBox(width: 8),
                            _QuickFilterChip(
                              label: 'Active Today',
                              icon: Icons.local_fire_department_rounded,
                              color: const Color(0xFF66BB6A),
                              onTap: () {
                                final notifier = ref.read(studentFilterProvider.notifier);
                                notifier.clearFilters();
                                notifier.setActivityFilter(ActivityStatus.activeToday);
                                context.push('/multi-dashboard');
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final (studentProfile, studentProgress) =
                        students[index];
                    return Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: padding, vertical: 4),
                      child: _StudentCard(
                        name: studentProfile.name,
                        wordsLearned: studentProgress.wordsLearned,
                        streak: studentProgress.streakDays,
                        stars: studentProgress.totalStars,
                        lastActive: studentProgress.lastActivityDate,
                        hc: hc,
                        onTap: () {
                          ref
                              .read(profileProvider.notifier)
                              .viewAsStudent(studentProfile);
                          context.push('/dashboard');
                        },
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 300.ms, delay: (100 * index).ms)
                        .slideY(begin: 0.05, end: 0);
                  },
                  childCount: students.length.clamp(0, 5),
                ),
              ),
            ],

            // ─── Empty State ──────────────────────
            if (students.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      const Text('📊', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text(
                        isParent
                            ? 'No children profiles yet'
                            : 'No student profiles yet',
                        style: AppTypography.titleMedium
                            .copyWith(color: hc.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create student profiles to start tracking learning progress.',
                        style: AppTypography.bodyMedium
                            .copyWith(color: hc.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => context.push('/create-student'),
                        icon: const Icon(Icons.person_add_rounded),
                        label: const Text('Create Student Profile'),
                      ),
                    ],
                  ),
                ),
              ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
      ),
    );
  }
}

// ─── Overview Stats Row ────────────────────────────────

class _OverviewStats extends StatelessWidget {
  final int totalStudents;
  final int activeToday;
  final int avgWords;
  final HCColor hc;

  const _OverviewStats({
    required this.totalStudents,
    required this.activeToday,
    required this.avgWords,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.people_rounded,
            label: 'Students',
            value: '$totalStudents',
            color: const Color(0xFF5C6BC0),
            hc: hc,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.local_fire_department_rounded,
            label: 'Active Today',
            value: '$activeToday',
            color: const Color(0xFFEF5350),
            hc: hc,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.auto_stories_rounded,
            label: 'Avg Words',
            value: '$avgWords',
            color: const Color(0xFF26A69A),
            hc: hc,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final HCColor hc;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: hc.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Quick Action Buttons ──────────────────────────────

class _QuickActions extends StatelessWidget {
  final bool isParent;
  final HCColor hc;

  const _QuickActions({required this.isParent, required this.hc});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionChip(
          icon: Icons.person_add_rounded,
          label: 'Add Student',
          color: const Color(0xFF43A047),
          onTap: () => context.push('/create-student'),
        ),
        _ActionChip(
          icon: Icons.people_rounded,
          label: 'All Students',
          color: const Color(0xFF5C6BC0),
          onTap: () => context.push('/multi-dashboard'),
        ),
        _ActionChip(
          icon: Icons.analytics_rounded,
          label: 'Analytics',
          color: const Color(0xFF26A69A),
          onTap: () => context.push('/teacher-analytics'),
        ),
        _ActionChip(
          icon: Icons.assessment_rounded,
          label: 'Reports',
          color: const Color(0xFFFFA726),
          onTap: () => context.push('/weekly-reports'),
        ),
        _ActionChip(
          icon: Icons.quiz_rounded,
          label: 'Assessments',
          color: const Color(0xFFEF5350),
          onTap: () => context.push('/assessment'),
        ),
        _ActionChip(
          icon: Icons.assignment_turned_in_rounded,
          label: 'Assign Tasks',
          color: const Color(0xFF66BB6A),
          onTap: () => context.push('/assessment/assign'),
        ),
        _ActionChip(
          icon: Icons.track_changes_rounded,
          label: 'Track Progress',
          color: const Color(0xFF29B6F6),
          onTap: () => context.push('/assessment/tracking'),
        ),
        _ActionChip(
          icon: Icons.print_rounded,
          label: 'Worksheets',
          color: const Color(0xFF7E57C2),
          onTap: () => context.push('/worksheets'),
        ),
        if (isParent)
          _ActionChip(
            icon: Icons.family_restroom_rounded,
            label: 'Family View',
            color: const Color(0xFFEC407A),
            onTap: () => context.push('/parent-dashboard'),
          ),
        if (!isParent)
          _ActionChip(
            icon: Icons.cast_for_education_rounded,
            label: 'Classroom',
            color: const Color(0xFFEC407A),
            onTap: () => context.push('/classroom'),
          ),
        _ActionChip(
          icon: Icons.qr_code_2_rounded,
          label: 'Manage Classes',
          color: const Color(0xFF26A69A),
          onTap: () => context.push('/classroom-manage'),
        ),
        _ActionChip(
          icon: Icons.message_rounded,
          label: 'Messages',
          color: const Color(0xFF42A5F5),
          onTap: () => context.push('/messages'),
        ),
        // ─── Thesis Research Tools ────────────
        _ActionChip(
          icon: Icons.science_rounded,
          label: 'Experiment Setup',
          color: const Color(0xFF8E24AA),
          onTap: () => context.push('/experiment-setup'),
        ),
        _ActionChip(
          icon: Icons.poll_rounded,
          label: 'SUS Survey',
          color: const Color(0xFF00897B),
          onTap: () => context.push('/survey-results'),
        ),
        _ActionChip(
          icon: Icons.file_download_rounded,
          label: 'Research Export',
          color: const Color(0xFF6D4C41),
          onTap: () => context.push('/research-export'),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Student Card ──────────────────────────────────────

class _StudentCard extends StatelessWidget {
  final String name;
  final int wordsLearned;
  final int streak;
  final int stars;
  final DateTime lastActive;
  final HCColor hc;
  final VoidCallback onTap;

  const _StudentCard({
    required this.name,
    required this.wordsLearned,
    required this.streak,
    required this.stars,
    required this.lastActive,
    required this.hc,
    required this.onTap,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      color: hc.surface,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.06),
              Colors.transparent,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: hc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$wordsLearned words  •  🔥 $streak streak  •  ⭐ $stars',
                        style: AppTypography.bodySmall.copyWith(
                          color: hc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _timeAgo(lastActive),
                  style: AppTypography.labelSmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: hc.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Quick Filter Chip ─────────────────────────────────

class _QuickFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickFilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
