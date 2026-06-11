import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import 'tilt_3d.dart';

// ═══════════════════════════════════════════════════════════════════
// 1. FLASHCARD NAVIGATION BUTTON
//    Rounded rectangle, bright green (Next) / red (Back), arrow icons,
//    bold large font, slight scale-up on press.
// ═══════════════════════════════════════════════════════════════════

class FlashcardNavButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const FlashcardNavButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  /// Convenience constructor for a "Next" button.
  const FlashcardNavButton.next({
    super.key,
    this.label = 'Next',
    this.icon = Icons.arrow_forward_rounded,
    this.color = AppColors.success,
    this.onPressed,
  });

  /// Convenience constructor for a "Back" button.
  const FlashcardNavButton.back({
    super.key,
    this.label = 'Back',
    this.icon = Icons.arrow_back_rounded,
    this.color = AppColors.error,
    this.onPressed,
  });

  @override
  State<FlashcardNavButton> createState() => _FlashcardNavButtonState();
}

class _FlashcardNavButtonState extends State<FlashcardNavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onPressed?.call(),
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        // pressScale 1.0: this button already animates its own scale-up;
        // Pressable3D only adds the perspective tilt toward the finger.
        child: Pressable3D(
          enabled: widget.onPressed != null,
          maxTilt: 0.08,
          pressScale: 1.0,
          child: Material(
            color: widget.color,
            borderRadius: BorderRadius.circular(20),
            elevation: 4,
            shadowColor: widget.color.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              // FittedBox lets the icon+label shrink as one unit when the
              // user's Font Size setting (XL = 1.5x) would otherwise push past
              // the available width.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 26),
                    const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: AppTypography.buttonText.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 2. GAME START / LEVEL SELECTION BUTTON
//    Pill-shaped with shadow, orange→yellow gradient, play icon,
//    large text, glow/bounce on hover.
// ═══════════════════════════════════════════════════════════════════

class GameStartButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Gradient? gradient;
  final VoidCallback? onPressed;
  final double? width;

  const GameStartButton({
    super.key,
    this.label = 'Start Game',
    this.icon = Icons.play_arrow_rounded,
    this.gradient,
    this.onPressed,
    this.width,
  });

  @override
  State<GameStartButton> createState() => _GameStartButtonState();
}

class _GameStartButtonState extends State<GameStartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounce;
  late Animation<double> _glow;

  static const _defaultGradient = AppColors.gameStartGradient;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glow = Tween<double>(begin: 0.0, end: 12.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    _controller.forward().then((_) => _controller.reverse());
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final grad = widget.gradient ?? _defaultGradient;

    // pressScale 1.0: the bounce animation already handles scale; the wrapper
    // adds the held-down perspective tilt.
    return Pressable3D(
      enabled: widget.onPressed != null,
      maxTilt: 0.05,
      pressScale: 1.0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _bounce.value,
          child: Container(
            width: widget.width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: grad,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.45),
                  blurRadius: 16 + _glow.value,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _onTap,
            borderRadius: BorderRadius.circular(40),
            splashColor: Colors.white24,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
              // FittedBox keeps the icon+label as a single unit that shrinks
              // when font scaling (1.5x) would otherwise overflow the pill.
              // Icon size stays 32 (no scaleIcon) to avoid double-scaling.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      widget.label,
                      style: AppTypography.buttonText.copyWith(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 3. REWARD / FEEDBACK BUTTON
//    Circle or rounded square, gold/rainbow gradient, star/trophy icon,
//    optional text, confetti burst animation on press.
// ═══════════════════════════════════════════════════════════════════

class RewardFeedbackButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final double size;
  final Gradient? gradient;
  final VoidCallback? onPressed;
  final bool isCircle;

  const RewardFeedbackButton({
    super.key,
    this.icon = Icons.star_rounded,
    this.label,
    this.size = 72,
    this.gradient,
    this.onPressed,
    this.isCircle = true,
  });

  /// Trophy variant.
  const RewardFeedbackButton.trophy({
    super.key,
    this.icon = Icons.emoji_events_rounded,
    this.label,
    this.size = 72,
    this.gradient,
    this.onPressed,
    this.isCircle = true,
  });

  @override
  State<RewardFeedbackButton> createState() => _RewardFeedbackButtonState();
}

class _RewardFeedbackButtonState extends State<RewardFeedbackButton>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _burstController;
  late Animation<double> _pressScale;

  static const _defaultGold = AppColors.rewardGoldGradient;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  void _onTap() {
    _pressController.forward().then((_) => _pressController.reverse());
    _burstController.forward(from: 0.0);
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final grad = widget.gradient ?? _defaultGold;
    final shape = widget.isCircle
        ? BoxShape.circle
        : BoxShape.rectangle;
    final radius = widget.isCircle ? null : BorderRadius.circular(20);

    return SizedBox(
      width: widget.size + 24,
      height: widget.size + 24 + (widget.label != null ? 24 : 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Confetti burst particles
          ..._buildBurstParticles(),

          // Main button
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _onTap,
                // pressScale 1.0: the press controller already squashes to
                // 0.88; the wrapper adds the perspective tilt.
                child: Pressable3D(
                  maxTilt: 0.09,
                  pressScale: 1.0,
                  child: AnimatedBuilder(
                    animation: _pressScale,
                    builder: (context, child) => Transform.scale(
                      scale: _pressScale.value,
                      child: child,
                    ),
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: shape,
                        borderRadius: radius,
                        gradient: grad,
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFFD700).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        color: Colors.white,
                        size: widget.size * 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.label != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.label!,
                  style: AppTypography.labelMedium.copyWith(
                    color: HCColor.of(context).textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBurstParticles() {
    const colors = [
      Color(0xFFFF6B6B),
      Color(0xFFFFD93D),
      Color(0xFF6BCB77),
      Color(0xFF4D96FF),
      Color(0xFFB39DDB),
      Color(0xFFF48FB1),
    ];

    return List.generate(8, (i) {
      final angle = (i / 8) * 2 * pi;
      return AnimatedBuilder(
        animation: _burstController,
        builder: (context, _) {
          final t = _burstController.value;
          final distance = t * (widget.size * 0.8);
          final opacity = (1.0 - t).clamp(0.0, 1.0);
          return Transform.translate(
            offset: Offset(cos(angle) * distance, sin(angle) * distance),
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i % colors.length],
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════
// 4. DASHBOARD ACTION BUTTON (Parents / Teachers)
//    Square with clear edges, light blue or gray, graph/eye/gear icon,
//    small clear text, subtle highlight when tapped.
// ═══════════════════════════════════════════════════════════════════

class DashboardActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final Color? iconColor;
  final VoidCallback? onPressed;
  final double size;

  const DashboardActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.iconColor,
    this.onPressed,
    this.size = 88,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? AppColors.info.withValues(alpha: 0.12);
    final fgColor = iconColor ?? AppColors.info;

    // Pro-surface button: keep the 3D press subtle.
    return Pressable3D(
      enabled: onPressed != null,
      maxTilt: 0.04,
      pressScale: 0.98,
      child: SizedBox(
        width: size,
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            splashColor: fgColor.withValues(alpha: 0.15),
            highlightColor: fgColor.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: fgColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: fgColor, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: HCColor.of(context).textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(begin: const Offset(0.95, 0.95), duration: 200.ms);
  }
}
