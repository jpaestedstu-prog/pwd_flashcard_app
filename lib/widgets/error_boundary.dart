import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/error_handler.dart';

/// A widget that catches errors in its child widget tree and displays
/// a friendly fallback UI instead of a red error screen.
///
/// Also listens to the global [ErrorHandler.errorStream] to show
/// snackbar notifications for errors that occur outside the widget tree.
class ErrorBoundary extends StatefulWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  StreamSubscription<AppError>? _errorSub;

  @override
  void initState() {
    super.initState();
    // Listen for global errors and show snackbar
    _errorSub = ErrorHandler.errorStream.listen(_onGlobalError);
  }

  void _onGlobalError(AppError error) {
    if (!mounted) return;
    // Only show snackbar for non-widget-tree errors (widget errors are caught
    // by ErrorWidget.builder instead). Avoid spamming — debounce if needed.
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.textOnPrimary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error.userMessage,
                  style: const TextStyle(color: AppColors.textOnPrimary),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'OK',
            textColor: AppColors.textOnPrimary,
            onPressed: () => messenger.hideCurrentSnackBar(),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// A friendly error widget to replace the default red error screen.
/// Call [setupErrorWidget] in main() to install this globally.
void setupErrorWidget() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return _FriendlyErrorWidget(details: details);
  };
}

class _FriendlyErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;

  const _FriendlyErrorWidget({required this.details});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sentiment_dissatisfied_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HCColor.of(context).textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This part of the app ran into a problem.\n'
              'Try going back or restarting the app.',
              style: TextStyle(
                fontSize: 13,
                color: HCColor.of(context).textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
