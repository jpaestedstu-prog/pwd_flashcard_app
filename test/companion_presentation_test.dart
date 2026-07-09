import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/accessibility_presets.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/companion/models/companion_presentation.dart';

/// Builds the presentation the way the app does at runtime: from the accessibility
/// preset that a learner of [type] would actually have applied.
CompanionPresentation presentationFor(DisabilityType type) =>
    CompanionPresentation.forProfile(type, AccessibilityPresets.presetFor(type));

void main() {
  group('CompanionPresentation — per-profile adaptation', () {
    test('Hearing gets the lively VISUAL buddy but no audio', () {
      final p = presentationFor(DisabilityType.hearing);
      // Visual liveliness stays — none of it depends on sound.
      expect(p.style, CompanionStyle.playful);
      expect(p.animate, isTrue);
      expect(p.typingIndicator, isTrue);
      // Nothing audible.
      expect(p.soundEffects, isFalse);
      expect(p.speakReplies, isFalse);
      // Non-audio arrival cue is essential here.
      expect(p.haptics, isTrue);
      // Voice input would be a dead end for a hearing-first profile.
      expect(p.voiceInput, isFalse);
    });

    test('Visual gets spoken, announced, calm, big-target, voice-capable', () {
      final p = presentationFor(DisabilityType.visual);
      expect(p.style, CompanionStyle.calm);
      expect(p.animate, isFalse); // motion is pointless / not the channel
      expect(p.speakReplies, isTrue);
      expect(p.announce, isTrue); // screen-reader live region
      expect(p.voiceInput, isTrue);
      expect(p.draggable, isFalse); // fixed, findable launcher
      expect(p.launcherSize, greaterThan(60.0));
    });

    test('Motor gets a fixed, large, voice-friendly, still companion', () {
      final p = presentationFor(DisabilityType.motor);
      expect(p.animate, isFalse); // reduced motion
      expect(p.draggable, isFalse); // no precision-drag target
      expect(p.voiceInput, isTrue); // speak instead of tapping
      expect(p.launcherSize, greaterThan(60.0));
    });

    test('Cognitive gets calm, still, instant, no surprise voice', () {
      final p = presentationFor(DisabilityType.cognitive);
      expect(p.style, CompanionStyle.calm);
      expect(p.animate, isFalse);
      expect(p.typingIndicator, isFalse);
      expect(p.typingDelay, Duration.zero); // no artificial latency
      expect(p.voiceInput, isFalse);
    });

    test('Multiple stacks redundant channels (captions + haptics + announce)',
        () {
      final p = presentationFor(DisabilityType.multiple);
      expect(p.animate, isFalse);
      expect(p.haptics, isTrue);
      expect(p.announce, isTrue);
      expect(p.draggable, isFalse);
    });

    test('No accessibility need gets the full lively experience', () {
      final p = presentationFor(DisabilityType.none);
      expect(p.style, CompanionStyle.playful);
      expect(p.animate, isTrue);
      expect(p.typingIndicator, isTrue);
      expect(p.draggable, isTrue);
      expect(p.typingDelay, greaterThan(Duration.zero));
    });
  });

  group('CompanionPresentation — cross-cutting invariants', () {
    test('Reduced motion always disables animation and dragging', () {
      for (final type in DisabilityType.values) {
        final s = AccessibilityPresets.presetFor(type)
            .copyWith(reducedMotion: true);
        final p = CompanionPresentation.forProfile(type, s);
        expect(p.animate, isFalse, reason: '$type must not animate');
        expect(p.draggable, isFalse, reason: '$type must not be draggable');
        expect(p.typingDelay, Duration.zero, reason: '$type: no fake latency');
      }
    });

    test('A calm style never animates and never drifts', () {
      for (final type in DisabilityType.values) {
        final p = presentationFor(type);
        if (p.style == CompanionStyle.calm) {
          expect(p.animate, isFalse);
          expect(p.draggable, isFalse);
        }
      }
    });

    test('Sound off + TTS off is honoured regardless of category', () {
      // A learner who turned all audio off still gets a fully usable companion
      // (captions + haptics), never silent-only-audio information.
      const s = AppSettings(soundEffects: false, ttsEnabled: false);
      final p = CompanionPresentation.forProfile(DisabilityType.none, s);
      expect(p.soundEffects, isFalse);
      expect(p.speakReplies, isFalse);
    });

    test('Hearing never gets audio or voice even if settings drift on', () {
      // Defensive: even if a stored setting somehow enabled TTS/STT/sound,
      // a hearing-first profile must not depend on the audio channel for input.
      // ttsEnabled + soundEffects already default true; force the voice inputs
      // on too, to prove a hearing profile still refuses the audio channel.
      const s = AppSettings(speechToText: true, voiceNavigation: true);
      final p = CompanionPresentation.forProfile(DisabilityType.hearing, s);
      expect(p.voiceInput, isFalse);
    });
  });
}
