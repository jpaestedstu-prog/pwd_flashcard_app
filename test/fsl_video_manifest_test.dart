import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/fsl_assets_service.dart';
import 'package:pwdpwdpwd/core/services/media_url_resolver.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

/// Guards `assets/data/fsl_video_manifest.json` — the manifest that decides
/// which flashcards get a "watch the sign" video.
///
/// Every entry is keyed `[category]__[slug]`, which [FslAssetsService] matches
/// against `[Category label]__[wordEnglish lowercased]`. A typo in either
/// field silently drops the card's video, so these tests assert the wiring
/// rather than trusting it, and pin the hosting invariants the runtime relies
/// on (direct, non-expiring URLs that [MediaUrlResolver] passes through).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> entries;

  setUpAll(() async {
    final raw = await rootBundle.loadString(
      'assets/data/fsl_video_manifest.json',
    );
    entries = ((json.decode(raw) as Map<String, dynamic>)['entries'] as List)
        .cast<Map<String, dynamic>>();
  });

  setUp(() async {
    FslAssetsService.reset();
    await FslAssetsService.load();
  });

  tearDown(FslAssetsService.reset);

  group('Manifest wiring', () {
    test('every entry matches a real seed flashcard', () {
      final seedKeys = {
        for (final c in SeedData.allFlashcards)
          '${c.category.label}__${c.wordEnglish.toLowerCase()}',
      };
      for (final e in entries) {
        final key = '${e['category']}__${e['slug']}';
        expect(
          seedKeys,
          contains(key),
          reason: 'Manifest entry "$key" matches no seed card — the video '
              'would never be reachable (check category label / spelling).',
        );
      }
    });

    test('(category, slug) pairs are unique', () {
      final keys = entries.map((e) => '${e['category']}__${e['slug']}').toList();
      expect(keys.toSet().length, keys.length, reason: 'Duplicate manifest key');
    });

    test('every entry resolves to a playable source via the service', () {
      final byKey = {
        for (final c in SeedData.allFlashcards)
          '${c.category.label}__${c.wordEnglish.toLowerCase()}': c,
      };
      for (final e in entries) {
        final card = byKey['${e['category']}__${e['slug']}']!;
        expect(
          FslAssetsService.hasAnyVideoSource(card),
          isTrue,
          reason: 'No video source resolved for ${card.category.label} / '
              '${card.wordEnglish}',
        );
      }
    });

    test('the 12 original categories each report their manifest count', () async {
      const original = {
        FlashcardCategory.animals,
        FlashcardCategory.colorsAndShapes,
        FlashcardCategory.numbers,
        FlashcardCategory.bodyParts,
        FlashcardCategory.foodAndDrinks,
        FlashcardCategory.familyAndGreetings,
        FlashcardCategory.clothing,
        FlashcardCategory.weather,
        FlashcardCategory.classroom,
        FlashcardCategory.transportation,
        FlashcardCategory.emotions,
        FlashcardCategory.daysAndTime,
      };
      final availability = await FslAssetsService.load();
      for (final cat in original) {
        final expected = entries
            .where((e) => e['category'] == cat.label)
            .length;
        expect(
          availability.videoCountByCategory[cat],
          expected,
          reason: '${cat.label} should expose all $expected manifest videos',
        );
        // Enough words for the FSL games not to bounce to an empty state.
        expect(availability.playableCategories(), contains(cat));
      }
    });
  });

  group('Hosting invariants', () {
    test('no Streamable URLs survive — they expire', () {
      for (final e in entries) {
        for (final field in const ['download_url', 'stream_url']) {
          final url = e[field] as String?;
          expect(
            url ?? '',
            isNot(contains('streamable.com')),
            reason: '${e['category']} / ${e['slug']} still points at '
                'Streamable via $field',
          );
        }
        expect(
          e.containsKey('streamable_url'),
          isFalse,
          reason: '${e['category']} / ${e['slug']} kept the legacy '
              'streamable_url field',
        );
      }
    });

    test('every entry has a primary download_url on the GitHub release', () {
      for (final e in entries) {
        expect(
          e['download_url'],
          allOf(isA<String>(), contains('/releases/download/')),
          reason: 'Missing primary source for ${e['category']} / ${e['slug']}',
        );
      }
    });

    test('stream_url fallbacks are direct .mp4 files, not share pages', () {
      for (final e in entries) {
        final url = e['stream_url'] as String?;
        if (url == null) continue;
        expect(
          Uri.parse(url).path.toLowerCase(),
          endsWith('.mp4'),
          reason: '${e['category']} / ${e['slug']} stream_url is not a direct '
              'mp4 — it would need a share-page resolver',
        );
      }
    });

    test('MediaUrlResolver passes direct fallbacks through untouched', () async {
      // Direct URLs must survive the resolver unchanged: it only rewrites
      // known share-page hosts, and a rewrite here would mean a network hop
      // on every first play.
      final sample = entries
          .map((e) => e['stream_url'] as String?)
          .whereType<String>()
          .take(5);
      for (final url in sample) {
        expect(await MediaUrlResolver.resolve(url), url);
      }
    });
  });
}
