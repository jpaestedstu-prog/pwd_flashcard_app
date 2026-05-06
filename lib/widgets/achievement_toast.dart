import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/achievements.dart';

/// A compact, non-blocking achievement notification that slides in at the top.
///
/// Unlike [AchievementUnlockedOverlay] (full-screen modal), this toast is
/// lightweight and auto-dismisses after a few seconds — ideal for milestone
/// notifications during normal app usage (e.g. browsing flashcards).
class AchievementToast {
  AchievementToast._();

  /// Shows a brief achievement toast at the top of the screen.
  ///
  /// Automatically dismisses after [duration]. Tapping the toast dismisses
  /// it early. If [onTap] is provided, it is called on tap.
  static void show(
    BuildContext context, {
    required Achievement achievement,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _AchievementToastWidget(
        achievement: achievement,
        duration: duration,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
        onTap: onTap,
      ),
    );

    overlay.insert(entry);
    HapticFeedback.mediumImpact();
  }
}

class _AchievementToastWidget extends StatefulWidget {
  final Achievement achievement;
  final Duration duration;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  const _AchievementToastWidget({
    required this.achievement,
    required this.duration,
    required this.onDismiss,
    this.onTap,
  });

  @override
  State<_AchievementToastWidget> createState() =>
      _AchievementToastWidgetState();
}

class _AchievementToastWidgetState extends State<_AchievementToastWidget> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) {
        setState(() => _visible = false);
        Future.delayed(400.ms, widget.onDismiss);
      }
    });
  }

  void _dismiss() {
    widget.onTap?.call();
    setState(() => _visible = false);
    Future.delayed(400.ms, widget.onDismiss);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final a = widget.achievement;

    return Positioned(
      top: mq.padding.top + 12,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: 400.ms,
        child: IgnorePointer(
          ignoring: !_visible,
          child: GestureDetector(
            onTap: _dismiss,
            child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: HCColor.of(context).surface,
            shadowColor: a.color.withValues(alpha: 0.3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: a.color.withValues(alpha: 0.3)),
                gradient: LinearGradient(
                  colors: [
                    a.color.withValues(alpha: 0.05),
                    HCColor.of(context).surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: a.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(a.icon, color: a.color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🏆  Achievement Unlocked!',
                          style: AppTypography.labelSmall.copyWith(
                            color: a.color,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.title,
                          style: AppTypography.labelLarge.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: HCColor.of(context).textPrimary,
                          ),
                        ),
                        Text(
                          a.description,
                          style: AppTypography.labelSmall.copyWith(
                            color: HCColor.of(context).textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
          ),
        )
            .animate()
            .slideY(begin: -1.0, duration: 400.ms, curve: Curves.easeOutCubic)
            .fadeIn(duration: 300.ms),
      ),
    );
  }
}
