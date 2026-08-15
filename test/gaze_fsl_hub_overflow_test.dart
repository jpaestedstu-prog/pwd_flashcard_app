import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/features/games/screens/fsl_practice_hub_screen.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';

import 'support/device_matrix.dart';
import 'support/screen_matrix.dart';

/// The FSL Practice hub grows a longer "Sign It!" subtitle when Gaze Control is
/// on — it must add "Uses your hands — head control pauses here." That extra
/// line lands inside a gradient card, which is exactly the shape that bursts at
/// a large accessibility font. The hub had no overflow coverage at all, so this
/// pins both states.
///
/// **Portrait only**, matching how the other portrait-designed screens are
/// tested (see `FlashcardQuizScreen` in `games_screens_overflow_test`): the app
/// is locked to portrait in three layers, so a 360 px-tall landscape viewport
/// is not a configuration a learner can reach.

class _GazeOn extends GazeSettingsNotifier {
  @override
  GazeSettings build() => const GazeSettings(enabled: true);
}

class _GazeOff extends GazeSettingsNotifier {
  @override
  GazeSettings build() => const GazeSettings();
}

final List<DeviceSize> _portraitOnly =
    kTabletMatrix.where((d) => !d.label.contains('landscape')).toList();

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/fsl_hub_overflow');
    for (final name in const <String>['profiles', 'settings', 'progress']) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
  });

  tearDownAll(() async {
    try {
      await Hive.deleteFromDisk().timeout(const Duration(seconds: 10));
    } catch (_) {}
  });

  testWidgets('FSL hub survives the portrait matrix with gaze OFF',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      FslPracticeHubScreen.new,
      devices: _portraitOnly,
      overrides: [gazeSettingsProvider.overrideWith(_GazeOff.new)],
    );
  });

  testWidgets('FSL hub survives the portrait matrix with the gaze caveat shown',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      FslPracticeHubScreen.new,
      devices: _portraitOnly,
      overrides: [gazeSettingsProvider.overrideWith(_GazeOn.new)],
    );
  });
}
