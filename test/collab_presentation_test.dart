import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/accessibility_content_policy.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/peer_collaboration/models/collab_models.dart';
import 'package:pwdpwdpwd/features/peer_collaboration/models/collab_presentation.dart';

/// The adaptive matrix for Peer Collab, the same way `RacePresentation` is
/// tested: the policy is pure, so every accessibility category can be asserted
/// without building a widget.
///
/// Peer Collab previously looked and scored identically for all six categories,
/// which made the one feature named for including a peer the least adapted
/// learner surface in the app.
///
/// The picker's "Set up for you: …" line is built by the screen from
/// [CollabPresentation.adaptations]; this class stays pure and has no
/// `AppLocalizations`, so what is asserted here is the *reasons*, not the
/// sentence.
const _defaults = AppSettings();

CollabPresentation _for(DisabilityType type, [AppSettings s = _defaults]) =>
    CollabPresentation.forProfile(type, s);

void main() {
  group('Every learner gets something playable', () {
    for (final type in DisabilityType.values) {
      test('$type has a non-empty roster including Story Builder', () {
        final p = _for(type);
        expect(p.activities, isNotEmpty);
        expect(
          p.activities,
          contains(CollabActivityType.storyBuilder),
          reason: 'the open activity needs no sight, sound, sign or spelling',
        );
      });

      test('$type can answer by tapping', () {
        // The core promise of the rewrite: free text is never the *only* way
        // in, because a gaze or switch learner cannot produce it.
        expect(_for(type).tapToSelect, isTrue);
      });

      test('$type offers at least two answer choices', () {
        expect(_for(type).choiceCount, greaterThanOrEqualTo(2));
      });

      test('$type never disagrees with the app-wide FSL policy', () {
        expect(
          _for(type).showFsl,
          AccessibilityContentPolicy.forType(type).showFsl,
          reason: 'delegated, never re-derived',
        );
      });

      test('$type only offers Sign Challenge when it signs', () {
        final p = _for(type);
        if (p.activities.contains(CollabActivityType.signChallenge)) {
          expect(p.showFsl, isTrue,
              reason: 'an activity built on clips this learner cannot use');
        }
      });
    }
  });

  group('Per category', () {
    test('visual leans on audio and drops the two visual activities', () {
      final p = _for(DisabilityType.visual);
      expect(p.activities, isNot(contains(CollabActivityType.pictureGuess)));
      expect(p.activities, isNot(contains(CollabActivityType.signChallenge)));
      expect(p.showPictures, isFalse);
      expect(p.speakPrompts, isTrue);
      expect(p.announce, isTrue);
      expect(p.bigTargets, isTrue);
    });

    test('hearing keeps the full roster and never narrates', () {
      final p = _for(DisabilityType.hearing);
      expect(p.activities, CollabActivityType.values);
      expect(p.showFsl, isTrue);
      expect(p.canSpeak, isFalse, reason: 'TTS is not this learner\'s channel');
      expect(p.speakPrompts, isFalse);
    });

    test('hearing keeps haptics even with sound effects off', () {
      final p = _for(
        DisabilityType.hearing,
        const AppSettings(soundEffects: false),
      );
      expect(p.haptics, isTrue,
          reason: 'touch carries the cue others get from audio');
    });

    test('motor never needs the keyboard, and keeps every activity', () {
      final p = _for(DisabilityType.motor);
      expect(p.allowFreeText, isFalse);
      expect(p.bigTargets, isTrue);
      expect(p.activities, CollabActivityType.values,
          reason: 'every activity has a tap surface now');
    });

    test('cognitive is shorter, simpler, and drops spelling', () {
      final p = _for(DisabilityType.cognitive);
      expect(p.activities, isNot(contains(CollabActivityType.wordRelay)));
      expect(p.activities, isNot(contains(CollabActivityType.signChallenge)));
      expect(p.rounds, lessThan(CollabPresentation.standard.rounds));
      expect(p.choiceCount, lessThan(CollabPresentation.standard.choiceCount));
      expect(p.allowFreeText, isFalse);
    });

    test('multiple is the union of the motor and cognitive limits', () {
      final multiple = _for(DisabilityType.multiple);
      final motor = _for(DisabilityType.motor);
      final cognitive = _for(DisabilityType.cognitive);

      expect(multiple.allowFreeText, isFalse);
      expect(multiple.bigTargets, motor.bigTargets);
      expect(multiple.rounds, cognitive.rounds);
      expect(multiple.choiceCount, cognitive.choiceCount);
      for (final activity in multiple.activities) {
        expect(cognitive.activities, contains(activity),
            reason: 'never wider than the stricter half');
      }
    });

    test('none is the unchanged full experience', () {
      final p = _for(DisabilityType.none);
      expect(p.activities, CollabActivityType.values);
      expect(p.allowFreeText, isTrue);
      expect(p.rounds, CollabPresentation.standard.rounds);
      expect(p.choiceCount, CollabPresentation.standard.choiceCount);
      expect(p.bigTargets, isFalse);
      expect(p.showPictures, isTrue);
    });
  });

  group('Learner settings still apply', () {
    test('TTS off silences narration everywhere', () {
      for (final type in DisabilityType.values) {
        final p = _for(type, const AppSettings(ttsEnabled: false));
        expect(p.canSpeak, isFalse, reason: '$type');
        expect(p.speakPrompts, isFalse, reason: '$type');
      }
    });
  });

  group('The adaptation is visible', () {
    test('an unadapted learner is told nothing', () {
      expect(_for(DisabilityType.none).adaptations, isEmpty);
    });

    test('an adapted learner is told what changed', () {
      for (final type in const [
        DisabilityType.visual,
        DisabilityType.motor,
        DisabilityType.cognitive,
        DisabilityType.multiple,
      ]) {
        expect(_for(type).adaptations, isNotEmpty, reason: '$type');
      }
    });

    test('each reason matches the flag it reports', () {
      for (final type in DisabilityType.values) {
        final p = _for(type);
        expect(
          p.adaptations.contains(CollabAdaptation.tapToAnswer),
          !p.allowFreeText,
          reason: '$type',
        );
        expect(
          p.adaptations.contains(CollabAdaptation.readAloud),
          p.speakPrompts,
          reason: '$type',
        );
        expect(
          p.adaptations.contains(CollabAdaptation.biggerButtons),
          p.bigTargets,
          reason: '$type',
        );
        expect(
          p.adaptations.contains(CollabAdaptation.shorterSession),
          p.rounds < CollabPresentation.standard.rounds,
          reason: '$type',
        );
      }
    });
  });
}
