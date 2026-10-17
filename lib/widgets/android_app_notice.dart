import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';

/// Says, where a feature is offered in the browser version, that it needs
/// the Android app, and why; with a link to the website's download page.
///
/// The browser version has no file system, no system alarms or
/// notifications, no local server and no on-device recognisers. Each feature
/// built on those says so here instead of offering a button that fails, or
/// that seems to work and does nothing (a reminder that never comes).
class AndroidAppNotice extends StatelessWidget {
  const AndroidAppNotice({
    super.key,
    required this.message,
    this.showLink = true,
  });

  /// What does not work here and what to do instead, in the learner's
  /// language (a `web…` string).
  final String message;

  /// The "Get the Android app" link. Off where the notice repeats one shown
  /// higher on the same screen.
  final bool showLink;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final t = AppLocalizations.of(context) ?? AppLocalizationsEn();
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hc.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.phone_android_rounded, color: hc.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: AppTypography.bodyMedium.copyWith(
                      color: hc.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (showLink) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(AppConstants.downloadPageUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(t.webGetAndroidApp),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
