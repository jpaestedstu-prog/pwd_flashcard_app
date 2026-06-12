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
//  • Circular gauge that fills to the star rating (out of 3)
//  • Stars that bounce in one-by-one with golden glow
//  • Score counter that animates up with color shift
//  • "+N ⭐ earned" chip for the stars added to the balance
//  • Tier-based emoji message with entrance animation
//
//  Deliberately percentage-free: a 0–3 star rating is what young
//  PWD learners read at a glance, and percentages are meaningless
//  for the single-word rounds launched from Word Hunt.
// ─────────────────────────────────────────────────────────────

class AnimatedScoreReveal extends StatefulWidget {
  final int score;
  final int total;

  /// Performance rating for this round, 0–3 stars. Drives the gauge, the
  /// star row, and the message tier.
  final int rating;

  /// Currency stars added to the learner's balance (may differ from
  /// [rating] — e.g. a perfect Word Hunt round rates 3/3 but earns 1 ⭐).
  final int starsEarned;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;
  final VoidCallback? onReview;

  const AnimatedScoreReveal({
    super.key,
    required this.score,
    required this.total,
    required this.rating,
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
    final rating = widget.rating.clamp(0, 3);
    final hc = HCColor.of(context);
    final tier = _ScoreTier.forRating(rating);

    return Semantics(
      label:
          'Game results: ${widget.score} out of ${widget.total}, rating $rating out of 3 stars, '
          '${widget.starsEarned} stars earned',
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
            maxWidth: 520,
          ),
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
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
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
                          progress: gaugeValue * (rating / 3),
                          tier: tier,
                          backgroundColor: hc.hc
                              ? AppColors.hcSurface
                              : AppColors.surfaceLight,
                        ),
                        child: Center(
                          child: _buildGaugeCenter(rating, tier),
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
                        final isEarned = index < rating;
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tier.message,
                    style: AppTypography.displaySmall.copyWith(
                      color: hc.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                )
                    .animate(delay: 1400.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 6),

                // ─── Encouragement ────────────────
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tier.encouragement,
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
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

                // ─── Stars earned chip ────────────
                // The currency reward, separate from the rating above.
                if (widget.starsEarned > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '+${widget.starsEarned} ⭐ earned',
                      style: AppTypography.titleSmall.copyWith(
                        color: hc.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                      .animate(delay: 1200.ms)
                      .fadeIn(duration: 400.ms)
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                        curve: Curves.easeOutBack,
                      ),
                ],

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
                // OverflowBar lays the buttons in a Row when there's width,
                // and stacks them vertically when font scaling forces a wrap.
                OverflowBar(
                  spacing: 12,
                  overflowSpacing: 8,
                  alignment: MainAxisAlignment.center,
                  overflowAlignment: OverflowBarAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onExit,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Exit'),
                    ),
                    ElevatedButton.icon(
                      onPressed: widget.onPlayAgain,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Play Again'),
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

  Widget _buildGaugeCenter(int rating, _ScoreTier tier) {
    return AnimatedBuilder(
      animation: _scoreController,
      builder: (context, _) {
        final ease = Curves.easeOutCubic.transform(_scoreController.value);
        final displayRating = (rating * ease).round();
        // Lock TextScaler to 1.0 inside the gauge — at 1.5x the hardcoded
        // emoji/rating text would burst the painted circle. The rating is
        // duplicated by the star row + Semantics so accessibility isn't lost.
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tier.emoji,
                style: const TextStyle(fontSize: 28),
              ),
              Text(
                '$displayRating/3',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  color: tier.color,
                  fontSize: 22,
                ),
              ),
            ],
          ),
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

  static _ScoreTier forRating(int rating) {
    if (rating >= 3) return amazing;
    if (rating == 2) return great;
    if (rating == 1) return good;
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

// (The old animated percentage bar was removed: results are expressed as a
// 0–3 star rating + "+N ⭐ earned" chip, never as percentages.)
