import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/fsl_assets_service.dart';
import 'package:pwdpwdpwd/core/services/media_url_resolver.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show Flashcard;

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

  // ─── Light copies (phones) ──────────────────────────────────────
  //
  // Phones play the website's 480p copy of each sign (`light_url`): the
  // 1080p60 originals froze on a friend's phone or never started. The app
  // now depends on those website files, so renaming or deleting one breaks
  // a sign in the app, and a light copy filed under the wrong word would
  // teach the wrong sign. tools/fsl_light_urls.py writes these, attaching a
  // copy only when it is the same recording as the original (by duration).
  group('Light copies (phones)', () {
    const site =
        'https://jpaestedstu-prog.github.io/pwd_flashcard_app/assets/videos/fsl/';

    Map<String, String> websiteClipByWord() {
      final js = File('website/assets/fsl-dict.js').readAsStringSync();
      final cats = (json.decode(
        RegExp(r'window.FSL_CATS = (\[.*?\]);', dotAll: true)
            .firstMatch(js)!
            .group(1)!,
      ) as List)
          .map((c) => (c as Map)['en'] as String)
          .toList();
      return {
        for (final m in RegExp(r'\{c:(\d+),f:"([^"]+)",en:"([^"]+)"')
            .allMatches(js))
          '${cats[int.parse(m.group(1)!)]}__${m.group(3)!.toLowerCase()}':
              m.group(2)!,
      };
    }

    test('every light copy is a website clip that exists', () {
      for (final e in entries) {
        final url = e['light_url'] as String?;
        if (url == null) continue;
        expect(url, startsWith(site),
            reason: '${e['category']} / ${e['slug']}: light_url is not a '
                'website clip');
        final name = url.substring(site.length);
        expect(File('website/assets/videos/fsl/$name').existsSync(), isTrue,
            reason: '${e['category']} / ${e['slug']}: website clip $name is '
                'missing — the app plays it on phones');
      }
    });

    test("each light copy is the website's clip for the same word", () {
      final clipByWord = websiteClipByWord();
      for (final e in entries) {
        final url = e['light_url'] as String?;
        if (url == null) continue;
        final word = '${e['category']}__${(e['word_english'] as String).toLowerCase()}';
        expect('$site${clipByWord[word]}.mp4', url,
            reason: '$word: its light copy belongs to another word');
      }
    });

    test('almost every sign has one (a dropped field would fail here)', () {
      final withLight = entries.where((e) => e['light_url'] != null).length;
      expect(withLight / entries.length, greaterThanOrEqualTo(0.9),
          reason: 'only $withLight of ${entries.length} signs have a light '
              'copy: run tools/fsl_light_urls.py');
    });

    test('the service reads them, and a borrowed sign borrows its light copy',
        () {
      final dog = SeedData.allFlashcards.firstWhere(
          (c) => c.category == FlashcardCategory.animals && c.wordEnglish == 'Dog');
      expect(FslAssetsService.lightUrlFor(dog), '${site}dog.mp4');

      final walk = SeedData.allFlashcards.firstWhere(
          (c) => c.category == FlashcardCategory.actions && c.wordEnglish == 'Walk');
      final lender = SeedData.allFlashcards.firstWhere((c) =>
          c.category == FlashcardCategory.transportation && c.wordEnglish == 'Walk');
      expect(FslAssetsService.lightUrlFor(walk), isNotNull);
      expect(FslAssetsService.lightUrlFor(walk),
          FslAssetsService.lightUrlFor(lender));
    });

    test('a browser streams the light copy, else the 720p twin', () {
      Flashcard card(FlashcardCategory c, String word) => SeedData.allFlashcards
          .firstWhere((f) => f.category == c && f.wordEnglish == word);

      final dog = FslAssetsService.webSourceFor(
        card(FlashcardCategory.animals, 'Dog'),
      );
      expect(dog, isA<NetworkVideoSource>());
      expect((dog! as NetworkVideoSource).url, '${site}dog.mp4');

      // Its website clip is another recording, so it has no light copy.
      final yellow = card(FlashcardCategory.colorsAndShapes, 'Yellow');
      expect(FslAssetsService.lightUrlFor(yellow), isNull);
      final source = FslAssetsService.webSourceFor(yellow);
      expect((source! as NetworkVideoSource).url,
          FslAssetsService.streamUrlFor(yellow));
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
