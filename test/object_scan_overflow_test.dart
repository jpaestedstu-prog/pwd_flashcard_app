import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/features/object_scan/models/object_scan_models.dart';
import 'package:pwdpwdpwd/features/object_scan/screens/object_scan_screen.dart';
import 'package:pwdpwdpwd/features/object_scan/services/object_labeler.dart';
import 'package:pwdpwdpwd/features/object_scan/widgets/discovered_word_sheet.dart';

import 'package:pwdpwdpwd/features/object_scan/widgets/photo_results_panel.dart';

import 'support/screen_matrix.dart';

/// Real cameras and ML Kit need platform channels; the screen takes both as
/// injectable factories so the no-camera fallback (what every camera-less
/// test environment and camera-less tablet shows) can render in tests.
class _FakeLabeler implements ObjectLabeler {
  @override
  Future<List<RecognizedLabel>> labelPhoto(String filePath) async => const [];

  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/object_scan_overflow');
    // `progress` holds the discovery log the screen reads on open (the 🎒
    // count and the hunt targets); `profiles` / `settings` back the active
    // profile and its gaze config, which decide whether voice control arms.
    // HiveService.init opens all three in the real app.
    for (final name in const ['progress', 'profiles', 'settings']) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  testWidgets('scan screen (no-camera fallback) survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => ObjectScanScreen(
        camerasLoader: () async => const <CameraDescription>[],
        labelerFactory: _FakeLabeler.new,
      ),
    );
  });

  testWidgets('discovered word sheet survives the device matrix',
      (tester) async {
    final card = SeedData.allFlashcards.firstWhere((c) => c.id == 'cr18');
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => Scaffold(
        body: SingleChildScrollView(
          // autoSpeak off: this layout-only test wires up no TTS/settings.
          child: DiscoveredWordSheet(
            card: card,
            isNewDiscovery: true,
            starAwarded: true,
            autoSpeak: false,
          ),
        ),
      ),
    );
  });

  group('hasFrontAndBackCameras (flip-button gate)', () {
    CameraDescription cam(CameraLensDirection dir) => CameraDescription(
          name: dir.name,
          lensDirection: dir,
          sensorOrientation: 0,
        );

    test('true only when both a front and a back lens exist', () {
      expect(
        hasFrontAndBackCameras(
            [cam(CameraLensDirection.back), cam(CameraLensDirection.front)]),
        isTrue,
      );
    });

    test('false with a single lens or none', () {
      expect(hasFrontAndBackCameras([cam(CameraLensDirection.back)]), isFalse);
      expect(hasFrontAndBackCameras([cam(CameraLensDirection.front)]), isFalse);
      expect(hasFrontAndBackCameras(const []), isFalse);
    });

    test('ignores extra lenses of the same direction (e.g. dual back)', () {
      expect(
        hasFrontAndBackCameras([
          cam(CameraLensDirection.back),
          cam(CameraLensDirection.back),
          cam(CameraLensDirection.external),
        ]),
        isFalse,
      );
    });
  });

  // The results panel is the busiest row in the feature: picture + two lines of
  // word + a NEW badge + a chevron, under a "Found it!" banner and a target
  // strip. All four decorations arrived after the panel's original layout, so
  // pin the fully-loaded version across the matrix.
  testWidgets('results panel survives the device matrix fully decorated',
      (tester) async {
    final table = SeedData.allFlashcards.firstWhere((c) => c.id == 'cr13');
    final cup = SeedData.allFlashcards.firstWhere((c) => c.id == 'f14');
    // The screen-level helper, not the widget one: the panel reads
    // AppLocalizations, so it needs the delegates that helper installs.
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => Scaffold(
        body: SingleChildScrollView(
          child: PhotoResultsPanel(
            matches: [
              WordMatch(card: table, sourceLabel: 'Desk', confidence: 0.9),
              WordMatch(card: cup, sourceLabel: 'Mug', confidence: 0.8),
            ],
            searching: false,
            newWordIds: {table.id, cup.id},
            targetsHit: [table, cup],
            onWordTap: (_) {},
            onRetake: () {},
          ),
        ),
      ),
    );
  });

  testWidgets('empty results panel with hunt targets survives the matrix',
      (tester) async {
    final targets = [
      for (final id in const ['cr13', 'f14', 'a01'])
        SeedData.allFlashcards.firstWhere((c) => c.id == id),
    ];
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => Scaffold(
        body: SingleChildScrollView(
          child: PhotoResultsPanel(
            matches: const [],
            searching: false,
            targets: targets,
            onWordTap: (_) {},
            onRetake: () {},
          ),
        ),
      ),
    );
  });
}
