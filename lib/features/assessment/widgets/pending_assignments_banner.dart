import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/shared_widgets.dart';
import '../services/assessment_service.dart';

/// "You have N assessments to complete" — the only place a learner finds out
/// an educator set them work.
///
/// Shared by the Student and Child homes deliberately. It began as a private
/// widget inside `home_screen.dart`, which meant a Child — who a Parent can
/// assign to exactly as a Teacher assigns to a Student — had no way to learn
/// that work existed, and no route into the Assessment Center at all.
///
/// Renders nothing when there is no outstanding work, so a caller can add it
/// unconditionally; callers that publish gaze cells should still gate on
/// [hasPendingWork] so they don't register a cell for an invisible banner.
class PendingAssignmentsBanner extends StatelessWidget {
  final String? profileId;

  const PendingAssignmentsBanner({super.key, required this.profileId});

  /// Whether [profileId] has anything outstanding — the same condition this
  /// widget uses to decide whether to render at all.
  static bool hasPendingWork(String? profileId) =>
      profileId != null &&
      profileId.isNotEmpty &&
      AssessmentService.getPendingAssignments(profileId).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final id = profileId;
    if (id == null || id.isEmpty) return const SizedBox.shrink();
    final pending = AssessmentService.getPendingAssignments(id);
    if (pending.isEmpty) return const SizedBox.shrink();

    final count = pending.length;
    final hasOverdue = pending.any((a) => a.isOverdue);

    return FeatureBanner(
      emoji: hasOverdue ? '⚠️' : '📋',
      title: hasOverdue ? 'Overdue Assignments' : 'Pending Assignments',
      subtitle: 'You have $count assessment${count > 1 ? 's' : ''} to complete',
      gradientColors: hasOverdue
          ? const [AppColors.error, AppColors.sectionAssessment]
          : const [AppColors.info, AppColors.sectionLearning],
      onTap: () => context.push('/assessment'),
      semanticLabel:
          '$count pending assessment${count > 1 ? 's' : ''} assigned to you',
    );
  }
}
