import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/services/update_check_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/pro_surface.dart';
import '../data/local/hive_service.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';
import 'app_snack_bar.dart';

AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();

/// Opens the website's download section in the browser, or — when no browser
/// answers — says where to go, so the button is never a dead tap.
Future<void> openUpdatePage(BuildContext context, AppRelease release) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(release.pageUrl),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    AppSnackBar.info(
      context,
      message: _t(context).updateOpenFailed(release.pageUrl),
    );
  }
}

/// "A new version is ready" on the educator home.
///
/// Teachers and parents only: they are the ones who install the APK, and a
/// child cannot act on it. "Later" hides it for that version; a newer one
/// brings it back. Renders nothing when the tablet is up to date, offline, or
/// the check has not answered yet.
class UpdateAvailableCard extends ConsumerStatefulWidget {
  const UpdateAvailableCard({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  ConsumerState<UpdateAvailableCard> createState() =>
      _UpdateAvailableCardState();
}

class _UpdateAvailableCardState extends ConsumerState<UpdateAvailableCard> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(updateStatusProvider).valueOrNull;
    // Status first: only a real update reads the settings box.
    if (status is! UpdateAvailable || _dismissed) {
      return const SizedBox.shrink();
    }
    final release = status.release;
    if (HiveService.getDismissedUpdateVersion() == release.version) {
      return const SizedBox.shrink();
    }
    final t = _t(context);
    final hc = HCColor.of(context);
    return Padding(
      padding: widget.padding,
      child: ProPanel(
        accent: hc.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.system_update_rounded, color: hc.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.updateCardTitle,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hc.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t.updateCardBody(release.version),
              style: AppTypography.bodyMedium.copyWith(
                color: hc.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            // A Wrap, not ProButtonRow: the accent stripe measures the panel
            // with IntrinsicHeight, which a LayoutBuilder cannot answer.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => openUpdatePage(context, release),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(t.updateCardGet),
                ),
                OutlinedButton(
                  onPressed: () {
                    HiveService.dismissUpdateVersion(release.version);
                    setState(() => _dismissed = true);
                  },
                  child: Text(t.updateCardLater),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
