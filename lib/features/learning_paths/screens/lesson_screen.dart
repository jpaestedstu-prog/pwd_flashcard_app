import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/score_utils.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/local/learning_path_data.dart';
import '../../../data/models/learning_path.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';

/// Detail screen for a single learning path showing all steps.
class LessonScreen extends ConsumerWidget {
  final String pathId;

  const LessonScreen({super.key, required this.pathId});

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
    final categoryColor = path.category.color;

    // Auto-start path on first visit
    if (progress == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.startPath(path.id);
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: () => context.go('/learning-paths'),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(path.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(path.title),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Path header ──────────────────
              _PathHeader(path: path, progress: progress),

              const SizedBox(height: 28),

              // ─── Steps timeline ───────────────
              ...path.steps.asMap().entries.map((entry) {
                final i = entry.key;
                final step = entry.value;
                final isCompleted =
                    progress?.completedStepIndices.contains(i) ?? false;
                final isCurrent = !isCompleted &&
                    i == (progress?.currentStepIndex ?? 0);
                final isLocked = !isCompleted && !isCurrent;
                final isLast = i == path.steps.length - 1;
                final bestScore = progress?.bestScores[i];

                return _StepTile(
                  step: step,
                  index: i,
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                  isLocked: isLocked,
                  isLast: isLast,
                  bestScore: bestScore,
                  categoryColor: categoryColor,
                  onStart: isCurrent
                      ? () => _navigateToStep(context, step, path)
                      : isCompleted
                          ? () => _navigateToStep(context, step, path)
                          : null,
                )
                    .animate()
                    .fadeIn(duration: 350.ms, delay: (200 + i * 100).ms)
                    .slideX(begin: 0.05, end: 0);
              }),

              const SizedBox(height: 20),

              // ─── Overall completion message ───
              if (progress?.isCompleted ?? false)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.success,
                        AppColors.success.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text('🎉', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      Text(
                        'Path Mastered!',
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You\'ve completed all steps in ${path.title}!',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0)),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToStep(BuildContext context, LessonStep step, LearningPath path) {
    final stepIndex = path.steps.indexOf(step);
    final totalSteps = path.steps.length;

    switch (step.type) {
      case LessonStepType.flashcards:
        context.push(
          '/learning-path-viewer/${path.category.index}'
          '?pathId=${path.id}&stepIndex=$stepIndex&totalSteps=$totalSteps',
        );
        break;
      case LessonStepType.game:
      case LessonStepType.quiz:
        if (step.gameType != null) {
          final gameRoute = switch (step.gameType!) {
            GameType.wordMatch => 'word-match',
            GameType.spellingBee => 'spelling-bee',
            GameType.memoryMatch => 'memory-match',
            GameType.dragAndDrop => 'drag-drop',
            GameType.flashcardQuiz => 'flashcard-quiz',
            GameType.pronunciation => 'pronunciation',
            GameType.sentenceBuilder => 'sentence-builder',
            GameType.storyQuiz => 'flashcard-quiz',
            GameType.tracing => 'tracing',
            GameType.fslPractice => 'fsl-practice',
            GameType.jigsawPuzzle => 'jigsaw-puzzle',
            GameType.pictureWord => 'picture-word',
          };
          final difficulty = step.gameDifficulty?.name ?? 'medium';
          context.push(
            '/games/$gameRoute?difficulty=$difficulty&categories=${path.category.index}',
          );
        }
        break;
      case LessonStepType.story:
        context.push('/stories');
        break;
      case LessonStepType.smartReview:
        context.push('/smart-review');
        break;
    }
  }
}

// ────────────────────────────────────────
// Path Header
// ────────────────────────────────────────
class _PathHeader extends StatelessWidget {
  final LearningPath path;
  final LearningPathProgress? progress;

  const _PathHeader({required this.path, this.progress});

  @override
  Widget build(BuildContext context) {
    final completedSteps = progress?.completedStepIndices.length ?? 0;
    final totalSteps = path.totalSteps;
    final pct = totalSteps > 0 ? completedSteps / totalSteps : 0.0;
    final categoryColor = path.category.color;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(path.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path.title,
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${path.category.label} vocabulary',
                      style: AppTypography.bodyMedium.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: categoryColor.withValues(alpha: 0.15),
                    color: categoryColor,
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$completedSteps/$totalSteps',
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: categoryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1, end: 0);
  }
}

// ────────────────────────────────────────
// Step Tile (timeline item)
// ────────────────────────────────────────
class _StepTile extends StatelessWidget {
  final LessonStep step;
  final int index;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLocked;
  final bool isLast;
  final double? bestScore;
  final Color categoryColor;
  final VoidCallback? onStart;

  const _StepTile({
    required this.step,
    required this.index,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLocked,
    required this.isLast,
    this.bestScore,
    required this.categoryColor,
    this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Timeline line + dot ────────
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Dot
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success
                        : isCurrent
                            ? categoryColor
                            : HCColor.of(context).border,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: categoryColor, width: 3)
                        : null,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: categoryColor.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: AppColors.textOnPrimary)
                        : Text(
                            '${index + 1}',
                            style: AppTypography.labelSmall.copyWith(
                              color: isCurrent
                                  ? AppColors.textOnPrimary
                                  : HCColor.of(context).textSecondary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isCompleted
                          ? AppColors.success.withValues(alpha: 0.3)
                          : HCColor.of(context).border,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ─── Step content card ──────────
          Expanded(
            child: GestureDetector(
              onTap: onStart,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? HCColor.of(context).surface
                      : isCompleted
                          ? AppColors.success.withValues(alpha: 0.05)
                          : HCColor.of(context).surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrent
                        ? categoryColor.withValues(alpha: 0.4)
                        : isCompleted
                            ? AppColors.success.withValues(alpha: 0.2)
                            : HCColor.of(context).border,
                    width: isCurrent ? 2 : 1,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: categoryColor.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          step.type.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step.title,
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isLocked
                                  ? HCColor.of(context).textSecondary
                                  : HCColor.of(context).textPrimary,
                            ),
                          ),
                        ),
                        if (bestScore != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _scoreColor(bestScore!).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${(bestScore! * 100).round()}%',
                              style: AppTypography.labelSmall.copyWith(
                                color: _scoreColor(bestScore!),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.description,
                      style: AppTypography.bodySmall.copyWith(
                        color: HCColor.of(context).textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onStart,
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: Text(
                            isCompleted ? 'Retry' : 'Start',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.textOnPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: categoryColor,
                            foregroundColor: AppColors.textOnPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (isLocked) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.lock_rounded,
                              size: 14, color: HCColor.of(context).textHint),
                          const SizedBox(width: 4),
                          Text(
                            'Complete the previous step first',
                            style: AppTypography.bodySmall.copyWith(
                              color: HCColor.of(context).textHint,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) => scoreColor(score);
}
