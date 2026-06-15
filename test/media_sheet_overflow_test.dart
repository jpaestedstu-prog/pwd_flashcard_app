import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/flashcards/widgets/media_sheet_layout.dart';

import 'support/device_matrix.dart';

/// Regression test for the "Show Me" sheet bottom overflow: a square (720×720)
/// clip used to force the media as tall as the sheet is wide, overflowing a
/// short landscape viewport. [MediaSheetLayout] must cap the media height and
/// scroll, so it never overflows on any device / orientation / font scale.
void main() {
  Widget squareMediaSheet(_) => MediaSheetLayout(
        icon: Icons.smart_display_rounded,
        title: 'Show Me — Partly Cloudy',
        caption:
            'A long caption that describes the word in a full, kid-friendly '
            'sentence so we also exercise the wrapping/scrolling of the text.',
        mediaBuilder: (_) => const Center(
          // The worst case: a square clip (aspect 1.0).
          child: AspectRatio(
            aspectRatio: 1,
            child: ColoredBox(color: Colors.black12),
          ),
        ),
        belowMedia: const SizedBox(height: 8, width: 40),
      );

  testWidgets('Show Me / media sheet never overflows across the matrix',
      (tester) async {
    await expectNoOverflowAcrossDevices(tester, squareMediaSheet);
  });

  testWidgets('media sheet survives a very wide landscape viewport',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      squareMediaSheet,
      devices: const [
        DeviceSize('phone landscape', Size(640, 360), devicePixelRatio: 3.0),
        DeviceSize('7" landscape', Size(960, 600)),
        DeviceSize('XL landscape', Size(1366, 1024)),
      ],
    );
  });
}
