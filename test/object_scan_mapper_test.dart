import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/constants/flashcard_emojis.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/features/object_scan/models/object_scan_models.dart';
import 'package:pwdpwdpwd/features/object_scan/services/label_word_mapper.dart';

void main() {
  group('LabelWordMapper.match', () {
    test('matches a wordEnglish directly, case-insensitively', () {
      for (final label in const ['Chair', 'chair', 'CHAIR', '  chair  ']) {
        final m = LabelWordMapper.match(label);
        expect(m, isNotNull, reason: '"$label" should match');
        expect(m!.card.wordEnglish, 'Chair');
        expect(m.card.wordFilipino, 'Upuan');
      }
    });

    test('resolves ML Kit aliases to vocabulary words', () {
      expect(LabelWordMapper.match('Mobile phone')!.card.wordEnglish, 'Phone');
      expect(LabelWordMapper.match('Footwear')!.card.wordEnglish, 'Shoes');
      expect(LabelWordMapper.match('Desk')!.card.wordEnglish, 'Table');
      expect(LabelWordMapper.match('Tableware')!.card.wordEnglish, 'Plate');
      expect(LabelWordMapper.match('soccer ball')!.card.wordEnglish, 'Ball');
    });

    test('returns null for labels outside the vocabulary', () {
      expect(LabelWordMapper.match('Skyscraper'), isNull);
      expect(LabelWordMapper.match('Person'), isNull);
      expect(LabelWordMapper.match(''), isNull);
      expect(LabelWordMapper.match('   '), isNull);
    });

    test('every alias target resolves to a real seed card', () {
      final words =
          SeedData.allFlashcards.map((c) => c.wordEnglish.toLowerCase()).toSet();
      for (final entry in LabelWordMapper.aliases.entries) {
        expect(
          words.contains(entry.value.toLowerCase()),
          isTrue,
          reason:
              'Alias "${entry.key}" points to "${entry.value}" which is not in SeedData',
        );
      }
    });

    test('keeps the raw source label and confidence on the match', () {
      final m = LabelWordMapper.match('Mobile phone', confidence: 0.83)!;
      expect(m.sourceLabel, 'Mobile phone');
      expect(m.confidence, 0.83);
    });
  });

  group('LabelWordMapper.matchAll', () {
    test('dedupes per card keeping the highest confidence, sorted best-first',
        () {
      final matches = LabelWordMapper.matchAll(const [
        RecognizedLabel(label: 'Telephone', confidence: 0.6),
        RecognizedLabel(label: 'Mobile phone', confidence: 0.9),
        RecognizedLabel(label: 'Chair', confidence: 0.7),
        RecognizedLabel(label: 'Skyscraper', confidence: 0.99),
      ]);
      expect(matches, hasLength(2));
      expect(matches[0].card.wordEnglish, 'Phone');
      expect(matches[0].confidence, 0.9);
      expect(matches[1].card.wordEnglish, 'Chair');
    });

    test('returns empty for no recognizable labels', () {
      expect(
        LabelWordMapper.matchAll(
            const [RecognizedLabel(label: 'Galaxy', confidence: 1.0)]),
        isEmpty,
      );
    });
  });

  group('Word Hunt seed words', () {
    const expectedNewWords = {
      'f13': ('Bottle', 'Bote'),
      'f14': ('Cup', 'Tasa'),
      'f15': ('Spoon', 'Kutsara'),
      'f16': ('Fork', 'Tinidor'),
      'f17': ('Plate', 'Plato'),
      'cr13': ('Table', 'Mesa'),
      'cr14': ('Paper', 'Papel'),
      'cr15': ('Ball', 'Bola'),
      'cr16': ('Door', 'Pinto'),
      'cr17': ('Window', 'Bintana'),
      'cr18': ('Television', 'Telebisyon'),
      'cr19': ('Phone', 'Telepono'),
      'c13': ('Flower', 'Bulaklak'),
    };

    test('all new object words exist with Filipino translations', () {
      final byId = {for (final c in SeedData.allFlashcards) c.id: c};
      expectedNewWords.forEach((id, pair) {
        final card = byId[id];
        expect(card, isNotNull, reason: 'Missing seed card $id');
        expect(card!.wordEnglish, pair.$1);
        expect(card.wordFilipino, pair.$2);
        expect(card.exampleSentence, isNotEmpty);
        expect(card.isCustom, isFalse);
      });
    });

    test('all new object words have their own emoji (not the fallback)', () {
      for (final id in expectedNewWords.keys) {
        expect(
          FlashcardEmojis.forId(id),
          isNot('📖'),
          reason: 'Seed card $id should have a dedicated emoji',
        );
      }
    });

    test('every new word is reachable from a camera label', () {
      expectedNewWords.forEach((id, pair) {
        final m = LabelWordMapper.match(pair.$1);
        expect(m, isNotNull, reason: '"${pair.$1}" should be matchable');
        expect(m!.card.id, id);
      });
    });
  });
}
