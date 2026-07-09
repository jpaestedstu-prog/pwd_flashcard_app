import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/features/games/widgets/pause_overlay.dart';

import 'support/device_matrix.dart';

/// Overflow coverage for the in-game **Pause overlay** — a button-dense,
/// non-scrolling centred card. Its risk case is a short (landscape / small
/// phone) viewport at a large accessibility font scale, where the stacked
/// header + four action buttons + divider + sound toggle can exceed the
/// viewport height. Rendered across the full tablet/phone matrix here.
void main() {
  setUpAll(() async {
    // PauseOverlay reads settingsProvider (Hive-backed, per-profile).
    Hive.init('./build/test_cache/pause_overlay');
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
    if (!Hive.isBoxOpen('profiles')) await Hive.openBox('profiles');
  });
  tearDownAll(() async => Hive.deleteFromDisk());

  testWidgets('PauseOverlay survives the device matrix', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) =>
          PauseOverlay(onResume: () {}, onRestart: () {}, onQuit: () async {}),
    );
  });
}
