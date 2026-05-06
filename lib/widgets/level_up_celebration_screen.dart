import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/responsive_utils.dart';
import '../core/services/xp_level_service.dart';
import 'animated_gradient_background.dart';

/// A full-screen celebration overlay that displays when the user levels up.
///
/// Shows the new level badge, title, Lottie animation, confetti burst,
/// and a radial glow effect. Auto-dismisses after [duration] or on tap.
class LevelUpCelebrationScreen extends StatefulWidget {
  /// The new [PlayerLevel] the user just reached.
  final PlayerLevel newLevel;

  /// Called when the celebration finishes or user taps to dismiss.
  final VoidCallback onDismiss;

  /// How long before auto-dismiss. Defaults to 5 seconds.
  final Duration duration;

  /// Whether to skip animations (reduced motion).
  final bool reducedMotion;

  const LevelUpCelebrationScreen({
    super.key,
    required this.newLevel,
    required this.onDismiss,
    this.duration = const Duration(seconds: 5),
    this.reducedMotion = false,
  });

  @override
  State<LevelUpCelebrationScreen> createState() =>
      _LevelUpCelebrationScreenState();
}

class _LevelUpCelebrationScreenState extends State<LevelUpCelebrationScreen>
    with TickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final AnimationController _glowController;

  late final Animation<double> _badgeScale;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _buttonOpacity;
  late final Animation<double> _glowRadius;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Entrance: badge scales up, then text fades in
    _entranceController = AnimationController(
      vsync: this,
      duration: widget.reducedMotion
          ? const Duration(milliseconds: 300)
          : const Duration(milliseconds: 1800),
    );

    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 30,
      ),
    ]).animate(_entranceController);

    _titleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 0.65, curve: Curves.easeIn),
      ),
    );

    _subtitleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 0.80, curve: Curves.easeIn),
      ),
    );

    _buttonOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
      ),
    );

    // Continuous pulse on the badge
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Radial glow expansion
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _glowRadius = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeOut),
    );

    _start();
  }

  void _start() {
    _entranceController.forward();
    if (!widget.reducedMotion) {
      _confettiController.play();
      _pulseController.repeat(reverse: true);
      _glowController.repeat(reverse: true);
    }

    // Auto-dismiss
    Future.delayed(widget.duration, () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _entranceController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Color get _levelColor {
    const colors = [
      Color(0xFF81C784), // 1 Beginner — green
      Color(0xFF64B5F6), // 2 Explorer — blue
      Color(0xFF90CAF9), // 3 Learner — light blue
      Color(0xFFFFD54F), // 4 Achiever — gold
      Color(0xFFBA68C8), // 5 Scholar — purple
      Color(0xFF4DD0E1), // 6 Expert — cyan
      Color(0xFFFF8A65), // 7 Champion — orange
      Color(0xFFFFD700), // 8 Master — bright gold
      Color(0xFFE040FB), // 9 Legend — magenta
      Color(0xFF69F0AE), // 10 Grandmaster — neon green
    ];
    final idx = (widget.newLevel.level - 1).clamp(0, colors.length - 1);
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final lvl = widget.newLevel;
    final color = _levelColor;

    return GestureDetector(
      onTap: widget.onDismiss,
      child: AnimatedGradientBackground(
        preset: GradientPreset.celebration,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Radial glow behind badge
              if (!widget.reducedMotion)
                Center(
                  child: AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, _) {
                      final glowBase = context.responsiveSize(250);
                      return Container(
                        width: glowBase + (_glowRadius.value * 100),
                        height: glowBase + (_glowRadius.value * 100),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              color.withValues(alpha: 0.3),
                              color.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Main content
              SafeArea(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _entranceController,
                    builder: (context, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Lottie animation
                          if (!widget.reducedMotion)
                            SizedBox(
                              width: context.responsiveSize(160),
                              height: context.responsiveSize(160),
                              child: Lottie.asset(
                                'assets/animations/level_up.json',
                                repeat: false,
                                errorBuilder: (_, e, s) =>
                                    const SizedBox.shrink(),
                              ),
                            ),

                          const SizedBox(height: 8),

                          // "LEVEL UP!" text
                          Opacity(
                            opacity: _titleOpacity.value,
                            child: Text(
                              'LEVEL UP!',
                              style: AppTypography.displaySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(
                                    color: color.withValues(alpha: 0.6),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Badge circle
                          Transform.scale(
                            scale: _badgeScale.value,
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                final pulse = widget.reducedMotion
                                    ? 0.0
                                    : math.sin(_pulseController.value *
                                            math.pi) *
                                        0.05;
                                return Transform.scale(
                                  scale: 1.0 + pulse,
                                  child: child,
                                );
                              },
                              child: Container(
                                width: context.responsiveSize(140),
                                height: context.responsiveSize(140),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      color,
                                      color.withValues(alpha: 0.7),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    width: 4,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      lvl.emoji,
                                      style: const TextStyle(fontSize: 40),
                                    ),
                                    Text(
                                      'Lv. ${lvl.level}',
                                      style:
                                          AppTypography.titleLarge.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Level title
                          Opacity(
                            opacity: _subtitleOpacity.value,
                            child: Column(
                              children: [
                                Text(
                                  lvl.title,
                                  style:
                                      AppTypography.headlineMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'You\'ve reached Level ${lvl.level}!',
                                  style: AppTypography.bodyLarge.copyWith(
                                    color: Colors.white
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Continue button
                          Opacity(
                            opacity: _buttonOpacity.value,
                            child: FilledButton.icon(
                              onPressed: widget.onDismiss,
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('Continue'),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.25),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Confetti — two cannons from top-left and top-right
              RepaintBoundary(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirection: -math.pi / 4,
                    minBlastForce: 8,
                    colors: [
                      color,
                      AppColors.warning,
                      AppColors.accent,
                      AppColors.primary,
                      Colors.white,
                    ],
                  ),
                ),
              ),
              RepaintBoundary(
                child: Align(
                  alignment: Alignment.topRight,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirection: -3 * math.pi / 4,
                    minBlastForce: 8,
                    colors: [
                      color,
                      AppColors.warning,
                      AppColors.accent,
                      AppColors.primary,
                      Colors.white,
                    ],
                  ),
                ),
              ),

              // Tap to dismiss hint
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _buttonOpacity.value,
                  child: Text(
                    'Tap anywhere to continue',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
