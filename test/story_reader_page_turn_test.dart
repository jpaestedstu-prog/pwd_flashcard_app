import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/story_image_service.dart';
import 'package:pwdpwdpwd/data/local/seed_stories.dart';
import 'package:pwdpwdpwd/features/stories/screens/story_reader_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/widgets/page_turn_switcher.dart';

/// Behaviour coverage for the Stories reader **page-turn** navigation: the
/// Next / Back buttons must turn the page (the entering sentence comes into
/// view and the page we left disappears once the turn settles), across several
/// consecutive turns and in both directions — i.e. the new transition wraps the
/// card without breaking the reader's paging.
///
/// To keep the test hermetic these checks stay *before* the final page: reaching
/// the last sentence records progress to Hive, and a disk write kicked off
/// inside the widget-test fake-async zone would otherwise be left pending and
/// hang teardown. The last-page → Take Quiz swap is unchanged by this feature
/// and is already exercised by the reader's other coverage.
///
/// The flip pictures are network images the test binding can't fetch; the
/// override resolves them to a neutral placeholder so the screen lays out
/// deterministically without touching the disk cache / network.
void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/story_reader_page_turn');
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
    StoryImageService.debugResolverOverride = (_, _) async => null;
  });

  tearDown(() {
    StoryImageService.debugResolverOverride = null;
    StoryImageService.reset();
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  // A tall phone so the reader card and the full bottom bar (Back · FSL ·
  // Next/Quiz) are all on screen and tappable.
  Future<void> pumpReader(WidgetTester tester, String storyId) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Unmount the screen when the test ends so the page-turn AnimationController
    // is disposed before the suite tears down.
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StoryReaderScreen(storyId: storyId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the card is wrapped in the page-turn transition', (tester) async {
    await pumpReader(tester, 's_a01');
    expect(find.byType(PageTurnSwitcher), findsOneWidget);
  });

  testWidgets('Next turns the page forward and the old page leaves', (
    tester,
  ) async {
    final story = SeedStories.all.firstWhere((s) => s.id == 's_a01');
    final n = story.sentencesEn.length;
    expect(n, greaterThan(2), reason: 's_a01 should have several pages');

    await pumpReader(tester, 's_a01');

    expect(find.text('Page 1 of $n'), findsOneWidget);
    expect(find.text(story.sentencesEn[0]), findsOneWidget);

    // Tap Next → the page-turn transition runs (kick a frame, advance to
    // mid-turn, then let it settle on page 2).
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230)); // mid-turn
    await tester.pumpAndSettle();

    expect(find.text('Page 2 of $n'), findsOneWidget);
    expect(find.text(story.sentencesEn[1]), findsOneWidget);
    // The page we turned away from is gone once the turn settles.
    expect(find.text(story.sentencesEn[0]), findsNothing);
  });

  testWidgets('several consecutive turns page forward then Back returns', (
    tester,
  ) async {
    final story = SeedStories.all.firstWhere((s) => s.id == 's_a01');
    final n = story.sentencesEn.length;

    await pumpReader(tester, 's_a01');

    // Turn forward up to the second-to-last page (staying off the final page so
    // no progress is written). Each turn must land on the next sentence and
    // keep showing Next (never Take Quiz before the end).
    for (var page = 2; page <= n - 1; page++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Page $page of $n'), findsOneWidget);
      expect(find.text(story.sentencesEn[page - 1]), findsOneWidget);
      expect(find.text('Take Quiz'), findsNothing);
    }

    // Turn back one page — the Back button reverses the transition.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Page ${n - 2} of $n'), findsOneWidget);
    expect(find.text(story.sentencesEn[n - 3]), findsOneWidget);
  });
}
