import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

void main() {
  group('GameType — new types', () {
    test('jigsawPuzzle has correct label', () {
      expect(GameType.jigsawPuzzle.label, 'Jigsaw Puzzle');
    });

    test('jigsawPuzzle has non-empty description', () {
      expect(GameType.jigsawPuzzle.description, isNotEmpty);
    });

    test('pictureWord has correct label', () {
      expect(GameType.pictureWord.label, 'Picture-Word');
    });

    test('pictureWord has non-empty description', () {
      expect(GameType.pictureWord.description, isNotEmpty);
    });

    test('all GameType values have unique labels', () {
      final labels = GameType.values.map((t) => t.label).toSet();
      expect(labels.length, GameType.values.length);
    });

    test('all GameType values have an icon', () {
      for (final type in GameType.values) {
        expect(type.icon, isNotNull, reason: '${type.name} missing icon');
      }
    });

    test('all GameType values have a color', () {
      for (final type in GameType.values) {
        expect(type.color, isNotNull, reason: '${type.name} missing color');
      }
    });
  });

  group('GameDifficulty', () {
    test('all difficulties have unique labels', () {
      final labels = GameDifficulty.values.map((d) => d.label).toSet();
      expect(labels.length, GameDifficulty.values.length);
    });
  });

  group('FlashcardCategory', () {
    test('all categories have unique labels', () {
      final labels = FlashcardCategory.values.map((c) => c.label).toSet();
      expect(labels.length, FlashcardCategory.values.length);
    });

    test('all categories have icon', () {
      for (final cat in FlashcardCategory.values) {
        expect(cat.icon, isNotNull,
            reason: '${cat.name} missing icon');
      }
    });
  });
}
