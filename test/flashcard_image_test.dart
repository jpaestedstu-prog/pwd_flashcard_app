import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/constants/flashcard_emojis.dart';
import 'package:pwdpwdpwd/core/services/flashcard_photo_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/widgets/flashcard_image.dart';

/// Coverage for FlashcardImage's static rendering, the `expand` layout, the
/// manual emoji⇄photo tap toggle (now an animated 3D flip), and the optional
/// black outline effect.
void main() {
  // Keep the photo service dormant so emoji-only cards have no photo source.
  setUp(FlashcardPhotoService.reset);

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
        'Tap to see the real photograph (Photo).',
      );
      expect(
        FlashcardImage.tapHint(showingPhoto: true),
        'Tap to see the emoji (Emoji).',
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

    testWidgets('tap toggles emoji ⇄ photo with the right instructions', (
      tester,
    ) async {
      // A card with a photo source (imageAsset) so interactive mode engages.
      const card = Flashcard(
        id: 'tst_apple',
        wordEnglish: 'Apple',
        wordFilipino: 'Mansanas',
        category: FlashcardCategory.foodAndDrinks,
        imageAsset: 'assets/images/__missing_test_fixture__.png',
      );

      await pump(tester, const FlashcardImage(card: card, interactive: true));

      // Emoji first → instruction invites revealing the photo.
      expect(
        find.text('Tap to see the real photograph (Photo).'),
        findsOneWidget,
      );

      // Tap the image → photo face → instruction now invites the emoji.
      // pumpAndSettle drains the 3D-flip animation's ticker (a bare pump()
      // would leave it pending and fail the test).
      await tester.tap(find.byType(FlashcardImage));
      await tester.pumpAndSettle();
      expect(find.text('Tap to see the emoji (Emoji).'), findsOneWidget);

      // Tap again → back to the emoji face.
      await tester.tap(find.byType(FlashcardImage));
      await tester.pumpAndSettle();
      expect(
        find.text('Tap to see the real photograph (Photo).'),
        findsOneWidget,
      );

      // The missing test fixture triggers a benign asset-load error once the
      // photo face is shown; absorb it (real photos exist at runtime).
      tester.takeException();
    });

    testWidgets('caption survives an unbounded FittedBox (viewer hosts it so)', (
      tester,
    ) async {
      // The flashcard viewer wraps the card face in a FittedBox, which imposes
      // UNBOUNDED width. The instruction pill must not use a flex child there.
      const card = Flashcard(
        id: 'tst_fitted',
        wordEnglish: 'Apple',
        wordFilipino: 'Mansanas',
        category: FlashcardCategory.foodAndDrinks,
        imageAsset: 'assets/images/__missing_test_fixture__.png',
      );
      await pump(
        tester,
        const FittedBox(child: FlashcardImage(card: card, interactive: true)),
      );
      await tester.pumpAndSettle(); // drain the initial flip ticker
      expect(tester.takeException(), isNull);
      expect(
        find.text('Tap to see the real photograph (Photo).'),
        findsOneWidget,
      );
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
