import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import 'animated_dialogs.dart';

/// Animated button with scale press effect and optional icon
class AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsets? padding;
  final double borderRadius;
  final double? width;
  final double? height;
  final List<BoxShadow>? shadow;

  const AnimatedPressButton({
    super.key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.borderRadius = 20,
    this.width,
    this.height,
    this.shadow,
  });

  @override
  State<AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AppColors.primary;
    final radius = BorderRadius.circular(widget.borderRadius);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Material(
          color: bgColor,
          borderRadius: radius,
          elevation: widget.shadow != null && widget.shadow!.isEmpty ? 0 : 4,
          shadowColor: bgColor.withValues(alpha: 0.3),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: widget.width,
            height: widget.height,
            padding: widget.padding ??
                const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            child: DefaultTextStyle(
              style: TextStyle(
                color: widget.foregroundColor ?? AppColors.textOnPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable emoji avatar circle with animated bounce
class EmojiAvatar extends StatelessWidget {
  final String emoji;
  final double size;
  final Color backgroundColor;
  final bool animate;

  const EmojiAvatar({
    super.key,
    required this.emoji,
    this.size = 80,
    this.backgroundColor = AppColors.primaryLight,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: AppColors.softShadow,
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: size * 0.45),
        ),
      ),
    );

    if (!animate) return avatar;

    // Use a gentle idle pulse but keep it lightweight — only 2 cycles
    // instead of infinite repeat to avoid a permanent animation controller.
    return avatar
        .animate(onPlay: (c) => c.repeat(reverse: true, count: 3))
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.04, 1.04),
          duration: 2500.ms,
          curve: Curves.easeInOut,
        );
  }
}

/// Animated card with gradient, icon, and title
class GradientCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;
  final double? height;

  const GradientCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.trailing,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPressButton(
      onPressed: onTap,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      shadow: const [],
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Section header widget with optional "See All" action
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final IconData? icon;
  final Color? color;
  final String? actionLabel;

  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.icon,
    this.color,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color ??
        Theme.of(context).textTheme.bodyLarge?.color ??
        AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: textColor),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: Text(actionLabel ?? 'See All'),
            ),
        ],
      ),
    );
  }
}

// ─── M3 Feature Banner ────────────────────────────────
/// Reusable gradient banner card used on the home screen for feature navigation.
/// Replaces the repetitive Container+GestureDetector pattern with a
/// Material 3 compliant Card widget with InkWell.
class FeatureBanner extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final String? semanticLabel;

  const FeatureBanner({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? '$title. $subtitle',
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── M3 App Card ──────────────────────────────────────
/// A Material 3 card wrapper that supports optional gradients and onTap.
/// Use this instead of Container + BoxDecoration for card-like UI.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final LinearGradient? gradient;
  final Color? color;
  final double borderRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double elevation;
  final String? semanticLabel;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.gradient,
    this.color,
    this.borderRadius = 24,
    this.padding,
    this.margin,
    this.elevation = 2,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    );

    Widget card;
    if (gradient != null) {
      card = Card(
        elevation: 0,
        margin: margin ?? EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: shape,
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Ink(
            decoration: BoxDecoration(gradient: gradient),
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      );
    } else {
      card = Card(
        elevation: elevation,
        margin: margin ?? EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: shape,
        color: color,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      );
    }

    if (semanticLabel != null) {
      return Semantics(button: onTap != null, label: semanticLabel, child: card);
    }
    return card;
  }
}

// ─── M3 Dialog Helpers ────────────────────────────────

/// Shows a Material 3 styled confirmation dialog with bounce entrance,
/// backdrop blur, and confirm/cancel buttons.
/// Returns true if confirmed, false if cancelled.
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) {
  return showAnimatedConfirmDialog(
    context,
    title: title,
    content: content,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    isDestructive: isDestructive,
  );
}

/// Shows a Material 3 styled dialog with custom content and bounce entrance.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  required Widget content,
  List<Widget>? actions,
}) {
  return showAnimatedAppDialog<T>(
    context,
    title: title,
    content: content,
    actions: actions,
  );
}
