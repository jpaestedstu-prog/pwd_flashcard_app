import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/smart_review_screen.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/screen_matrix.dart';

/// SmartReviewScreen reads `profileProvider`'s `id` directly, so it needs a
/// non-null active profile. Rather than seed Hive (which drags in the
/// Firebase-backed remote-changes stream via `ProfileNotifier.build`), stub
/// the notifier to return a fixed profile and skip that side effect.
class _StubProfileNotifier extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
        id: 'test-profile',
        name: 'Test Learner',
        role: UserRole.student,
        createdAt: DateTime(2026),
      );
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/smart_review');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name, compactionStrategy: (_, _) => false);
    }
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  testWidgets('SmartReviewScreen survives the device matrix', (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const SmartReviewScreen(),
      overrides: [profileProvider.overrideWith(_StubProfileNotifier.new)],
    );
  });

  // ─── The accessibility themes, at the accessibility font sizes ───
  //
  // The pass above renders under Flutter's default theme, which is not a theme
  // any learner sees. The dyslexia theme adds a 1.6 line height and 0.6 letter
  // spacing on top of its own font sizes; high contrast overrides the text
  // theme and outlines every card. Narrow portrait at 1.5x/2.0x, where a
  // theme's metrics bite first.
  testWidgets('SmartReviewScreen survives the accessibility themes',
      (tester) async {
    await expectScreenSurvivesThemes(
      tester,
      () => const SmartReviewScreen(),
      overrides: [profileProvider.overrideWith(_StubProfileNotifier.new)],
    );
  });
}
