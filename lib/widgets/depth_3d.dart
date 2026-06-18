import 'package:flutter/material.dart';

/// Shared "vibrant 3D depth" decoration kit.
///
/// These are pure paint-time layers — gradients, shadows, transforms — so they
/// render identically on every Android version and add no new platform calls.
/// The goal is to give flat gradient cards a sense of depth and dimension
/// (rich, layered, glossy) *without* making them brighter: we anchor on deep,
/// saturated tones rather than washing out to near-white pastels.
///
/// The pieces are deliberately small and composable so the Cards, Home, Games,
/// Stories and Progress surfaces can share one visual vocabulary:
///  - [Depth3D.vibrantGradient] / [Depth3D.anchor] / [Depth3D.shadows] — colour
///    + shadow helpers.
///  - [GlossySheen] — top-light → bottom-shade overlay for a rounded 3D form.
///  - [RimLight] — a 1px lit inner edge for a raised look.
///  - [DepthBubble] — a soft-lit translucent sphere accent.
///  - [Badge3D] — a raised, coin-like icon/emoji holder.
class Depth3D {
  Depth3D._();

  /// Normalises any [base] colour to a rich, deep, saturated anchor tone.
  ///
  /// Pale pastels are pulled down in lightness and nudged up in saturation so
  /// white foreground keeps strong contrast; colours that are already deep are
  /// left essentially unchanged.
  static Color anchor(Color base) {
    final hsl = HSLColor.fromColor(base);
    final lightness = hsl.lightness.clamp(0.0, 0.46);
    final saturation =
        (hsl.saturation < 0.5 ? hsl.saturation + 0.25 : hsl.saturation).clamp(
          0.0,
          1.0,
        );
    return hsl.withLightness(lightness).withSaturation(saturation).toColor();
  }

  /// A rich 3-stop gradient built around the deep [anchor] of [base].
  ///
  /// A vivid lighter shade up top gives a glossy sheen; the bulk stays deep so
  /// labels and icons keep contrast everywhere — vibrant, not washed out.
  static LinearGradient vibrantGradient(
    Color base, {
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    final deep = HSLColor.fromColor(anchor(base));
    final vivid = deep
        .withLightness((deep.lightness + 0.16).clamp(0.0, 0.60))
        .toColor();
    final deepest = deep
        .withLightness((deep.lightness - 0.07).clamp(0.0, 1.0))
        .toColor();
    return LinearGradient(
      colors: [vivid, deep.toColor(), deepest],
      stops: const [0.0, 0.45, 1.0],
      begin: begin,
      end: end,
    );
  }

  /// Layered drop shadows: a colour-tinted ambient glow (the "lift" off the
  /// page) plus a soft neutral grounding shadow. [pressed] tucks the surface
  /// down toward the page on touch.
  static List<BoxShadow> shadows(Color tint, {bool pressed = false}) {
    return [
      BoxShadow(
        color: tint.withValues(alpha: pressed ? 0.20 : 0.34),
        blurRadius: pressed ? 10 : 22,
        offset: Offset(0, pressed ? 4 : 12),
        spreadRadius: pressed ? -3 : -1,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: pressed ? 0.06 : 0.12),
        blurRadius: pressed ? 4 : 10,
        offset: Offset(0, pressed ? 2 : 5),
      ),
    ];
  }
}

/// A top-light → bottom-shade sheen that gives a flat fill a rounded, glossy 3D
/// form. Drop it as a [Positioned.fill] near the top of a clipped card stack
/// (above the gradient, below the content).
class GlossySheen extends StatelessWidget {
  const GlossySheen({super.key, this.topAlpha = 0.20, this.bottomAlpha = 0.10});

  /// Highlight strength at the top edge.
  final double topAlpha;

  /// Shade strength at the bottom edge (grounds the form).
  final double bottomAlpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: topAlpha),
              Colors.white.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: bottomAlpha),
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
      ),
    );
  }
}

/// A drop-in "vibrant 3D" fill for any tappable surface (button, chip, tile).
///
/// Paints, clipped to [radius]: a [Depth3D.vibrantGradient] base, a
/// [GlossySheen] top-light/bottom-shade, and a [RimLight] lit edge — the exact
/// layering the Cards/Home/Stories cards use, packaged so a button can reuse
/// the same look in one line. It is non-interactive (no gestures, sizes to its
/// parent), so drop it as the *background* of a `Stack` — e.g. a
/// `Positioned.fill` behind a transparent `Material`/button content, or as a
/// `Stack`'s first child under `Padding`ed content. The owning surface keeps
/// its own ripple, semantics, sizing and tap handling untouched.
class Depth3DFill extends StatelessWidget {
  const Depth3DFill({
    super.key,
    required this.color,
    required this.radius,
    this.topAlpha = 0.22,
    this.bottomAlpha = 0.12,
    this.rimAlpha = 0.20,
  });

  /// Base colour; normalised to a deep, saturated [Depth3D.anchor] tone so
  /// white foreground keeps strong contrast — vibrant, not washed out.
  final Color color;

  /// Corner radius; match the host surface so the gloss/rim hug the edges.
  final double radius;

  /// Top highlight strength of the [GlossySheen].
  final double topAlpha;

  /// Bottom shade strength of the [GlossySheen].
  final double bottomAlpha;

  /// Lit-edge strength of the [RimLight].
  final double rimAlpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: Depth3D.vibrantGradient(color),
              ),
            ),
            GlossySheen(topAlpha: topAlpha, bottomAlpha: bottomAlpha),
            RimLight(radius: radius, alpha: rimAlpha),
          ],
        ),
      ),
    );
  }
}

/// A 1px inner rim-light border that reads as a raised, lit edge. Place it as
/// the top-most [Positioned.fill] of a clipped card stack.
class RimLight extends StatelessWidget {
  const RimLight({super.key, required this.radius, this.alpha = 0.18});

  final double radius;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: alpha)),
        ),
      ),
    );
  }
}

/// A soft-lit translucent sphere used as a floating decorative accent. The
/// off-centre radial highlight makes it read as a 3D bubble rather than a flat
/// disc. Non-interactive (wrapped in [IgnorePointer]).
class DepthBubble extends StatelessWidget {
  const DepthBubble({super.key, required this.size, this.light = 0.16});

  final double size;

  /// Peak highlight opacity at the lit edge.
  final double light;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.4, -0.4),
            radius: 0.95,
            colors: [
              Colors.white.withValues(alpha: light + 0.08),
              Colors.white.withValues(alpha: light * 0.4),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}

/// A raised, coin-like badge holding an [icon] or an [emoji]. A spherical
/// radial highlight plus a drop shadow make it read as a 3D object floating
/// just above the card surface. Sized exactly to [size] so it is a drop-in
/// replacement for a flat icon container (no layout change).
class Badge3D extends StatelessWidget {
  const Badge3D({
    super.key,
    required this.size,
    this.icon,
    this.emoji,
    this.iconSize,
    this.circle = true,
    this.borderRadius,
  }) : assert(icon != null || emoji != null, 'Badge3D needs an icon or emoji');

  final double size;
  final IconData? icon;
  final String? emoji;

  /// Glyph size; defaults to half the badge size.
  final double? iconSize;

  /// Circular by default; pass false for a rounded-square badge.
  final bool circle;

  /// Corner radius when [circle] is false. Defaults to ~30% of [size].
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final glyph = iconSize ?? size * 0.5;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle
            ? null
            : BorderRadius.circular(borderRadius ?? size * 0.3),
        // Off-centre light source gives the disc a glossy, domed look.
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.45),
          colors: [
            Color(0x75FFFFFF), // white @ ~0.46
            Color(0x29FFFFFF), // white @ ~0.16
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.40),
          width: 1.5,
        ),
        boxShadow: [
          // Drop shadow lifts the badge off the card.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          // Faint top bloom (rim light).
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: icon != null
          ? Icon(
              icon,
              size: glyph,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              // height:1.0 + even leading strips the asymmetric line-box padding
              // emoji glyphs carry, so the glyph sits dead-centre (vertically and
              // horizontally) inside the badge at every font scale.
              child: Text(
                emoji!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: glyph,
                  height: 1.0,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ),
    );
  }
}
