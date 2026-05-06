import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/local/learning_path_data.dart';
import '../../../providers/app_providers.dart';
import '../widgets/path_card.dart';

class LearningPathListScreen extends ConsumerWidget {
  const LearningPathListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = LearningPathData.allPaths;
    final progressMap = ref.watch(learningPathProvider);
    final notifier = ref.read(learningPathProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Learning Paths'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Learning Journey 🗺️',
                      style: AppTypography.headlineMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: HCColor.of(context).textPrimary,
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05, end: 0),
                    const SizedBox(height: 6),
                    Text(
                      'Complete each path to unlock the next one. '
                      'Master all 12 categories to become a vocabulary champion!',
                      style: AppTypography.bodyMedium.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                    const SizedBox(height: 12),
                    // Overall progress bar
                    _OverallProgressBar(
                      completedCount: progressMap.values
                          .where((p) => p.isCompleted)
                          .length,
                      totalCount: paths.length,
                    ),
                  ],
                ),
              ),
            ),

            // ─── Path Cards ─────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final path = paths[index];
                    final progress = progressMap[path.id];
                    final isUnlocked = notifier.isPathUnlocked(path);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: PathCard(
                        path: path,
                        progress: progress,
                        isUnlocked: isUnlocked,
                        index: index,
                        onTap: isUnlocked
                            ? () => context.push('/learning-paths/${path.id}')
                            : null,
                      ),
                    )
                        .animate()
                        .fadeIn(
                          duration: 400.ms,
                          delay: (200 + index * 60).ms,
                        )
                        .slideY(begin: 0.08, end: 0);
                  },
                  childCount: paths.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallProgressBar extends StatelessWidget {
  final int completedCount;
  final int totalCount;

  const _OverallProgressBar({
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$completedCount',
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
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
                  '$completedCount / $totalCount paths completed',
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }
}
