import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/story_image_service.dart';
import 'package:pwdpwdpwd/features/stories/screens/story_reader_screen.dart';

import 'support/screen_matrix.dart';

/// Overflow matrix for the Story Reader after the English / Filipino /
/// Watch-in-FSL controls were moved off the story card and into the fixed
/// bottom navigation bar (mirroring Flashcards → Cards).
///
/// "A Day at the Farm" (`s_a01`) is the most demanding story to render: it
/// ships TTS (so the English/Filipino replay bar shows), an FSL clip per page
/// (so the full-width "Watch in FSL" chip shows) AND a cartoon⇄real flip
/// picture — i.e. every control in the new bottom bar is present at once. We
/// render it across the full device × text-scale matrix and assert the bar
/// (and the page above it) never overflow, even on the smallest phone in
/// landscape at the 2.0× accessibility font scale.
void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/story_reader_screen');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
  });

  setUp(() {
    StoryImageService.reset();
    // The flip pictures are network images the test binding can't fetch; the
    // override resolves them to a placeholder so the screen lays out
    // deterministically without touching the disk cache / network.
    StoryImageService.debugResolverOverride = (_, _) async => null;
  });

  tearDown(() {
    StoryImageService.debugResolverOverride = null;
    StoryImageService.reset();
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  testWidgets('StoryReaderScreen survives the device matrix', (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const StoryReaderScreen(storyId: 's_a01'),
    );
  });
}
