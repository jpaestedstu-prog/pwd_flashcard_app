import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/local/learning_path_data.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/learning_path.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_back_button.dart';
import '../lesson_step_launcher.dart';
import '../widgets/winding_trail.dart';

/// A playful, game-like "adventure trail" view of a single learning path:
/// the path's steps are laid out as a winding column of nodes (Duolingo-style)
/// that the learner climbs from bottom to top. Completed steps are filled with
/// a check, the current step pulses and is tappable, and locked steps are
/// dimmed.
///
/// This is an *additive* alternative to [LessonScreen]'s vertical timeline —
/// both read the same `learningPathProvider` progress and launch steps through
/// the shared [launchLessonStep], so progress stays perfectly in sync.
///
/// Overflow-safety lives in the shared [WindingTrail] widget (fixed geometry,
/// font-scaled rows, two-line capped labels) — see
/// test/lesson_trail_overflow_test.dart.
class LessonTrailScreen extends ConsumerWidget {
  final String pathId;

  const LessonTrailScreen({super.key, required this.pathId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = LearningPathData.allPaths;
    final path = paths.firstWhere(
      (p) => p.id == pathId,
      orElse: () => paths.first,
    );
    final progressMap = ref.watch(learningPathProvider);
    final progress = progressMap[path.id];
    final notifier = ref.read(learningPathProvider.notifier);

    // Auto-start the path on first visit, mirroring LessonScreen.
    if (progress == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.startPath(path.id);
      });
    }

    final categoryColor = path.category.color;
    final completedCount = progress?.completedStepIndices.length ?? 0;
    final totalSteps = path.totalSteps;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/learning-paths'),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(path.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Flexible(child: Text(path.title, overflow: TextOverflow.ellipsis)),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            children: [
              _TrailHeader(
                categoryColor: categoryColor,
                completedCount: completedCount,
                totalSteps: totalSteps,
                isCompleted: progress?.isCompleted ?? false,
              ),
              LessonTrail(
                path: path,
                progress: progress,
                categoryColor: categoryColor,
                onStep: (step) => launchLessonStep(context, step, path),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact progress banner above the trail.
class _TrailHeader extends StatelessWidget {
  const _TrailHeader({
    required this.categoryColor,
    required this.completedCount,
    required this.totalSteps,
    required this.isCompleted,
  });

  final Color categoryColor;
  final int completedCount;
  final int totalSteps;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final pct = totalSteps > 0 ? completedCount / totalSteps : 0.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            categoryColor.withValues(alpha: 0.15),
            categoryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: categoryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(
            isCompleted ? '🏆' : '🧭',
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCompleted
                      ? 'Adventure complete!'
                      : 'Climb the trail to master every step',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: categoryColor.withValues(alpha: 0.15),
                    color: categoryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$completedCount/$totalSteps',
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: categoryColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// The single-path winding trail: maps each step to a [TrailNode] and renders
/// them through the shared [WindingTrail].
///
/// Public (and provider-free) so it can be rendered directly with seed data in
/// the cross-device overflow suite without standing up Riverpod/Hive/router.
class LessonTrail extends StatelessWidget {
  const LessonTrail({
    super.key,
    required this.path,
    required this.progress,
    required this.categoryColor,
    required this.onStep,
  });

  final LearningPath path;
  final LearningPathProgress? progress;
  final Color categoryColor;
  final void Function(LessonStep step) onStep;

  @override
  Widget build(BuildContext context) {
    final steps = path.steps;
    final currentIndex = progress?.currentStepIndex ?? 0;
    return WindingTrail(
      nodes: [
        for (var i = 0; i < steps.length; i++)
          _nodeFor(steps[i], i, currentIndex),
      ],
    );
  }

  TrailNode _nodeFor(LessonStep step, int i, int currentIndex) {
    final isDone = progress?.completedStepIndices.contains(i) ?? false;
    final isCurrent = !isDone && i == currentIndex;
    final state = isDone
        ? TrailNodeState.done
        : isCurrent
            ? TrailNodeState.current
            : TrailNodeState.locked;
    return TrailNode(
      state: state,
      emoji: step.type.emoji,
      label: step.title,
      accent: categoryColor,
      pillText: isCurrent
          ? 'START'
          : isDone
              ? 'REPLAY'
              : null,
      onTap: state == TrailNodeState.locked ? null : () => onStep(step),
    );
  }
}
