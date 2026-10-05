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
        () => _FixedSettings(const GazeSettings(
          enabled: true,
          navScope: GazeNavScope.bottomNav,
        )),
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

    // …and back again: nav-only stays a real, selectable choice.
    await tester.tap(find.text('Bottom nav only'));
    await tester.pump();
    expect(container.read(gazeSettingsProvider).navScope, GazeNavScope.bottomNav);
  });

  testWidgets('every slider has − / + buttons a hands-free learner can press',
      (tester) async {
    final container = ProviderContainer(overrides: [
      gazeSettingsProvider.overrideWith(
        () => _FixedSettings(const GazeSettings(enabled: true, scanMode: true)),
      ),
    ]);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GazeSettingsScreen()),
      ),
    );
    await tester.pump();

    GazeSettings now() => container.read(gazeSettingsProvider);

    await tester.tap(find.byTooltip('Increase Sensitivity'));
    await tester.pump();
    expect(now().sensitivity, 4);
    await tester.tap(find.byTooltip('Decrease Hold time'));
    await tester.pump();
    expect(now().dwellMs, 1400, reason: 'one 0.1 s notch');
    await tester.tap(find.byTooltip('Increase Scan speed'));
    await tester.pump();
    expect(now().scanStepMs, 2250, reason: 'one 0.25 s notch');

    // At the top of the range the + stops, rather than doing nothing.
    container.read(gazeSettingsProvider.notifier).setSensitivity(5);
    await tester.pump();
    final plus = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.add_circle_outline_rounded).first,
        matching: find.byType(IconButton),
      ),
    );
    expect(plus.onPressed, isNull);
  });

  testWidgets('scanning locks "Blink to confirm" on, and says why',
      (tester) async {
    final container = ProviderContainer(overrides: [
      gazeSettingsProvider.overrideWith(
        () => _FixedSettings(const GazeSettings(
          enabled: true,
          blinkEnabled: false,
        )),
      ),
    ]);
    addTearDown(container.dispose);
    // Tall enough that the lazy list builds the tuning section.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GazeSettingsScreen()),
      ),
    );
    await tester.pump();

    SwitchListTile blinkTile() => tester.widget<SwitchListTile>(
          find.ancestor(
            of: find.text('Blink to confirm'),
            matching: find.byType(SwitchListTile),
          ),
        );

    // Head mode: the learner's own choice (off) shows, and it can change.
    expect(blinkTile().value, isFalse);
    expect(blinkTile().onChanged, isNotNull);

    container.read(gazeSettingsProvider.notifier).setScanMode(true);
    await tester.pump();

    // Scanning picks with a blink and nothing else: shown on, not switchable.
    expect(blinkTile().value, isTrue);
    expect(blinkTile().onChanged, isNull);
    expect(find.textContaining('a blink is how scanning picks'), findsOneWidget);
    expect(container.read(gazeSettingsProvider).blinkSelects, isTrue);
  });

  // ─── The accessibility themes, at the accessibility font sizes ───
  //
  // The pass above renders under Flutter's default theme, which is not a theme
  // any learner sees. The dyslexia theme adds a 1.6 line height and 0.6 letter
  // spacing on top of its own font sizes; high contrast overrides the text
  // theme and outlines every card. Narrow portrait at 1.5x/2.0x, where a
  // theme's metrics bite first.
  testWidgets('GazeSettingsScreen survives the accessibility themes',
      (tester) async {
    await expectScreenSurvivesThemes(
      tester,
      () => const GazeSettingsScreen(),
    );
  });

  testWidgets('GazeSettingsScreen with scan mode survives the themes',
      (tester) async {
    await expectScreenSurvivesThemes(
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
}
