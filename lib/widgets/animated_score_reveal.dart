import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/responsive_utils.dart';

// ─────────────────────────────────────────────────────────────
//  Animated Score Reveal
//
//  An enhanced game result dialog featuring:
//  • Circular score gauge that fills with color gradient
//  • Stars that bounce in one-by-one with golden glow
//  • Score counter that animates up with color shift
//  • Percentage bar with gradient fill
//  • Tier-based emoji message with entrance animation
// ─────────────────────────────────────────────────────────────

class AnimatedScoreReveal extends StatefulWidget {
  final int score;
  final int total;
  final int starsEarned;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;
  final VoidCallback? onReview;

  const AnimatedScoreReveal({
    super.key,
    required this.score,
    required this.total,
    required this.starsEarned,
    required this.onPlayAgain,
    required this.onExit,
    this.onReview,
  });

  @override
  State<AnimatedScoreReveal> createState() => _AnimatedScoreRevealState();
}

class _AnimatedScoreRevealState extends State<AnimatedScoreReveal>
    with TickerProviderStateMixin {
  late final AnimationController _gaugeController;
  late final AnimationController _starController;
  late final AnimationController _scoreController;

  @override
  void initState() {
    super.initState();

    _gaugeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Sequence: gauge → stars → score
    _gaugeController.forward().then((_) {
      _starController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        _scoreController.forward();
      });
    });
  }

  @override
  void dispose() {
    _gaugeController.dispose();
    _starController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.score / widget.total * 100).round();
    final hc = HCColor.of(context);
    final tier = _ScoreTier.forPercentage(percentage);

    return Semantics(
      label:
          'Game results: ${widget.score} out of ${widget.total}, $percentage percent correct, '
          '${widget.starsEarned} stars earned',
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Card(
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: hc.hc
                ? const BorderSide(color: AppColors.hcPrimary, width: 2)
                : BorderSide.none,
          ),
          color: hc.surface,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                context.pagePadding, 32, context.pagePadding, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── Score Gauge ──────────────────
                SizedBox(
                  width: context.responsiveSize(140),
                  height: context.responsiveSize(140),
                  child: AnimatedBuilder(
                    animation: _gaugeController,
                    builder: (context, _) {
                      final gaugeValue = Curves.easeOutCubic
                          .transform(_gaugeController.value);
                      return CustomPaint(
                        painter: _ScoreGaugePainter(
                          progress: gaugeValue * (percentage / 100),
                          tier: tier,
                          backgroundColor: hc.hc
                              ? AppColors.hcSurface
                              : AppColors.surfaceLight,
                        ),
                        child: Center(
                          child: _buildGaugeCenter(percentage, tier),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // ─── Stars ────────────────────────
                AnimatedBuilder(
                  animation: _starController,
                  builder: (context, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        final isEarned = index < widget.starsEarned;
                        final starDelay = index * 0.25;
                        final starProgress = ((_starController.value - starDelay) / 0.5)
                            .clamp(0.0, 1.0);
                        final bounced = isEarned
                            ? Curves.elasticOut.transform(starProgress)
                            : starProgress;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Transform.scale(
                            scale: isEarned ? bounced : 1.0,
                            child: _StarIcon(
                              isEarned: isEarned,
                              size: index == 1
                                  ? context.responsiveSize(60)
                                  : context.responsiveSize(44),
                              glowIntensity: isEarned ? bounced : 0,
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ─── Message ──────────────────────
                Text(
                  tier.message,
                  style: AppTypography.displaySmall.copyWith(
                    color: hc.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate(delay: 1400.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 6),

                // ─── Encouragement ────────────────
                Text(
                  tier.encouragement,
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate(delay: 1600.ms)
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: 12),

                // ─── Score Counter ────────────────
                AnimatedBuilder(
                  animation: _scoreController,
                  builder: (context, _) {
                    final ease =
                        Curves.easeOutCubic.transform(_scoreController.value);
                    final displayScore = (widget.score * ease).round();
                    final color = Color.lerp(
                      HCColor.of(context).textSecondary,
                      tier.color,
                      ease,
                    )!;

                    return RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$displayScore',
                            style: AppTypography.gameScore.copyWith(
                              color: color,
                            ),
                          ),
                          TextSpan(
                            text: ' / ${widget.total}',
                            style: AppTypography.headlineMedium.copyWith(
                              color: HCColor.of(context).textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 10),

                // ─── Percentage Bar ───────────────
                _AnimatedPercentageBar(
                  percentage: percentage,
                  tier: tier,
                  controller: _gaugeController,
                ),

                // ─── Review Button ────────────────
                if (widget.onReview != null) ...[
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: widget.onReview,
                    icon: const Icon(Icons.rate_review_rounded, size: 18),
                    label: const Text('Review Words'),
                  ),
                ],

                const SizedBox(height: 24),

                // ─── Action Buttons ───────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onExit,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Exit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onPlayAgain,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Play Again'),
                      ),
                    ),
                  ],
                )
                    .animate(delay: 1800.ms)
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.15, end: 0),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1, 1),
          duration: 450.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 300.ms);
  }

  Widget _buildGaugeCenter(int percentage, _ScoreTier tier) {
    return AnimatedBuilder(
      animation: _scoreController,
      builder: (context, _) {
        final ease = Curves.easeOutCubic.transform(_scoreController.value);
        final displayPct = (percentage * ease).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tier.emoji,
              style: const TextStyle(fontSize: 28),
            ),
            Text(
              '$displayPct%',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w900,
                color: tier.color,
                fontSize: 22,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Score Tier ──────────────────────────────────────

class _ScoreTier {
  final String message;
  final String emoji;
  final Color color;
  final List<Color> gradientColors;
  final String encouragement;

  const _ScoreTier({
    required this.message,
    required this.emoji,
    required this.color,
    required this.gradientColors,
    required this.encouragement,
  });

  static _ScoreTier forPercentage(int pct) {
    if (pct >= 90) return amazing;
    if (pct >= 70) return great;
    if (pct >= 50) return good;
    return practice;
  }

  static const amazing = _ScoreTier(
    message: 'Amazing! 🌟',
    emoji: '🏆',
    color: Color(0xFFFFC107),
    gradientColors: [Color(0xFFFFC107), Color(0xFFFF9800)],
    encouragement: 'You\'re a superstar! Try a harder level next!',
  );

  static const great = _ScoreTier(
    message: 'Great Job! 🎉',
    emoji: '⭐',
    color: Color(0xFF4CAF50),
    gradientColors: [Color(0xFF66BB6A), Color(0xFF43A047)],
    encouragement: 'You\'re doing wonderfully! Keep it up!',
  );

  static const good = _ScoreTier(
    message: 'Good Try! 👍',
    emoji: '💪',
    color: Color(0xFF42A5F5),
    gradientColors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
    encouragement: 'You\'re learning! Review the words you missed.',
  );

  static const practice = _ScoreTier(
    message: 'Keep Practicing! 💪',
    emoji: '📚',
    color: Color(0xFFFF7043),
    gradientColors: [Color(0xFFFF7043), Color(0xFFE64A19)],
    encouragement: 'Every try makes you stronger! Try again!',
  );
}

// ─── Score Gauge Painter ─────────────────────────────

class _ScoreGaugePainter extends CustomPainter {
  final double progress;
  final _ScoreTier tier;
  final Color backgroundColor;

  _ScoreGaugePainter({
    required this.progress,
    required this.tier,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    const strokeWidth = 10.0;

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc with gradient
    if (progress > 0) {
      final sweepAngle = 2 * math.pi * progress;
      final rect = Rect.fromCircle(center: center, radius: radius);

      final gradientPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + sweepAngle,
          colors: tier.gradientColors,
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect);

      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweepAngle,
        false,
        gradientPaint,
      );

      // Glow dot at the end
      final endAngle = -math.pi / 2 + sweepAngle;
      final dotX = center.dx + radius * math.cos(endAngle);
      final dotY = center.dy + radius * math.sin(endAngle);

      final glowPaint = Paint()
        ..color = tier.color.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(dotX, dotY), 6, glowPaint);

      final dotPaint = Paint()
        ..color = tier.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter old) =>
      old.progress != progress;
}

// ─── Star Icon with Glow ──────────────────────────────

class _StarIcon extends StatelessWidget {
  final bool isEarned;
  final double size;
  final double glowIntensity;

  const _StarIcon({
    required this.isEarned,
    required this.size,
    required this.glowIntensity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isEarned && glowIntensity > 0
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.warning.withValues(alpha: 0.4 * glowIntensity),
                  blurRadius: 12 * glowIntensity,
                  spreadRadius: 2 * glowIntensity,
                ),
              ],
            )
          : null,
      child: Icon(
        isEarned ? Icons.star_rounded : Icons.star_border_rounded,
        size: size,
        color: isEarned
            ? AppColors.warning
            : HCColor.of(context).textSecondary.withValues(alpha: 0.3),
      ),
    );
  }
}

// ─── Animated Percentage Bar ──────────────────────────

class _AnimatedPercentageBar extends StatelessWidget {
  final int percentage;
  final _ScoreTier tier;
  final AnimationController controller;

  const _AnimatedPercentageBar({
    required this.percentage,
    required this.tier,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final ease = Curves.easeOutCubic.transform(controller.value);
            final fill = (percentage / 100) * ease;

            return Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: HCColor.of(context).surfaceLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fill.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: tier.gradientColors),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: tier.color.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          '$percentage% correct',
          style: AppTypography.bodyLarge.copyWith(
            color: HCColor.of(context).textSecondary,
          ),
        ),
      ],
    );
  }
}
