import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/constants/flashcard_emojis.dart';
import 'package:pwdpwdpwd/core/services/action_clip_service.dart';
import 'package:pwdpwdpwd/core/services/flashcard_photo_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

void main() {
  group('Actions / verbs category', () {
    test('actions is appended last (preserves existing Hive indices)', () {
      // Hive persists categories by `index`, so `actions` MUST stay last.
      expect(
        FlashcardCategory.values.last,
        FlashcardCategory.actions,
        reason: 'actions must remain the last enum value',
      );
    });

    test('actions has full extension metadata', () {
      const cat = FlashcardCategory.actions;
      expect(cat.label, 'Actions');
      expect(cat.labelFilipino, isNotEmpty);
      expect(cat.emoji, isNotEmpty);
      expect(cat.icon, isNotNull);
      expect(cat.color, isNotNull);
      expect(cat.darkColor, isNotNull);
    });

    test('ships 20 action cards, all in the actions category', () {
      final actions = SeedData.getByCategory(FlashcardCategory.actions);
      expect(actions.length, 20);
      for (final card in actions) {
        expect(card.category, FlashcardCategory.actions);
        expect(card.wordEnglish, isNotEmpty);
        expect(card.wordFilipino, isNotEmpty);
        expect(card.definition, isNotNull,
            reason: '${card.id} should have a kid-friendly definition');
      }
    });

    test('every action card has a mapped emoji fallback', () {
      final actions = SeedData.getByCategory(FlashcardCategory.actions);
      for (final card in actions) {
        final emoji = FlashcardEmojis.forId(card.id);
        expect(emoji, isNotEmpty);
        expect(emoji, isNot('📖'),
            reason: '${card.id} should have a specific emoji, not the default');
      }
    });
  });

  group('Media services are dormant when unconfigured', () {
    final card = SeedData.getByCategory(FlashcardCategory.actions).first;

    test('photo service: no source until a manifest base_url is set', () {
      FlashcardPhotoService.reset();
      expect(FlashcardPhotoService.hasPhoto(card), isFalse);
      expect(FlashcardPhotoService.urlFor(card), isNull);
      expect(FlashcardPhotoService.resolvedFile(card), isNull);
    });

    test('action clip service: no clip until a manifest base_url is set', () {
      ActionClipService.reset();
      expect(ActionClipService.hasClip(card), isFalse);
      expect(ActionClipService.urlFor(card), isNull);
    });
  });
}
