import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/learning_path.dart';

class PathCard extends StatelessWidget {
  final LearningPath path;
  final LearningPathProgress? progress;
  final bool isUnlocked;
  final int index;
  final VoidCallback? onTap;

  const PathCard({
    super.key,
    required this.path,
    this.progress,
    required this.isUnlocked,
    required this.index,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final isCompleted = progress?.isCompleted ?? false;
    final completedSteps = progress?.completedStepIndices.length ?? 0;
    final totalSteps = path.totalSteps;
    final categoryColor = path.category.color;

    return Semantics(
      button: isUnlocked,
      enabled: isUnlocked,
      label:
          '${path.title} learning path. $completedSteps of $totalSteps steps completed.'
          '${isUnlocked ? "" : " Locked. Complete the previous path to unlock."}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: isUnlocked
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      hc.surface,
                      categoryColor.withValues(alpha: 0.04),
                    ],
                  )
                : null,
            color: isUnlocked ? null : hc.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCompleted
                  ? AppColors.success
                  : isUnlocked
                      ? categoryColor.withValues(alpha: 0.4)
                      : hc.border,
              width: isCompleted ? 2.5 : 1.5,
            ),
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: categoryColor.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // ─── Path number + emoji ────────
              _PathBadge(
                index: index,
                emoji: path.emoji,
                isCompleted: isCompleted,
                isUnlocked: isUnlocked,
                color: categoryColor,
              ),
              const SizedBox(width: 14),

              // ─── Title & progress ───────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path.title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isUnlocked
                            ? hc.textPrimary
                            : hc.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      path.description,
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (isUnlocked) ...[
                      const SizedBox(height: 8),
                      // Step dots
                      Row(
                        children: List.generate(totalSteps, (i) {
                          final isDone =
                              progress?.completedStepIndices.contains(i) ??
                                  false;
                          final isCurrent =
                              i == (progress?.currentStepIndex ?? 0) &&
                                  !isCompleted;
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: isCurrent ? 22 : 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? AppColors.success
                                  : isCurrent
                                      ? categoryColor
                                      : categoryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: isCurrent
                                  ? Border.all(
                                      color: categoryColor, width: 2)
                                  : null,
                              boxShadow: isCurrent
                                  ? [
                                      BoxShadow(
                                        color: categoryColor.withValues(alpha: 0.35),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : isDone
                                      ? [
                                          BoxShadow(
                                            color: AppColors.success.withValues(alpha: 0.25),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                            ),
                            child: isDone
                                ? const Icon(Icons.check_rounded,
                                    size: 10, color: Colors.white)
                                : null,
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),

              // ─── Status icon ────────────────
              if (isCompleted)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.25),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 22),
                )
              else if (!isUnlocked)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: hc.border.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded,
                      color: hc.textHint, size: 20),
                )
              else
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 18, color: hc.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _PathBadge extends StatelessWidget {
  final int index;
  final String emoji;
  final bool isCompleted;
  final bool isUnlocked;
  final Color color;

  const _PathBadge({
    required this.index,
    required this.emoji,
    required this.isCompleted,
    required this.isUnlocked,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.success.withValues(alpha: 0.15)
            : isUnlocked
                ? color.withValues(alpha: 0.15)
                : hc.border.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: (isCompleted ? AppColors.success : color)
                      .withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            emoji,
            style: TextStyle(
              fontSize: 28,
              color: isUnlocked ? null : Colors.grey,
            ),
          ),
          // Small path number
          Positioned(
            top: 2,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.success
                    : isUnlocked
                        ? color
                        : hc.textHint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${index + 1}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textOnPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
