import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/local/learning_path_data.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/learning_path.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_back_button.dart';
import '../widgets/winding_trail.dart';

/// Top-level "learning world": every learning path is a region on one big
/// winding trail. Completed regions show a check, the next region to tackle
/// pulses, other unlocked regions are tappable, and regions whose prerequisite
/// isn't met are locked.
///
/// Tapping an unlocked region drills into that path's [LessonTrailScreen].
/// This is an *additive* alternative to the card-list [LearningPathListScreen];
/// both read the same `learningPathProvider`, so progress stays in sync.
class LearningWorldScreen extends ConsumerWidget {
  const LearningWorldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = LearningPathData.allPaths;
    final progressMap = ref.watch(learningPathProvider);
    final notifier = ref.read(learningPathProvider.notifier);

    final completedRegions =
        progressMap.values.where((p) => p.isCompleted).length;

    // The "current" region is the first unlocked, not-yet-completed path — the
    // single node that pulses. Every other unlocked-incomplete path is
    // [available] (tappable, calm).
    int? currentIndex;
    for (var i = 0; i < paths.length; i++) {
      final prog = progressMap[paths[i].id];
      final done = prog?.isCompleted ?? false;
      if (!done && notifier.isPathUnlocked(paths[i])) {
        currentIndex = i;
        break;
      }
    }

    final nodes = <TrailNode>[
      for (var i = 0; i < paths.length; i++)
        _regionNode(
          context,
          path: paths[i],
          progress: progressMap[paths[i].id],
          unlocked: notifier.isPathUnlocked(paths[i]),
          isCurrent: i == currentIndex,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/learning-paths'),
        title: const Text('Adventure Map 🗺️'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            children: [
              _WorldHeader(
                completedRegions: completedRegions,
                totalRegions: paths.length,
              ),
              WindingTrail(nodes: nodes),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  TrailNode _regionNode(
    BuildContext context, {
    required LearningPath path,
    required LearningPathProgress? progress,
    required bool unlocked,
    required bool isCurrent,
  }) {
    final done = progress?.isCompleted ?? false;
    final completedSteps = progress?.completedStepIndices.length ?? 0;
    final total = path.totalSteps;

    final TrailNodeState state;
    if (done) {
      state = TrailNodeState.done;
    } else if (!unlocked) {
      state = TrailNodeState.locked;
    } else if (isCurrent) {
      state = TrailNodeState.current;
    } else {
      state = TrailNodeState.available;
    }

    final String? pill = switch (state) {
      TrailNodeState.done => 'DONE',
      TrailNodeState.current =>
        completedSteps > 0 ? '$completedSteps/$total' : 'START',
      TrailNodeState.available => 'ENTER',
      TrailNodeState.locked => null,
    };

    return TrailNode(
      state: state,
      emoji: path.emoji,
      label: path.title,
      accent: path.category.color,
      pillText: pill,
      onTap: state == TrailNodeState.locked
          ? null
          : () => context.push('/learning-paths/${path.id}/trail'),
    );
  }
}

/// Banner showing how many regions are mastered.
class _WorldHeader extends StatelessWidget {
  const _WorldHeader({
    required this.completedRegions,
    required this.totalRegions,
  });

  final int completedRegions;
  final int totalRegions;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final pct = totalRegions > 0 ? completedRegions / totalRegions : 0.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.secondary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Text('🗺️', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completedRegions >= totalRegions && totalRegions > 0
                      ? 'You mastered the whole world!'
                      : 'Explore every region to become a champion',
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
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$completedRegions/$totalRegions',
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
