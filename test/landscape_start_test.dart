import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/utils/responsive_utils.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/onboarding_tutorial_screen.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/splash_screen.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/welcome_intro_screen.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/device_matrix.dart';
import 'support/screen_matrix.dart';

/// The first screens anyone sees, on a phone held sideways (the app turns
/// with the device since 1.4.0).
///
/// On the emulator the splash overflowed by 28 px on every sideways start:
/// its column (logo, name, tagline, progress) is about 406 dp in the real
/// font, and a 20:9 phone has 411 dp minus the status bar. The test font is
/// shorter than the real one, so these sizes are tighter than the phone to
/// keep the margin honest: 380 dp leaves the old splash short and the new one
/// room to spare.
const _sideways = <DeviceSize>[
  DeviceSize('20:9 phone sideways, under a status bar', Size(914, 380),
      devicePixelRatio: 2.625),
  DeviceSize('small phone sideways, under a status bar', Size(640, 336)),
];

/// The tour needs someone signed in, or it sends the app home.
class _Learner extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
        id: 'landscape-learner',
        name: 'Test Learner',
        role: UserRole.player,
        disabilityType: DisabilityType.none,
        createdAt: DateTime(2026),
      );
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/landscape_start');
    for (final name in const ['profiles', 'settings', 'progress', 'error_logs']) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
  });
  tearDownAll(() async => Hive.deleteFromDisk());

  testWidgets('the splash fits a phone held sideways', (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const SplashScreen(),
      devices: _sideways,
      checkReadability: false,
    );
  });

  testWidgets('the welcome slides and the tour fit a phone held sideways',
      (tester) async {
    for (final build in <Widget Function()>[
      () => const WelcomeIntroScreen(),
      () => const OnboardingTutorialScreen(),
    ]) {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        build,
        devices: _sideways,
        checkReadability: false,
        overrides: [profileProvider.overrideWith(_Learner.new)],
      );
    }
  });

  testWidgets('a phone held sideways stays a phone', (tester) async {
    late BuildContext ctx;
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    // 914 dp wide: the width alone said "large tablet".
    expect(ctx.isPhone, isTrue);
    expect(ctx.isLargeTablet, isFalse);
    expect(ctx.responsiveSize(100), 90);
    // Columns still follow the width.
    expect(ctx.gameGridColumns, 3);
  });
}
