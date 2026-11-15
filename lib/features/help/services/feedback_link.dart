import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/adult_gate_dialog.dart';

/// The website's Rate & Feedback form. The app has no feedback form of its
/// own: the website's form saves each message for the team's dashboard and
/// says honestly whether it was sent, so the app sends people there.
final Uri feedbackFormUri = Uri.parse(
  '${AppConstants.websiteUrl}faq.html#feedback',
);

/// Opens the feedback form in the browser — after a grown-up's yes for a
/// student or child, as for every web page the app opens. When no browser
/// opens (none installed, or blocked), says so and shows the address — never
/// a silent tap.
Future<void> openFeedbackForm(BuildContext context, WidgetRef ref) async {
  final t = AppLocalizations.of(context);
  final allowed = await requireAdult(
    context,
    ref,
    reason:
        t?.settingPrivacyAdultReason ??
        'This opens a web page. A grown-up needs to say yes first.',
  );
  if (!allowed || !context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(
      feedbackFormUri,
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          t?.feedbackOpenFailed(feedbackFormUri.toString()) ??
              'Could not open the feedback page. Visit $feedbackFormUri',
        ),
      ),
    );
  }
}
