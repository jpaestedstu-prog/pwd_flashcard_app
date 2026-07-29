import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/classroom_provider.dart';
import '../../../widgets/app_back_button.dart';

/// Real-time classroom monitoring screen for teachers.
///
/// Shows all student profiles, their current activity, accuracy, and
/// aggregate class statistics. Updates live: the underlying
/// [teacherDashboardSnapshotProvider] watches Firestore stream providers
/// for classrooms + members and a 10 s wall-clock tick, so changes from
/// any device surface within seconds without polling.
class ClassroomDashboardScreen extends ConsumerStatefulWidget {
  const ClassroomDashboardScreen({super.key});

  @override
  ConsumerState<ClassroomDashboardScreen> createState() =>
      _ClassroomDashboardScreenState();
}

class _ClassroomDashboardScreenState
    extends ConsumerState<ClassroomDashboardScreen> {
  /// Manual refresh — kept as a safety net for the IconButton.
  void _refresh() {
    final profile = ref.read(profileProvider);
    if (profile != null && profile.role.isEducator) {
      ref.invalidate(teacherDashboardSnapshotProvider(profile.id));
    } else {
      ref.read(classroomProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    // Educators (teacher/parent) read student data from Firestore so the
    // dashboard reflects students enrolled from any device. Students/players
    // fall back to the local snapshot.
    final isEducator = profile != null && profile.role.isEducator;
    final snapshotAsync = isEducator
        ? ref.watch(teacherDashboardSnapshotProvider(profile.id))
        : AsyncData<ClassroomSnapshot>(ref.watch(classroomProvider));

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(
          AppLocalizations.of(context)!.classroomView,
          style:
              AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (isEducator)
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Export CSV report',
              onPressed: () => context.push('/reports/export'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load dashboard:\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (snapshot) => snapshot.students.isEmpty
            ? _EmptyState()
            : CustomScrollView(
                slivers: [
                  // ─── Aggregate Stats ──────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: _AggregateRow(snapshot: snapshot),
                    ),
                  ),

                // ─── Section Header ──────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.people_rounded,
                            color: AppColors.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.students,
                            style: AppTypography.titleSmall
                                .copyWith(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text(
                          '${snapshot.activeStudents} ${AppLocalizations.of(context)!.active} / ${snapshot.totalStudents} ${AppLocalizations.of(context)!.total}',
                          style: AppTypography.labelSmall
                              .copyWith(color: HCColor.of(context).textSecondary),
                        ),
                      ],
                    ).animate().fadeIn(duration: 300.ms),
                  ),
                ),

                // ─── Student Cards ────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final student = snapshot.students[index];
                        return _StudentCard(student: student)
                            .animate()
                            .fadeIn(
                                duration: 400.ms,
                                delay: (100 + index * 80).ms)
                            .slideY(begin: 0.08, end: 0);
                      },
                      childCount: snapshot.students.length,
                    ),
                  ),
                ),

                // ─── Last Updated ────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'Last updated: ${_formatTime(snapshot.timestamp)}',
                        style: AppTypography.labelSmall
                            .copyWith(color: AppColors.textHint),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ─── Aggregate Stats Row ─────────────────────────────

class _AggregateRow extends StatelessWidget {
  final ClassroomSnapshot snapshot;
  const _AggregateRow({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border:
            hc.hc ? Border.all(color: AppColors.hcPrimary, width: 2) : null,
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          _StatTile(
            icon: Icons.school_rounded,
            label: AppLocalizations.of(context)!.words,
            value: '${snapshot.totalWordsLearned}',
            color: AppColors.primary,
          ),
          _StatTile(
            icon: Icons.star_rounded,
            label: AppLocalizations.of(context)!.stars,
            value: '${snapshot.totalStarsEarned}',
            color: AppColors.warning,
          ),
          _StatTile(
            icon: Icons.sports_esports_rounded,
            label: AppLocalizations.of(context)!.games,
            value: '${snapshot.totalGamesPlayed}',
            color: AppColors.success,
          ),
          _StatTile(
            icon: Icons.percent_rounded,
            label: AppLocalizations.of(context)!.accuracy,
            value: '${(snapshot.overallAccuracy * 100).round()}%',
            color: AppColors.info,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value,
              style: AppTypography.titleMedium
                  .copyWith(fontWeight: FontWeight.w800)),
          Text(label,
              style: AppTypography.labelSmall
                  .copyWith(color: HCColor.of(context).textSecondary)),
        ],
      ),
    );
  }
}

// ─── Student Card ────────────────────────────────────

class _StudentCard extends StatelessWidget {
  final StudentStatus student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final accuracy = (student.averageAccuracy * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: student.isActive
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (student.isActive ? AppColors.success : AppColors.border)
                .withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: student.isActive
                  ? Border.all(color: AppColors.success, width: 2.5)
                  : null,
            ),
            child: Center(
              child: Text(
                student.avatarEmoji ?? '👤',
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Name + activity
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        student.name,
                        style: AppTypography.titleSmall
                            .copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (student.isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  student.currentActivity,
                  style: AppTypography.bodySmall.copyWith(
                    color: student.isActive
                        ? AppColors.success
                        : hc.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          // Quick stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 2),
                  Text('${student.starsEarned}',
                      style: AppTypography.labelMedium),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.percent_rounded, size: 14, color: AppColors.info),
                  const SizedBox(width: 2),
                  Text('$accuracy%', style: AppTypography.labelMedium),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.group_off_rounded,
              size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'No student profiles found',
            style: AppTypography.titleMedium
                .copyWith(color: HCColor.of(context).textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Create student profiles to see them here.\nEach student will appear with their progress.',
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
