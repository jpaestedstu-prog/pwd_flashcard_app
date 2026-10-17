import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';

import 'support/all_screens.dart';
import 'support/deep_scroll.dart';
import 'support/real_fonts.dart';

/// Every screen on a 360 dp phone, scrolled to the end, at the default text
/// size, the Visual Impairment preset's 1.4x and the 2.0x maximum, in English
/// and in Filipino (whose words run longer): no layout error, no row wider
/// than its space, no word broken in two. See [collectDeepLayoutIssues].
void main() {
  setUpAll(() async {
    // The app's fonts and theme: with the test's em-wide glyphs every row
    // of text looks too wide, and the real problems drown.
    await loadRealFonts();
    await openSweepBoxes('deep_scroll_layout');
  });
  tearDownAll(closeSweepBoxes);

  for (final language in const ['en', 'fil']) {
    group(language == 'en' ? 'English' : 'Filipino', () {
      // Screens choose their words from the learner's own settings as well
      // as from the app's locale: both follow [language].
      setUpAll(() async {
        await HiveService.saveSettings(
          HiveService.getSettings(profileId: 'sweep-profile')
              .copyWith(locale: language),
          profileId: 'sweep-profile',
        );
      });

      for (final entry in kAllScreens.entries) {
        // Moves on to the next screen after its timer, which needs the
        // app's router; uncovered_screens_test lays it out.
        if (entry.key == 'SplashScreen') continue;
        for (final scale in const [1.0, 1.4, 2.0]) {
          testWidgets('${entry.key} reads whole to the end at ${scale}x',
              (tester) async {
            final (build, role) = entry.value;
            final issues = await collectDeepLayoutIssues(
              tester,
              build,
              overrides: [sweepProfileOverride(role)],
              scale: scale,
              locale: Locale(language),
              theme: AppTheme.light,
              settle: const Duration(seconds: 3),
            );
            for (final issue in issues) {
              debugPrint('DEEP $language ${entry.key} ${scale}x | $issue');
            }
            expect(issues, isEmpty);
          });
        }
      }
    });
  }
}
