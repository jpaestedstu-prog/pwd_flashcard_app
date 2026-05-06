import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

/// Floating particle overlay — renders soft, drifting shapes (circles, stars,
/// sparkles) that float upward across the screen.
///
/// Theme-aware via [ParticleStyle] presets. Respects reduced-motion setting.
///
/// Designed to be layered inside a `Stack` on top of a background gradient
/// and below the main content.
///
/// Usage:
/// ```dart
/// Stack(
///   children: [
///     FloatingParticles(style: ParticleStyle.bubbles),
///     child,
///   ],
/// )
/// ```
class FloatingParticles extends ConsumerStatefulWidget {
  const FloatingParticles({
    super.key,
    this.style = ParticleStyle.sparkles,
    this.particleCount = 18,
    this.colors,
    this.maxOpacity = 0.35,
    this.minSize = 4.0,
    this.maxSize = 14.0,
    this.speed = 1.0,
  });

  /// Predefined visual style for the particles.
  final ParticleStyle style;

  /// Number of particles rendered simultaneously.
  final int particleCount;

  /// Custom particle colors — overrides the style's default palette.
  final List<Color>? colors;

  /// Maximum opacity for any particle (0.0–1.0).
  final double maxOpacity;

  /// Minimum particle radius in logical pixels.
  final double minSize;

  /// Maximum particle radius in logical pixels.
  final double maxSize;

  /// Speed multiplier (1.0 = normal).
  final double speed;

  @override
  ConsumerState<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends ConsumerState<FloatingParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(
      widget.particleCount,
      (_) => _generateParticle(randomizeY: true),
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _Particle _generateParticle({bool randomizeY = false}) {
    final size =
        widget.minSize + _random.nextDouble() * (widget.maxSize - widget.minSize);
    return _Particle(
      x: _random.nextDouble(),
      y: randomizeY ? _random.nextDouble() : 1.0 + _random.nextDouble() * 0.3,
      size: size,
      opacity: 0.1 + _random.nextDouble() * (widget.maxOpacity - 0.1),
      speedY: (0.015 + _random.nextDouble() * 0.025) * widget.speed,
      speedX: (_random.nextDouble() - 0.5) * 0.008 * widget.speed,
      wobblePhase: _random.nextDouble() * 2 * math.pi,
      wobbleAmplitude: 0.003 + _random.nextDouble() * 0.008,
      shape: _shapeForStyle(widget.style),
      rotation: _random.nextDouble() * 2 * math.pi,
      rotationSpeed:
          (_random.nextDouble() - 0.5) * 0.02 * widget.speed,
    );
  }

  _ParticleShape _shapeForStyle(ParticleStyle style) {
    return switch (style) {
      ParticleStyle.bubbles => _ParticleShape.circle,
      ParticleStyle.sparkles => _random.nextBool()
          ? _ParticleShape.diamond
          : _ParticleShape.star,
      ParticleStyle.stars => _ParticleShape.star,
      ParticleStyle.hearts => _ParticleShape.heart,
      ParticleStyle.snow => _ParticleShape.snowflake,
      ParticleStyle.confetti => _ParticleShape.values[
          _random.nextInt(_ParticleShape.values.length)],
    };
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    if (settings.reducedMotion) {
      return const SizedBox.shrink();
    }

    final colors = widget.colors ?? _colorsForStyle(widget.style, context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Advance particles each frame
        for (int i = 0; i < _particles.length; i++) {
          var p = _particles[i];
          p = p.copyWith(
            y: p.y - p.speedY * (1 / 60),
            x: p.x + p.speedX + math.sin(p.wobblePhase + p.y * 8) * p.wobbleAmplitude,
            rotation: p.rotation + p.rotationSpeed,
          );
          // Reset particle when it drifts off-screen
          if (p.y < -0.1) {
            _particles[i] = _generateParticle();
          } else {
            _particles[i] = p;
          }
        }

        return IgnorePointer(
          child: CustomPaint(
            painter: _ParticlePainter(
              particles: _particles,
              colors: colors,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  List<Color> _colorsForStyle(ParticleStyle style, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (style) {
      ParticleStyle.bubbles => [
          scheme.primary.withValues(alpha: 0.25),
          scheme.secondary.withValues(alpha: 0.2),
          scheme.tertiary.withValues(alpha: 0.2),
          Colors.white.withValues(alpha: 0.3),
        ],
      ParticleStyle.sparkles => [
          const Color(0xFFFFD54F), // gold
          const Color(0xFFFFF176), // light gold
          Colors.white.withValues(alpha: 0.5),
          scheme.primary.withValues(alpha: 0.35),
        ],
      ParticleStyle.stars => [
          const Color(0xFFFFD54F),
          const Color(0xFFFFAB40),
          Colors.white.withValues(alpha: 0.4),
          scheme.tertiary.withValues(alpha: 0.3),
        ],
      ParticleStyle.hearts => [
          const Color(0xFFF48FB1),
          const Color(0xFFE91E63).withValues(alpha: 0.35),
          const Color(0xFFFF80AB),
          scheme.primary.withValues(alpha: 0.3),
        ],
      ParticleStyle.snow => [
          Colors.white.withValues(alpha: 0.5),
          Colors.white.withValues(alpha: 0.35),
          const Color(0xFFE3F2FD).withValues(alpha: 0.4),
          const Color(0xFFBBDEFB).withValues(alpha: 0.3),
        ],
      ParticleStyle.confetti => [
          const Color(0xFFE57373),
          const Color(0xFF81C784),
          const Color(0xFF64B5F6),
          const Color(0xFFFFD54F),
          const Color(0xFFBA68C8),
          const Color(0xFFFF8A65),
        ],
    };
  }
}

/// Visual styles for the floating particles.
enum ParticleStyle {
  /// Soft transparent circles — dreamy underwater feel.
  bubbles,

  /// Gold/white diamonds and stars — magical sparkle effect.
  sparkles,

  /// Star shapes — game/reward feel.
  stars,

  /// Heart shapes — cute/playful.
  hearts,

  /// Snowflake shapes — winter seasonal.
  snow,

  /// Mixed shapes and bright colors — celebration.
  confetti,
}

/// Internal particle data.
class _Particle {
  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.speedY,
    required this.speedX,
    required this.wobblePhase,
    required this.wobbleAmplitude,
    required this.shape,
    required this.rotation,
    required this.rotationSpeed,
  });

  final double x; // 0.0–1.0 normalized
  final double y; // 0.0–1.0 normalized (0 = top)
  final double size;
  final double opacity;
  final double speedY;
  final double speedX;
  final double wobblePhase;
  final double wobbleAmplitude;
  final _ParticleShape shape;
  final double rotation;
  final double rotationSpeed;

  _Particle copyWith({
    double? x,
    double? y,
    double? rotation,
  }) =>
      _Particle(
        x: x ?? this.x,
        y: y ?? this.y,
        size: size,
        opacity: opacity,
        speedY: speedY,
        speedX: speedX,
        wobblePhase: wobblePhase,
        wobbleAmplitude: wobbleAmplitude,
        shape: shape,
        rotation: rotation ?? this.rotation,
        rotationSpeed: rotationSpeed,
      );
}

enum _ParticleShape { circle, star, diamond, heart, snowflake }

/// Paints all particles onto the canvas.
class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.particles,
    required this.colors,
  });

  final List<_Particle> particles;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      final color = colors[i % colors.length].withValues(alpha: p.opacity);
      final paint = Paint()..color = color;
      final center = Offset(p.x * size.width, p.y * size.height);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(p.rotation);

      switch (p.shape) {
        case _ParticleShape.circle:
          canvas.drawCircle(Offset.zero, p.size, paint);
          // Add a white highlight for bubble effect
          canvas.drawCircle(
            Offset(-p.size * 0.25, -p.size * 0.25),
            p.size * 0.3,
            Paint()..color = Colors.white.withValues(alpha: p.opacity * 0.5),
          );
        case _ParticleShape.star:
          _drawStar(canvas, p.size, paint);
        case _ParticleShape.diamond:
          _drawDiamond(canvas, p.size, paint);
        case _ParticleShape.heart:
          _drawHeart(canvas, p.size, paint);
        case _ParticleShape.snowflake:
          _drawSnowflake(canvas, p.size, paint);
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 2 * math.pi / 5) - math.pi / 2;
      final innerAngle = outerAngle + math.pi / 5;
      final outerPoint = Offset(
        radius * math.cos(outerAngle),
        radius * math.sin(outerAngle),
      );
      final innerPoint = Offset(
        radius * 0.4 * math.cos(innerAngle),
        radius * 0.4 * math.sin(innerAngle),
      );
      if (i == 0) {
        path.moveTo(outerPoint.dx, outerPoint.dy);
      } else {
        path.lineTo(outerPoint.dx, outerPoint.dy);
      }
      path.lineTo(innerPoint.dx, innerPoint.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, double radius, Paint paint) {
    final path = Path()
      ..moveTo(0, -radius)
      ..lineTo(radius * 0.6, 0)
      ..lineTo(0, radius)
      ..lineTo(-radius * 0.6, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawHeart(Canvas canvas, double radius, Paint paint) {
    final path = Path();
    final s = radius * 0.8;
    path.moveTo(0, s * 0.4);
    path.cubicTo(-s, -s * 0.3, -s * 0.5, -s, 0, -s * 0.4);
    path.cubicTo(s * 0.5, -s, s, -s * 0.3, 0, s * 0.4);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawSnowflake(Canvas canvas, double radius, Paint paint) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final end = Offset(
        radius * math.cos(angle),
        radius * math.sin(angle),
      );
      canvas.drawLine(Offset.zero, end, paint);
      // Small cross at each arm tip
      final tipAngle1 = angle + math.pi / 6;
      final tipAngle2 = angle - math.pi / 6;
      final tipLen = radius * 0.3;
      canvas.drawLine(
        end,
        Offset(
          end.dx + tipLen * math.cos(tipAngle1),
          end.dy + tipLen * math.sin(tipAngle1),
        ),
        paint,
      );
      canvas.drawLine(
        end,
        Offset(
          end.dx + tipLen * math.cos(tipAngle2),
          end.dy + tipLen * math.sin(tipAngle2),
        ),
        paint,
      );
    }
    paint.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}
