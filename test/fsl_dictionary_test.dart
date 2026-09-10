import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:pwdpwdpwd/core/services/fsl_assets_service.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/fsl_dictionary_screen.dart';
import 'package:pwdpwdpwd/widgets/fsl_video_sheet.dart';

import 'support/screen_matrix.dart';

/// Layout matrix for the FSL Dictionary and the shared word-video sheet it
/// opens. Behavioural coverage lives in `fsl_dictionary_behavior_test.dart`.

/// A [VideoSource] backed by a controller the (absent) test plugin can never
/// initialize, so the sheet settles into its "unable to load" layout — the
/// state a learner sees when a clip fails, and the one worth pinning.
class _StubSource implements VideoSource {
  @override
  VideoPlayerController createController() =>
      VideoPlayerController.networkUrl(Uri.parse('https://example.test/x.mp4'));
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/fsl_dictionary');
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

  testWidgets('FslDictionaryScreen survives the device matrix', (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const FslDictionaryScreen(),
    );
  });

  testWidgets('the word-video sheet survives the device matrix', (
    tester,
  ) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      // Worst case for the title row and the Replay/Close row: a long English
      // word with a long Filipino gloss under it.
      () => Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SingleChildScrollView(
            child: FslVideoSheet(
              videoSource: _StubSource(),
              wordEnglish: 'Partly Cloudy',
              wordFilipino: 'Bahagyang Maulap',
            ),
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
  testWidgets('FslDictionaryScreen survives the accessibility themes',
      (tester) async {
    await expectScreenSurvivesThemes(tester, () => const FslDictionaryScreen());
  });

  testWidgets('the word-video sheet survives the accessibility themes',
      (tester) async {
    await expectScreenSurvivesThemes(
      tester,
      () => Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SingleChildScrollView(
            child: FslVideoSheet(
              videoSource: _StubSource(),
              wordEnglish: 'Partly Cloudy',
              wordFilipino: 'Bahagyang Maulap',
            ),
          ),
        ),
      ),
    );
  });
}
