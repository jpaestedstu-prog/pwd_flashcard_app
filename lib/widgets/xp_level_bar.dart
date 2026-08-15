import 'package:flutter/material.dart';

import '../core/services/xp_level_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../data/models/models.dart';
import 'app_card.dart';

/// The learner's level, XP and progress towards the next level.
///
/// One implementation shared by every surface that shows the level — the
/// Student / Player-with-Progress home, the Child home, and the Player Profile
/// — so the number a learner sees can never differ between two screens.
///
/// **The label always matches the bar.** Both are scoped to the *current level
/// band*: at 115 total XP on a level that runs 100 → 300, this reads "15 / 200
/// XP" over a bar filled 7.5%. The bar previously sat next to "115 / 300 XP",
/// which reads as 38% full — two denominators in one row, which is precisely
/// the kind of thing the learners this app is for cannot be asked to reconcile.
/// Lifetime XP is still announced to screen readers via [Semantics].
class XpLevelBar extends StatelessWidget {
  final LearningProgress progress;

  /// Adds a line naming the next level and the XP still needed to reach it.
  /// On at the Player Profile, where there is room for a goal; off on the
  /// home screens, where the bar is one row in a dense column.
  final bool showNextGoal;

  const XpLevelBar({
    super.key,
    required this.progress,
    this.showNextGoal = false,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final xp = XpService.calculateXp(progress);
    final level = XpService.currentLevel(progress);
    final next = XpService.nextLevel(progress);
    final fraction = XpService.progressToNextLevel(progress);
    final into = XpService.xpIntoLevel(progress);
    final span = XpService.xpLevelSpan(progress);
    final toNext = XpService.xpToNextLevel(progress);

    return Semantics(
      label:
          'Level ${level.level} ${level.title}, $xp XP total, '
          '${toNext != null ? '$toNext XP to level ${next!.level} ${next.title}' : 'Max level reached'}',
      // The Row below spells the same thing out in fragments; let the one
      // sentence above stand for the whole card.
      excludeSemantics: true,
      child: AppCard(
        color: hc.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Level badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: hc.heroGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    level.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                // Level info + XP bar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Lv.${level.level} ${level.title}',
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.w800,
                                color: hc.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Spacer(),
                          Text(
                            span != null ? '$into / $span XP' : '$xp XP ✨',
                            style: AppTypography.labelSmall.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 6,
                          backgroundColor: hc.border,
                          valueColor: AlwaysStoppedAnimation<Color>(hc.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showNextGoal && next != null && toNext != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(next.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$toNext XP to Lv.${next.level} ${next.title}',
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
