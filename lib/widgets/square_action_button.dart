import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/responsive_utils.dart';
import 'depth_3d.dart';

/// A compact, square icon-over-label action button.
///
/// This is the shared form of the bottom-bar buttons used by the Flashcards →
/// Cards viewer (Prev / FSL / Flip / Next): a rounded square holding an icon,
/// with a small caption beneath. It is used in the Stories reader's bottom
/// navigation bar so its Back / FSL / Next controls match that look.
///
/// Overflow-safe at any font scale: the square grows with the Font Size setting
/// but stays capped (so the strip never balloons), and the label sits in a
/// fixed-width [FittedBox] that scales DOWN to fit rather than wrapping or
/// pushing the button wider — keeping it safe on every Android phone/tablet.
class SquareActionButton extends StatelessWidget {
  /// The glyph shown in the square (e.g. an arrow for Back/Next).
  final IconData icon;

  /// The caption beneath the square (e.g. "Back", "Next", "FSL").
  final String label;

  /// Tapped when [enabled] and not [loading]. Null disables the button.
  final VoidCallback? onTap;

  /// Accent colour. Defaults to the app primary.
  final Color? color;

  /// Greys the button out and blocks taps when false.
  final bool enabled;

  /// Shows a spinner in place of the icon and blocks taps (e.g. while an FSL
  /// clip is resolving). The button still reads as enabled to screen readers.
  final bool loading;

  /// Spoken description for screen readers. Defaults to "<label> button".
  final String? semanticLabel;

  const SquareActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.enabled = true,
    this.loading = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = enabled
        ? (color ?? AppColors.primary)
        : HCColor.of(context).textSecondary.withValues(alpha: 0.3);
    // The tap target grows with the Font Size setting but stays capped so the
    // strip never balloons; a 54dp base keeps it comfortably above the 48dp
    // accessibility floor for child / motor-impaired users.
    final box = context.scaledHeightCapped(54, max: 1.3);
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? '$label button',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: (enabled && !loading) ? onTap : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: box,
                height: box,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  // Enabled: a deep vibrant fill (painted below) lifted by a
                  // colour-tinted depth shadow. Disabled: the original flat
                  // tinted tile so it clearly reads as unavailable.
                  color: enabled ? null : c.withValues(alpha: 0.12),
                  border:
                      enabled ? null : Border.all(color: c.withValues(alpha: 0.15)),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                            color: Depth3D.anchor(c).withValues(alpha: 0.34),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                            spreadRadius: -1,
                          ),
                        ]
                      : [],
                ),
                // Icon scales with the box (itself text-scale aware) so it never
                // clips, and never grows past the box at XL font sizes. While
                // loading, a spinner takes the icon's place. White-on-deep when
                // enabled; the muted accent on the flat tile when disabled.
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (enabled)
                      Positioned.fill(child: Depth3DFill(color: c, radius: 16)),
                    loading
                        ? Padding(
                            padding: EdgeInsets.all(box * 0.28),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                enabled ? Colors.white : c,
                              ),
                            ),
                          )
                        : Icon(
                            icon,
                            color: enabled ? Colors.white : c,
                            size: box * 0.48,
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Fixed-width label that scales DOWN to fit (FittedBox) instead of
              // wrapping or pushing the button wider than its cell — so the
              // strip can never overflow horizontally at any font scale.
              SizedBox(
                width: box + 24,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppTypography.labelSmall.copyWith(color: c),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
