import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/widgets/media_capture_screen.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_media.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_media_store.dart';
import 'package:pwdpwdpwd/features/assessment/widgets/assessment_media_editor.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_camera_owners.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

/// The in-app camera: recording a signed question or answer, or a photo.
///
/// The camera plugin exists in no test binding, so these cover what the
/// screen does around it — claiming the single camera from background gaze,
/// saying plainly when there is no camera or no permission, never leaving a
/// learner stuck — plus where the editors offer it. Recording itself is
/// verified on a device.
void main() {
  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 2000) * 1.75;
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('MediaCaptureScreen', () {
    testWidgets('with no camera it says so and can be closed', (tester) async {
      String? result = 'unset';
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => MediaCaptureScreen(
                      mode: CaptureMode.video,
                      prompt: 'Sign the word for cat',
                      camerasLoader: () async => const <CameraDescription>[],
                    ),
                  ),
                );
              },
              child: const Text('OPEN'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('This tablet has no camera the app can use.'), findsOneWidget);
      expect(find.text('Sign the word for cat'), findsOneWidget,
          reason: 'the question stays in view while recording an answer');
      expect(find.text('Try again'), findsNothing,
          reason: 'retrying cannot conjure a camera');

      await tester.tap(find.text('Close').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(result, isNull);
    });

    testWidgets('a camera that will not load reads as no camera', (
      tester,
    ) async {
      await pumpApp(
        tester,
        MediaCaptureScreen(
          mode: CaptureMode.photo,
          camerasLoader: () async => throw CameraException('x', 'boom'),
        ),
      );
      expect(find.text('This tablet has no camera the app can use.'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
    });

    testWidgets('it holds the camera from background gaze while open', (
      tester,
    ) async {
      final before = gazeCameraOwners.count;
      await pumpApp(
        tester,
        MediaCaptureScreen(
          mode: CaptureMode.video,
          camerasLoader: () async => const <CameraDescription>[],
        ),
      );
      expect(gazeCameraOwners.count, before + 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(gazeCameraOwners.count, before,
          reason: 'released on close, or gaze would never come back');
    });
  });

  group('where the editors offer it', () {
    Future<void> openSource(WidgetTester tester, String button) async {
      await pumpApp(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: AssessmentMediaEditor(
              value: AssessmentMedia.none,
              onChanged: (_) {},
              ownerKey: 'q1',
              ledger: AssessmentMediaLedger(),
            ),
          ),
        ),
      );
      await tester.tap(find.text(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('an FSL video can be recorded then and there', (tester) async {
      await openSource(tester, 'Add FSL video');
      expect(find.text('Record with the camera'), findsOneWidget);
      expect(find.text('Choose from this device'), findsOneWidget);
    });

    testWidgets('a photo can be taken with the camera', (tester) async {
      await openSource(tester, 'Add Photo');
      expect(find.text('Take a photo with the camera'), findsOneWidget);
    });

    testWidgets('a GIF or a sound is not offered the camera', (tester) async {
      await openSource(tester, 'Add GIF');
      expect(find.text('Record with the camera'), findsNothing);
      expect(find.text('Take a photo with the camera'), findsNothing);
    });
  });
}
