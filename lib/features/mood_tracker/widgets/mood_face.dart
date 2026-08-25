import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../models/mood_models.dart';

/// One selectable mood face.
///
/// Extracted from the check-in screen so the full-page grid and the compact
/// post-game strip cannot drift apart — the same target sizes, the same
/// selected state, and the same screen-reader label in both places.
class MoodFace extends StatelessWidget {
  final MoodType mood;
  final bool isSelected;
  final bool isFilipino;
  final VoidCallback onTap;

  /// Smaller face for inline use inside a result dialog, where a full-size
  /// grid would push the buttons off the card.
  final bool compact;

  const MoodFace({
    super.key,
    required this.mood,
    required this.isSelected,
    required this.isFilipino,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final label = mood.labelOf(isFilipino: isFilipino);

    // The border and label take `darkColor`: the pale `color` swatches
    // (happy, tired, sad) are for fills only and do not read as an outline on
    // a white card, let alone on the high-contrast theme.
    final accent = mood.darkColor;

    final width = compact
        ? 84.0
        : context.responsiveTier<double>(
            phone: 100,
            tablet: 130,
            large: 160,
            xl: 180,
            ultra: 200,
          );

    final verticalPadding = compact
        ? 10.0
        : context.responsiveTier<double>(
            phone: 14,
            tablet: 18,
            large: 22,
            xl: 26,
          );

    final emojiSize = compact ? 28.0 : (context.isTablet ? 44.0 : 36.0);

    return Semantics(
      button: true,
      selected: isSelected,
      label: isFilipino ? 'Pakiramdam na $label' : '$label mood',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: width,
          padding: EdgeInsets.symmetric(
            vertical: verticalPadding,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? accent.withValues(alpha: 0.15) : hc.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? accent : hc.border,
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 4 : 8),
                decoration: isSelected
                    ? BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      )
                    : null,
                child: Text(
                  mood.emoji,
                  style: TextStyle(fontSize: emojiSize),
                ),
              ),
              SizedBox(height: compact ? 4 : 6),
              Text(
                label,
                style: (compact
                        ? AppTypography.labelSmall
                        : AppTypography.labelMedium)
                    .copyWith(
                  color: isSelected ? accent : hc.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
