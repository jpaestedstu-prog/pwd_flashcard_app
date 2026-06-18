import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/story_image_service.dart';
import 'package:pwdpwdpwd/core/theme/app_colors.dart';
import 'package:pwdpwdpwd/data/local/seed_stories.dart';
import 'package:pwdpwdpwd/features/stories/widgets/story_image_flip.dart';

import 'support/device_matrix.dart';

/// Coverage for the Stories → Cartoon ⇄ Real-Life tap-to-flip illustration:
/// the exact instruction strings, the tap-to-flip caption swap (the 3D flip),
/// and graceful behaviour when the pictures can't be fetched (offline / first
/// run) so the surrounding story stays usable.
///
/// The pictures are network images that the test binding can't actually fetch,
/// so [StoryImageService.debugResolverOverride] stands in — here it always
/// returns null, which is exactly the "offline / first run" path: each face
/// resolves to a neutral placeholder while the caption + flip stay fully
/// functional.
void main() {
  setUp(() {
    StoryImageService.reset();
    // Simulate offline: every picture resolves to null (no disk/network).
    StoryImageService.debugResolverOverride =
        (_, _) async => null;
  });

  tearDown(() {
    StoryImageService.debugResolverOverride = null;
    StoryImageService.reset();
  });

  const pair = StoryImagePair(
    cartoonUrl: 'https://postimg.cc/8fcqh6SR',
    realUrl: 'https://postimg.cc/k6f06ykB',
  );

  Finder flipTarget() => find.descendant(
        of: find.byType(StoryImageFlip),
        matching: find.byType(GestureDetector),
      );

  Future<void> pump(WidgetTester tester, {bool compact = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: StoryImageFlip(
                pair: pair,
                cacheKey: 'test_s_a01_page0',
                color: AppColors.primary,
                semanticLabel: 'A cow on the farm',
                compact: compact,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('tapHint strings', () {
    test('match the requested instructions exactly', () {
      expect(
        StoryImageFlip.tapHint(showingReal: false),
        'Tap to see the real picture.',
      );
      expect(
        StoryImageFlip.tapHint(showingReal: true),
        'Tap to see the cartoon picture.',
      );
    });
  });

  group('tap-to-flip caption', () {
    testWidgets('starts on the cartoon, flips to real and back', (
      tester,
    ) async {
      await pump(tester);

      // Cartoon shown first → caption invites revealing the real picture.
      expect(find.text('Tap to see the real picture.'), findsOneWidget);
      expect(find.text('Tap to see the cartoon picture.'), findsNothing);

      // Tap the picture → real-life face → caption now invites the cartoon.
      await tester.tap(flipTarget());
      await tester.pumpAndSettle();
      expect(find.text('Tap to see the cartoon picture.'), findsOneWidget);
      expect(find.text('Tap to see the real picture.'), findsNothing);

      // Tap again → back to the cartoon face.
      await tester.tap(flipTarget());
      await tester.pumpAndSettle();
      expect(find.text('Tap to see the real picture.'), findsOneWidget);
    });

    testWidgets('compact variant flips the same way', (tester) async {
      await pump(tester, compact: true);
      expect(find.text('Tap to see the real picture.'), findsOneWidget);

      await tester.tap(flipTarget());
      await tester.pumpAndSettle();
      expect(find.text('Tap to see the cartoon picture.'), findsOneWidget);
    });
  });

  group('offline / failed fetch', () {
    testWidgets('renders a stable placeholder without crashing', (
      tester,
    ) async {
      await pump(tester);
      // After the resolve returns null the face shows a neutral broken-image
      // icon (not a crash) and the caption is still usable.
      expect(find.text('Tap to see the real picture.'), findsOneWidget);
      expect(
        find.byIcon(Icons.image_not_supported_rounded),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('cross-device layout', () {
    // The flip picture + its caption are page content (both the reader and the
    // quiz host them inside a vertical scroll view), so we only care that they
    // never overflow horizontally — across every tablet/phone size and the
    // full accessibility font-scale range.
    testWidgets('full-size picture survives the device matrix', (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        (_) => const Padding(
          padding: EdgeInsets.all(16),
          child: StoryImageFlip(
            pair: pair,
            cacheKey: 'matrix_full',
            color: AppColors.primary,
            semanticLabel: 'A cow eating grass on the farm',
          ),
        ),
        host: LayoutHost.scrollable,
      );
    });

    testWidgets('compact (quiz option) picture survives the device matrix', (
      tester,
    ) async {
      await expectNoOverflowAcrossDevices(
        tester,
        (_) => const Padding(
          padding: EdgeInsets.all(16),
          child: StoryImageFlip(
            pair: pair,
            cacheKey: 'matrix_compact',
            color: AppColors.primary,
            semanticLabel: 'A cow eating grass on the farm',
            compact: true,
            maxWidth: 220,
          ),
        ),
        host: LayoutHost.scrollable,
      );
    });
  });

  group('seed data wiring', () {
    test('A Day at the Farm ships a full set of flip pictures', () {
      final story = SeedStories.all.firstWhere((s) => s.id == 's_a01');

      // One picture per story page.
      expect(story.sentenceImages.length, story.sentencesEn.length);
      for (var i = 0; i < story.sentencesEn.length; i++) {
        final p = story.imageForSentence(i);
        expect(p, isNotNull, reason: 'page $i should have a picture');
        expect(p!.cartoonUrl, isNotEmpty);
        expect(p.realUrl, isNotEmpty);
      }

      // Each question + every one of its options has a picture.
      for (final q in story.questions) {
        expect(q.image, isNotNull);
        expect(q.optionImages.length, q.optionsEn.length);
        for (var i = 0; i < q.optionsEn.length; i++) {
          final p = q.imageForOption(i);
          expect(p, isNotNull);
          expect(p!.cartoonUrl, isNotEmpty);
          expect(p.realUrl, isNotEmpty);
        }
      }
    });
  });
}
