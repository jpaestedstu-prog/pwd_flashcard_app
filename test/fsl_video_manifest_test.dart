import 'dart:convert';
import 'dart:io';

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

  // ─── The source manifest ────────────────────────────────────────
  //
  // `tools/fsl_video_manifest.json` is the hand-edited source of truth that
  // `tools/publish_fsl_videos.mjs` reads; the bundled manifest above is its
  // *output*. Everything above therefore only catches a mistake after the
  // upload has already happened. These run against the input, so a bad row
  // fails on `flutter test` — before anything is published.
  group('Source manifest (tools/fsl_video_manifest.json)', () {
    late List<Map<String, dynamic>> sourceRows;

    setUpAll(() {
      final file = File('tools/fsl_video_manifest.json');
      sourceRows =
          ((json.decode(file.readAsStringSync()) as Map<String, dynamic>)
                  ['entries']
              as List)
              .cast<Map<String, dynamic>>();
    });

    test('every row matches a real seed flashcard', () {
      final seedKeys = {
        for (final c in SeedData.allFlashcards)
          '${c.category.label}__${c.wordEnglish.toLowerCase()}',
      };
      for (final row in sourceRows) {
        expect(
          seedKeys,
          contains('${row['category']}__${row['slug']}'),
          reason: 'Source row "${row['category']}__${row['slug']}" matches no '
              'seed card — publishing it would upload a clip nothing can reach.',
        );
      }
    });

    test('rows use the source shape, not the app shape', () {
      // The publisher destructures `wordEnglish` / `wordFilipino` / `source`.
      // A row pasted in the bundled manifest's snake_case shape publishes as
      // `word_english: undefined` with no file to upload — silently.
      for (final row in sourceRows) {
        final where = '${row['category']}__${row['slug']}';
        for (final field in const [
          'category',
          'slug',
          'wordEnglish',
          'wordFilipino',
          'source',
        ]) {
          expect(
            row[field],
            isNotNull,
            reason: 'Source row "$where" is missing "$field"',
          );
        }
        expect(
          row.keys.any(
            (k) => const [
              'word_english',
              'word_filipino',
              'download_url',
              'stream_url',
            ].contains(k),
          ),
          isFalse,
          reason: 'Source row "$where" carries app-manifest fields — this file '
              'uses wordEnglish / wordFilipino / source',
        );
      }
    });

    test('keys are unique', () {
      final keys = sourceRows
          .map((r) => '${r['category']}__${r['slug']}')
          .toList();
      expect(keys.toSet().length, keys.length, reason: 'Duplicate source row');
    });

    test('every published sign still has a source row', () {
      // The publisher rewrites the bundled manifest from the source rows it
      // walked, so a sign dropped from the source would be dropped from the
      // app on the next publish even though its video is still hosted.
      // Coverage only ever grows.
      final sourceKeys = {
        for (final r in sourceRows) '${r['category']}__${r['slug']}',
      };
      for (final e in entries) {
        expect(
          sourceKeys,
          contains('${e['category']}__${e['slug']}'),
          reason: 'Published sign "${e['category']}__${e['slug']}" has no row '
              'in the source manifest — the next publish would drop it.',
        );
      }
    });
  });
}
