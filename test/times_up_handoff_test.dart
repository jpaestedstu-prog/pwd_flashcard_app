import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/constants/avatar_data.dart';
import 'package:pwdpwdpwd/core/constants/lock_media.dart';
import 'package:pwdpwdpwd/core/services/fsl_assets_service.dart';
import 'package:pwdpwdpwd/core/services/media_url_resolver.dart';
import 'package:pwdpwdpwd/core/services/guardian_address.dart';
import 'package:pwdpwdpwd/core/services/handoff_target.dart';
import 'package:pwdpwdpwd/core/services/story_image_service.dart';
import 'package:pwdpwdpwd/core/services/lock_enforcer.dart';
import 'package:pwdpwdpwd/core/services/lock_presentation.dart';
import 'package:pwdpwdpwd/data/models/child_time_limit.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/parent/screens/child_time_limits_screen.dart';
import 'package:pwdpwdpwd/features/parent/screens/time_up_lock_screen.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/child_time_limit_provider.dart';
import 'package:pwdpwdpwd/providers/lock_announcement_provider.dart';
import 'package:pwdpwdpwd/providers/managed_child_profile_provider.dart';
import 'package:pwdpwdpwd/providers/lock_state_provider.dart';
import 'package:pwdpwdpwd/providers/unlocking_educators_provider.dart';

import 'support/device_matrix.dart';
import 'support/lock_test_doubles.dart';

/// Covers the "Time's up" hand-off announcement end to end:
///
///   * **[GuardianAddress]** — the Ma'am / Sir / Mommy / Daddy derivation
///     comes from the educator's *avatar*, and a preferred name always
///     wins over it.
///   * **[LockPresentation]** — every accessibility profile resolves to a
///     defined set of channels, and each profile's primary channel is
///     actually enabled.
///   * **[ChildTimeLimit]** — the new fields round-trip, and documents
///     written before the feature existed still announce.
///   * **[TimeUpLockScreen]** — announces once on appearance with the
///     resolved message, always offers "Switch account", shows the FSL
///     clip only for profiles that need it, and lays out without
///     overflow across the device × font-scale matrix.
void main() {
  setUp(() {
    // The hand-off picture goes through the app's shared image pipeline,
    // which downloads and disk-caches — neither exists under the test
    // binding. Resolving to null exercises the "couldn't fetch" face while
    // still building the card, which is what these tests assert on.
    StoryImageService.debugResolverOverride = (url, cacheKey) async => null;
  });

  tearDown(() {
    StoryImageService.debugResolverOverride = null;
    StoryImageService.reset();
  });

  group('GuardianAddress honorifics', () {
    test('derive from the educator avatar, not from their name', () {
      expect(
        GuardianAddress.honorificFor(
          role: UserRole.teacher,
          avatarIndex: GuardianAddress.avatarFemaleTeacher,
        ),
        "Ma'am",
      );
      expect(
        GuardianAddress.honorificFor(
          role: UserRole.teacher,
          avatarIndex: GuardianAddress.avatarMaleTeacher,
        ),
        'Sir',
      );
      expect(
        GuardianAddress.honorificFor(
          role: UserRole.parent,
          avatarIndex: GuardianAddress.avatarMother,
        ),
        'Mommy',
      );
      expect(
        GuardianAddress.honorificFor(
          role: UserRole.parent,
          avatarIndex: GuardianAddress.avatarFather,
        ),
        'Daddy',
      );
    });

    test('the honorific avatar indices match AvatarData', () {
      // The whole derivation rests on these four indices. If the avatar
      // list is ever reordered, this test fails before a child is told
      // to hand their tablet to the wrong person.
      expect(AvatarData.avatars[GuardianAddress.avatarMaleTeacher].label,
          'Male Teacher');
      expect(AvatarData.avatars[GuardianAddress.avatarFemaleTeacher].label,
          'Female Teacher');
      expect(AvatarData.avatars[GuardianAddress.avatarFather].label, 'Father');
      expect(AvatarData.avatars[GuardianAddress.avatarMother].label, 'Mother');
    });

    test('fall back to a neutral term for a non-gendered avatar', () {
      expect(
        GuardianAddress.honorificFor(role: UserRole.teacher, avatarIndex: 3),
        'your teacher',
      );
      expect(
        GuardianAddress.honorificFor(role: UserRole.parent, avatarIndex: 0),
        'your parent',
      );
    });

    test('a preferred name beats the derived honorific', () {
      expect(
        GuardianAddress.resolve(
          preferredName: 'Teacher Ana',
          stampedHonorific: "Ma'am",
          role: UserRole.teacher,
        ),
        'Teacher Ana',
      );
      // Blank / whitespace-only names do not shadow the honorific.
      expect(
        GuardianAddress.resolve(
          preferredName: '   ',
          stampedHonorific: 'Daddy',
          role: UserRole.parent,
        ),
        'Daddy',
      );
    });

    test('resolve derives from role + avatar when nothing was stamped', () {
      expect(
        GuardianAddress.resolve(
          preferredName: '',
          stampedHonorific: '',
          role: UserRole.parent,
          avatarIndex: GuardianAddress.avatarMother,
        ),
        'Mommy',
      );
    });

    test('message verb follows the setter role', () {
      expect(
        GuardianAddress.timesUpMessage(
            address: "Ma'am", setterRole: UserRole.teacher),
        "Time's up. Please give your device to Ma'am.",
      );
      expect(
        GuardianAddress.timesUpMessage(
            address: 'Dad', setterRole: UserRole.parent),
        "Time's up. Please return your device to Dad.",
      );
    });

    test('every variant names the address and is non-empty', () {
      for (final role in UserRole.values) {
        expect(
          GuardianAddress.timesUpMessage(address: 'Lola', setterRole: role),
          contains('Lola'),
        );
        expect(
          GuardianAddress.timesUpMessageFilipino(
              address: 'Lola', setterRole: role),
          contains('Lola'),
        );
      }
      expect(GuardianAddress.timesUpMessageSimple(address: 'Nanay'),
          contains('Nanay'));
      expect(GuardianAddress.timesUpMessageSimpleFilipino(address: 'Nanay'),
          contains('Nanay'));
    });
  });

  group('Hand-off picture', () {
    test('each gendered educator avatar maps to its own artwork', () {
      final pairs = <HandoffFigure, (UserRole, int)>{
        HandoffFigure.maam:
            (UserRole.teacher, GuardianAddress.avatarFemaleTeacher),
        HandoffFigure.sir:
            (UserRole.teacher, GuardianAddress.avatarMaleTeacher),
        HandoffFigure.mommy: (UserRole.parent, GuardianAddress.avatarMother),
        HandoffFigure.daddy: (UserRole.parent, GuardianAddress.avatarFather),
      };
      for (final entry in pairs.entries) {
        final (role, avatar) = entry.value;
        expect(
          GuardianAddress.figureFor(role: role, avatarIndex: avatar),
          entry.key,
        );
      }
      // Four distinct artworks, one per figure — a copy/paste in the URL
      // table would hand a child the wrong picture.
      final urls = LockMediaDefaults.timesUpImageUrls.values.toList();
      expect(urls, hasLength(HandoffFigure.values.length));
      expect(urls.toSet(), hasLength(urls.length));
      for (final url in urls) {
        expect(url, startsWith('https://res.cloudinary.com/'));
        expect(url, endsWith('.png'));
      }
    });

    test('a non-gendered avatar has no artwork', () {
      expect(
        GuardianAddress.figureFor(role: UserRole.teacher, avatarIndex: 3),
        isNull,
      );
      expect(LockMediaDefaults.timesUpImageUrl(null), isNull);
    });

    test('the figure survives a round-trip through the stamped honorific',
        () {
      // The child's device usually has only this string, so the picture has
      // to be recoverable from it.
      expect(GuardianAddress.figureFromHonorific("Ma'am"), HandoffFigure.maam);
      expect(GuardianAddress.figureFromHonorific('MAAM'), HandoffFigure.maam);
      expect(GuardianAddress.figureFromHonorific('Sir'), HandoffFigure.sir);
      expect(
          GuardianAddress.figureFromHonorific('Mommy'), HandoffFigure.mommy);
      expect(
          GuardianAddress.figureFromHonorific('Daddy'), HandoffFigure.daddy);
      expect(GuardianAddress.figureFromHonorific('your teacher'), isNull);
      expect(GuardianAddress.figureFromHonorific(''), isNull);
    });

    test('a preferred name changes the words but not the picture', () {
      final target = HandoffTarget.resolve(
        limit: _limit(
          guardianHonorific: "Ma'am",
          guardianPreferredName: 'Teacher Ana',
          role: UserRole.teacher,
        ),
        educators: const [],
        filipino: false,
      );
      expect(target.address, 'Teacher Ana');
      expect(target.figure, HandoffFigure.maam);
    });

    test('the live educator avatar wins over a stale stamped honorific', () {
      final target = HandoffTarget.resolve(
        // Document says Daddy; the linked educator's avatar says Mother.
        limit: _limit(guardianHonorific: 'Daddy', role: UserRole.parent),
        educators: [_educator()],
        filipino: false,
      );
      expect(target.figure, HandoffFigure.mommy);
    });

    test('cache keys are stable and per-figure', () {
      const url = 'https://x/a.png';
      final a = LockMediaDefaults.imageCacheKey(HandoffFigure.maam, url);
      expect(a, LockMediaDefaults.imageCacheKey(HandoffFigure.maam, url));
      expect(
        a,
        isNot(LockMediaDefaults.imageCacheKey(HandoffFigure.sir, url)),
      );
      // A re-hosted artwork must not replay the old cached file.
      expect(
        a,
        isNot(LockMediaDefaults.imageCacheKey(
            HandoffFigure.maam, 'https://x/b.png')),
      );
    });
  });

  group('FSL clip URL', () {
    test('a Cloudinary animated GIF is rewritten to a playable MP4', () {
      // `video_player` cannot decode GIF; Cloudinary transcodes on
      // delivery when the extension is swapped on the image path.
      expect(
        MediaUrlResolver.asPlayableVideo(
          'https://res.cloudinary.com/lorjhyp9/image/upload/'
          'v1785480915/FSL_-_ALARM_f76t8l.gif',
        ),
        'https://res.cloudinary.com/lorjhyp9/image/upload/'
        'v1785480915/FSL_-_ALARM_f76t8l.mp4',
      );
    });

    test('every hand-off figure has its own playable signed clip', () {
      const urls = LockMediaDefaults.timesUpFslVideoUrls;
      // One clip per figure, all distinct — a copy/paste here would sign
      // the wrong adult at a deaf learner, who has no caption fallback
      // they can hear.
      expect(urls, hasLength(HandoffFigure.values.length));
      expect(urls.values.toSet(), hasLength(urls.length));
      for (final entry in urls.entries) {
        expect(entry.value, startsWith('https://res.cloudinary.com/'));
        // Shipped in playable form, and idempotent under normalisation.
        expect(entry.value, endsWith('.mp4'), reason: '${entry.key}');
        expect(
          MediaUrlResolver.asPlayableVideo(entry.value),
          entry.value,
          reason: '${entry.key}',
        );
      }
      // The clip table and the picture table cover the same four figures,
      // so the two faces of the card can never disagree about who.
      for (final figure in HandoffFigure.values) {
        expect(LockMediaDefaults.timesUpFslVideoUrl(figure), urls[figure]);
        expect(LockMediaDefaults.timesUpImageUrl(figure), isNotNull);
      }
      expect(LockMediaDefaults.timesUpFslVideoUrl(null), isNull);
    });

    test('the alarm clip is playable and distinct from every FSL clip', () {
      const url = LockMediaDefaults.timesUpAlarmClipUrl;
      expect(url, isNotEmpty);
      expect(url, endsWith('.mp4'));
      expect(MediaUrlResolver.asPlayableVideo(url), url);
      // It is an animated clock, not signing. Sharing a URL with the FSL
      // table would mean some learner is told a clock is sign language.
      expect(
        LockMediaDefaults.timesUpFslVideoUrls.values,
        isNot(contains(url)),
      );
    });

    test('leaves every other URL untouched', () {
      const untouched = [
        // Not a GIF.
        'https://res.cloudinary.com/lorjhyp9/image/upload/v1/clip.mp4',
        // A GIF, but not Cloudinary — no transcode to rely on.
        'https://i.postimg.cc/abc/animation.gif',
        // Cloudinary video-type delivery does not transcode a GIF upload.
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1/clip.gif',
        '',
        'not a url at all',
      ];
      for (final url in untouched) {
        expect(MediaUrlResolver.asPlayableVideo(url), url, reason: url);
      }
    });

    test('the cache key follows the URL so a re-host re-downloads', () {
      final gifKey = LockMediaDefaults.clipCacheKey('https://x/a.gif');
      final mp4Key = LockMediaDefaults.clipCacheKey('https://x/a.mp4');
      expect(gifKey, isNot(mp4Key));
      expect(gifKey, LockMediaDefaults.clipCacheKey('https://x/a.gif'));
    });

    test('each figure\'s clip gets its own cache slot', () {
      // The four clips share a slot prefix, so if the key stopped folding
      // in the URL every deaf learner would replay whichever figure's
      // clip happened to download first.
      final keys = LockMediaDefaults.timesUpFslVideoUrls.values
          .map(LockMediaDefaults.clipCacheKey)
          .toList();
      expect(keys.toSet(), hasLength(keys.length));
      expect(
        keys,
        isNot(contains(
          LockMediaDefaults.clipCacheKey(
            LockMediaDefaults.timesUpAlarmClipUrl,
          ),
        )),
      );
    });
  });

  group('LockPresentation', () {
    const settings = AppSettings();

    test('every accessibility profile resolves to a defined presentation',
        () {
      for (final type in DisabilityType.values) {
        final p = LockPresentation.forProfile(type, settings);
        // No profile may end up with zero ways of being told.
        final hasAChannel = p.playAlarmSound ||
            p.speakMessage ||
            p.showFslVideo ||
            p.visualAlert ||
            p.haptics;
        expect(hasAChannel, isTrue, reason: 'no channel for $type');
        expect(p.alarmRepeats, greaterThanOrEqualTo(1), reason: '$type');
        expect(p.minTouchTarget, greaterThanOrEqualTo(48), reason: '$type');
        expect(p.educatorSummary, isNotEmpty, reason: '$type');
      }
    });

    test('every profile gets a second face on the hand-off card', () {
      // Deafness is the only barrier the signed clip answers, so it is the
      // only profile that trades the alarm animation away for it.
      const signs = {DisabilityType.hearing};
      for (final type in DisabilityType.values) {
        final p = LockPresentation.forProfile(type, settings);
        expect(
          p.clip,
          signs.contains(type) ? LockClipKind.fsl : LockClipKind.alarm,
          reason: '$type',
        );
        // No learner is left with a dead card.
        expect(p.showClip, isTrue, reason: '$type');
        // `showFslVideo` must mean *sign language*, not "has a clip" —
        // the educator's clip-URL field and the PIN autofocus rule both
        // read it and would be wrong if the alarm counted.
        expect(p.showFslVideo, signs.contains(type), reason: '$type');
      }
    });

    test('every learner is led into the clip, with the picture one tap away',
        () {
      // Motion is what pulls a child's eye off the activity they were
      // mid-way through, so the lock opens on the clip for all six.
      for (final type in DisabilityType.values) {
        final p = LockPresentation.forProfile(type, settings);
        expect(p.clipFirst, isTrue, reason: '$type');
      }
      // …but the warning has no clip to lead with.
      expect(
        LockPresentation.forProfile(DisabilityType.none, settings)
            .warningVariant
            .clipFirst,
        isFalse,
      );
    });

    test('the educator summary names the actual opening face', () {
      final hearing =
          LockPresentation.forProfile(DisabilityType.hearing, settings)
              .educatorSummary;
      expect(hearing, contains(startsWith('FSL video first')));
      expect(hearing, isNot(contains(startsWith('Alarm animation'))));

      for (final type in DisabilityType.values.where(
        (t) => t != DisabilityType.hearing,
      )) {
        final summary =
            LockPresentation.forProfile(type, settings).educatorSummary;
        expect(
          summary,
          contains(startsWith('Alarm animation first')),
          reason: '$type',
        );
        // A parent must never be told a non-signing learner gets FSL.
        expect(summary.where((l) => l.contains('FSL')), isEmpty,
            reason: '$type');
      }
    });

    test('hearing profiles get the FSL clip and no speech', () {
      final p = LockPresentation.forProfile(DisabilityType.hearing, settings);
      expect(p.showFslVideo, isTrue);
      expect(p.clip, LockClipKind.fsl);
      expect(p.clipFirst, isTrue);
      expect(p.speakMessage, isFalse);
      // The chime stays on — it is aimed at the adult in the room.
      expect(p.playAlarmSound, isTrue);
      expect(p.haptics, isTrue);
      expect(p.visualAlert, isTrue);
    });

    test('visual profiles lead with audio and announce to the screen reader',
        () {
      final p = LockPresentation.forProfile(DisabilityType.visual, settings);
      expect(p.speakMessage, isTrue);
      expect(p.repeatSpokenMessage, isTrue);
      expect(p.announce, isTrue);
      expect(p.messageScale, greaterThan(1.0));
      expect(p.showFslVideo, isFalse);
    });

    test('motor profiles get the largest touch targets', () {
      final motor = LockPresentation.forProfile(DisabilityType.motor, settings);
      final none = LockPresentation.forProfile(DisabilityType.none, settings);
      expect(motor.minTouchTarget, greaterThan(none.minTouchTarget));
    });

    test('cognitive profiles get one chime, short wording, no flashing', () {
      final p = LockPresentation.forProfile(DisabilityType.cognitive, settings);
      expect(p.alarmRepeats, 1);
      expect(p.simplifiedWording, isTrue);
      expect(p.visualAlert, isFalse);
      expect(p.reduceMotion, isTrue);
    });

    test('multiple-disability profiles get speech plus the alarm animation',
        () {
      final p = LockPresentation.forProfile(DisabilityType.multiple, settings);
      expect(p.speakMessage, isTrue);
      expect(p.simplifiedWording, isTrue);
      // Not FSL: this category cannot assume signing fluency, and the
      // wordless clock reads for every combination of barriers in it.
      expect(p.clip, LockClipKind.alarm);
      expect(p.showFslVideo, isFalse);
      expect(p.showClip, isTrue);
    });

    test('hearing is the only profile that gets sign language', () {
      final signing = DisabilityType.values
          .where((t) => LockPresentation.forProfile(t, settings).showFslVideo)
          .toList();
      expect(signing, [DisabilityType.hearing]);
    });

    test('the learner\'s own settings override the profile default', () {
      const noTts = AppSettings(ttsEnabled: false);
      for (final type in DisabilityType.values) {
        final p = LockPresentation.forProfile(type, noTts);
        expect(p.speakMessage, isFalse, reason: '$type');
        expect(p.repeatSpokenMessage, isFalse, reason: '$type');
      }

      const reduced = AppSettings(reducedMotion: true);
      final hearing =
          LockPresentation.forProfile(DisabilityType.hearing, reduced);
      expect(hearing.visualAlert, isFalse);
      expect(hearing.reduceMotion, isTrue);
      // Losing the pulse must not leave a deaf learner with nothing:
      // the caption, the FSL clip and the haptic all remain.
      expect(hearing.showFslVideo, isTrue);
      expect(hearing.haptics, isTrue);
    });

    test('the visual-alert pulse stays out of the seizure-risk band', () {
      final p = LockPresentation.forProfile(DisabilityType.hearing, settings);
      // WCAG 2.3.1: nothing may flash faster than 3 Hz.
      expect(p.flashPeriod.inMilliseconds, greaterThanOrEqualTo(1000));
    });
  });

  group('LockPolicyDefaults', () {
    test('every profile has a usable recommended limit and window', () {
      for (final type in DisabilityType.values) {
        final minutes = LockPolicyDefaults.dailyMinutesFor(type);
        expect(minutes, inInclusiveRange(5, 240), reason: '$type');
        final (start, end) = LockPolicyDefaults.scheduleFor(type);
        expect(start, inInclusiveRange(0, 23), reason: '$type');
        expect(end, inInclusiveRange(0, 23), reason: '$type');
        expect(end, greaterThan(start), reason: '$type');
        expect(LockPolicyDefaults.rationaleFor(type), isNotEmpty);
      }
    });

    test('shorter sessions where attention or fatigue is the constraint', () {
      expect(
        LockPolicyDefaults.dailyMinutesFor(DisabilityType.cognitive),
        lessThan(LockPolicyDefaults.dailyMinutesFor(DisabilityType.none)),
      );
      expect(
        LockPolicyDefaults.dailyMinutesFor(DisabilityType.motor),
        lessThan(LockPolicyDefaults.dailyMinutesFor(DisabilityType.none)),
      );
    });
  });

  group('ChildTimeLimit serialisation', () {
    test('the hand-off fields round-trip', () {
      final limit = ChildTimeLimit(
        childProfileId: 'child-1',
        setterProfileId: 'teacher-1',
        setterRole: UserRole.teacher,
        dailyLimitEnabled: true,
        dailyLimitMinutes: 45,
        // Flipped off so the round-trip proves `false` survives — a bare
        // default would pass even if the field were dropped.
        alarmSoundEnabled: false,
        guardianPreferredName: 'Teacher Ana',
        guardianHonorific: "Ma'am",
        fslVideoUrl: 'https://example.test/fsl.mp4',
        updatedAt: DateTime(2026, 7, 31, 10),
      );
      final restored = ChildTimeLimit.fromJson(limit.toJson());
      expect(restored.alarmSoundEnabled, isFalse);
      expect(restored.voiceMessageEnabled, isTrue);
      expect(restored.guardianPreferredName, 'Teacher Ana');
      expect(restored.guardianHonorific, "Ma'am");
      expect(restored.fslVideoUrl, 'https://example.test/fsl.mp4');
      // Pre-existing fields are untouched by the addition.
      expect(restored.dailyLimitMinutes, 45);
      expect(restored.dailyLimitEnabled, isTrue);
    });

    test('documents written before the feature still announce', () {
      // Exactly the shape the old writer produced — no announcement keys.
      final legacy = ChildTimeLimit.fromJson(<String, dynamic>{
        'child_profile_id': 'child-1',
        'setter_profile_id': 'parent-1',
        'setter_role': UserRole.parent.index,
        'daily_limit_minutes': 60,
        'daily_limit_enabled': true,
        'schedule_enabled': false,
        'allowed_start_hour': 8,
        'allowed_end_hour': 20,
        'allowed_days': <int>[],
        'updated_at': '2026-01-01T00:00:00.000',
      });
      expect(legacy.alarmSoundEnabled, isTrue);
      expect(legacy.voiceMessageEnabled, isTrue);
      expect(legacy.guardianPreferredName, isEmpty);
      expect(legacy.guardianHonorific, isEmpty);
      expect(legacy.fslVideoUrl, isEmpty);
    });

    test('copyWith carries the new fields', () {
      final base = ChildTimeLimit.empty('child-1');
      final next = base.copyWith(
        guardianPreferredName: 'Dad',
        alarmSoundEnabled: false,
      );
      expect(next.guardianPreferredName, 'Dad');
      expect(next.alarmSoundEnabled, isFalse);
      expect(next.voiceMessageEnabled, isTrue);
    });
  });

  group('TimeUpLockScreen', () {
    testWidgets('announces the resolved hand-off message once', (tester) async {
      final announcer = RecordingAnnouncer();
      await _pumpLock(
        tester,
        announcer: announcer,
        child: _child(DisabilityType.none),
        limit: _limit(guardianHonorific: "Ma'am", role: UserRole.teacher),
      );

      // Nothing before the deliberate settle delay — the child should see
      // the screen before they hear it.
      expect(announcer.calls, isEmpty);

      await tester.pump(const Duration(milliseconds: 600));
      expect(announcer.calls, hasLength(1));
      expect(
        announcer.calls.single.message,
        "Time's up. Please give your device to Ma'am.",
      );

      // Further frames must not re-announce.
      await tester.pump(const Duration(seconds: 2));
      expect(announcer.calls, hasLength(1));

      await _drain(tester);
    });

    testWidgets('a preferred name replaces the honorific', (tester) async {
      final announcer = RecordingAnnouncer();
      await _pumpLock(
        tester,
        announcer: announcer,
        child: _child(DisabilityType.none),
        limit: _limit(
          guardianHonorific: "Ma'am",
          guardianPreferredName: 'Teacher Ana',
          role: UserRole.teacher,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        announcer.calls.single.message,
        "Time's up. Please give your device to Teacher Ana.",
      );
      expect(find.textContaining('Teacher Ana'), findsWidgets);
      await _drain(tester);
    });

    testWidgets('a parent limit says "return", a teacher limit says "give"',
        (tester) async {
      final parentAnnouncer = RecordingAnnouncer();
      await _pumpLock(
        tester,
        announcer: parentAnnouncer,
        child: _child(DisabilityType.none),
        limit: _limit(guardianHonorific: 'Daddy', role: UserRole.parent),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(parentAnnouncer.calls.single.message,
          "Time's up. Please return your device to Daddy.");
      await _drain(tester);
    });

    testWidgets('the educator switches are passed through', (tester) async {
      final announcer = RecordingAnnouncer();
      await _pumpLock(
        tester,
        announcer: announcer,
        child: _child(DisabilityType.none),
        limit: _limit(
          guardianHonorific: 'Daddy',
          role: UserRole.parent,
          alarmSoundEnabled: false,
          voiceMessageEnabled: false,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(announcer.calls.single.alarmEnabled, isFalse);
      expect(announcer.calls.single.voiceEnabled, isFalse);
      await _drain(tester);
    });

    testWidgets('cognitive profiles get the short sentence', (tester) async {
      final announcer = RecordingAnnouncer();
      await _pumpLock(
        tester,
        announcer: announcer,
        child: _child(DisabilityType.cognitive),
        limit: _limit(guardianHonorific: 'Mommy', role: UserRole.parent),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(announcer.calls.single.message,
          "Time's up. Give the tablet to Mommy.");
      expect(announcer.calls.single.presentation.alarmRepeats, 1);
      await _drain(tester);
    });

    testWidgets('every profile opens on the clip, picture one tap behind',
        (tester) async {
      // Only a deaf learner's clip may be *called* sign language. Telling
      // anyone else that an alarm clock is signing would mislead exactly
      // the learner who cannot check by listening.
      for (final entry in <DisabilityType, bool>{
        DisabilityType.hearing: true,
        DisabilityType.multiple: false,
        DisabilityType.none: false,
        DisabilityType.visual: false,
        DisabilityType.motor: false,
        DisabilityType.cognitive: false,
      }.entries) {
        await _pumpLock(
          tester,
          announcer: RecordingAnnouncer(),
          child: _child(entry.key),
          limit: _limit(guardianHonorific: 'Mommy', role: UserRole.parent),
          // `fslSource` defaults to null: the loader resolves nothing, so
          // this exercises the graceful "unavailable" path instead of
          // trying to decode a real video in the test binding.
        );
        await tester.pump(const Duration(milliseconds: 600));

        // The clip leads for everyone, so the prompt always points at the
        // picture — never back at the clip already on screen.
        expect(
          find.text('Tap to see the picture'),
          findsOneWidget,
          reason: '${entry.key} should open on the clip',
        );
        expect(
          find.textContaining('Tap to see the alarm'),
          findsNothing,
          reason: '${entry.key} is already showing the clip',
        );
        // Which clip it is comes through the screen-reader label.
        expect(
          find.bySemanticsLabel(RegExp('Sign-language video')).evaluate(),
          entry.value ? isNotEmpty : isEmpty,
          reason: '${entry.key} should '
              '${entry.value ? "" : "not "}name the sign-language clip',
        );
        expect(
          find.bySemanticsLabel(RegExp('Alarm clock animation')).evaluate(),
          entry.value ? isEmpty : isNotEmpty,
          reason: '${entry.key} alarm label',
        );
        await _drain(tester);
      }
    });

    testWidgets('each profile loads the clip its back face claims to show',
        (tester) async {
      // Deaf learners get the signed clip *for their own figure*; everyone
      // else gets the alarm animation.
      for (final figure in HandoffFigure.values) {
        final honorific = switch (figure) {
          HandoffFigure.maam => "Ma'am",
          HandoffFigure.sir => 'Sir',
          HandoffFigure.mommy => 'Mommy',
          HandoffFigure.daddy => 'Daddy',
        };
        final role = figure == HandoffFigure.maam || figure == HandoffFigure.sir
            ? UserRole.teacher
            : UserRole.parent;

        final deaf = <String>[];
        await _pumpLock(
          tester,
          announcer: RecordingAnnouncer(),
          child: _child(DisabilityType.hearing),
          limit: _limit(guardianHonorific: honorific, role: role),
          educators: const <UserProfile>[],
          requestedClips: deaf,
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          deaf,
          contains(LockMediaDefaults.timesUpFslVideoUrls[figure]),
          reason: 'a deaf learner handed to $honorific must see that sign',
        );
        await _drain(tester);

        final hearingLearner = <String>[];
        await _pumpLock(
          tester,
          announcer: RecordingAnnouncer(),
          child: _child(DisabilityType.none),
          limit: _limit(guardianHonorific: honorific, role: role),
          educators: const <UserProfile>[],
          requestedClips: hearingLearner,
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          hearingLearner,
          everyElement(LockMediaDefaults.timesUpAlarmClipUrl),
          reason: '$honorific / no accessibility need → alarm animation',
        );
        expect(hearingLearner, isNotEmpty);
        await _drain(tester);
      }
    });

    testWidgets('the educator\'s own clip overrides the signed default',
        (tester) async {
      final requested = <String>[];
      await _pumpLock(
        tester,
        announcer: RecordingAnnouncer(),
        child: _child(DisabilityType.hearing),
        limit: _limit(
          guardianHonorific: 'Mommy',
          role: UserRole.parent,
          fslVideoUrl: 'https://example.test/fsl.mp4',
        ),
        requestedClips: requested,
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(requested, contains('https://example.test/fsl.mp4'));
      expect(
        requested,
        isNot(contains(
          LockMediaDefaults.timesUpFslVideoUrls[HandoffFigure.mommy],
        )),
      );
      await _drain(tester);
    });

    testWidgets('a per-child clip pasted as a GIF is fetched as playable MP4',
        (tester) async {
      // The educator pastes whatever Cloudinary showed them. `video_player`
      // cannot decode GIF, so the rewrite has to happen before the cache
      // key is computed or the lock re-downloads on every appearance.
      final requested = <String>[];
      await _pumpLock(
        tester,
        announcer: RecordingAnnouncer(),
        child: _child(DisabilityType.hearing),
        limit: _limit(
          guardianHonorific: 'Mommy',
          role: UserRole.parent,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1/x.gif',
        ),
        requestedClips: requested,
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        requested,
        contains('https://res.cloudinary.com/lorjhyp9/image/upload/v1/x.mp4'),
      );
      await _drain(tester);
    });

    testWidgets('a deaf learner with no known figure falls back to the alarm',
        (tester) async {
      // Legacy educator avatar → no figure → no signed clip exists. The
      // card must still have something moving, and must not claim that
      // an alarm clock is sign language.
      final requested = <String>[];
      await _pumpLock(
        tester,
        announcer: RecordingAnnouncer(),
        child: _child(DisabilityType.hearing),
        limit: _limit(guardianHonorific: '', role: UserRole.parent),
        educators: const <UserProfile>[],
        requestedClips: requested,
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(requested, everyElement(LockMediaDefaults.timesUpAlarmClipUrl));
      expect(requested, isNotEmpty);
      expect(find.textContaining('sign-language'), findsNothing);
      await _drain(tester);
    });

    testWidgets('every profile gets the picture of who to hand it to',
        (tester) async {
      for (final type in DisabilityType.values) {
        await _pumpLock(
          tester,
          announcer: RecordingAnnouncer(),
          child: _child(type),
          limit: _limit(guardianHonorific: 'Mommy', role: UserRole.parent),
        );
        await tester.pump(const Duration(milliseconds: 600));

        // The resolver override returns null, so the picture face renders
        // its "couldn't fetch" icon — enough to prove the card is built for
        // this profile without decoding a real PNG in the test binding.
        //
        // Hearing leads with the clip, so there the picture is one tap away
        // rather than on screen; either counts as "this learner gets the
        // picture".
        final showing = find
            .byIcon(Icons.image_not_supported_rounded)
            .evaluate()
            .isNotEmpty;
        final oneTapAway =
            find.text('Tap to see the picture').evaluate().isNotEmpty;
        expect(
          showing || oneTapAway,
          isTrue,
          reason: '$type should show the hand-off picture',
        );
        await _drain(tester);
      }
    });

    testWidgets('the clip flips to the picture and back, both kinds',
        (tester) async {
      // clip → tap → picture → tap → clip, for the signed clip and for the
      // alarm animation, each labelled for what it actually is.
      for (final entry in <DisabilityType, String>{
        DisabilityType.hearing: 'Tap to see the sign-language video',
        DisabilityType.multiple: 'Tap to see the alarm',
        DisabilityType.none: 'Tap to see the alarm',
      }.entries) {
        await _pumpLock(
          tester,
          announcer: RecordingAnnouncer(),
          child: _child(entry.key),
          limit: _limit(guardianHonorific: 'Mommy', role: UserRole.parent),
        );
        await tester.pump(const Duration(milliseconds: 600));

        // Opens on the clip.
        expect(find.text('Tap to see the picture'), findsOneWidget,
            reason: '${entry.key} opens on the clip');

        // Tap → picture.
        await tester.tap(find.text('Tap to see the picture'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.text(entry.value), findsOneWidget,
            reason: '${entry.key} flipped to the picture');

        // Tap → back to the clip.
        await tester.tap(find.text(entry.value));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.text('Tap to see the picture'), findsOneWidget,
            reason: '${entry.key} flipped back to the clip');

        await _drain(tester);
      }
    });

    testWidgets('a learner whose educator has no matching artwork still locks',
        (tester) async {
      await _pumpLock(
        tester,
        announcer: RecordingAnnouncer(),
        child: _child(DisabilityType.none),
        // An educator left on a legacy animal avatar: no honorific maps to
        // a picture, so the card has only the alarm face and nothing to
        // flip to.
        limit: _limit(guardianHonorific: '', role: UserRole.parent),
        educators: const <UserProfile>[],
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byIcon(Icons.image_not_supported_rounded), findsNothing);
      expect(find.textContaining('sign-language'), findsNothing);
      // No picture to turn to, so no flip prompt is offered.
      expect(find.textContaining('Tap to see'), findsNothing);
      // The written hand-off line still carries the message.
      expect(find.textContaining('Time\'s up.'), findsWidgets);
      await _drain(tester);
    });

    testWidgets('"Switch account" is always offered and never unlocks',
        (tester) async {
      final announcer = RecordingAnnouncer();
      await _pumpLock(
        tester,
        announcer: announcer,
        child: _child(DisabilityType.motor),
        limit: _limit(guardianHonorific: 'Sir', role: UserRole.teacher),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Pinned below the scroll area, so it is on screen from the first
      // frame — no drag needed. `tap` would throw if it weren't hit-testable.
      expect(find.text('Switch account'), findsOneWidget);
      await tester.tap(find.text('Switch account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Routed to the switcher, and the announcement was silenced so a
      // voice doesn't trail onto the next screen.
      expect(find.text('SWITCHER'), findsOneWidget);
      expect(announcer.stopCount, greaterThanOrEqualTo(1));
      await _drain(tester);
    });

    testWidgets('no educator linked still leaves a way to hand over',
        (tester) async {
      await _pumpLock(
        tester,
        announcer: RecordingAnnouncer(),
        child: _child(DisabilityType.none),
        limit: _limit(guardianHonorific: 'Mommy', role: UserRole.parent),
        educators: const <UserProfile>[],
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('No parent or teacher is linked'),
          findsOneWidget);
      expect(find.text('Switch account'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('"Switch account" needs no scrolling, even at 2x text on a '
        'small phone', (tester) async {
      // The regression this pins: the lock's content is genuinely taller
      // than a 360×640 viewport once the font scale is turned up, so a
      // "Switch account" that lived at the end of the ListView was only
      // reachable by an awkward drag — on the one control a child uses to
      // hand the device on without an adult.
      for (final device in kTabletMatrix.where(
        (d) => d.label.startsWith('phone'),
      )) {
        for (final scale in kTextScales) {
          for (final type in DisabilityType.values) {
            tester.view.physicalSize = device.size * device.devicePixelRatio;
            tester.view.devicePixelRatio = device.devicePixelRatio;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await _pumpLock(
              tester,
              announcer: RecordingAnnouncer(),
              child: _child(type),
              limit: _limit(guardianHonorific: 'Mommy', role: UserRole.parent),
              textScale: scale,
            );
            await tester.pump(const Duration(milliseconds: 600));

            final where = '$type on ${device.label} at ${scale}x';
            final button = find.widgetWithText(
              OutlinedButton,
              'Switch account',
            );
            expect(button, findsOneWidget, reason: where);

            // Fully inside the viewport — not merely laid out somewhere
            // below the fold.
            final rect = tester.getRect(button);
            expect(rect.top, greaterThanOrEqualTo(0.0), reason: where);
            expect(
              rect.bottom,
              lessThanOrEqualTo(device.size.height + 0.5),
              reason: where,
            );

            // And actually tappable where it sits. `tap` fails the test if
            // the hit test lands on a different widget.
            await tester.tap(button);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            expect(find.text('SWITCHER'), findsOneWidget, reason: where);

            await _drain(tester);
          }
        }
      }
    });

    testWidgets('lays out without overflow across profiles and font scales',
        (tester) async {
      for (final type in DisabilityType.values) {
        for (final device in kTabletMatrix) {
          for (final scale in kTextScales) {
            tester.view.physicalSize = device.size * device.devicePixelRatio;
            tester.view.devicePixelRatio = device.devicePixelRatio;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await _pumpLock(
              tester,
              announcer: RecordingAnnouncer(),
              child: _child(type),
              limit: _limit(guardianHonorific: 'Mommy', role: UserRole.parent),
              textScale: scale,
            );
            await tester.pump(const Duration(milliseconds: 600));

            expect(
              tester.takeException(),
              isNull,
              reason: '$type on ${device.label} at ${scale}x overflowed',
            );
            await _drain(tester);
          }
        }
      }
    });
  });

  group('ChildTimeLimitsScreen', () {
    testWidgets('shows the learner\'s profile and what the lock will do',
        (tester) async {
      await _pumpEditor(tester, child: _child(DisabilityType.hearing));
      await tester.pump();

      expect(find.text(DisabilityType.hearing.profileTypeLabel),
          findsOneWidget);
      // The resolved channels, not a generic description.
      expect(find.textContaining('FSL video'), findsWidgets);
      expect(find.textContaining('Switch account'), findsWidgets);
      // The recommended limit for this profile is offered by value.
      expect(
        find.textContaining(
          '${LockPolicyDefaults.dailyMinutesFor(DisabilityType.hearing)} min/day',
        ),
        findsOneWidget,
      );
    });

    testWidgets('applying the recommended settings fills the limit',
        (tester) async {
      await _pumpEditor(tester, child: _child(DisabilityType.cognitive));
      await tester.pump();

      await tester.tap(find.textContaining('Use recommended'));
      await tester.pump();

      final minutes =
          LockPolicyDefaults.dailyMinutesFor(DisabilityType.cognitive);
      expect(find.text('$minutes minutes per day'), findsOneWidget);
      // A Save action appears because the draft is now dirty.
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('the preview shows the exact sentence the child will hear',
        (tester) async {
      await _pumpEditor(
        tester,
        child: _child(DisabilityType.none),
        // A mother avatar on a parent profile ⇒ "Mommy".
        me: _educator(),
      );
      await _scrollToHandoffSection(tester);

      expect(
        find.textContaining('Please return your device to Mommy'),
        findsOneWidget,
      );
      expect(find.textContaining('Leave blank to use "Mommy"'),
          findsOneWidget);
    });

    testWidgets('a preferred name replaces the honorific in the preview',
        (tester) async {
      await _pumpEditor(
        tester,
        child: _child(DisabilityType.none),
        me: _educator(),
      );
      await _scrollToHandoffSection(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'What should the child call you?'),
        'Nanay Bebang',
      );
      await tester.pump();

      expect(
        find.textContaining('Please return your device to Nanay Bebang'),
        findsOneWidget,
      );
    });
  });
}

// ─── Fixtures ────────────────────────────────────────────────

UserProfile _child(DisabilityType type) => UserProfile(
      id: 'child-1',
      name: 'Test Learner',
      role: UserRole.child,
      disabilityType: type,
      createdAt: DateTime(2026),
    );

UserProfile _educator() => UserProfile(
      id: 'parent-1',
      name: 'Test Parent',
      role: UserRole.parent,
      avatarIndex: GuardianAddress.avatarMother,
      createdAt: DateTime(2026),
    );

ChildTimeLimit _limit({
  required String guardianHonorific,
  required UserRole role,
  String guardianPreferredName = '',
  String fslVideoUrl = '',
  bool alarmSoundEnabled = true,
  bool voiceMessageEnabled = true,
}) =>
    ChildTimeLimit(
      childProfileId: 'child-1',
      setterProfileId: 'parent-1',
      setterRole: role,
      dailyLimitEnabled: true,
      dailyLimitMinutes: 30,
      guardianHonorific: guardianHonorific,
      guardianPreferredName: guardianPreferredName,
      fslVideoUrl: fslVideoUrl,
      alarmSoundEnabled: alarmSoundEnabled,
      voiceMessageEnabled: voiceMessageEnabled,
      updatedAt: DateTime(2026, 7, 31),
    );

/// Mounts [TimeUpLockScreen] behind a real GoRouter (so "Switch account"
/// can be tapped) with every Firestore- and Hive-backed provider stubbed.
Future<void> _pumpLock(
  WidgetTester tester, {
  required RecordingAnnouncer announcer,
  required UserProfile child,
  required ChildTimeLimit limit,
  List<UserProfile>? educators,
  VideoSource? fslSource,
  double textScale = 1.0,
  List<String>? requestedClips,
}) async {
  final router = GoRouter(
    initialLocation: '/time-up-lock',
    routes: [
      GoRoute(
        path: '/time-up-lock',
        builder: (_, _) => const TimeUpLockScreen(),
      ),
      GoRoute(
        path: '/profile-switcher',
        builder: (_, _) => const Scaffold(body: Text('SWITCHER')),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(() => FixedProfile(child)),
        settingsProvider.overrideWith(() => FixedSettings(const AppSettings())),
        lockAnnouncerProvider.overrideWithValue(announcer),
        // Records what the screen actually asked for, so a test can assert
        // *which* clip a profile resolved to rather than only that some
        // clip appeared.
        lockFslVideoLoaderProvider.overrideWithValue((
          url, {
          required cacheKey,
        }) async {
          requestedClips?.add(url);
          return fslSource;
        }),
        childTimeLimitProvider(child.id)
            .overrideWith((ref) => Stream.value(limit)),
        unlockingEducatorsProvider(child.id).overrideWith(
          (ref) async => educators ?? [_educator()],
        ),
        lockStateProvider(child.id).overrideWithValue(
          const TimeLimitReached(dailyLimitMinutes: 30, minutesUsed: 31),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Mounts the educator's [ChildTimeLimitsScreen] with the learner's
/// profile, the limit stream, and the announcer all stubbed.
Future<void> _pumpEditor(
  WidgetTester tester, {
  required UserProfile child,
  UserProfile? me,
  ChildTimeLimit? limit,
}) async {
  final educator = me ?? _educator();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(() => FixedProfile(educator)),
        settingsProvider.overrideWith(() => FixedSettings(const AppSettings())),
        lockAnnouncerProvider.overrideWithValue(RecordingAnnouncer()),
        managedChildProfileProvider(child.id).overrideWith((ref) async => child),
        childTimeLimitProvider(child.id).overrideWith(
          (ref) => Stream.value(limit),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ChildTimeLimitsScreen(
          childProfileId: child.id,
          childDisplayName: child.name,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Brings the "When time is up" section into view. The editor is a
/// `ListView`, so the hand-off controls below the schedule are not built
/// until they are scrolled to.
Future<void> _scrollToHandoffSection(WidgetTester tester) async {
  await tester.pump();
  await tester.dragUntilVisible(
    find.text('The child will hear'),
    find.byType(ListView),
    const Offset(0, -200),
  );
  await tester.pump();
}

/// Tears the tree down and lets pending timers finish, so a later test
/// doesn't inherit this one's announce timer.
Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}
