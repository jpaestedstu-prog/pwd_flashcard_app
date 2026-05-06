import 'dart:ui';

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  Animated Dialog
// ─────────────────────────────────────────────────────────────

/// Shows a dialog with a bounce-scale + fade entrance animation,
/// optional gradient header bar, and backdrop blur.
///
/// Drop-in replacement for [showDialog]. All callers get the
/// animated treatment automatically.
Future<T?> showAnimatedDialog<T>(
  BuildContext context, {
  required Widget child,
  bool barrierDismissible = true,
  Color? headerColor,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, animation, secondaryAnimation) {
      return child;
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 3.0 * animation.value,
          sigmaY: 3.0 * animation.value,
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        ),
      );
    },
  );
}

/// Shows an animated confirmation dialog with bounce entrance,
/// backdrop blur, and optional gradient header.
///
/// Drop-in replacement for [showConfirmDialog].
Future<bool?> showAnimatedConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
  Color? headerColor,
  String? emoji,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return showAnimatedDialog<bool>(
    context,
    child: AlertDialog(
      title: Row(
        children: [
          if (emoji != null) ...[
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(title)),
        ],
      ),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// Shows an animated dialog with custom content.
///
/// Drop-in replacement for [showAppDialog].
Future<T?> showAnimatedAppDialog<T>(
  BuildContext context, {
  required String title,
  required Widget content,
  List<Widget>? actions,
  String? emoji,
}) {
  return showAnimatedDialog<T>(
    context,
    child: AlertDialog(
      title: Row(
        children: [
          if (emoji != null) ...[
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(title)),
        ],
      ),
      content: content,
      actions: actions,
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  Animated Bottom Sheet
// ─────────────────────────────────────────────────────────────

/// Shows a bottom sheet with slide-up + fade animation and
/// a rounded top with drag handle. Optional gradient header.
///
/// Drop-in replacement for [showModalBottomSheet].
Future<T?> showAnimatedBottomSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext context) builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  Color? headerColor,
  double? maxHeightFraction,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.transparent,
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 400),
    ),
    builder: (ctx) {
      final content = builder(ctx);
      return _AnimatedSheetWrapper(
        headerColor: headerColor,
        maxHeightFraction: maxHeightFraction ?? 0.85,
        child: content,
      );
    },
  );
}

class _AnimatedSheetWrapper extends StatelessWidget {
  final Widget child;
  final Color? headerColor;
  final double maxHeightFraction;

  const _AnimatedSheetWrapper({
    required this.child,
    this.headerColor,
    this.maxHeightFraction = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final height = MediaQuery.sizeOf(context).height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height * maxHeightFraction),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Handle + optional gradient header ─────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: headerColor != null
                    ? LinearGradient(
                        colors: [
                          headerColor!,
                          headerColor!.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: headerColor != null
                        ? Colors.white.withValues(alpha: 0.5)
                        : theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // ─── Content ───────────────────────────────
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
