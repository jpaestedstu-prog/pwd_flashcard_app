import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/parent/screens/sign_check_screen.dart';

import 'support/screen_matrix.dart';

/// The educator's Sign Check surface — where a learner's "I can sign this"
/// claim meets a teacher's judgement, producing the calibration pair.
///
/// The matrix test here exists because the first build of this screen rendered
/// a **blank body under a working app bar** on the tablet: `SafeScaffold`
/// wraps its body in a `SingleChildScrollView` by default, and the body was
/// already a `ListView`, so the list got unbounded height and Scaffold layout
/// failed outright. Nothing in the unit tests could see it — it is a layout
/// failure, which is exactly what the device matrix is for.
void main() {
  const learnerId = 'learner_signcheck';

  setUpAll(() async {
    const dir = './build/test_cache/fsl_sign_check';
    try {
      final d = Directory(dir);
      if (d.existsSync()) d.deleteSync(recursive: true);
    } catch (_) {}
    Hive.init(dir);
    for (final name in const <String>['profiles', 'settings', 'progress']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (total, deleted) => false);
      }
    }
    // Seed two claims: one the learner is confident about, one they are not.
    await HiveService.setFslMastery(
      learnerId,
      'Animals',
      'Dog',
      SignMastery.canSign,
    );
    await HiveService.setFslMastery(
      learnerId,
      'Animals',
      'Cat',
      SignMastery.learning,
    );
  });

  tearDownAll(() async {
    try {
      await Hive.deleteFromDisk().timeout(const Duration(seconds: 5));
    } catch (_) {}
  });

  testWidgets('lays out across the device matrix', (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const SignCheckScreen(
        learnerId: learnerId,
        learnerName: 'Deaf Student',
      ),
    );
  });

  testWidgets('shows both kinds of claim, quoting the learner', (tester) async {
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: SignCheckScreen(
          learnerId: learnerId,
          learnerName: 'Deaf Student',
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Dog'), findsOneWidget);
    expect(find.text('Cat'), findsOneWidget);
    expect(find.text('Says: “I can sign this”'), findsOneWidget);
    expect(
      find.text('Says: “Not yet”'),
      findsOneWidget,
      reason:
          'a learner still working on a sign is exactly who a teacher '
          'should spend a minute with — hiding them would make this a '
          'victory-lap list',
    );
    expect(find.text('2 to check'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
