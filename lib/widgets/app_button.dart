import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/accessibility/haptic_service.dart';
import '../core/accessibility/sound_service.dart';
import 'tilt_3d.dart';

/// Visual styling for an [AppButton]. Maps onto Material3's button family
/// without the consumer having to remember which one they want.
enum AppButtonVariant {
  /// Filled, primary-coloured. The default for CTAs and dialog accept.
  primary,

  /// Outlined / bordered, used for secondary actions next to a primary
  /// CTA (cancel, learn more, etc.).
  secondary,

  /// Tonal — softer than primary, for medium-importance actions.
  tertiary,

  /// Text-only, for low-importance actions and inline links.
  text,
}

/// One button to rule the regular CTAs.
///
/// Wraps Material3's button family with the things every interactive
/// surface in this app should have:
/// - Scale-on-press animation (gated on reducedMotion).
/// - Light haptic + tap sound on press, via the global accessibility
///   services. Disable by setting [hapticOnPress] / [soundOnPress] to false.
/// - Optional leading icon, optional full-width sizing.
/// - A single screen-reader node: the Material button already exposes
///   button semantics, and [semanticLabel] overrides the announced text
///   through the label's own semantics — no wrapper node, so TalkBack
///   users get exactly one focus stop per button.
///
/// Heavy specialty buttons (FlashcardNavButton, GameStartButton,
/// RewardFeedbackButton, DashboardActionButton) stay where they are —
/// reach for [AppButton] for regular dialog buttons, form submits,
/// inline CTAs, and "play again / exit" rows. New screens should default
/// to this widget.
class AppButton extends ConsumerWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  /// Stretches the button to fill the parent's width when true.
  final bool fullWidth;

  /// When true (default), a light haptic fires on press.
  final bool hapticOnPress;

  /// When true (default), the button-tap sound effect fires on press.
  final bool soundOnPress;

  /// Optional override for the semantic label that screen readers
  /// announce. Defaults to [label].
  final String? semanticLabel;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.fullWidth = false,
    this.hapticOnPress = true,
    this.soundOnPress = true,
    this.semanticLabel,
  });

  /// Filled, primary-coloured button — the default for CTAs.
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.hapticOnPress = true,
    this.soundOnPress = true,
    this.semanticLabel,
  }) : variant = AppButtonVariant.primary;

  /// Outlined button — for secondary actions next to a primary CTA.
  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.hapticOnPress = true,
    this.soundOnPress = true,
    this.semanticLabel,
  }) : variant = AppButtonVariant.secondary;

  /// Tonal button — softer than primary, for medium-importance actions.
  const AppButton.tertiary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.hapticOnPress = true,
    this.soundOnPress = true,
    this.semanticLabel,
  }) : variant = AppButtonVariant.tertiary;

  /// Text-only button — for inline / low-importance actions.
  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.hapticOnPress = true,
    this.soundOnPress = true,
    this.semanticLabel,
  })  : variant = AppButtonVariant.text,
        fullWidth = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void handlePress() {
      final pressed = onPressed;
      if (pressed == null) return;
      if (hapticOnPress) {
        ref.read(hapticServiceProvider).lightTap();
      }
      if (soundOnPress) {
        ref.read(soundServiceProvider).playTap();
      }
      pressed();
    }

    final iconWidget = icon == null ? null : Icon(icon, size: 20);
    final labelWidget = Text(label, semanticsLabel: semanticLabel);
    final button = switch (variant) {
      AppButtonVariant.primary => iconWidget == null
          ? FilledButton(
              onPressed: onPressed == null ? null : handlePress,
              child: labelWidget,
            )
          : FilledButton.icon(
              onPressed: onPressed == null ? null : handlePress,
              icon: iconWidget,
              label: labelWidget,
            ),
      AppButtonVariant.secondary => iconWidget == null
          ? OutlinedButton(
              onPressed: onPressed == null ? null : handlePress,
              child: labelWidget,
            )
          : OutlinedButton.icon(
              onPressed: onPressed == null ? null : handlePress,
              icon: iconWidget,
              label: labelWidget,
            ),
      AppButtonVariant.tertiary => iconWidget == null
          ? FilledButton.tonal(
              onPressed: onPressed == null ? null : handlePress,
              child: labelWidget,
            )
          : FilledButton.tonalIcon(
              onPressed: onPressed == null ? null : handlePress,
              icon: iconWidget,
              label: labelWidget,
            ),
      AppButtonVariant.text => iconWidget == null
          ? TextButton(
              onPressed: onPressed == null ? null : handlePress,
              child: labelWidget,
            )
          : TextButton.icon(
              onPressed: onPressed == null ? null : handlePress,
              icon: iconWidget,
              label: labelWidget,
            ),
    };

    final sized =
        fullWidth ? SizedBox(width: double.infinity, child: button) : button;

    return Pressable3D(
      enabled: onPressed != null,
      maxTilt: 0.05,
      pressScale: 0.96,
      child: sized,
    );
  }
}
