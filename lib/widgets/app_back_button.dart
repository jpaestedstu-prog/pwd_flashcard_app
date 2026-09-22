import 'package:flutter/material.dart';

import '../navigation/nav_extensions.dart';
import '../l10n/app_localizations.dart';
import 'app_icon_button.dart';

/// Pops the nav stack when possible; falls back to [fallbackRoute] otherwise
/// (deep-link entry, browser refresh). Use [onBeforePop] for cleanup that
/// must run before navigation; return false to cancel.
///
/// Renders an [AppIconButton], so it inherits the app's accessible icon sizing
/// (26dp icon, ≥48dp tap target), the light haptic + tap sound, and the
/// screen-reader semantics for free — no call-site changes required.
class AppBackButton extends StatelessWidget {
  final String fallbackRoute;
  final Future<bool> Function()? onBeforePop;
  /// Defaults to "Go back" in the reader's language.
  final String? tooltip;
  final Color? color;

  const AppBackButton({
    super.key,
    this.fallbackRoute = '/home',
    this.onBeforePop,
    this.tooltip,
    this.color,
  });

  Future<void> _handlePop(BuildContext context) async {
    if (onBeforePop != null) {
      final proceed = await onBeforePop!();
      if (!proceed || !context.mounted) return;
    }
    context.popOrGo(fallbackRoute);
  }

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: tooltip ?? AppLocalizations.of(context)?.navGoBack ?? 'Go back',
      color: color,
      onPressed: () => _handlePop(context),
    );
  }
}
