import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/responsive_utils.dart';

// ─────────────────────────────────────────────────────────────
//  Enhanced Streak Display
//
//  A visually rich streak hero card with:
//  • Animated flame icon that pulses & scales with streak length
//  • Ring progress toward the next milestone (3, 7, 14, 30)
//  • Streak tier label (Starting, Building, Consistent, Champion)
//  • Particle embers floating upward behind the flame
// ─────────────────────────────────────────────────────────────

class EnhancedStreakHero extends StatelessWidget {
  final int streakDays;
  final int? longestStreak;

  const EnhancedStreakHero({
    super.key,
    required this.streakDays,
    this.longestStreak,
  });

  @override
  Widget build(BuildContext context) {
    final tier = _StreakTier.forDays(streakDays);
    final nextMilestone = _nextMilestone(streakDays);
    final milestoneProgress = nextMilestone > 0
        ? streakDays / nextMilestone
        : 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: tier.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: tier.gradientColors.first.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── Flame + Ring Indicator ──────────
          SizedBox(
            width: context.scaleIcon(120),
            height: context.scaleIcon(120),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Milestone progress ring
                _AnimatedProgressRing(
                  progress: milestoneProgress.clamp(0.0, 1.0),
                  size: context.scaleIcon(120),
                  strokeWidth: 5,
                  color: Colors.white,
                ),
                // Floating ember particles
                _EmberParticles(
                  tier: tier,
                  size: context.scaleIcon(90),
                ),
                // Pulsing flame
                _PulsingFlame(tier: tier, streakDays: streakDays),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ─── Streak Number ──────────────────
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: streakDays),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Text(
                '$value',
                style: AppTypography.headlineLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 52,
                  height: 1.0,
                ),
              );
            },
          ),

          const SizedBox(height: 2),

          Text(
            'Day Streak',
            style: AppTypography.titleSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          // ─── Tier Badge ─────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tier.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  tier.label,
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // ─── Next Milestone ─────────────────
          if (nextMilestone > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${nextMilestone - streakDays} day${nextMilestone - streakDays == 1 ? '' : 's'} to $nextMilestone-day milestone',
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // ─── Longest Streak ─────────────────
          if (longestStreak != null && longestStreak! > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  'Best: $longestStreak days',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static int _nextMilestone(int days) {
    const milestones = [3, 7, 14, 30, 60, 100];
    for (final m in milestones) {
      if (days < m) return m;
    }
    return 0; // past all milestones
  }
}

// ─── Streak Tiers ──────────────────────────────────────

class _StreakTier {
  final String label;
  final String emoji;
  final List<Color> gradientColors;
  final int minDays;

  const _StreakTier({
    required this.label,
    required this.emoji,
    required this.gradientColors,
    required this.minDays,
  });

  static _StreakTier forDays(int days) {
    if (days >= 30) return champion;
    if (days >= 14) return blazing;
    if (days >= 7) return consistent;
    if (days >= 3) return building;
    return starting;
  }

  static const starting = _StreakTier(
    label: 'Just Starting',
    emoji: '🌱',
    gradientColors: [Color(0xFFFF9800), Color(0xFFF57C00)],
    minDays: 0,
  );

  static const building = _StreakTier(
    label: 'Building Up',
    emoji: '🔥',
    gradientColors: [Color(0xFFFF7043), Color(0xFFE64A19)],
    minDays: 3,
  );

  static const consistent = _StreakTier(
    label: 'On Fire!',
    emoji: '🔥',
    gradientColors: [Color(0xFFF44336), Color(0xFFC62828)],
    minDays: 7,
  );

  static const blazing = _StreakTier(
    label: 'Blazing',
    emoji: '💥',
    gradientColors: [Color(0xFFD50000), Color(0xFFB71C1C)],
    minDays: 14,
  );

  static const champion = _StreakTier(
    label: 'Streak Champion',
    emoji: '👑',
    gradientColors: [Color(0xFFFF6F00), Color(0xFFE65100)],
    minDays: 30,
  );
}

// ─── Animated Progress Ring ──────────────────────────

class _AnimatedProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color color;

  const _AnimatedProgressRing({
    required this.progress,
    required this.size,
    required this.strokeWidth,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return CustomPaint(
          size: Size(size, size),
          painter: _RingPainter(
            progress: value,
            strokeWidth: strokeWidth,
            color: color,
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress;
}

// ─── Pulsing Flame ───────────────────────────────────

class _PulsingFlame extends StatefulWidget {
  final _StreakTier tier;
  final int streakDays;

  const _PulsingFlame({required this.tier, required this.streakDays});

  @override
  State<_PulsingFlame> createState() => _PulsingFlameState();
}

class _PulsingFlameState extends State<_PulsingFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Faster pulse for higher streaks
    final durationMs = widget.streakDays >= 14 ? 600 : 900;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + 0.08 * _controller.value;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Text(
        '🔥',
        style: TextStyle(
          fontSize: widget.streakDays >= 14 ? 52 : 44,
        ),
      ),
    );
  }
}

// ─── Ember Particles ─────────────────────────────────

class _EmberParticles extends StatefulWidget {
  final _StreakTier tier;
  final double size;

  const _EmberParticles({required this.tier, required this.size});

  @override
  State<_EmberParticles> createState() => _EmberParticlesState();
}

class _EmberParticlesState extends State<_EmberParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Ember> _embers;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    final count = widget.tier.minDays >= 14 ? 8 : 5;
    _embers = List.generate(count, (_) => _Ember(
      x: _random.nextDouble(),
      delay: _random.nextDouble(),
      speed: 0.5 + _random.nextDouble() * 0.5,
      size: 2.0 + _random.nextDouble() * 3.0,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _EmberPainter(
            embers: _embers,
            progress: _controller.value,
            color: widget.tier.gradientColors.last,
          ),
        );
      },
    );
  }
}

class _Ember {
  final double x;
  final double delay;
  final double speed;
  final double size;

  const _Ember({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
  });
}

class _EmberPainter extends CustomPainter {
  final List<_Ember> embers;
  final double progress;
  final Color color;

  _EmberPainter({
    required this.embers,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final ember in embers) {
      final p = (progress + ember.delay) % 1.0;
      final y = size.height * (1.0 - p * ember.speed);
      final x = size.width * ember.x + math.sin(p * math.pi * 2) * 4;
      final opacity = (1.0 - p) * 0.7;

      final paint = Paint()
        ..color = Colors.orange.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), ember.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberPainter old) =>
      old.progress != progress;
}

// ─────────────────────────────────────────────────────────────
//  Enhanced Streak Stat Item (for home screen stats banner)
//
//  A mini animated flame icon for the home screen _StatItem,
//  replacing the plain fire_department icon with a subtle pulse.
// ─────────────────────────────────────────────────────────────

class AnimatedStreakIcon extends StatefulWidget {
  final int streakDays;
  final double size;

  const AnimatedStreakIcon({
    super.key,
    required this.streakDays,
    this.size = 28,
  });

  @override
  State<AnimatedStreakIcon> createState() => _AnimatedStreakIconState();
}

class _AnimatedStreakIconState extends State<AnimatedStreakIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.streakDays == 0) {
      return Icon(
        Icons.local_fire_department_rounded,
        color: HCColor.of(context).textSecondary,
        size: widget.size,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + 0.1 * _controller.value;
        final glow = _controller.value;
        return Transform.scale(
          scale: scale,
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                AppColors.warning,
                Color.lerp(AppColors.warning, Colors.red, glow * 0.3)!,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: child,
          ),
        );
      },
      child: Icon(
        Icons.local_fire_department_rounded,
        color: Colors.white,
        size: widget.size,
      ),
    );
  }
}
