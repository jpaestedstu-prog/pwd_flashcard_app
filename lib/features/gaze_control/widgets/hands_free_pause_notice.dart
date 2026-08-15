import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart' show AppColors;
import '../../../core/theme/app_typography.dart' show AppTypography;

/// Warns before entering an activity that **takes the camera away from Gaze
/// Control**, and asks the learner to confirm.
///
/// Two activities do this. FSL "Sign It!" records the learner signing, and
/// video recording cannot share a `CameraController` with the gaze detector's
/// image stream. **Word Hunt** points the *back* lens at the world, and the
/// detector needs the front one. Either way head control genuinely cannot run
/// while the activity is open, so [reason] says which it is.
///
/// The honest design is not to pretend these are hands-free, and not to hide
/// them either — it is to say plainly what will happen and let the learner
/// decide. The dialog itself is gaze-navigable (it is shown from the hub, where
/// the focus-traversal fallback is live), so the choice is reachable hands-free
/// even when the destination is not.
///
/// Where the two differ is the escape hatch. Sign It is by its nature done
/// *with your hands*; Word Hunt is not, and it keeps the microphone listening,
/// so a learner with voice commands on can drive the whole activity by voice —
/// see [voiceHint].
Future<bool> confirmHandsFreePause(
  BuildContext context, {
  required String activityName,
  required bool voiceAvailable,

  /// Why this activity needs the camera to itself. Defaults to Sign It's
  /// reason, the original caller.
  String reason =
      'This activity records you signing, so it needs the camera '
      'to itself. Head control will pause while it is open.',

  /// What voice can still do inside, shown when [voiceAvailable]. Defaults to
  /// the bare minimum every such screen offers: a spoken way out.
  String voiceHint = 'You can still say "go back" to leave at any time.',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.front_hand_rounded, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$activityName uses the camera',
              style: AppTypography.titleLarge,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reason, style: AppTypography.bodyLarge),
          const SizedBox(height: 12),
          Text(
            voiceAvailable
                ? voiceHint
                : 'To leave, use the Back button at the top — or turn on Voice '
                      'commands in Settings → Accessibility → Gaze Control first, '
                      'so you can say "go back".',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Open anyway'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
