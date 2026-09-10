import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/widgets/language_replay_bar.dart';

import 'support/screen_matrix.dart';

/// The two-language audio replay bar (English + Filipino "listen" buttons) must
/// lay out without overflow on every Android tablet size × orientation ×
/// accessibility font scale — including the narrow widths / 2.0× font scale
/// where its two equal-width cells stack onto a second row.
///
/// Rendered via the localization-aware screen matrix because the widget reads
/// `AppLocalizations` for its button labels.
void main() {
  testWidgets('LanguageReplayBar never overflows across the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          // Bottom-aligned, mirroring how it sits above the action strip on the
          // real flashcard / smart-review screens (a bounded-width Column cell).
          child: Column(
            children: [
              const Spacer(),
              LanguageReplayBar(onEnglish: () {}, onFilipino: () {}),
            ],
          ),
        ),
      ),
    );
  });

  // ─── The accessibility themes, at the accessibility font sizes ───
  //
  // The pass above renders under Flutter's default theme, which is not a theme
  // any learner sees. The dyslexia theme adds a 1.6 line height and 0.6 letter
  // spacing on top of its own font sizes; high contrast overrides the text
  // theme and outlines every card. Narrow portrait at 1.5x/2.0x, where a
  // theme's metrics bite first.
  testWidgets('LanguageReplayBar survives the accessibility themes',
      (tester) async {
    await expectScreenSurvivesThemes(
      tester,
      () => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Spacer(),
              LanguageReplayBar(onEnglish: () {}, onFilipino: () {}),
            ],
          ),
        ),
      ),
    );
  });
}
