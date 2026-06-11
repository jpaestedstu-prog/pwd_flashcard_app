import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/widgets/hub_header.dart';

import 'support/device_matrix.dart';

/// Cross-device overflow matrix for the kid / guest hub header.
///
/// [HubHeader] is the icon + title + subtitle strip used at the top of the
/// Child / Player home and Stories hub. It must lay out without overflow across
/// every tablet size × orientation × font scale — including with deliberately
/// long, wrapping title/subtitle text at the 2.0× accessibility scale.
///
/// `HubScaffold` is intentionally not rendered here: it composes the already
/// app-wide `AnimatedGradientBackground` (which reads Hive-backed settings) and
/// adds no new layout logic of its own — it's a thin Scaffold/SafeArea wrapper.

void main() {
  testWidgets('HubHeader (short) never overflows', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const HubHeader(
        leadingIcon: Icons.auto_stories_rounded,
        title: 'Stories',
        subtitle: 'Read stories and answer',
      ),
      host: LayoutHost.scrollable,
    );
  });

  testWidgets('HubHeader (long, wrapping) never overflows', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const HubHeader(
        leadingIcon: Icons.menu_book_rounded,
        title: 'Mga Kuwento at Pagsasanay sa Pagbabasa',
        subtitle:
            'Magbasa ng mahahabang kuwento at sagutin ang mga tanong upang '
            'makakuha ng mga bituin habang natututo.',
      ),
      host: LayoutHost.scrollable,
    );
  });

  testWidgets('HubHeader (no subtitle) never overflows', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const HubHeader(
        leadingIcon: Icons.home_rounded,
        title: 'Home',
      ),
      host: LayoutHost.scrollable,
    );
  });
}
