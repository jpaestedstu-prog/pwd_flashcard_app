import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/accessibility/haptic_service.dart';
import '../core/accessibility/sound_service.dart';
import 'tilt_3d.dart';

/// Accessible icon-only control — the shared primitive behind the app's
/// navigation / utility icon buttons (Back, Menu, Close, Exit, and others).
///
/// On top of a plain [IconButton] it adds the things every interactive surface
/// in this app should have, mirroring [AppButton]:
///
///  - **Haptic + tap sound** on press, via the global accessibility services
///    (disable with [hapticOnPress] / [soundOnPress]).
///  - A **single screen-reader node**: the [IconButton] already exposes
///    button semantics and announces [tooltip]; [semanticLabel] overrides it
///    via the icon's own semantics. No wrapper node, so TalkBack users get
///    exactly one focus stop per control.
///  - A guaranteed **≥48dp tap target** (inherited from the global
///    `iconButtonTheme`; raise it with [minSize] for primary controls so
///    they're easy to hit for motor-impaired users and young children).
///  - A **larger default icon** than Flutter's 24px (the theme sets 26),
///    sized for child students and low-vision users.
///
/// Colour defaults to the active theme; pass [color] only when a screen needs
/// an explicit tint (e.g. an icon sitting on a coloured header).
class AppIconButton extends ConsumerWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.semanticLabel,
    this.color,
    this.iconSize,
    this.minSize,
    this.hapticOnPress = true,
    this.soundOnPress = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Shown on long-press / hover and used as the default screen-reader label.
  final String tooltip;

  /// Overrides the screen-reader label; defaults to [tooltip].
  final String? semanticLabel;

  /// Explicit icon tint. When null the icon inherits the theme's icon color.
  final Color? color;

  /// Icon size override. When null it inherits the global `iconButtonTheme`
  /// (26dp), which is already larger than Flutter's 24dp default.
  final double? iconSize;

  /// Minimum tap-target size (square). When null it inherits the global 48dp
  /// floor; raise to ~56 for primary controls.
  final double? minSize;

  /// When true (default), a light haptic fires on press.
  final bool hapticOnPress;

  /// When true (default), the button-tap sound effect fires on press.
  final bool soundOnPress;

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

    // Only build a style override when a screen actually customizes the size;
    // otherwise inherit the global iconButtonTheme so themes stay consistent.
    final ButtonStyle? style = minSize == null
        ? null
        : IconButton.styleFrom(
            minimumSize: Size(minSize!, minSize!),
            tapTargetSize: MaterialTapTargetSize.padded,
          );

    return Pressable3D(
      enabled: onPressed != null,
      maxTilt: 0.08,
      pressScale: 0.92,
      child: IconButton(
        icon: Icon(icon, color: color, semanticLabel: semanticLabel),
        tooltip: tooltip,
        iconSize: iconSize,
        style: style,
        onPressed: onPressed == null ? null : handlePress,
      ),
    );
  }
}
