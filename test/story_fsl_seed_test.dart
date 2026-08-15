import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/seed_stories.dart';
import 'package:pwdpwdpwd/features/tv_cast/services/tv_cast_asset_bridge.dart';

/// Guards the sign-language track baked into [SeedStories].
///
/// Story FSL clips are plain data on the seed objects, and the reader, quiz and
/// TV Cast all index into them positionally — `sentenceFslUrls[i]` must be the
/// clip for sentence `i`, `optionFslUrls[j]` the clip for option `j`. A list
/// that is short, misaligned, or shared between two slots shows a learner the
/// wrong sign with no visible error, so these tests pin the shape rather than
/// trusting it.
void main() {
  final storiesWithFsl = SeedStories.all
      .where((s) => s.sentenceFslUrls.isNotEmpty)
      .toList();

  test('the 12 primary stories carry a full FSL track', () {
    expect(storiesWithFsl.length, 12);
    // One clip per page, and every entry present.
    for (final s in storiesWithFsl) {
      expect(s.sentenceFslUrls.length, s.sentencesEn.length,
          reason: '${s.id} has ${s.sentenceFslUrls.length} page clips for '
              '${s.sentencesEn.length} pages');
      for (var i = 0; i < s.sentenceFslUrls.length; i++) {
        expect(s.fslForSentence(i), isNotNull, reason: '${s.id} page $i');
      }
      // Question prompt + one clip per answer option.
      for (final q in s.questions) {
        expect(q.fslVideoUrl, isNotNull, reason: '${s.id} question prompt');
        expect(q.optionFslUrls.length, q.optionsEn.length,
            reason: '${s.id} has ${q.optionFslUrls.length} option clips for '
                '${q.optionsEn.length} options');
        for (var j = 0; j < q.optionsEn.length; j++) {
          expect(q.fslForOption(j), isNotNull, reason: '${s.id} option $j');
        }
      }
    }
  });

  test('a story either has a full FSL track or none at all', () {
    // Half-wired stories are the dangerous state: the button appears on some
    // pages and silently vanishes on others.
    for (final s in SeedStories.all) {
      if (s.sentenceFslUrls.isNotEmpty) continue;
      for (final q in s.questions) {
        expect(q.fslVideoUrl, isNull,
            reason: '${s.id} has question clips but no page clips');
        expect(q.optionFslUrls, isEmpty, reason: '${s.id} option clips');
      }
    }
  });

  test('every clip is a direct, non-expiring media URL', () {
    for (final s in storiesWithFsl) {
      final urls = <String>[
        ...s.sentenceFslUrls.whereType<String>(),
        for (final q in s.questions) ...[
          if (q.fslVideoUrl != null) q.fslVideoUrl!,
          ...q.optionFslUrls.whereType<String>(),
        ],
      ];
      for (final url in urls) {
        expect(url, isNot(contains('streamable.com')),
            reason: '${s.id} still points at Streamable (URLs expire)');
        expect(Uri.parse(url).path.toLowerCase(), endsWith('.mp4'),
            reason: '${s.id} clip is not a direct mp4: $url');
      }
    }
  });

  test('no clip URL is reused across slots', () {
    // Catches the copy/paste slip that would show one page's sign on another.
    final seen = <String, String>{};
    for (final s in storiesWithFsl) {
      void claim(String url, String slot) {
        expect(seen.containsKey(url), isFalse,
            reason: 'clip reused by ${seen[url]} and $slot');
        seen[url] = slot;
      }

      for (var i = 0; i < s.sentenceFslUrls.length; i++) {
        claim(s.sentenceFslUrls[i]!, '${s.id} page$i');
      }
      for (var qi = 0; qi < s.questions.length; qi++) {
        final q = s.questions[qi];
        claim(q.fslVideoUrl!, '${s.id} q$qi');
        for (var oi = 0; oi < q.optionFslUrls.length; oi++) {
          claim(q.optionFslUrls[oi]!, '${s.id} q${qi}o$oi');
        }
      }
    }
    expect(seen.length, 12 * (5 + 3 + 9));
  });

  test('the same 12 stories carry a full cartoon/real flip set', () {
    // The flip pairs are indexed positionally just like the FSL clips, so the
    // same alignment rules apply.
    final withImages =
        SeedStories.all.where((s) => s.sentenceImages.isNotEmpty).toList();
    expect(withImages.length, 12);
    expect(
      withImages.map((s) => s.id).toSet(),
      storiesWithFsl.map((s) => s.id).toSet(),
      reason: 'a story with signs but no pictures (or vice versa) is a '
          'half-wired state',
    );
    for (final s in withImages) {
      expect(s.sentenceImages.length, s.sentencesEn.length,
          reason: '${s.id} page pictures');
      for (var i = 0; i < s.sentenceImages.length; i++) {
        expect(s.imageForSentence(i), isNotNull, reason: '${s.id} page $i');
      }
      for (final q in s.questions) {
        expect(q.image, isNotNull, reason: '${s.id} question picture');
        expect(q.optionImages.length, q.optionsEn.length,
            reason: '${s.id} option pictures');
        for (var j = 0; j < q.optionsEn.length; j++) {
          expect(q.imageForOption(j), isNotNull, reason: '${s.id} option $j');
        }
      }
    }
  });

  test('every picture is a direct image URL, and no face is reused', () {
    final seen = <String, String>{};
    void claim(StoryImagePair p, String slot) {
      for (final entry in {'cartoon': p.cartoonUrl, 'real': p.realUrl}.entries) {
        final url = entry.value;
        expect(Uri.parse(url).path.toLowerCase(),
            anyOf(endsWith('.png'), endsWith('.jpg'), endsWith('.jpeg')),
            reason: '$slot ${entry.key} is not a direct image: $url');
        final where = '$slot ${entry.key}';
        expect(seen.containsKey(url), isFalse,
            reason: 'picture reused by ${seen[url]} and $where');
        seen[url] = where;
      }
    }

    for (final s in SeedStories.all.where((s) => s.sentenceImages.isNotEmpty)) {
      for (var i = 0; i < s.sentenceImages.length; i++) {
        claim(s.sentenceImages[i]!, '${s.id} page$i');
      }
      for (var qi = 0; qi < s.questions.length; qi++) {
        final q = s.questions[qi];
        claim(q.image!, '${s.id} q$qi');
        for (var oi = 0; oi < q.optionImages.length; oi++) {
          claim(q.optionImages[oi]!, '${s.id} q${qi}o$oi');
        }
      }
    }
    expect(seen.length, 12 * (5 + 3 + 9) * 2);
  });

  test('cast + in-app reader share one cache key per page', () {
    // The TV Cast server and the story reader must resolve the same on-disk
    // file, and keys must stay unique now that 12 stories have clips.
    final keys = <String>{};
    for (final s in storiesWithFsl) {
      for (var i = 0; i < s.sentenceFslUrls.length; i++) {
        final key = TvCastAssetBridge.storyFslCacheKey(s.id, i);
        expect(key, 'story_${s.id}_s$i',
            reason: 'cast key must match the reader key in '
                'story_reader_screen.dart');
        expect(keys.add(key), isTrue, reason: 'duplicate cache key $key');
      }
    }
    expect(keys.length, 12 * 5);
  });
}
