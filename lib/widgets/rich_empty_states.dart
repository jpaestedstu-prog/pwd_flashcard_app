import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import 'tilt_3d.dart';

/// A visually rich empty state with animated illustration, decorative
/// background elements, and an optional action button.
///
/// Drop-in replacement for the plain emoji + text empty states scattered
/// across the app. Respects reducedMotion via flutter_animate's global
/// default duration (set in main.dart to 0 ms when reducedMotion is on).
class RichEmptyState extends StatelessWidget {
  /// Large emoji displayed as the focal illustration.
  final String emoji;

  /// Primary headline.
  final String title;

  /// Longer description placed below the title.
  final String description;

  /// Optional CTA label. When provided, [onAction] must also be set.
  final String? actionLabel;

  /// Optional icon shown inside the action button.
  final IconData? actionIcon;

  /// Callback for the action button.
  final VoidCallback? onAction;

  /// Accent colour used for decorative rings and button.
  /// Falls back to [AppColors.primary].
  final Color? accentColor;

  /// Whether this empty state is compact (inside a card) vs full-page.
  final bool compact;

  const RichEmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.description,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.accentColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final accent = accentColor ?? AppColors.primary;
    final emojiSize = compact ? 48.0 : 64.0;
    final ringSize = compact ? 96.0 : 130.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Animated illustration with decorative rings ───
            SizedBox(
              width: ringSize + 20,
              height: ringSize + 20,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer dashed ring
                  _DecorativeRing(
                    size: ringSize + 16,
                    color: accent.withValues(alpha: 0.12),
                    dashed: true,
                  ),
                  // Inner solid ring
                  _DecorativeRing(
                    size: ringSize,
                    color: accent.withValues(alpha: 0.08),
                    strokeWidth: 0,
                    filled: true,
                  ),
                  // Floating dots
                  ..._buildDots(accent, ringSize),
                  // Emoji — gentle 3D sway (replaces the flat bob, and
                  // honours the reduced-motion setting).
                  Float3D(
                    period: const Duration(seconds: 6),
                    tilt: 0.10,
                    bob: 6,
                    child: Text(
                      emoji,
                      style: TextStyle(fontSize: emojiSize),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                ),

            SizedBox(height: compact ? 16 : 24),

            // ─── Title ───────────────────────────
            Text(
              title,
              style: (compact ? AppTypography.titleSmall : AppTypography.titleLarge).copyWith(
                color: hc.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 200.ms)
                .slideY(begin: 0.15, end: 0),

            SizedBox(height: compact ? 6 : 12),

            // ─── Description ─────────────────────
            Text(
              description,
              style: (compact ? AppTypography.bodySmall : AppTypography.bodyMedium).copyWith(
                color: hc.textSecondary,
              ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 350.ms)
                .slideY(begin: 0.12, end: 0),

            // ─── Action button ───────────────────
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: compact ? 18 : 28),
              FilledButton.icon(
                onPressed: onAction,
                icon: actionIcon != null
                    ? Icon(actionIcon, size: 18)
                    : const SizedBox.shrink(),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 500.ms)
                  .slideY(begin: 0.15, end: 0),
            ],
          ],
        ),
      ),
    );
  }

  /// Generates small decorative dots positioned around the ring.
  List<Widget> _buildDots(Color accent, double ringSize) {
    final rng = math.Random(emoji.hashCode);
    return List.generate(5, (i) {
      final angle = (i * 72.0 + rng.nextDouble() * 30) * math.pi / 180;
      final radius = ringSize / 2 + 4;
      final dotSize = 4.0 + rng.nextDouble() * 4;

      return Positioned(
        left: (ringSize + 20) / 2 + math.cos(angle) * radius - dotSize / 2,
        top: (ringSize + 20) / 2 + math.sin(angle) * radius - dotSize / 2,
        child: Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.25 + rng.nextDouble() * 0.2),
            shape: BoxShape.circle,
          ),
        )
            .animate(
              onPlay: (c) => c.repeat(reverse: true),
            )
            .fadeIn(duration: 300.ms, delay: (300 + i * 100).ms)
            .scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1.0, 1.0),
              duration: (1800 + i * 200).ms,
              curve: Curves.easeInOut,
            ),
      );
    });
  }
}

/// Draws a circular ring, optionally dashed or filled.
class _DecorativeRing extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;
  final bool dashed;
  final bool filled;

  const _DecorativeRing({
    required this.size,
    required this.color,
    this.strokeWidth = 2,
    this.dashed = false,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          color: color,
          strokeWidth: strokeWidth,
          dashed: dashed,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool dashed;

  _RingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (dashed) {
      const dashLength = 6.0;
      const gapLength = 4.0;
      final radius = size.width / 2;
      final circumference = 2 * math.pi * radius;
      final dashCount = (circumference / (dashLength + gapLength)).floor();

      for (var i = 0; i < dashCount; i++) {
        final startAngle =
            (i * (dashLength + gapLength)) / radius;
        final sweepAngle = dashLength / radius;
        canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      }
    } else {
      canvas.drawOval(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashed != oldDelegate.dashed;
}
