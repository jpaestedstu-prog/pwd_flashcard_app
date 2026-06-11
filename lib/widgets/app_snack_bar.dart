import 'package:flutter/material.dart';

import '../core/theme/semantic_colors.dart';

/// Unified snackbar helper that enforces consistent styling across the app.
///
/// Usage:
/// ```dart
/// AppSnackBar.show(context, message: 'Saved!');
/// AppSnackBar.success(context, message: 'Flashcard created! 🎉');
/// AppSnackBar.error(context, message: 'Something went wrong');
/// AppSnackBar.warning(context, message: 'No internet connection');
/// ```
class AppSnackBar {
  AppSnackBar._();

  /// Show a themed snackbar with the app's standard styling.
  static void show(
    BuildContext context, {
    required String message,
    Color? backgroundColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor ?? colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: duration,
        action: action,
      ),
    );
  }

  /// Success variant — adapts to the active theme's semantic palette.
  static void success(BuildContext context, {required String message}) {
    show(
      context,
      message: message,
      backgroundColor: SemanticColors.of(context).success,
      icon: Icons.check_circle_rounded,
    );
  }

  /// Error variant — adapts to the active theme's semantic palette.
  static void error(BuildContext context, {required String message}) {
    show(
      context,
      message: message,
      backgroundColor: SemanticColors.of(context).error,
      icon: Icons.error_rounded,
      duration: const Duration(seconds: 4),
    );
  }

  /// Warning variant — adapts to the active theme's semantic palette.
  static void warning(BuildContext context, {required String message}) {
    show(
      context,
      message: message,
      backgroundColor: SemanticColors.of(context).warning,
      icon: Icons.warning_rounded,
    );
  }

  /// Info variant — adapts to the active theme's semantic palette.
  static void info(BuildContext context, {required String message}) {
    show(
      context,
      message: message,
      backgroundColor: SemanticColors.of(context).info,
      icon: Icons.info_rounded,
    );
  }
}
