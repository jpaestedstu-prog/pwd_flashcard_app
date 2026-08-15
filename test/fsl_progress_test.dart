import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/xp_level_service.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/achievements.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';

/// Sign-language engagement as *data*: how it is stored, that it survives
/// trimming, and that it reaches the surfaces that reason about a learner.
///
/// Six surfaces call `recordFslVideoView`, and until now exactly one label read
/// the result. The log was also unbounded — every view ever, in one key,
/// rescanned for the unique count on every dictionary rebuild.
///
/// Plain `test()`, not `testWidgets`: a Hive write inside the fake-async zone
/// leaves its Future pending and hangs `deleteFromDisk` at teardown.
void main() {
  const profileId = 'p_fsl';

  setUpAll(() async {
    const dir = './build/test_cache/fsl_progress';
    try {
      final d = Directory(dir);
      if (d.existsSync()) d.deleteSync(recursive: true);
    } catch (_) {}
    Hive.init(dir);
    for (final name in const <String>['profiles', 'settings', 'progress']) {
      if (!Hive.isBoxOpen(name)) {
        // Compaction off: these tests do hundreds of sequential writes and then
        // clear the box between cases, which makes Hive compact mid-flight. On
        // Windows that compaction renames the .hivec over the .hive and loses
        // the race against the write still holding it ("Access is denied").
        // Nothing here is testing compaction, so take it out of the picture.
        await Hive.openBox(name, compactionStrategy: (total, deleted) => false);
      }
    }
  });

  tearDown(() async => Hive.box('progress').clear());
  tearDownAll(() async => Hive.deleteFromDisk());

  LearningProgress progressWithSigns(Set<String> keys) => LearningProgress(
    profileId: profileId,
    lastActivityDate: DateTime(2026, 8, 11),
    signedWordKeys: keys,
  );

  group('the view log', () {
    test('is capped, while the distinct-signs count keeps climbing', () async {
      // 260 views of 260 different words — more than the 200-entry cap.
      for (var i = 0; i < 260; i++) {
        await HiveService.recordFslVideoView(profileId, 'Animals', 'word$i');
      }

      expect(
        HiveService.getFslVideoViews(profileId).length,
        200,
        reason: 'the log is a recent window, not an ever-growing list',
      );
      expect(
        HiveService.fslUniqueWordsViewed(profileId),
        260,
        reason: 'trimming the log must never cost the learner progress',
      );
    });

    test('keeps the most recent entries', () async {
      for (var i = 0; i < 205; i++) {
        await HiveService.recordFslVideoView(profileId, 'Animals', 'word$i');
      }
      final words = HiveService.getFslVideoViews(
        profileId,
      ).map((v) => v['word']).toList();
      expect(words.first, 'word5');
      expect(words.last, 'word204');
    });

    test('re-watching a word does not double-count it', () async {
      await HiveService.recordFslVideoView(profileId, 'Animals', 'Dog');
      await HiveService.recordFslVideoView(profileId, 'Animals', 'Dog');
      await HiveService.recordFslVideoView(profileId, 'Animals', 'Cat');

      expect(HiveService.getFslVideoViews(profileId).length, 3);
      expect(HiveService.fslUniqueWordsViewed(profileId), 2);
    });

    test('the same word in two categories counts twice', () async {
      // `chicken` is a real collision: Animals and Food & Drinks both have it.
      await HiveService.recordFslVideoView(profileId, 'Animals', 'Chicken');
      await HiveService.recordFslVideoView(
        profileId,
        'Food & Drinks',
        'Chicken',
      );
      expect(HiveService.fslUniqueWordsViewed(profileId), 2);
      expect(
        HiveService.hasViewedFslWord(profileId, 'Animals', 'Chicken'),
        isTrue,
      );
      expect(
        HiveService.hasViewedFslWord(profileId, 'Clothing', 'Chicken'),
        isFalse,
      );
    });
  });

  test(
    'a profile written before the unique-set key still reports progress',
    () async {
      // Exactly what an existing install looks like: a log, and no unique key.
      await Hive.box('progress').put('fsl_views_$profileId', [
        {
          'category': 'Animals',
          'word': 'Dog',
          'date': '2026-08-01T10:00:00.000',
        },
        {
          'category': 'Animals',
          'word': 'Cat',
          'date': '2026-08-01T10:01:00.000',
        },
        {
          'category': 'Animals',
          'word': 'Dog',
          'date': '2026-08-02T10:00:00.000',
        },
      ]);

      expect(
        HiveService.fslUniqueWordsViewed(profileId),
        2,
        reason:
            'derived from the log rather than showing a legacy learner zero',
      );

      // …and the next view persists the set, so it stops being derived.
      await HiveService.recordFslVideoView(profileId, 'Animals', 'Bird');
      expect(Hive.box('progress').get('fsl_unique_$profileId'), isNotNull);
      expect(HiveService.fslUniqueWordsViewed(profileId), 3);
    },
  );

  group('cloud merge', () {
    test('unions the remote set instead of replacing it', () async {
      await HiveService.recordFslVideoView(profileId, 'Animals', 'Dog');
      await HiveService.recordFslVideoView(profileId, 'Animals', 'Cat');

      // The other device watched Cat too, plus one this one has never seen.
      final changed = await HiveService.mergeFslWordsViewed(profileId, [
        'Animals_Cat',
        'Weather_Rainy',
      ]);

      expect(changed, isTrue);
      expect(
        HiveService.fslWordsViewed(profileId),
        {'Animals_Dog', 'Animals_Cat', 'Weather_Rainy'},
        reason:
            'a pull must never roll back what this device already had — '
            'the set feeds XP, so losing entries would de-level the learner',
      );
    });

    test('reports no change when the remote adds nothing', () async {
      await HiveService.recordFslVideoView(profileId, 'Animals', 'Dog');
      expect(
        await HiveService.mergeFslWordsViewed(profileId, ['Animals_Dog']),
        isFalse,
      );
    });

    test('ignores blank keys from a malformed document', () async {
      await HiveService.mergeFslWordsViewed(profileId, ['', 'Animals_Dog', '']);
      expect(HiveService.fslWordsViewed(profileId), {'Animals_Dog'});
    });
  });

  group('favourites', () {
    test('toggle on and off, and stay separate from watched', () async {
      expect(
        await HiveService.toggleFslFavourite(profileId, 'Animals', 'Dog'),
        isTrue,
      );
      expect(HiveService.isFslFavourite(profileId, 'Animals', 'Dog'), isTrue);
      // Starring is a bookmark, not progress: it must not count as watched.
      expect(HiveService.fslUniqueWordsViewed(profileId), 0);

      expect(
        await HiveService.toggleFslFavourite(profileId, 'Animals', 'Dog'),
        isFalse,
      );
      expect(HiveService.fslFavourites(profileId), isEmpty);
    });

    test('are per word, per category, and per profile', () async {
      await HiveService.toggleFslFavourite(profileId, 'Animals', 'Chicken');
      expect(
        HiveService.isFslFavourite(profileId, 'Food & Drinks', 'Chicken'),
        isFalse,
      );
      expect(HiveService.fslFavourites('someone_else'), isEmpty);
    });
  });

  group('"I can sign this" — claim, verdict, and the line between them', () {
    test('a claim can be withdrawn, unlike a sign watched', () async {
      await HiveService.recordFslVideoView(profileId, 'Animals', 'Dog');
      await HiveService.setFslMastery(
        profileId,
        'Animals',
        'Dog',
        SignMastery.canSign,
      );
      expect(HiveService.fslCanSignKeys(profileId), {'Animals_Dog'});

      // Capability can be withdrawn — the property that makes this a different
      // measure from exposure.
      await HiveService.setFslMastery(
        profileId,
        'Animals',
        'Dog',
        SignMastery.learning,
      );
      expect(HiveService.fslCanSignKeys(profileId), isEmpty);
      expect(
        HiveService.fslMasteryFor(profileId, 'Animals', 'Dog'),
        SignMastery.learning,
      );

      // …while watching it stays true forever.
      expect(HiveService.fslWordsViewed(profileId), contains('Animals_Dog'));
    });

    test('changing a claim does not erase the educator’s verdict', () async {
      await HiveService.setFslMastery(
        profileId,
        'Animals',
        'Dog',
        SignMastery.canSign,
      );
      await HiveService.setFslVerification(
        profileId,
        'Animals',
        'Dog',
        SignVerification.confirmed,
        verifierId: 'teacher_1',
        verifierRole: 'teacher',
      );

      await HiveService.setFslMastery(
        profileId,
        'Animals',
        'Dog',
        SignMastery.learning,
      );

      expect(
        HiveService.fslVerificationFor(profileId, 'Animals', 'Dog'),
        SignVerification.confirmed,
        reason:
            'the teacher watched them do it; the learner second-guessing '
            'themselves later does not undo that observation — and discarding '
            'it would destroy the calibration pair',
      );
    });

    test('a downgrade drops the confirmed set but never the XP set', () async {
      await HiveService.setFslVerification(
        profileId,
        'Animals',
        'Dog',
        SignVerification.confirmed,
        verifierId: 't',
        verifierRole: 'teacher',
      );
      expect(HiveService.fslConfirmedKeys(profileId), {'Animals_Dog'});
      expect(HiveService.fslEverConfirmedKeys(profileId), {'Animals_Dog'});

      await HiveService.setFslVerification(
        profileId,
        'Animals',
        'Dog',
        SignVerification.notConfirmed,
        verifierId: 't',
        verifierRole: 'teacher',
      );

      expect(
        HiveService.fslConfirmedKeys(profileId),
        isEmpty,
        reason: 'what everyone sees follows the current verdict',
      );
      expect(
        HiveService.fslEverConfirmedKeys(profileId),
        {'Animals_Dog'},
        reason: 'but the level they already earned is never taken back',
      );
    });

    test('records who ruled and when, for the export', () async {
      await HiveService.setFslVerification(
        profileId,
        'Animals',
        'Dog',
        SignVerification.confirmed,
        verifierId: 'parent_7',
        verifierRole: 'parent',
      );
      final rows = HiveService.fslVerificationRows(profileId);
      expect(rows, hasLength(1));
      expect(rows.first['role'], 'parent');
      expect(rows.first['by'], 'parent_7');
      expect(rows.first['at'], isNotEmpty);
    });
  });

  group('signs reach the rest of the app', () {
    test('a self-claim earns no XP; an educator confirmation does', () {
      final watchedOnly = LearningProgress(
        profileId: profileId,
        lastActivityDate: DateTime(2026, 8, 11),
        signedWordKeys: {'Animals_Dog'},
      );
      final alsoClaimed = watchedOnly.copyWith(canSignKeys: {'Animals_Dog'});
      final alsoConfirmed = alsoClaimed.copyWith(
        everConfirmedSignKeys: {'Animals_Dog'},
      );

      expect(
        XpService.calculateXp(alsoClaimed),
        XpService.calculateXp(watchedOnly),
        reason:
            'unverified self-report must not pay — otherwise a learner '
            'can tap through 142 words and level up without signing once, '
            'and the calibration measure is worthless',
      );
      expect(
        XpService.calculateXp(alsoConfirmed) -
            XpService.calculateXp(alsoClaimed),
        15,
      );
    });

    test('XP counts them, and never goes backwards', () {
      final none = progressWithSigns({});
      final some = progressWithSigns({'Animals_Dog', 'Animals_Cat'});

      expect(
        XpService.calculateXp(some),
        greaterThan(XpService.calculateXp(none)),
      );
      // The set only ever grows, so XP derived from it is monotonic — the
      // invariant the whole level economy rests on.
      expect(XpService.calculateXp(some) - XpService.calculateXp(none), 2 * 8);
    });

    test('the sign achievements unlock off distinct signs', () {
      expect(
        Achievements.firstSign.checkUnlocked(progressWithSigns({})),
        isFalse,
      );
      expect(
        Achievements.firstSign.checkUnlocked(
          progressWithSigns({'Animals_Dog'}),
        ),
        isTrue,
      );

      final twentyFive = {for (var i = 0; i < 25; i++) 'Animals_w$i'};
      expect(
        Achievements.signExplorer.checkUnlocked(progressWithSigns(twentyFive)),
        isTrue,
      );
      expect(
        Achievements.signFluent.checkUnlocked(progressWithSigns(twentyFive)),
        isFalse,
      );

      final hundred = {for (var i = 0; i < 100; i++) 'Animals_w$i'};
      expect(
        Achievements.signFluent.checkUnlocked(progressWithSigns(hundred)),
        isTrue,
      );
    });

    test('every sign achievement is registered for display', () {
      final ids = Achievements.all.map((a) => a.id).toSet();
      expect(ids, containsAll(['first_sign', 'sign_explorer', 'sign_fluent']));
    });
  });
}
