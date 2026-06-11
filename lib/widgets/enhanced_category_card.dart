import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/responsive_utils.dart';
import '../data/models/enums.dart';
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
    final hc = HCColor.of(context);
    final catColor = hc.categoryColor(widget.category);
    final darkColor = widget.category.darkColor;

    return Semantics(
      button: true,
      label: '${widget.category.label} flashcards, ${widget.wordCount} words, '
          '${(widget.progress * 100).round()} percent progress',
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: Pressable3D(
          pressScale: 0.95,
          child: Card(
            elevation: _pressed ? 1 : 4,
            shadowColor: catColor.withValues(alpha: 0.3),
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                // ─── Gradient background ────────────
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [darkColor, catColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
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

                // ─── Blob accent (top-right) ────────
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),

                // ─── Blob accent (bottom-left) ──────
                Positioned(
                  bottom: -15,
                  left: -15,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),

                // ─── Content ────────────────────────
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Top section: icon + label + word count
                        Expanded(
                          flex: 3,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Container(
                                  width: context.scaleIcon(56),
                                  height: context.scaleIcon(56),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.15),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    widget.category.icon,
                                    size: context.scaleIcon(30),
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    widget.category.label,
                                    style: AppTypography.titleMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.auto_stories_rounded,
                                      size: context.scaleIcon(13),
                                      color:
                                          Colors.white.withValues(alpha: 0.75),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '${widget.wordCount} words',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: Colors.white
                                              .withValues(alpha: 0.85),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Bottom section: progress pill + mini progress bar
                        Expanded(
                          flex: 2,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
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
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _MiniProgressBar(
                                progress: widget.progress,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
            Container(
              color: Colors.white.withValues(alpha: 0.15),
            ),
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
  _WavePainter({
    required this.color,
    required this.seed,
  });

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
      final y = size.height * 0.55 +
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
      final y = size.height * 0.65 +
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
