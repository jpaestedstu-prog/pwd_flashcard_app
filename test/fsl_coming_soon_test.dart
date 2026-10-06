import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/fsl_assets_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/flashcard_viewer_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/fsl_dictionary_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/widgets/fsl_video_sheet.dart';

/// The app's own words that have no recorded sign yet read "coming soon"
/// everywhere — the same promise the website's dictionary makes under "Signs
/// coming soon". Before, the app said "No FSL video available yet" in a sheet
/// titled "Filipino Sign Language", and the dictionary only showed a crossed-
/// out camera.
///
/// Only the app's own words get the promise: a teacher's custom card or a
/// routine step will never be recorded, and an offline learner's sign exists.
void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/fsl_coming_soon');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
  });

  tearDownAll(() async {
    try {
      await Hive.deleteFromDisk().timeout(const Duration(seconds: 5));
    } catch (_) {}
  });

  // The real manifest, read once outside the test's fake-async zone. The
  // provider is then fed from inside the zone: the cached future itself was
  // completed outside it, so a screen watching it would stay loading forever
  // (and every word would look unsigned, which hides the very difference
  // these tests are about).
  late FslAvailability availability;
  setUp(() async {
    FslAssetsService.reset();
    availability = await FslAssetsService.load();
  });
  tearDown(FslAssetsService.reset);

  Widget app(Widget home, {String locale = 'en'}) => ProviderScope(
    overrides: [
      fslAvailabilityProvider.overrideWith((ref) async => availability),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  Future<void> pumpFrames(WidgetTester tester, [int n = 10]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openSheet(
    WidgetTester tester,
    String word, {
    bool unreachable = false,
    String locale = 'en',
  }) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showFslUnavailableSheet(
                  context,
                  wordEnglish: word,
                  unreachable: unreachable,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('the shared sheet', () {
    testWidgets('an app word with no sign: "Sign coming soon"', (
      tester,
    ) async {
      await openSheet(tester, 'Run');
      expect(find.text('Sign coming soon'), findsOneWidget);
      expect(
        find.text(
          'The sign for “Run” is coming soon. For now, learn this word '
          'with its picture and words.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a teacher’s own word is not promised a sign', (
      tester,
    ) async {
      await openSheet(tester, 'Brush my teeth');
      expect(find.text('Sign coming soon'), findsNothing);
      expect(find.text('Filipino Sign Language'), findsOneWidget);
      expect(
        find.text(
          'There is no sign video for “Brush my teeth”. Signs are recorded '
          'for the app’s own words.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('offline: the sign exists, so it is not "coming soon"', (
      tester,
    ) async {
      await openSheet(tester, 'Dog', unreachable: true);
      expect(find.text('Sign coming soon'), findsNothing);
      expect(find.text('Filipino Sign Language'), findsOneWidget);
      expect(find.textContaining('needs the internet'), findsOneWidget);
    });

    testWidgets('Filipino says it too', (tester) async {
      await openSheet(tester, 'Run', locale: 'fil');
      expect(find.text('Malapit na ang senyas'), findsOneWidget);
      expect(find.textContaining('Malapit nang idagdag'), findsOneWidget);
    });
  });

  test('isAppWord knows the app’s own words, in any case', () {
    expect(isAppWord('Run'), isTrue);
    expect(isAppWord(' run '), isTrue);
    expect(isAppWord('Brush my teeth'), isFalse);
  });

  testWidgets('the dictionary tags a word with no sign "Coming soon"', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(app(const FslDictionaryScreen()));
    await pumpFrames(tester, 8);

    await tester.enterText(find.byType(TextField), 'Run');
    await pumpFrames(tester, 8);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Run, Tumakbo\. Sign coming soon\.')),
      findsOneWidget,
    );

    // A word that has a sign carries no tag.
    await tester.enterText(find.byType(TextField), 'Dog');
    await pumpFrames(tester, 8);
    expect(find.text('Coming soon'), findsNothing);

    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the flashcard viewer’s FSL button says "Coming soon" first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    // Actions opens on "Run", which has no recorded sign.
    await tester.pumpWidget(
      app(const FlashcardViewerScreen(category: FlashcardCategory.actions)),
    );
    await pumpFrames(tester);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Sign coming soon')), findsOneWidget);
    expect(find.text('FSL'), findsNothing);

    // A deck whose words are signed keeps the plain FSL button. (Unmount
    // first: the viewer loads its deck once, in initState.)
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      app(
        const FlashcardViewerScreen(
          category: FlashcardCategory.familyAndGreetings,
        ),
      ),
    );
    await pumpFrames(tester);
    expect(find.text('FSL'), findsOneWidget);
    expect(find.text('Coming soon'), findsNothing);

    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
