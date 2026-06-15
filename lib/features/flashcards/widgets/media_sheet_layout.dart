import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';

/// Shared, overflow-proof scaffold for the media bottom sheets
/// ("Show Me" clips and the "Examples" gallery).
///
/// Responsive across every phone/tablet size and both orientations:
///   * the media is **height-capped** (≤ 55% of the — possibly short, landscape
///     — viewport, and never taller than the screen is wide) so a square or
///     portrait clip can't dominate and push the sheet off-screen;
///   * the whole sheet is capped to 92% of the screen height; and
///   * the content **scrolls** if it still doesn't fit.
///
/// Together these guarantee there is never a `RenderFlex` bottom overflow,
/// regardless of clip aspect ratio, screen dimensions, or font scale.
class MediaSheetLayout extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? caption;

  /// Builds the media to show, given the maximum height it must fit within.
  /// The returned widget is placed in a box that is exactly that tall and as
  /// wide as the sheet, so it should fit itself (e.g. `Center` + `AspectRatio`,
  /// or `BoxFit.contain`).
  final Widget Function(double maxMediaHeight) mediaBuilder;

  /// Optional widget shown directly under the media (e.g. gallery page dots).
  final Widget? belowMedia;

  const MediaSheetLayout({
    super.key,
    required this.icon,
    required this.title,
    required this.mediaBuilder,
    this.iconColor = AppColors.secondaryDark,
    this.caption,
    this.belowMedia,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final size = MediaQuery.sizeOf(context);
    final maxMediaHeight =
        math.min(size.width, size.height * 0.55).clamp(96.0, 520.0);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.92),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: BoxDecoration(
            color: hc.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hc.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: iconColor, size: context.scaleIcon(24)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: AppTypography.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Media — fixed, capped height so it can never overflow.
                SizedBox(
                  width: double.infinity,
                  height: maxMediaHeight,
                  child: mediaBuilder(maxMediaHeight),
                ),
                if (belowMedia != null) ...[
                  const SizedBox(height: 12),
                  belowMedia!,
                ],
                if (caption != null && caption!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    caption!,
                    style: AppTypography.bodyMedium
                        .copyWith(color: hc.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
