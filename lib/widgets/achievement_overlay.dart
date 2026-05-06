import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/responsive_utils.dart';
import '../../data/models/achievements.dart';

/// A full-screen overlay that announces a newly unlocked achievement
/// with a glow effect, scale animation, and confetti.
///
/// Shows achievements one at a time from [achievements] list, with a
/// "Continue" button that progresses through them.
class AchievementUnlockedOverlay extends StatefulWidget {
  final List<Achievement> achievements;
  final VoidCallback onDismiss;

  const AchievementUnlockedOverlay({
    super.key,
    required this.achievements,
    required this.onDismiss,
  });

  @override
  State<AchievementUnlockedOverlay> createState() =>
      _AchievementUnlockedOverlayState();
}

class _AchievementUnlockedOverlayState
    extends State<AchievementUnlockedOverlay> {
  late ConfettiController _confettiController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _confettiController.play();
    // Celebratory haptic on achievement unlock
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () => HapticFeedback.mediumImpact());
    Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.lightImpact());
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentIndex < widget.achievements.length - 1) {
      setState(() => _currentIndex++);
      _confettiController.play();
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final achievement = widget.achievements[_currentIndex];
    final hasMore = _currentIndex < widget.achievements.length - 1;

    return Material(
      color: Colors.black54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ─── Confetti ─────────────────────────
          RepaintBoundary(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.06,
              numberOfParticles: 25,
              maxBlastForce: 25,
              minBlastForce: 8,
              colors: [
                achievement.color,
                AppColors.warning,
                AppColors.primary,
                AppColors.accent,
                Colors.white,
              ],
            ),
            ),
          ),
          ),

          // ─── Achievement Card ─────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
            decoration: BoxDecoration(
              color: HCColor.of(context).surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: achievement.color.withValues(alpha: 0.3),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: achievement.color.withValues(alpha: 0.15),
                  blurRadius: 80,
                  spreadRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "Achievement Unlocked" label
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: achievement.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🏆 Achievement Unlocked!',
                    style: AppTypography.labelLarge.copyWith(
                      color: achievement.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.3, end: 0),

                const SizedBox(height: 24),

                // ─── Glowing Badge ──────────────
                _GlowingBadge(
                  icon: achievement.icon,
                  color: achievement.color,
                )
                    .animate()
                    .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                      delay: 200.ms,
                    ),

                const SizedBox(height: 20),

                // Title
                Text(
                  achievement.title,
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: HCColor.of(context).textPrimary,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 400.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 8),

                // Description
                Text(
                  achievement.description,
                  style: AppTypography.bodyMedium.copyWith(
                    color: HCColor.of(context).textSecondary,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 500.ms),

                // Counter (if multiple)
                if (widget.achievements.length > 1) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${_currentIndex + 1} of ${widget.achievements.length}',
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.textHint),
                  ),
                ],

                const SizedBox(height: 24),

                // Action button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: achievement.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      hasMore ? 'Next Achievement' : 'Awesome! 🎉',
                      style: AppTypography.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 600.ms)
                    .slideY(begin: 0.2, end: 0),
              ],
            ),
          )
              .animate(key: ValueKey(_currentIndex))
              .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 300.ms),
        ],
      ),
    );
  }
}

/// A badge icon with a pulsating glow ring behind it.
class _GlowingBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _GlowingBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final badgeOuter = context.responsiveSize(120);
    final badgeInner = context.responsiveSize(88);
    final iconCircle = context.responsiveSize(72);
    final iconSize = context.responsiveSize(36);
    return SizedBox(
      width: badgeOuter,
      height: badgeOuter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring (pulsating)
          Container(
            width: badgeOuter,
            height: badgeOuter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.08),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.92, 0.92),
                end: const Offset(1.08, 1.08),
                duration: 1200.ms,
                curve: Curves.easeInOut,
              ),

          // Inner glow ring
          Container(
            width: badgeInner,
            height: badgeInner,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),

          // Icon circle
          Container(
            width: iconCircle,
            height: iconCircle,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color, width: 3),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, size: iconSize, color: color),
          ),
        ],
      ),
    );
  }
}
