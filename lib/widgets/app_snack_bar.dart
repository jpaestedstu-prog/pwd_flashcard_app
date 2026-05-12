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
///
/// For async flows — capture once before the await, show after:
/// ```dart
/// final bar = AppSnackBar.captureFor(context);
/// final ok = await someFuture();
/// if (!mounted) return;
/// bar.success('Saved!');  // safe: no BuildContext used post-await
/// ```
class AppSnackBar {
  AppSnackBar._();

  /// Snapshot the ScaffoldMessenger and ColorScheme for [context] so the
  /// snackbar can be shown safely after an `await`, even if the widget that
  /// originally provided [context] has been unmounted.
  ///
  /// The caller is still responsible for checking `mounted` before doing
  /// anything else with the original context (e.g. `Navigator.pop`).
  static CapturedAppSnackBar captureFor(BuildContext context) {
    return CapturedAppSnackBar._(
      messenger: ScaffoldMessenger.of(context),
      semanticColors: SemanticColors.of(context),
      inverseSurface: Theme.of(context).colorScheme.inverseSurface,
    );
  }

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
    _showOn(
      ScaffoldMessenger.of(context),
      message: message,
      backgroundColor: backgroundColor ?? colorScheme.inverseSurface,
      icon: icon,
      duration: duration,
      action: action,
    );
  }

  static void _showOn(
    ScaffoldMessengerState messenger, {
    required String message,
    required Color backgroundColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    messenger.clearSnackBars();
    messenger.showSnackBar(
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
        backgroundColor: backgroundColor,
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

/// Async-safe snackbar handle returned by [AppSnackBar.captureFor].
///
/// Holds a reference to the [ScaffoldMessengerState] that was alive when
/// [AppSnackBar.captureFor] was called, so the snackbar can be shown after
/// an `await` without touching a potentially-deactivated [BuildContext].
class CapturedAppSnackBar {
  final ScaffoldMessengerState _messenger;
  final SemanticColors _semanticColors;
  final Color _inverseSurface;

  const CapturedAppSnackBar._({
    required ScaffoldMessengerState messenger,
    required SemanticColors semanticColors,
    required Color inverseSurface,
  })  : _messenger = messenger,
        _semanticColors = semanticColors,
        _inverseSurface = inverseSurface;

  void show(String message, {Color? backgroundColor, IconData? icon}) {
    AppSnackBar._showOn(
      _messenger,
      message: message,
      backgroundColor: backgroundColor ?? _inverseSurface,
      icon: icon,
    );
  }

  void success(String message) => show(
        message,
        backgroundColor: _semanticColors.success,
        icon: Icons.check_circle_rounded,
      );

  void error(String message) => show(
        message,
        backgroundColor: _semanticColors.error,
        icon: Icons.error_rounded,
      );

  void warning(String message) => show(
        message,
        backgroundColor: _semanticColors.warning,
        icon: Icons.warning_rounded,
      );

  void info(String message) => show(
        message,
        backgroundColor: _semanticColors.info,
        icon: Icons.info_rounded,
      );
}
