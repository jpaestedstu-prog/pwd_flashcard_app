import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/app_providers.dart';
import 'floating_particles.dart';

/// A beautiful animated gradient background that slowly morphs and flows.
///
/// Theme-aware — automatically picks colors based on the current app theme.
/// Respects reduced-motion accessibility setting.
///
/// Usage:
/// ```dart
/// AnimatedGradientBackground(
///   preset: GradientPreset.home,
///   child: Scaffold(
///     backgroundColor: Colors.transparent,
///     body: ...,
///   ),
/// )
/// ```
class AnimatedGradientBackground extends ConsumerStatefulWidget {
  const AnimatedGradientBackground({
    super.key,
    required this.child,
    this.preset = GradientPreset.home,
    this.customColors,
    this.intensity = 0.35,
    this.speed = 1.0,
    this.showParticles = true,
    this.particleStyle,
    this.particleCount,
  });

  /// The content displayed on top of the gradient.
  final Widget child;

  /// Predefined color preset.
  final GradientPreset preset;

  /// Custom colors — overrides [preset] if provided.
  final List<Color>? customColors;

  /// Gradient opacity intensity (0.0–1.0). Lower = more subtle.
  final double intensity;

  /// Animation speed multiplier (1.0 = normal, 0.5 = half speed).
  final double speed;

  /// Whether to show floating particles on top of the gradient.
  final bool showParticles;

  /// Particle visual style — defaults to a style matching [preset].
  final ParticleStyle? particleStyle;

  /// Number of particles — defaults based on preset.
  final int? particleCount;

  @override
  ConsumerState<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends ConsumerState<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (12000 / widget.speed).round()),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final reducedMotion = settings.reducedMotion;

    // Pick colors from preset or custom
    final colors = widget.customColors ??
        _colorsForPreset(widget.preset, context);

    // If reduced motion, show a static gradient
    if (reducedMotion) {
      return _StaticGradient(
        colors: colors,
        intensity: widget.intensity,
        child: widget.child,
      );
    }

    final particleStyle = widget.particleStyle ??
        _defaultParticleStyle(widget.preset);
    final particleCount = widget.particleCount ??
        _defaultParticleCount(widget.preset);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _GradientPainter(
            progress: _controller.value,
            colors: colors,
            intensity: widget.intensity,
            backgroundColor:
                Theme.of(context).scaffoldBackgroundColor,
          ),
          child: child,
        );
      },
      child: widget.showParticles
          ? Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: FloatingParticles(
                      style: particleStyle,
                      particleCount: particleCount,
                      maxOpacity: 0.28,
                      speed: widget.speed * 0.7,
                    ),
                  ),
                ),
                widget.child,
              ],
            )
          : widget.child,
    );
  }

  /// Returns theme-aware colors for each preset.
  List<Color> _colorsForPreset(GradientPreset preset, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return switch (preset) {
      GradientPreset.home => [
          scheme.primary.withValues(alpha: 0.5),
          scheme.tertiary.withValues(alpha: 0.4),
          scheme.secondary.withValues(alpha: 0.5),
          scheme.primaryContainer.withValues(alpha: 0.6),
        ],
      GradientPreset.games => [
          AppColors.gameWordMatch.withValues(alpha: 0.4),
          AppColors.gameSpelling.withValues(alpha: 0.35),
          AppColors.gameMemory.withValues(alpha: 0.4),
          AppColors.gameQuiz.withValues(alpha: 0.3),
        ],
      GradientPreset.shop => [
          AppColors.warning.withValues(alpha: 0.35),
          scheme.primary.withValues(alpha: 0.4),
          AppColors.accent.withValues(alpha: 0.35),
          AppColors.warningLight.withValues(alpha: 0.45),
        ],
      GradientPreset.flashcards => [
          scheme.primaryContainer.withValues(alpha: 0.5),
          scheme.secondaryContainer.withValues(alpha: 0.4),
          scheme.tertiaryContainer.withValues(alpha: 0.45),
          scheme.primary.withValues(alpha: 0.3),
        ],
      GradientPreset.assessment => [
          AppColors.info.withValues(alpha: 0.35),
          scheme.primary.withValues(alpha: 0.3),
          AppColors.success.withValues(alpha: 0.3),
          AppColors.infoLight.withValues(alpha: 0.4),
        ],
      GradientPreset.celebration => [
          AppColors.warning.withValues(alpha: 0.4),
          AppColors.accent.withValues(alpha: 0.45),
          scheme.primary.withValues(alpha: 0.4),
          AppColors.success.withValues(alpha: 0.35),
        ],
    };
  }

  /// Default particle visual style for each gradient preset.
  ParticleStyle _defaultParticleStyle(GradientPreset preset) {
    return switch (preset) {
      GradientPreset.home => ParticleStyle.sparkles,
      GradientPreset.games => ParticleStyle.stars,
      GradientPreset.shop => ParticleStyle.stars,
      GradientPreset.flashcards => ParticleStyle.bubbles,
      GradientPreset.assessment => ParticleStyle.bubbles,
      GradientPreset.celebration => ParticleStyle.confetti,
    };
  }

  /// Default particle count for each gradient preset.
  int _defaultParticleCount(GradientPreset preset) {
    return switch (preset) {
      GradientPreset.home => 15,
      GradientPreset.games => 20,
      GradientPreset.shop => 18,
      GradientPreset.flashcards => 12,
      GradientPreset.assessment => 10,
      GradientPreset.celebration => 25,
    };
  }
}

/// Predefined gradient presets for different screens.
enum GradientPreset {
  /// Home screen — primary theme colors, warm feel.
  home,

  /// Game hub — playful, multi-colored.
  games,

  /// Star shop — golden/warm with accents.
  shop,

  /// Flashcards — soft, study-oriented.
  flashcards,

  /// Assessment — calm, focused blues/greens.
  assessment,

  /// Celebrations — vibrant, festive.
  celebration,
}

/// Custom painter that draws 4 morphing gradient blobs.
class _GradientPainter extends CustomPainter {
  _GradientPainter({
    required this.progress,
    required this.colors,
    required this.intensity,
    required this.backgroundColor,
  });

  final double progress;
  final List<Color> colors;
  final double intensity;

  final Color backgroundColor;

  /// Slow radius pulse, phase-shifted per blob — reads as blobs drifting
  /// nearer/farther (a depth axis) rather than just sliding around the
  /// plane. Periodic over a full cycle so the repeat wraps seamlessly.
  double _breath(double phase) =>
      1 + 0.08 * math.sin(progress * 2 * math.pi + phase);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw scaffold background first
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = backgroundColor,
    );

    final blobs = <_BlobConfig>[
      _BlobConfig(
        center: Offset(
          size.width * (0.2 + 0.15 * math.sin(progress * 2 * math.pi)),
          size.height * (0.15 + 0.1 * math.cos(progress * 2 * math.pi)),
        ),
        radius: size.width * 0.55 * _breath(0),
        color: colors[0 % colors.length],
      ),
      _BlobConfig(
        center: Offset(
          size.width *
              (0.8 +
                  0.12 *
                      math.cos(progress * 2 * math.pi + math.pi * 0.5)),
          size.height *
              (0.3 +
                  0.15 *
                      math.sin(progress * 2 * math.pi + math.pi * 0.7)),
        ),
        radius: size.width * 0.5 * _breath(math.pi * 0.6),
        color: colors[1 % colors.length],
      ),
      _BlobConfig(
        center: Offset(
          size.width *
              (0.5 +
                  0.2 * math.sin(progress * 2 * math.pi + math.pi)),
          size.height *
              (0.75 +
                  0.12 *
                      math.cos(progress * 2 * math.pi + math.pi * 1.3)),
        ),
        radius: size.width * 0.6 * _breath(math.pi * 1.1),
        color: colors[2 % colors.length],
      ),
      _BlobConfig(
        center: Offset(
          size.width *
              (0.35 +
                  0.18 *
                      math.cos(progress * 2 * math.pi + math.pi * 1.5)),
          size.height *
              (0.5 +
                  0.1 *
                      math.sin(progress * 2 * math.pi + math.pi * 0.3)),
        ),
        radius: size.width * 0.45 * _breath(math.pi * 1.7),
        color: colors[3 % colors.length],
      ),
    ];

    for (final blob in blobs) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            blob.color.withValues(alpha: intensity),
            blob.color.withValues(alpha: 0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(
          Rect.fromCircle(center: blob.center, radius: blob.radius),
        )
        ..blendMode = BlendMode.srcOver;

      canvas.drawCircle(blob.center, blob.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_GradientPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _BlobConfig {
  const _BlobConfig({
    required this.center,
    required this.radius,
    required this.color,
  });
  final Offset center;
  final double radius;
  final Color color;
}

/// Static (reduced motion) fallback — subtle two-color gradient.
class _StaticGradient extends StatelessWidget {
  const _StaticGradient({
    required this.colors,
    required this.intensity,
    required this.child,
  });

  final List<Color> colors;
  final double intensity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.first.withValues(alpha: intensity * 0.6),
            colors.last.withValues(alpha: intensity * 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}
