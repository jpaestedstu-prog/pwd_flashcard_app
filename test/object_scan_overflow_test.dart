import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/features/object_scan/models/object_scan_models.dart';
import 'package:pwdpwdpwd/features/object_scan/screens/object_scan_screen.dart';
import 'package:pwdpwdpwd/features/object_scan/services/object_labeler.dart';
import 'package:pwdpwdpwd/features/object_scan/widgets/discovered_word_sheet.dart';

import 'support/screen_matrix.dart';

/// Real cameras and ML Kit need platform channels; the screen takes both as
/// injectable factories so the no-camera fallback (what every camera-less
/// test environment and camera-less tablet shows) can render in tests.
class _FakeLabeler implements ObjectLabeler {
  @override
  Future<List<RecognizedLabel>> labelImage(InputImage image) async => const [];

  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/object_scan_overflow');
    if (!Hive.isBoxOpen('progress')) await Hive.openBox('progress');
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
          child: DiscoveredWordSheet(
            card: card,
            isNewDiscovery: true,
            starAwarded: true,
          ),
        ),
      ),
    );
  });
}
