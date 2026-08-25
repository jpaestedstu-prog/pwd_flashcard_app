import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/student_list_provider.dart';
import '../models/assessment_models.dart';
import '../providers/assessment_provider.dart';
import '../services/assessment_service.dart';
import '../services/assessment_cloud_service.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_snack_bar.dart';

/// Screen showing all assignments created by the current educator,
/// with per-student completion tracking.
class AssignmentTrackingScreen extends ConsumerWidget {
  const AssignmentTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final hc = HCColor.of(context);
    if (profile == null) return const SizedBox.shrink();

    // Pull assignments made on another device, and the results that turn a
    // row from Pending into a score. Watched so the list repaints when it
    // lands; the local data renders straight away in the meantime.
    ref.watch(educatorAssessmentSyncProvider(profile.id));

    // Display names for the assignees. The roster spans devices; local Hive
    // does not, so without this a cross-device student reads "Unknown".
    final names = {
      for (final d in ref.watch(educatorLearnerRosterProvider))
        d.$1.id: d.$1.name,
    };

    // Watched, not read: assigning from this screen's "+" action or deleting a
    // card has to repaint the list immediately.
    final assignments = [...ref.watch(assignmentsProvider)]
      // Sort: most recent first
      ..sort((a, b) => b.assignedAt.compareTo(a.assignedAt));

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(fallbackRoute: '/assessment-hub'),
        title: Text(
          'Assignment Tracking',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        actions: [
          // The cloud pull runs once per profile per session, which is right
          // for a screen you glance at — but this is the screen an educator
          // sits on waiting for "did they do it yet?", so give them a way to
          // ask again without restarting the app.
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: hc.textSecondary),
            tooltip: 'Check for new results',
            onPressed: () =>
                ref.invalidate(educatorAssessmentSyncProvider(profile.id)),
          ),
          IconButton(
            icon: Icon(Icons.add_rounded, color: hc.primary),
            tooltip: 'Assign Assessment',
            onPressed: () => context.push('/assessment/assign'),
          ),
        ],
      ),
      body: assignments.isEmpty
          ? _EmptyState(hc: hc)
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: assignments.length,
              itemBuilder: (context, index) {
                final assignment = assignments[index];
                final statuses = AssessmentService.getAssignmentStatuses(
                  assignment,
                  names: names,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _AssignmentCard(
                    assignment: assignment,
                    statuses: statuses,
                    hc: hc,
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Assignment?'),
                          content: const Text(
                              'This will remove the assignment. Student results will be kept.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final outcome = await ref
                            .read(assignmentsProvider.notifier)
                            .deleteAssignment(assignment.id);
                        // The row leaves this list either way. Whether it also
                        // left the learner's tablet is the part worth saying —
                        // a teacher who thinks they withdrew work that is
                        // still sitting on a pupil's screen finds out the
                        // hard way.
                        if (context.mounted &&
                            outcome == CloudSyncOutcome.notOwner) {
                          AppSnackBar.warning(
                            context,
                            message: 'Removed here only. This profile was '
                                'restored on another device, so that one now '
                                'handles syncing — your learners still have '
                                'this assignment.',
                          );
                        }
                      }
                    },
                  ),
                )
                    .animate()
                    .fadeIn(duration: 300.ms, delay: (80 * index).ms)
                    .slideY(begin: 0.05, end: 0);
              },
            ),
    );
  }
}

// ─── Assignment Card ──────────────────────────────────

class _AssignmentCard extends StatelessWidget {
  final AssessmentAssignment assignment;
  final List<StudentAssignmentStatus> statuses;
  final HCColor hc;
  final VoidCallback onDelete;

  const _AssignmentCard({
    required this.assignment,
    required this.statuses,
    required this.hc,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final completed =
        statuses.where((s) => s.status == AssignmentStatus.completed).length;
    final overdue =
        statuses.where((s) => s.status == AssignmentStatus.overdue).length;
    final total = statuses.length;
    final progress = total > 0 ? completed / total : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: hc.textSecondary.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    assignment.assessmentTitle,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hc.textPrimary,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: hc.textSecondary, size: 20),
                  onSelected: (v) {
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded,
                              color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Meta info
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14, color: hc.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _formatDate(assignment.assignedAt),
                  style: AppTypography.labelSmall
                      .copyWith(color: hc.textSecondary),
                ),
                if (assignment.deadline != null) ...[
                  const SizedBox(width: 12),
                  Icon(
                    assignment.isOverdue
                        ? Icons.warning_rounded
                        : Icons.schedule_rounded,
                    size: 14,
                    color: assignment.isOverdue ? Colors.red : hc.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${_formatDate(assignment.deadline!)}',
                    style: AppTypography.labelSmall.copyWith(
                      color: assignment.isOverdue
                          ? Colors.red
                          : hc.textSecondary,
                    ),
                  ),
                ],
              ],
            ),

            if (assignment.instructions != null) ...[
              const SizedBox(height: 8),
              Text(
                assignment.instructions!,
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            // Progress bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: hc.textSecondary.withValues(alpha: 0.1),
                      color: overdue > 0
                          ? Colors.orange
                          : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$completed/$total',
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Student status list
            ...statuses.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            _statusColor(s.status).withValues(alpha: 0.15),
                        child: Text(
                          s.studentName.isNotEmpty
                              ? s.studentName[0].toUpperCase()
                              : '?',
                          style: AppTypography.labelSmall.copyWith(
                            color: _statusColor(s.status),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.studentName,
                          style: AppTypography.bodySmall.copyWith(
                            color: hc.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        s.status.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      if (s.result != null)
                        Text(
                          '${(s.result!.percentage * 100).round()}%',
                          style: AppTypography.labelMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _scoreColor(s.result!.percentage),
                          ),
                        )
                      else
                        Text(
                          s.status.label,
                          style: AppTypography.labelSmall.copyWith(
                            color: _statusColor(s.status),
                          ),
                        ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Color _statusColor(AssignmentStatus status) => switch (status) {
    AssignmentStatus.completed => const Color(0xFF4CAF50),
    AssignmentStatus.pending => const Color(0xFFFFA726),
    AssignmentStatus.overdue => const Color(0xFFEF5350),
  };

  Color _scoreColor(double pct) {
    if (pct >= 0.75) return const Color(0xFF4CAF50);
    if (pct >= 0.5) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Empty State ──────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final HCColor hc;
  const _EmptyState({required this.hc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📋', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'No assignments yet',
            style:
                AppTypography.titleMedium.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Assign assessments to students and track their progress here.',
            style:
                AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/assessment/assign'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Assign Assessment'),
          ),
        ],
      ),
    );
  }
}
