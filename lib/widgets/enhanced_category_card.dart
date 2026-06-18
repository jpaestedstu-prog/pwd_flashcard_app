import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/responsive_utils.dart';
import '../data/models/enums.dart';
import 'depth_3d.dart';
import 'tilt_3d.dart';

/// An enhanced category card with painted wave decorations, gradient background,
/// subtle entrance animation, and a 3D tilt-on-press interaction.
///
/// Replaces the plain `_CategoryCard` in the home screen grid with richer
/// visual design while preserving accessibility.
class EnhancedCategoryCard extends StatefulWidget {
  const EnhancedCategoryCard({
    super.key,
    required this.category,
    required this.wordCount,
    required this.progress,
    required this.onTap,
  });

  final FlashcardCategory category;
  final int wordCount;
  final double progress;
  final VoidCallback onTap;

  @override
  State<EnhancedCategoryCard> createState() => _EnhancedCategoryCardState();
}

class _EnhancedCategoryCardState extends State<EnhancedCategoryCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Anchor on the deep, saturated category tone (shared with the Cards deck
    // grid via Depth3D) so the card stays rich and readable rather than fading
    // to a washed-out pastel.
    final deep = widget.category.darkColor;

    return Semantics(
      button: true,
      label:
          '${widget.category.label} flashcards, ${widget.wordCount} words, '
          '${(widget.progress * 100).round()} percent progress',
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: Pressable3D(
          pressScale: 0.95,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: Depth3D.shadows(deep, pressed: _pressed),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // ─── Rich, depth-balanced gradient ───
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: Depth3D.vibrantGradient(deep),
                      ),
                    ),
                  ),

                  // ─── Wave decoration ────────────────
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _WavePainter(
                        color: Colors.white.withValues(alpha: 0.12),
                        seed: widget.category.index,
                      ),
                    ),
                  ),

                  // ─── Floating 3D bubbles ────────────
                  const Positioned(
                    top: -18,
                    right: -16,
                    child: DepthBubble(size: 84, light: 0.18),
                  ),
                  const Positioned(
                    bottom: -14,
                    left: -12,
                    child: DepthBubble(size: 56, light: 0.13),
                  ),

                  // ─── Glossy sheen + lit rim ─────────
                  const Positioned.fill(child: GlossySheen()),
                  const Positioned.fill(child: RimLight(radius: 24)),

                  // ─── Content ────────────────────────
                  Positioned.fill(
                    child: Padding(
                      // Consistent inset on every side so the badge, label,
                      // stats row and bar share one balanced margin.
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          // Top: raised 3D badge + category label.
                          //
                          // Both sit in a Flexible + FittedBox so they render at
                          // full size when there's room, yet scale down (rather
                          // than crush the badge or clip the text) at large font
                          // scales or in a short cell. The badge gets the larger
                          // flex share so it stays prominent instead of being
                          // squeezed to a sliver by an even split.
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  flex: 3,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Badge3D(
                                      size: context.scaleIcon(54),
                                      icon: widget.category.icon,
                                      iconSize: context.scaleIcon(28),
                                      circle: false,
                                      borderRadius: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Flexible(
                                  flex: 2,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      widget.category.label,
                                      style: AppTypography.titleMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.28,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Bottom: word count (left) + progress chip (right),
                          // mirroring the Flashcards deck card so the two
                          // surfaces read as one family.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_stories_rounded,
                                      size: context.scaleIcon(14),
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '${widget.wordCount} words',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${(widget.progress * 100).round()}%',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _MiniProgressBar(progress: widget.progress),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small linear progress bar with a soft glow effect.
class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            // Track
            Container(color: Colors.white.withValues(alpha: 0.15)),
            // Fill
            FractionallySizedBox(
              widthFactor: progress.clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints decorative wave curves unique to each category.
class _WavePainter extends CustomPainter {
  _WavePainter({required this.color, required this.seed});

  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Use seed to vary wave pattern per category
    final phase = seed * 0.6;
    final amplitude = size.height * (0.12 + (seed % 3) * 0.04);

    // First wave (lower)
    final path1 = Path()..moveTo(0, size.height * 0.55);
    for (double x = 0; x <= size.width; x += 1) {
      final y =
          size.height * 0.55 +
          amplitude * math.sin((x / size.width * 2 * math.pi) + phase);
      path1.lineTo(x, y);
    }
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint);

    // Second wave (upper, lighter)
    final paint2 = Paint()
      ..color = color.withValues(alpha: color.a * 0.6)
      ..style = PaintingStyle.fill;

    final path2 = Path()..moveTo(0, size.height * 0.65);
    for (double x = 0; x <= size.width; x += 1) {
      final y =
          size.height * 0.65 +
          amplitude *
              0.7 *
              math.sin((x / size.width * 2.5 * math.pi) + phase + 1.5);
      path2.lineTo(x, y);
    }
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);

    // Decorative dots cluster (top-left area)
    final dotPaint = Paint()..color = color.withValues(alpha: color.a * 0.5);
    final rng = math.Random(seed);
    for (int i = 0; i < 5; i++) {
      final dx = size.width * (0.05 + rng.nextDouble() * 0.35);
      final dy = size.height * (0.05 + rng.nextDouble() * 0.3);
      final r = 2.0 + rng.nextDouble() * 3.0;
      canvas.drawCircle(Offset(dx, dy), r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => false;
}
