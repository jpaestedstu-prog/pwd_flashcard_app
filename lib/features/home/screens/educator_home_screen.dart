import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/connectivity_indicator.dart';
import '../../../widgets/rich_empty_states.dart';
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
    final isEducator = profile != null && profile.role.isEducator;

    // Use Firestore-backed roster for educator views so cross-device joined
    // students appear consistently in Home/Students/Analytics/Reports.
    final fallback = ref.watch(allProfilesWithProgressProvider);
    final rosterAsync = isEducator
        ? ref.watch(educatorRosterProvider(profile.id))
        : null;
    final allData = rosterAsync?.valueOrNull ?? fallback;
    final students = allData
        .where((d) => d.$1.role.isEnrollableLearner && !d.$1.isGuestPlayer)
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

    // Distinct educator identities: the Teacher (Classroom, indigo theme)
    // gets the calm academic "assessment" backdrop with bubbles, while the
    // Parent (Family Group, coral theme) keeps the warm "home" backdrop with
    // sparkles — so the two roles read as clearly different environments
    // beyond their color schemes.
    return AnimatedGradientBackground(
      intensity: 0.25,
      preset: isParent ? GradientPreset.home : GradientPreset.assessment,
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                    // Settings gear (top-right). Switching profiles now lives
                    // inside Settings, matching the Student/Child surfaces.
                    Semantics(
                      button: true,
                      label: 'Open settings',
                      child: IconButton(
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(Icons.settings_rounded),
                        iconSize: 28,
                        color: hc.textSecondary,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms)
                        .rotate(begin: -0.1, end: 0, duration: 500.ms),
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
                ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
              ),
            ),

            // ─── Dashboard CTA (both educator roles) ──
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 0, padding, 16),
                child: _EducatorDashboardCta(hc: hc, isParent: isParent)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 175.ms),
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

            // ─── Cards ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 24, padding, 8),
                child: Row(
                  children: [
                    Text(
                      'Cards',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.push('/flashcards'),
                      child: Text(
                        'View All',
                        style: AppTypography.labelMedium.copyWith(
                          color: hc.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  itemCount: _popularDeckCategories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final category = _popularDeckCategories[i];
                    final count = SeedData.getByCategory(category).length;
                    return _DeckTile(
                      category: category,
                      cardCount: count,
                      onTap: () => context.push(
                        '/flashcards/viewer/${category.index}',
                      ),
                    )
                        .animate()
                        .fadeIn(
                          duration: 300.ms,
                          delay: (250 + i * 60).ms,
                        )
                        .slideX(begin: 0.1, end: 0);
                  },
                ),
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
                          // Expanded + ellipsis so a long (or XL-scaled) title
                          // can't push "View All" off-screen and overflow.
                          Expanded(
                            child: Text(
                              isParent ? 'Your Children' : 'Recent Students',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: hc.textPrimary,
                              ),
                            ),
                          ),
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
                              color: AppColors.error,
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
                              color: AppColors.warning,
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
                              color: AppColors.success,
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
                  // No per-row entrance animation: rows in a lazy sliver are
                  // rebuilt on every scroll-back, so a staggered `.animate()`
                  // replays from opacity 0 each time and the roster flickers.
                  // Section headers above still animate.
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
                    );
                  },
                  childCount: students.length.clamp(0, 5),
                ),
              ),
            ],

            // ─── Empty State ──────────────────────
            if (students.isEmpty)
              SliverToBoxAdapter(
                child: RichEmptyState(
                  emoji: isParent ? '👨‍👩‍👧' : '📊',
                  title: isParent ? 'No children yet' : 'No students yet',
                  description: isParent
                      ? 'Create a home group, then share the code with your child to join.'
                      : 'Create a class, then share the code with your students to join.',
                  actionLabel:
                      isParent ? 'Share Home Group Code' : 'Share Class Code',
                  actionIcon: isParent
                      ? Icons.family_restroom_rounded
                      : Icons.qr_code_2_rounded,
                  onAction: () => context.push(
                      isParent ? '/home-group-manage' : '/classroom-manage'),
                ),
              ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
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

  const _OverviewStats({
    required this.totalStudents,
    required this.activeToday,
    required this.avgWords,
  });

  @override
  Widget build(BuildContext context) {
    // Professional surface kit: a structured, overflow-safe stat grid instead
    // of the playful gradient cards used on the student surfaces. Reads as a
    // dashboard, which suits responsible progress tracking.
    return ProStatGrid(
      tiles: [
        ProStatTile(
          icon: Icons.people_rounded,
          label: 'Students',
          value: '$totalStudents',
          caption: 'enrolled',
          accent: AppColors.sectionLearning,
        ),
        ProStatTile(
          icon: Icons.local_fire_department_rounded,
          label: 'Active Today',
          value: '$activeToday',
          caption: 'in last 24h',
          accent: AppColors.error,
        ),
        ProStatTile(
          icon: Icons.auto_stories_rounded,
          label: 'Avg Words',
          value: '$avgWords',
          caption: 'per student',
          accent: AppColors.sectionCommunication,
        ),
      ],
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
    if (isParent) {
      return _buildParentChips(context);
    }
    return _buildTeacherChips(context);
  }

  Widget _buildParentChips(BuildContext context) {
    // Primary actions as large, easy-to-tap professional tiles; the rest tuck
    // into a compact "More" grid. (Family View lives in the hero CTA above, so
    // it isn't duplicated here.)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProActionGrid(
          tiles: [
            ProActionTile(
              icon: Icons.assessment_rounded,
              label: 'Reports',
              caption: 'Weekly summary',
              accent: AppColors.warning,
              onTap: () => context.push('/weekly-reports'),
            ),
            ProActionTile(
              icon: Icons.shield_rounded,
              label: 'Parental Controls',
              caption: 'Limits & safety',
              accent: AppColors.sectionAssessment,
              onTap: () => context.push('/parental-controls'),
            ),
            ProActionTile(
              icon: Icons.style_rounded,
              label: 'Cards',
              caption: 'Browse decks',
              accent: AppColors.info,
              onTap: () => context.push('/flashcards'),
            ),
            ProActionTile(
              icon: Icons.qr_code_2_rounded,
              label: 'Share Code',
              caption: 'Invite your child',
              accent: AppColors.success,
              onTap: () => context.push('/home-group-manage'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const ProSectionHeader(title: 'More'),
        const SizedBox(height: 12),
        ProActionGrid(
          compact: true,
          tiles: [
            ProActionTile(
              compact: true,
              icon: Icons.tv_rounded,
              label: 'TV Cast',
              accent: AppColors.primary,
              onTap: () => context.push('/tv-cast'),
            ),
            ProActionTile(
              compact: true,
              icon: Icons.message_rounded,
              label: 'Messages',
              accent: AppColors.sectionSocial,
              onTap: () => context.push('/messages'),
            ),
            ProActionTile(
              compact: true,
              icon: Icons.sticky_note_2_rounded,
              label: 'Teacher Notes',
              accent: AppColors.sectionCommunication,
              onTap: () => context.push('/parent-teacher-notes'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeacherChips(BuildContext context) {
    // Six large primary tiles for the daily essentials, then the long tail of
    // actions grouped under a compact "More" section.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProActionGrid(
          tiles: [
            ProActionTile(
              icon: Icons.people_rounded,
              label: 'All Students',
              caption: 'Roster & progress',
              accent: AppColors.sectionLearning,
              onTap: () => context.push('/multi-dashboard'),
            ),
            ProActionTile(
              icon: Icons.analytics_rounded,
              label: 'Analytics',
              caption: 'Class insights',
              accent: AppColors.sectionCommunication,
              onTap: () => context.push('/teacher-analytics'),
            ),
            ProActionTile(
              icon: Icons.assessment_rounded,
              label: 'Reports',
              caption: 'Weekly summary',
              accent: AppColors.warning,
              onTap: () => context.push('/weekly-reports'),
            ),
            ProActionTile(
              icon: Icons.cast_for_education_rounded,
              label: 'Classroom',
              caption: 'Live session',
              accent: AppColors.accent,
              onTap: () => context.push('/classroom'),
            ),
            ProActionTile(
              icon: Icons.style_rounded,
              label: 'Cards',
              caption: 'Browse decks',
              accent: AppColors.info,
              onTap: () => context.push('/flashcards'),
            ),
            ProActionTile(
              icon: Icons.qr_code_2_rounded,
              label: 'Share Code',
              caption: 'Invite students',
              accent: AppColors.success,
              onTap: () => context.push('/classroom-manage'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const ProSectionHeader(title: 'More'),
        const SizedBox(height: 12),
        _GroupLabel(text: 'Content', color: hc.textSecondary),
        const SizedBox(height: 8),
        ProActionGrid(
          compact: true,
          tiles: [
            ProActionTile(
              compact: true,
              icon: Icons.tv_rounded,
              label: 'TV Cast',
              accent: AppColors.primary,
              onTap: () => context.push('/tv-cast'),
            ),
            ProActionTile(
              compact: true,
              icon: Icons.print_rounded,
              label: 'Worksheets',
              accent: AppColors.sectionWellbeing,
              onTap: () => context.push('/worksheets'),
            ),
            ProActionTile(
              compact: true,
              icon: Icons.message_rounded,
              label: 'Messages',
              accent: AppColors.sectionSocial,
              onTap: () => context.push('/messages'),
            ),
            ProActionTile(
              compact: true,
              icon: Icons.sticky_note_2_rounded,
              label: 'Parent Notes',
              accent: AppColors.sectionCommunication,
              onTap: () => context.push('/parent-teacher-notes'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _GroupLabel(text: 'Assessments & Progress', color: hc.textSecondary),
        const SizedBox(height: 8),
        ProActionGrid(
          compact: true,
          tiles: [
            ProActionTile(
              compact: true,
              icon: Icons.quiz_rounded,
              label: 'Assessments',
              accent: AppColors.sectionAssessment,
              onTap: () => context.push('/assessment'),
            ),
            ProActionTile(
              compact: true,
              icon: Icons.assignment_turned_in_rounded,
              label: 'Assign Tasks',
              accent: AppColors.success,
              onTap: () => context.push('/assessment/assign'),
            ),
            ProActionTile(
              compact: true,
              icon: Icons.track_changes_rounded,
              label: 'Track Progress',
              accent: AppColors.info,
              onTap: () => context.push('/assessment/tracking'),
            ),
            ProActionTile(
              compact: true,
              icon: Icons.qr_code_2_rounded,
              label: 'Manage Classes',
              accent: AppColors.sectionCommunication,
              onTap: () => context.push('/classroom-manage'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _GroupLabel(text: 'Research', color: hc.textSecondary),
        const SizedBox(height: 8),
        ProActionGrid(
          compact: true,
          tiles: [
            ProActionTile(
              compact: true,
              icon: Icons.science_rounded,
              label: 'Experiment Setup',
              accent: AppColors.sectionWellbeing,
              onTap: () => context.push('/experiment-setup'),
            ),
            ProActionTile(
              compact: true,
              icon: Icons.poll_rounded,
              label: 'SUS Survey',
              accent: AppColors.sectionCommunication,
              onTap: () => context.push('/survey-results'),
            ),
            ProActionTile(
              compact: true,
              icon: Icons.file_download_rounded,
              label: 'Research Export',
              accent: AppColors.primaryDark,
              onTap: () => context.push('/research-export'),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Group Label for Quick Action sub-sections ─────────

class _GroupLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _GroupLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.labelSmall.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─── Dashboard CTA (teacher + parent) ──────────────────

/// Hero shortcut into the role's detailed dashboard. Both educator roles get
/// one — the destination is the same screen with role-specific copy (see
/// `EducatorDashboardScreen`).
class _EducatorDashboardCta extends StatelessWidget {
  final HCColor hc;
  final bool isParent;

  const _EducatorDashboardCta({required this.hc, required this.isParent});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(
        isParent ? '/parent-dashboard' : '/teacher-dashboard',
      ),
      borderRadius: 20,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          hc.primary.withValues(alpha: 0.18),
          hc.accent.withValues(alpha: 0.12),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hc.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.dashboard_customize_rounded,
                color: hc.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isParent ? 'Parent Dashboard' : 'Teacher Dashboard',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Detailed insights, alerts, and recommendations',
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: hc.primary),
        ],
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
    return AppCard(
      onTap: onTap,
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      borderColor: AppColors.primary.withValues(alpha: 0.12),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ),
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
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$wordsLearned words  •  🔥 $streak streak  •  ⭐ $stars',
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
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

// ─── Cards Section ────────────────────────────────────

const List<FlashcardCategory> _popularDeckCategories = [
  FlashcardCategory.animals,
  FlashcardCategory.colorsAndShapes,
  FlashcardCategory.numbers,
  FlashcardCategory.familyAndGreetings,
];

class _DeckTile extends StatelessWidget {
  final FlashcardCategory category;
  final int cardCount;
  final VoidCallback onTap;

  const _DeckTile({
    required this.category,
    required this.cardCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${category.label} deck, $cardCount cards',
      child: SizedBox(
        width: 128,
        child: Card(
          elevation: 3,
          shadowColor: category.color.withValues(alpha: 0.35),
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: InkWell(
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [category.darkColor, category.color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(
                        category.icon,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          category.label,
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$cardCount cards',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
