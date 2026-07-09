import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/haptic_service.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/core/services/fsl_assets_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/fsl_interpreter/screens/sign_it_screen.dart';
import 'package:pwdpwdpwd/features/games/widgets/fsl_empty_state.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_camera_owners.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'support/device_matrix.dart';

/// Behaviour + layout suite for the FSL "Sign It!" production-practice mode.
///
/// The screen's [SignItScreen.camerasLoader] seam exists precisely so these
/// tests can drive every camera outcome without platform channels:
///   * an empty enumeration → the "no camera, watch-only" fallback,
///   * a [CameraException] from the enumerator → the same graceful fallback,
/// while the reference video deterministically stays on its shimmer
/// placeholder (no bundled videos; cloud resolution fails offline in tests).
///
/// Deliberate constraints, mirroring the rest of the widget suite:
///   * No profile is loaded and no session is ever completed, so nothing
///     writes to Hive mid-test — a pending `box.put` inside the fake-async
///     zone would hang `Hive.deleteFromDisk` at teardown.
///   * The `error_logs` box is intentionally NOT opened: `ErrorHandler`
///     degrades to a debug print instead of a Hive write if a non-critical
///     service reports in a test.
///   * Sound is a silent fake (the real service constructs an [AudioPlayer])
///     and haptics are disabled, per `word_hunt_focus_mode_test` /
///     `break_time_test`.
class _SilentSoundService implements SoundService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

Future<void> _pumpSignIt(
  WidgetTester tester, {
  required Future<List<CameraDescription>> Function() camerasLoader,
  List<FlashcardCategory> categories = const [],
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        soundServiceProvider.overrideWithValue(_SilentSoundService()),
        hapticServiceProvider.overrideWithValue(HapticService(enabled: false)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Inject the text scaler inside MaterialApp.builder — a MediaQuery
        // wrapped outside MaterialApp is rebuilt away from the FlutterView.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: SignItScreen(
          categories: categories,
          camerasLoader: camerasLoader,
          // Keep tests off the cache/download stack: "video unavailable" is
          // a supported state (the reference panel holds its placeholder).
          videoLoader: (_) async => null,
        ),
      ),
    ),
  );
  await _settle(tester);
}

/// Lets the screen's real-async work (asset-manifest reads, cloud-manifest
/// parse, the video resolve attempt, camera enumeration) actually finish.
/// Those futures complete outside the test's fake-async zone, so plain pumps
/// never advance them — only [WidgetTester.runAsync], which spins the real
/// event loop. Interleave with pumps so each completion's setState gets a
/// frame. Bounded (the reference panel's shimmer loops forever, so
/// pumpAndSettle would never return).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}

Future<List<CameraDescription>> _noCameras() async => const [];

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/sign_it');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
    // Warm the FSL availability snapshot in a real-async context so the
    // static cache serves the widget tests (which run inside FakeAsync)
    // without depending on rootBundle timing.
    await FslAssetsService.load();
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  testWidgets(
      'shows the friendly FSL empty state when the chosen category has no videos',
      (tester) async {
    // Actions is the one category with no FSL videos in the manifest.
    await _pumpSignIt(
      tester,
      camerasLoader: _noCameras,
      categories: const [FlashcardCategory.actions],
    );

    expect(find.byType(FslEmptyStateScaffold), findsOneWidget);
    expect(find.text('FSL videos coming soon'), findsOneWidget);
  });

  testWidgets('runs watch-only when the device has no camera',
      (tester) async {
    await _pumpSignIt(tester, camerasLoader: _noCameras);

    // Practice UI is fully live: round counter, prompt, both panels.
    expect(find.textContaining('1/10'), findsOneWidget);
    expect(find.text('Watch, then sign it back!'), findsOneWidget);
    expect(find.text('Reference'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);

    // The mirror panel degrades to the friendly fallback…
    expect(find.textContaining('No camera found'), findsOneWidget);
    // …with no Record control (nothing to record with)…
    expect(find.text('Record'), findsNothing);
    // …while self-assessment stays available.
    expect(find.text('I got it!'), findsOneWidget);
    expect(find.text('Not yet'), findsOneWidget);
  });

  testWidgets(
      'a CameraException from the camera enumerator degrades to watch-only',
      (tester) async {
    await _pumpSignIt(
      tester,
      camerasLoader: () async =>
          throw CameraException('CameraAccessDenied', 'denied in test'),
    );

    expect(find.textContaining('No camera found'), findsOneWidget);
    expect(find.text('I got it!'), findsOneWidget);
  });

  testWidgets('self-assessment advances rounds and tallies only "I got it!"',
      (tester) async {
    await _pumpSignIt(tester, camerasLoader: _noCameras);
    expect(find.textContaining('1/10'), findsOneWidget);

    await tester.tap(find.text('I got it!'));
    await _settle(tester);
    expect(find.textContaining('2/10'), findsOneWidget);
    // The app-bar tally reflects the confirmed sign.
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Not yet'));
    await _settle(tester);
    expect(find.textContaining('3/10'), findsOneWidget);
    // "Not yet" advances without scoring.
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('holds the shared camera gate while open and releases on close',
      (tester) async {
    await _pumpSignIt(tester, camerasLoader: _noCameras);
    // Mirrors Word Hunt / gaze preview: the nav-gaze shell must stand its
    // camera down while this screen owns the (potential) camera.
    expect(gazeCameraOwners.isBusy, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(gazeCameraOwners.isBusy, isFalse);
  });

  // Like FlashcardQuiz in games_screens_overflow_test.dart, the portrait
  // practice screen treats the 360 px-tall phone-landscape viewport as not
  // applicable: the app is portrait-locked, and at 2.0× font that height
  // cannot hold a reference video + mirror + controls. Every tablet size +
  // orientation, plus phone portrait, at up to 2.0× font is still covered.
  final devices =
      kTabletMatrix.where((d) => d.label != 'phone landscape').toList();

  testWidgets('practice layout survives the device × text-scale matrix',
      (tester) async {
    for (final device in devices) {
      for (final scale in kTextScales) {
        tester.view.physicalSize = device.size * device.devicePixelRatio;
        tester.view.devicePixelRatio = device.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpSignIt(tester, camerasLoader: _noCameras,
            textScale: scale);
        // Assert the loaded practice layout (not the loading skeleton).
        expect(find.text('Watch, then sign it back!'), findsOneWidget,
            reason: 'practice UI did not load at $device, ${scale}x');

        // An overflowing body re-reports each frame; drain them all.
        Object? firstError;
        for (Object? e = tester.takeException();
            e != null;
            e = tester.takeException()) {
          firstError ??= e;
        }
        expect(
          firstError,
          isNull,
          reason: 'Overflow at $device, textScale ${scale}x:\n$firstError',
        );
      }
    }
  });
}
