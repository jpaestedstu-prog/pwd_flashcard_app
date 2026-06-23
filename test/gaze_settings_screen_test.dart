import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/screens/gaze_settings_screen.dart';

import 'support/screen_matrix.dart';

class _FixedSettings extends GazeSettingsNotifier {
  _FixedSettings(this._value);
  final GazeSettings _value;
  @override
  GazeSettings build() => _value;
}

void main() {
  testWidgets('gaze settings screen survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const GazeSettingsScreen(),
    );
  });

  testWidgets('settings screen survives the matrix with scan mode on '
      '(scan-speed slider shown)', (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const GazeSettingsScreen(),
      overrides: [
        gazeSettingsProvider.overrideWith(
          () => _FixedSettings(const GazeSettings(
            enabled: true,
            scanMode: true,
          )),
        ),
      ],
    );
  });

  testWidgets('toggling "Enable Gaze Control" updates the UI', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: GazeSettingsScreen()),
      ),
    );
    await tester.pump();

    // Off by default.
    expect(find.text('Off — touch only'), findsOneWidget);

    // Flip the enable switch (the first switch on the screen).
    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(find.text('Head movements & blinks can drive the app'),
        findsOneWidget);
  });

  testWidgets('selecting "Bottom nav + feature tiles" updates the nav scope',
      (tester) async {
    final container = ProviderContainer(overrides: [
      gazeSettingsProvider.overrideWith(
        () => _FixedSettings(const GazeSettings(enabled: true)),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GazeSettingsScreen()),
      ),
    );
    await tester.pump();

    expect(container.read(gazeSettingsProvider).navScope, GazeNavScope.bottomNav);

    await tester.tap(find.text('Bottom nav + feature tiles'));
    await tester.pump();

    expect(container.read(gazeSettingsProvider).navScope,
        GazeNavScope.bottomNavAndHomeTiles);
  });
}
