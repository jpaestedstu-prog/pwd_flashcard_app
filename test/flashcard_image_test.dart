import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/constants/flashcard_emojis.dart';
import 'package:pwdpwdpwd/core/services/flashcard_photo_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/widgets/flashcard_image.dart';

/// Coverage for FlashcardImage's static rendering, the `expand` layout, the
/// cartoon⇄realistic tap flip (an animated 3D flip), and the optional black
/// outline effect.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Keep the photo service dormant so emoji-only cards have no picture source.
  setUp(FlashcardPhotoService.reset);
  tearDown(() {
    FlashcardPhotoService.debugResolverOverride = null;
    FlashcardPhotoService.reset();
  });

  // An Actions verb: no cartoon and no photo, so it exercises the emoji
  // last-resort path.
  final emojiCard = SeedData.getByCategory(FlashcardCategory.actions).first;
  final emoji = FlashcardEmojis.forId(emojiCard.id);

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  group('tapHint strings', () {
    test('match the requested instructions exactly', () {
      expect(
        FlashcardImage.tapHint(showingPhoto: false),
        'Tap to see the real picture.',
      );
      expect(
        FlashcardImage.tapHint(showingPhoto: true),
        'Tap to see the cartoon picture.',
      );
    });
  });

  group('static mode', () {
    testWidgets('emoji-only card renders the emoji and settles cleanly', (
      tester,
    ) async {
      await pump(tester, FlashcardImage(card: emojiCard));
      expect(find.text(emoji), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('expand mode fills a bounded cell without overflow', (
      tester,
    ) async {
      await pump(
        tester,
        SizedBox(
          width: 150,
          height: 150,
          child: FlashcardImage(card: emojiCard, expand: true),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.text(emoji), findsOneWidget);
    });

    testWidgets('updating to a new card keeps rendering an emoji', (
      tester,
    ) async {
      final other = SeedData.getByCategory(
        FlashcardCategory.actions,
      ).elementAt(1);
      await pump(tester, FlashcardImage(card: emojiCard));
      expect(find.text(emoji), findsOneWidget);
      await pump(tester, FlashcardImage(card: other));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.text(FlashcardEmojis.forId(other.id)), findsOneWidget);
    });
  });

  group('interactive mode', () {
    testWidgets('emoji-only card shows no toggle instruction', (tester) async {
      await pump(tester, FlashcardImage(card: emojiCard, interactive: true));
      expect(find.text(emoji), findsOneWidget);
      expect(find.textContaining('Tap to see'), findsNothing);
      // Tapping must not crash even though there's nothing to toggle.
      await tester.tap(find.byType(FlashcardImage));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    group('with the shipped manifest', () {
      // The manifest load must happen in setUp, not inside testWidgets: asset
      // reads complete in the real zone, and testWidgets' FakeAsync never
      // advances them, so an in-test await would hang forever.
      setUp(() async {
        FlashcardPhotoService.debugResolverOverride = (_, _) async => null;
        await FlashcardPhotoService.load();
      });

      testWidgets('realistic-only card shows no toggle instruction', (
        tester,
      ) async {
        // Colors & Shapes ships a photo but no cartoon: one face, so tapping
        // must not offer a flip that would only ever show the same picture.
        final red = SeedData.getByCategory(
          FlashcardCategory.colorsAndShapes,
        ).firstWhere((c) => c.wordEnglish == 'Red');
        expect(FlashcardPhotoService.hasPhoto(red), isTrue);
        expect(FlashcardPhotoService.cartoonUrlFor(red), isNull);

        await pump(tester, FlashcardImage(card: red, interactive: true));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.textContaining('Tap to see'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('tap flips cartoon ⇄ realistic with the right instructions', (
        tester,
      ) async {
        // Animals/dog ships both faces, so interactive mode engages.
        final dog = SeedData.getByCategory(
          FlashcardCategory.animals,
        ).firstWhere((c) => c.wordEnglish == 'Dog');
        expect(FlashcardPhotoService.canFlip(dog), isTrue);

        await pump(tester, FlashcardImage(card: dog, interactive: true));

        // Cartoon first → instruction invites revealing the real picture.
        expect(find.text('Tap to see the real picture.'), findsOneWidget);

        // Tap → realistic face → instruction now invites the cartoon back.
        // Bounded pumps, not pumpAndSettle: the realistic face carries a loading
        // spinner (the stub never resolves a file), and that animation repeats
        // forever, so pumpAndSettle would never return. 700ms clears the 650ms
        // flip.
        await tester.tap(find.byType(FlashcardImage));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.text('Tap to see the cartoon picture.'), findsOneWidget);

        // Tap back to the cartoon face, which has no spinner — so the test also
        // ends with no ticker still running.
        await tester.tap(find.byType(FlashcardImage));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.text('Tap to see the real picture.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('caption survives an unbounded FittedBox (viewer hosts it so)', (
        tester,
      ) async {
        // The flashcard viewer wraps the card face in a FittedBox, which imposes
        // UNBOUNDED width. The instruction pill must not use a flex child there.
        final dog = SeedData.getByCategory(
          FlashcardCategory.animals,
        ).firstWhere((c) => c.wordEnglish == 'Dog');
        await pump(
          tester,
          FittedBox(child: FlashcardImage(card: dog, interactive: true)),
        );
        await tester.pumpAndSettle(); // drain the initial flip ticker
        expect(tester.takeException(), isNull);
        expect(find.text('Tap to see the real picture.'), findsOneWidget);
      });
    });
  });

  group('outline effect', () {
    // A foreground-painted black frame (the same one used on the photo face).
    bool hasBlackFrame(WidgetTester tester) {
      return tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).any((
        d,
      ) {
        if (d.position != DecorationPosition.foreground) return false;
        final dec = d.decoration;
        final border = dec is BoxDecoration ? dec.border : null;
        return border is Border &&
            border.top.color == Colors.black.withValues(alpha: 0.5);
      });
    }

    testWidgets('outlined: true frames the emoji card with a black border', (
      tester,
    ) async {
      await pump(tester, FlashcardImage(card: emojiCard, outlined: true));
      expect(hasBlackFrame(tester), isTrue);
    });

    testWidgets('default (un-outlined) emoji card has no black frame', (
      tester,
    ) async {
      await pump(tester, FlashcardImage(card: emojiCard));
      expect(hasBlackFrame(tester), isFalse);
    });
  });
}
