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
}
