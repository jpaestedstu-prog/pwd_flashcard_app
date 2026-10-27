import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'support/all_screens.dart';
import 'support/dpad_reach.dart';
import 'support/real_fonts.dart';

/// Every screen the sweeps know, as a D-pad meets it: each tap target must be
/// a control a directional press can land on. Pushed screens and dialogs
/// publish no grid, so this is the path gaze and the game controller take on
/// them too (focus traversal), not only a keyboard's arrow keys.
void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openSweepBoxes('dpad_focus_sweep');
  });
  tearDownAll(closeSweepBoxes);

  for (final entry in kAllScreens.entries) {
    testWidgets('${entry.key}: every tap target takes D-pad focus',
        (tester) async {
      final (build, role) = entry.value;
      final semantics = tester.ensureSemantics();
      const size = Size(686, 1097);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sweepProfileOverride(role)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: build(),
          ),
        ),
      );
      for (var t = 0; t < 25; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final report = await surveyDpadReach(
        tester,
        devicePixelRatio: 1.0,
        maxScrolls: 80,
      );
      for (final t in report.notFocusable) {
        debugPrint('FOCUS ${entry.key} | $t');
      }
      debugPrint('FOCUS ${entry.key} | ${report.targets.length} targets, '
          '${report.notFocusable.length} not focusable');
      expect(report.notFocusable.map((t) => '$t'), isEmpty,
          reason: 'every control takes D-pad focus');

      for (var t = 0; t < 30; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
      semantics.dispose();
    });
  }
}
