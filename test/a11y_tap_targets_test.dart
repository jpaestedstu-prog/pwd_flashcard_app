import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';

import 'support/a11y_sweep.dart';
import 'support/all_screens.dart';
import 'support/real_fonts.dart';

/// Targets the sweep cannot judge, by screen and label. Each sits in a strip
/// that scrolls sideways, which the sweep does not scroll, so it only ever
/// sees the part showing at the strip's edge; each is a full 48 dp tall.
const _cutOffBySidewaysStrip = <String, Set<String>>{
  'ShopScreen': {'Titles / Tab 4 of 6'},
  'AiTutorScreen': {'Hint / 💡 / Hint'},
  'ParentTeacherNotesScreen': {'Behaviour / 🌟 / Behaviour'},
  'FslDictionaryScreen': {'I can sign · 0'},
};

/// Every tap target on every screen, as a screen reader and a finger meet it:
/// it says what it is, and it is at least 48 x 48 dp. See
/// [collectTapTargetIssues].
void main() {
  setUpAll(() async {
    // The app's own theme and fonts: button and chip sizes follow them.
    await loadRealFonts();
    await openSweepBoxes('a11y_tap_targets');
  });
  tearDownAll(closeSweepBoxes);

  for (final entry in kAllScreens.entries) {
    testWidgets('${entry.key}: every tap target is named and big enough',
        (tester) async {
      final (build, role) = entry.value;
      final issues = await collectTapTargetIssues(
        tester,
        build,
        overrides: [sweepProfileOverride(role)],
        theme: AppTheme.light,
        settle: const Duration(seconds: 3),
        // The Quiz Builder lists every word: 80 steps reach its end.
        maxScrolls: 80,
      );
      final known = _cutOffBySidewaysStrip[entry.key] ?? const <String>{};
      final problems = [
        for (final issue in issues)
          if (!known.any((label) => issue.contains('"$label"'))) issue,
      ];
      for (final issue in problems) {
        debugPrint('A11Y ${entry.key} | $issue');
      }
      expect(problems, isEmpty);
    });
  }
}
