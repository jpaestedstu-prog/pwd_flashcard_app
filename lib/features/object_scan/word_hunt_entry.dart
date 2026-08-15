import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../gaze_control/providers/gaze_settings_provider.dart';
import '../gaze_control/widgets/hands_free_pause_notice.dart';

/// The single way into Word Hunt from a hub tile.
///
/// Word Hunt holds the camera, so the shell's head-control camera stands down
/// for as long as it is open — exactly the trade FSL "Sign It!" makes. A
/// learner who arrived by gaze needs to know that *before* the screen swallows
/// their only input, so they get the same plain warning and the same real
/// choice.
///
/// Unlike Sign It, Word Hunt is fully drivable by voice once inside (shutter,
/// picking a found word, leaving), so the hint says so rather than only
/// offering an exit.
///
/// One helper, called from every hub, so the two learner home screens can
/// never drift apart on this.
Future<void> openWordHunt(BuildContext context, WidgetRef ref) async {
  final gaze = ref.read(gazeSettingsProvider);
  if (gaze.enabled) {
    final reason = AppLocalizations.of(context)!.wordHuntCameraBusyReason;
    final proceed = await confirmHandsFreePause(
      context,
      activityName: 'Word Hunt',
      voiceAvailable: gaze.voiceCommands,
      reason: reason,
      voiceHint:
          'You can say "take a photo" to shoot, a word\'s name to open '
          'it, and "go back" to leave.',
    );
    if (!proceed || !context.mounted) return;
  }
  if (!context.mounted) return;
  context.push('/object-scan');
}
