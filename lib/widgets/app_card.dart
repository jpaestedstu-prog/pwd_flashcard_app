import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'depth_3d.dart';
import 'tilt_3d.dart';

/// Project-wide card surface.
///
/// The codebase had ~5 different ad-hoc card styles (`Container` with
/// rounded corners + soft shadow, `Card` with custom elevation, the shop
/// item card, the settings profile gradient card, etc.). [AppCard]
/// captures the common shape — 24px radius, soft shadow, optional
/// gradient — so new screens stay visually consistent.
///
/// Specialty cards that need a unique look (`EnhancedCategoryCard`,
/// `ThemePreviewCard`) keep their own implementation; this is for the
/// regular content cards that show up everywhere.
class AppCard extends StatelessWidget {
  /// Card content.
  final Widget child;

  /// Inner padding. Defaults to 16 (matches Material3 conventions).
  final EdgeInsetsGeometry padding;

  /// Outer margin. Defaults to none — let the parent layout decide.
  final EdgeInsetsGeometry? margin;

  /// Corner radius. Defaults to 24, matching the rest of the app.
  final double borderRadius;

  /// Optional gradient. Mutually exclusive with [color]; if both are set,
  /// the gradient wins.
  final Gradient? gradient;

  /// Optional solid colour. Defaults to the theme's surface colour.
  final Color? color;

  /// Optional border colour. Defaults to no border.
  final Color? borderColor;

  /// Border thickness. Only applied when [borderColor] is non-null.
  final double borderWidth;

  /// Whether to draw the soft shadow (uses [AppColors.softShadow]).
  /// Defaults to true.
  final bool elevated;

  /// Whether [child] should be clipped to the rounded shape. Useful when
  /// the child is an image or gradient. Defaults to false.
  final bool clip;

  /// Opt-in "vibrant 3D depth" treatment for gradient/colour cards: a glossy
  /// top sheen, a lit inner rim, and layered colour-tinted shadows (see
  /// [Depth3D]). Implies clipping. Defaults to false so existing cards are
  /// untouched.
  final bool depth;

  /// Shadow-glow tint for [depth] mode. Defaults to a deep, saturated anchor of
  /// the gradient's first colour (or [color]).
  final Color? depthTint;

  /// In [depth] mode, add soft floating corner bubbles for extra dimension.
  /// Skip on tiny/compact tiles where they'd crowd the content.
  final bool depthBubbles;

  /// Optional tap handler. When set, the card becomes interactive with
  /// a Material ripple respecting the rounded corners.
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 24,
    this.gradient,
    this.color,
    this.borderColor,
    this.borderWidth = 1.5,
    this.elevated = true,
    this.clip = false,
    this.depth = false,
    this.depthTint,
    this.depthBubbles = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final hc = HCColor.of(context);
    final resolvedColor = gradient != null ? null : (color ?? hc.surface);

    final glowTint = depth
        ? Depth3D.anchor(
            depthTint ??
                (gradient != null && gradient!.colors.isNotEmpty
                    ? gradient!.colors.first
                    : (color ?? hc.primary)),
          )
        : null;

    final decoration = BoxDecoration(
      color: resolvedColor,
      gradient: gradient,
      borderRadius: radius,
      boxShadow: depth
          ? Depth3D.shadows(glowTint!)
          : (elevated ? AppColors.softShadow : null),
      border: borderColor != null
          ? Border.all(color: borderColor!, width: borderWidth)
          : null,
    );

    Widget content = Padding(padding: padding, child: child);
    if (depth) {
      // Layer the glossy sheen + lit rim over the gradient, clipped to shape.
      // The padded content sizes the Stack; the overlays are IgnorePointer so
      // taps still reach the InkWell/GestureDetector below.
      content = ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            if (depthBubbles) ...[
              const Positioned(
                top: -14,
                right: -12,
                child: DepthBubble(size: 60),
              ),
              const Positioned(
                bottom: -12,
                left: -10,
                child: DepthBubble(size: 40, light: 0.12),
              ),
            ],
            const Positioned.fill(child: GlossySheen()),
            content,
            Positioned.fill(child: RimLight(radius: borderRadius)),
          ],
        ),
      );
    } else if (clip) {
      content = ClipRRect(borderRadius: radius, child: content);
    }

    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: decoration,
      child: content,
    );

    if (onTap == null) {
      return margin == null ? box : Padding(padding: margin!, child: box);
    }

    // Wrap in Material so the ripple respects the rounded shape. Cards are
    // large surfaces, so the 3D press tilt stays gentle.
    final tappable = Pressable3D(
      maxTilt: 0.035,
      pressScale: 0.985,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(decoration: decoration, child: content),
        ),
      ),
    );
    return margin == null
        ? tappable
        : Padding(padding: margin!, child: tappable);
  }
}
