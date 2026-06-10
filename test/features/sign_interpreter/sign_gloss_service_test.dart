import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/fsl_assets_service.dart';
import 'package:pwdpwdpwd/core/utils/research_export_rows.dart';
import 'package:pwdpwdpwd/features/sign_interpreter/models/sign_interpreter_models.dart';
import 'package:pwdpwdpwd/features/sign_interpreter/services/sign_gloss_service.dart';

const _entries = [
  FslManifestEntry(
    category: 'Animals',
    slug: 'dog',
    wordEnglish: 'Dog',
    wordFilipino: 'Aso',
  ),
  FslManifestEntry(
    category: 'Animals',
    slug: 'cat',
    wordEnglish: 'Cat',
    wordFilipino: 'Pusa',
  ),
  FslManifestEntry(
    category: 'Numbers',
    slug: 'three',
    wordEnglish: 'Three',
    wordFilipino: 'Tatlo',
  ),
  FslManifestEntry(
    category: 'Family & Greetings',
    slug: 'thank-you',
    wordEnglish: 'Thank you',
    wordFilipino: 'Salamat',
  ),
  FslManifestEntry(
    category: 'Colors & Shapes',
    slug: 'red',
    wordEnglish: 'Red',
    wordFilipino: 'Pula',
  ),
];

void main() {
  final gloss = SignGlossService(_entries);

  group('SignGlossService.glossify', () {
    test('matches English vocabulary in spoken order, dropping stopwords', () {
      final items = gloss.glossify('The dog and the cat');
      expect(items, hasLength(2));
      expect(items[0].entry?.slug, 'dog');
      expect(items[1].entry?.slug, 'cat');
    });

    test('matches Filipino vocabulary and drops Filipino particles', () {
      final items = gloss.glossify('ang aso at ang pusa po');
      expect(items.map((i) => i.entry?.slug), ['dog', 'cat']);
    });

    test('greedy phrase match beats single-word stopwords', () {
      // "you" alone is a stopword; "thank you" must match as a phrase.
      final items = gloss.glossify('thank you po');
      expect(items, hasLength(1));
      expect(items.first.entry?.slug, 'thank-you');
    });

    test('strips plurals', () {
      final items = gloss.glossify('dogs and cats');
      expect(items.map((i) => i.entry?.slug), ['dog', 'cat']);
    });

    test('maps digits to number words and back', () {
      expect(gloss.glossify('3').single.entry?.slug, 'three');
      expect(gloss.glossify('three').single.entry?.slug, 'three');
    });

    test('surfaces unknown content words as unmatched', () {
      final items = gloss.glossify('the purple dog');
      expect(items, hasLength(2));
      expect(items[0].isMatched, isFalse);
      expect(items[0].word, 'purple');
      expect(items[1].entry?.slug, 'dog');
    });

    test('ignores punctuation and casing', () {
      final items = gloss.glossify('DOG!!! cat?');
      expect(items.map((i) => i.entry?.slug), ['dog', 'cat']);
    });

    test('returns empty for empty or stopword-only input', () {
      expect(gloss.glossify(''), isEmpty);
      expect(gloss.glossify('the is and'), isEmpty);
    });
  });

  group('bundled manifest', () {
    test('indexes the real fsl_video_manifest.json vocabulary', () {
      final raw =
          File('assets/data/fsl_video_manifest.json').readAsStringSync();
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final entries = [
        for (final e in (decoded['entries'] as List).cast<Map>())
          FslManifestEntry(
            category: e['category'] as String,
            slug: e['slug'] as String,
            wordEnglish: e['word_english'] as String? ?? e['slug'] as String,
            wordFilipino: e['word_filipino'] as String? ?? '',
          ),
      ];
      expect(entries.length, greaterThan(100));

      final realGloss = SignGlossService(entries);
      expect(realGloss.indexSize, greaterThan(entries.length));

      final items = realGloss.glossify('the dog eats with the cat');
      final slugs = items.where((i) => i.isMatched).map((i) => i.entry!.slug);
      expect(slugs, containsAll(['dog', 'cat']));
    });
  });

  group('SignUsageEvent', () {
    test('JSON round-trips', () {
      final event = SignUsageEvent(
        timestamp: DateTime(2026, 6, 10, 9, 30),
        locale: 'fil-PH',
        source: 'mic',
        tokenCount: 5,
        matchedCount: 3,
        unmatchedWords: const ['purple', 'jeepney'],
        durationMs: 4200,
      );
      final restored = SignUsageEvent.fromJson(
        Map<String, dynamic>.from(json.decode(json.encode(event.toJson()))),
      );
      expect(restored.timestamp, event.timestamp);
      expect(restored.locale, event.locale);
      expect(restored.source, event.source);
      expect(restored.tokenCount, event.tokenCount);
      expect(restored.matchedCount, event.matchedCount);
      expect(restored.unmatchedWords, event.unmatchedWords);
      expect(restored.durationMs, event.durationMs);
    });
  });

  group('speech_to_sign_usage.csv rows', () {
    test('row column count matches the header', () {
      final rows = ResearchExportRows.speechToSignUsageRows(
        studentId: 'S001',
        events: [
          SignUsageEvent(
            timestamp: DateTime(2026, 6, 10),
            locale: 'en-US',
            source: 'typed',
            tokenCount: 4,
            matchedCount: 2,
            unmatchedWords: const ['purple', 'jeepney'],
            durationMs: 0,
          ),
        ],
      );
      expect(rows, hasLength(1));
      final headerCols =
          ResearchExportRows.speechToSignUsageHeader.split(',').length;
      expect(rows.single.split(',').length, headerCols);
      expect(rows.single, contains('purple;jeepney'));
    });
  });
}
