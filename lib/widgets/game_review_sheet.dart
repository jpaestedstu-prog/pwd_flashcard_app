import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/enums.dart';
import '../l10n/app_localizations.dart';
import 'animated_dialogs.dart';

/// Represents one word/item result from a game round.
class GameReviewItem {
  final String wordEnglish;
  final String wordFilipino;
  final FlashcardCategory category;
  final bool isCorrect;

  /// Optional: what the user answered (for wrong answers)
  final String? userAnswer;

  const GameReviewItem({
    required this.wordEnglish,
    required this.wordFilipino,
    required this.category,
    required this.isCorrect,
    this.userAnswer,
  });
}

/// Shows a bottom sheet with a word-by-word review of the game.
Future<void> showGameReview(
  BuildContext context, {
  required List<GameReviewItem> items,
  required String gameTitle,
}) {
  return showAnimatedBottomSheet(
    context,
    builder: (ctx) => _GameReviewSheet(items: items, gameTitle: gameTitle),
  );
}

class _GameReviewSheet extends StatelessWidget {
  final List<GameReviewItem> items;
  final String gameTitle;

  const _GameReviewSheet({required this.items, required this.gameTitle});

  @override
  Widget build(BuildContext context) {
    final correct = items.where((i) => i.isCorrect).length;
    final wrong = items.length - correct;
    final l10n = AppLocalizations.of(context)!;

    // Shown via [showAnimatedBottomSheet], which already height-caps the sheet
    // (to a fraction of the viewport) and draws the drag handle. So this body
    // is a fixed header + a flexible, scrolling list + a fixed close button —
    // the list shrinks to its content but scrolls (never overflows) when the
    // round has more words than fit a short viewport at a large font scale.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── Fixed Header ─────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.rate_review_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      l10n.gameReviewTitle(gameTitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Summary badges — a centered Wrap so the two pills drop to a
              // second line instead of overflowing on a narrow sheet at a
              // large font scale.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  _SummaryBadge(
                    icon: Icons.check_circle_rounded,
                    label: l10n.reviewCorrectCount(correct),
                    color: AppColors.success,
                  ),
                  _SummaryBadge(
                    icon: Icons.cancel_rounded,
                    label: l10n.reviewWrongCount(wrong),
                    color: wrong > 0 ? AppColors.error : AppColors.textHint,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: HCColor.of(context).border),
            ],
          ),
        ),

        // ─── Scrollable Word List ─────────
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return _ReviewCard(item: item, index: index)
                  .animate()
                  .fadeIn(
                    duration: 300.ms,
                    delay: Duration(milliseconds: 40 * index),
                  )
                  .slideX(begin: 0.05, end: 0);
            },
          ),
        ),

        // ─── Close Button ─────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                l10n.gotIt,
                style: AppTypography.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 6),
              ],
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final GameReviewItem item;
  final int index;

  const _ReviewCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.isCorrect
            ? AppColors.success.withValues(alpha: 0.06)
            : AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isCorrect
              ? AppColors.success.withValues(alpha: 0.25)
              : AppColors.error.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: (item.isCorrect ? AppColors.success : AppColors.error)
                .withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.isCorrect
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.error.withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(
                  color: (item.isCorrect ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              item.isCorrect ? Icons.check_rounded : Icons.close_rounded,
              color: item.isCorrect ? AppColors.success : AppColors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Word info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.wordEnglish,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: HCColor.of(context).textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.wordFilipino,
                  style: AppTypography.bodySmall.copyWith(
                    color: HCColor.of(context).textSecondary,
                  ),
                ),
                if (!item.isCorrect && item.userAnswer != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.yourAnswerLabel,
                        style: AppTypography.labelSmall.copyWith(
                          color: HCColor.of(context).textHint,
                        ),
                      ),
                      // A long wrong answer must ellipsise, not push the row
                      // past the card's width.
                      Flexible(
                        child: Text(
                          item.userAnswer!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Category chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: item.category.color.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.category.icon,
              size: 16,
              color: item.category.darkColor,
            ),
          ),
        ],
      ),
    );
  }
}
