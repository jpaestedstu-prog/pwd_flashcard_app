import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/game_catalog.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/multiplayer/models/multiplayer_models.dart';
import 'package:pwdpwdpwd/features/multiplayer/models/race_presentation.dart';

/// The accessibility matrix behind "Play Together".
///
/// Play Together is the one learner feature reachable from *both* Player
/// profiles and the six Student/Child accessibility categories, so the policy
/// has two jobs: adapt the race to each category, and leave the Player
/// experience exactly as it was.

const _defaults = AppSettings();

RacePresentation _for(DisabilityType t, [AppSettings s = _defaults]) =>
    RacePresentation.forProfile(t, s);

void main() {
  group('no accessibility category → nothing changes', () {
    test('matches the classic timed race', () {
      final p = _for(DisabilityType.none);
      expect(p.selfPaced, isFalse);
      expect(p.timeScoring, isTrue);
      expect(p.speakPrompts, isFalse);
      expect(p.bigTargets, isFalse);
      expect(p.rounds, RacePresentation.standard.rounds);
      expect(p.memoryPairs, RacePresentation.standard.memoryPairs);
      expect(p.modes, MpGameMode.values);
      expect(p.needsFairPlay, isFalse);
    });

    test('offers no adaptation note (nothing to explain)', () {
      expect(_for(DisabilityType.none).adaptationNote(isFilipino: false),
          isNull);
    });

    test('the standard policy is the same race', () {
      const s = RacePresentation.standard;
      expect(s.answerDelay, const Duration(milliseconds: 900));
      expect(s.flipBackDelay, const Duration(milliseconds: 700));
      expect(s.timeScoring, isTrue);
      expect(s.columnsFrom(4), 4);
    });
  });

  group('per-category adaptation', () {
    test('visual leads with audio and drops the clock', () {
      final p = _for(DisabilityType.visual);
      expect(p.speakPrompts, isTrue, reason: 'audio is the primary channel');
      expect(p.canSpeak, isTrue);
      expect(p.announce, isTrue);
      expect(p.bigTargets, isTrue);
      expect(p.selfPaced, isTrue, reason: 'listening takes as long as it takes');
      expect(p.timeScoring, isFalse);
    });

    test('hearing keeps the race a race, with haptics for the answer cue', () {
      final p = _for(DisabilityType.hearing);
      expect(p.timeScoring, isTrue, reason: 'nothing here depends on sound');
      expect(p.selfPaced, isFalse);
      expect(p.haptics, isTrue);
      expect(p.speakPrompts, isFalse);
      expect(p.canSpeak, isFalse, reason: 'never narrate to a deaf learner');
      expect(p.modes, MpGameMode.values);
    });

    test('hearing still gets haptics with sound effects switched off', () {
      final p = _for(
        DisabilityType.hearing,
        const AppSettings(soundEffects: false),
      );
      expect(p.haptics, isTrue,
          reason: 'haptics substitute for sound, so they cannot follow it');
    });

    test('motor gets big targets, self-pacing and no speed bonus', () {
      final p = _for(DisabilityType.motor);
      expect(p.bigTargets, isTrue);
      expect(p.selfPaced, isTrue);
      expect(p.timeScoring, isFalse,
          reason: 'a stopwatch is not a fair tie-breaker here');
      expect(p.flipBackDelay.inMilliseconds, greaterThan(1000));
      expect(p.columnsFrom(4), 3, reason: 'one column fewer, bigger cards');
    });

    test('cognitive gets a shorter, calmer match', () {
      final p = _for(DisabilityType.cognitive);
      expect(p.rounds, lessThan(RacePresentation.standard.rounds));
      expect(p.memoryPairs, lessThan(RacePresentation.standard.memoryPairs));
      expect(p.selfPaced, isTrue);
      expect(p.timeScoring, isFalse);
      expect(p.answerDelay, Duration.zero);
    });

    test('multiple is the union of the supports', () {
      final p = _for(DisabilityType.multiple);
      expect(p.speakPrompts, isTrue);
      expect(p.haptics, isTrue);
      expect(p.announce, isTrue);
      expect(p.bigTargets, isTrue);
      expect(p.selfPaced, isTrue);
      expect(p.timeScoring, isFalse);
      expect(p.rounds, lessThan(RacePresentation.standard.rounds));
    });

    test('every category is offered at least three games', () {
      for (final t in DisabilityType.values) {
        expect(_for(t).modes.length, greaterThanOrEqualTo(3), reason: '$t');
      }
    });

    test('adapted categories explain themselves in both languages', () {
      for (final t in DisabilityType.values) {
        if (t == DisabilityType.none || t == DisabilityType.hearing) continue;
        expect(_for(t).adaptationNote(isFilipino: false), isNotNull,
            reason: '$t must say what it changed');
        expect(_for(t).adaptationNote(isFilipino: true), isNotNull,
            reason: '$t must say it in Filipino too');
      }
    });
  });

  group('the roster agrees with the single-player Games hub', () {
    // A learner should never meet a mini-game in Play Together that their own
    // Games tab already judged unsuitable for them.
    test('picture prompts are hidden from visual, as Picture-Word is', () {
      expect(GameCatalog.forCategory(DisabilityType.visual),
          isNot(contains(GameType.pictureWord)));
      expect(RacePresentation.modesFor(DisabilityType.visual),
          isNot(contains(MpGameMode.pictureRace)));
    });

    test('spelling is hidden from cognitive, as Spelling Bee is', () {
      expect(GameCatalog.forCategory(DisabilityType.cognitive),
          isNot(contains(GameType.spellingBee)));
      expect(RacePresentation.modesFor(DisabilityType.cognitive),
          isNot(contains(MpGameMode.scrambleRace)));
    });

    test('spelling is hidden from multiple, as Spelling Bee is', () {
      expect(GameCatalog.forCategory(DisabilityType.multiple),
          isNot(contains(GameType.spellingBee)));
      expect(RacePresentation.modesFor(DisabilityType.multiple),
          isNot(contains(MpGameMode.scrambleRace)));
    });

    test('hearing and motor keep the full roster', () {
      expect(RacePresentation.modesFor(DisabilityType.hearing),
          MpGameMode.values);
      expect(
          RacePresentation.modesFor(DisabilityType.motor), MpGameMode.values);
    });
  });

  group('settings still have the last word', () {
    test('Slow Motion takes the clock off for any learner who opts in', () {
      final p = _for(
        DisabilityType.none,
        const AppSettings(slowMotionEnabled: true),
      );
      expect(p.selfPaced, isTrue);
      expect(p.timeScoring, isFalse);
      expect(p.needsFairPlay, isTrue);
    });

    test('TTS off silences narration even for a visual profile', () {
      final p = _for(
        DisabilityType.visual,
        const AppSettings(ttsEnabled: false),
      );
      expect(p.speakPrompts, isFalse);
      expect(p.canSpeak, isFalse);
      // …but the rest of the accommodation stands.
      expect(p.bigTargets, isTrue);
      expect(p.timeScoring, isFalse);
    });
  });

  group('fair play is negotiated, not assumed', () {
    test('a learner who needs an untimed score flags it', () {
      expect(_for(DisabilityType.motor).needsFairPlay, isTrue);
      expect(_for(DisabilityType.none).needsFairPlay, isFalse);
    });

    test('withoutTimeScoring drops only the clock', () {
      final p = _for(DisabilityType.hearing).withoutTimeScoring();
      expect(p.timeScoring, isFalse);
      expect(p.haptics, isTrue);
      expect(p.rounds, 6);
      expect(p.modes, MpGameMode.values);
    });

    test('withoutTimeScoring is a no-op when the clock is already off', () {
      final p = _for(DisabilityType.motor);
      expect(identical(p.withoutTimeScoring(), p), isTrue);
    });

    test('the room carries the flag across the wire', () {
      final room = GameRoom(
        id: 'r1',
        hostProfileId: 'h',
        hostName: 'Host',
        hostUid: 'u',
        hostAvatarIndex: 0,
        invitedProfileId: 'g',
        mode: MpGameMode.quizRace,
        status: GameRoomStatus.waiting,
        rounds: 6,
        fairPlay: true,
        createdAt: DateTime(2026, 8, 14),
        updatedAt: DateTime(2026, 8, 14),
        ownerUid: 'u',
      );
      final back = GameRoom.fromJson(room.toJson());
      expect(back.fairPlay, isTrue);
    });

    test('a peer on an older build (no field) races the classic timed match',
        () {
      final json = <String, dynamic>{
        'id': 'r2',
        'host_profile_id': 'h',
        'mode': 'quizRace',
        'status': 'waiting',
        'rounds': 6,
      };
      expect(GameRoom.fromJson(json).fairPlay, isFalse);
    });
  });
}
