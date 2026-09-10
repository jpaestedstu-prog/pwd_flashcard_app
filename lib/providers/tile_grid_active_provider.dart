import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/gamepad/providers/gamepad_settings_provider.dart';
import '../features/gamepad/providers/gamepad_status_provider.dart';
import '../features/gaze_control/providers/gaze_settings_provider.dart';

/// Whether the foreground hub should publish its feature tiles to
/// `gazeHomeGrid`.
///
/// The tile grid started life as a gaze-only affordance, so every hub gated it
/// on `gazeSettings.enabled && navHomeTiles`. A Bluetooth controller needs the
/// exact same list of addressable cells — and needs it *without* a camera or a
/// gaze opt-in — so the gate moved here, where both input methods can ask for
/// it. The grid itself is unchanged; only the question "does anyone need it?"
/// now has two possible answers.
///
/// The gamepad arm is additionally gated on a controller actually being
/// connected. Publishing costs a focus-ring `Stack` around every tile and an
/// eager (rather than lazy) category grid, so a learner who never pairs a pad
/// pays nothing for the feature being switched on by default.
final tileGridActiveProvider = Provider<bool>((ref) {
  final gazeWants = ref.watch(
    gazeSettingsProvider.select((s) => s.enabled && s.navHomeTiles),
  );
  if (gazeWants) return true;

  final gamepadOn = ref.watch(
    gamepadSettingsProvider.select((s) => s.enabled),
  );
  if (!gamepadOn) return false;

  return ref.watch(gamepadStatusProvider.select((s) => s.connected));
});
