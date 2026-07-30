import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/accessibility_presets.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/ai_tutor/models/tutor_media_policy.dart';

/// Builds the policy the way the app does at runtime: from the accessibility
/// preset a learner of [type] would actually have applied.
TutorMediaPolicy policyFor(DisabilityType type, {UserRole? role}) =>
    TutorMediaPolicy.forLearner(
      type,
      role ?? UserRole.student,
      AccessibilityPresets.presetFor(type),
    );

void main() {
  group('TutorMediaPolicy — per-profile channels', () {
    test('Hearing gets pictures and signs, never audio', () {
      final p = policyFor(DisabilityType.hearing);
      expect(p.photo, isTrue);
      expect(p.sign, isTrue, reason: 'FSL is the primary path for a Deaf learner');
      expect(p.speak, isFalse, reason: 'the hearing preset turns TTS off');
    });

    test('Visual gets spoken prompts, and neither pictures nor signs', () {
      final p = policyFor(DisabilityType.visual);
      expect(p.photo, isFalse, reason: 'a photograph is not their channel');
      expect(p.sign, isFalse, reason: 'signs are visual too');
      expect(p.speak, isTrue);
    });

    test('Cognitive gets pictures but no signs', () {
      // FSL clips add confusion for this group — the app-wide content policy
      // already says so and this must not diverge from it.
      final p = policyFor(DisabilityType.cognitive);
      expect(p.photo, isTrue);
      expect(p.sign, isFalse);
    });

    test('Motor and multiple keep every alternative channel available', () {
      for (final type in [DisabilityType.motor, DisabilityType.multiple]) {
        final p = policyFor(type);
        expect(p.photo, isTrue, reason: '$type');
        expect(p.sign, isTrue, reason: '$type');
      }
    });

    test('a learner with no accessibility needs still gets picture + sign', () {
      final p = policyFor(DisabilityType.none);
      expect(p.photo, isTrue);
      expect(p.sign, isTrue);
    });
  });

  group('TutorMediaPolicy — role', () {
    test('a Child is auto-spoken to; a Student is not', () {
      // The Child persona already reads replies aloud; the prompt should match.
      // A Student keeps the manual "Listen" control instead of narration.
      final settings = AccessibilityPresets.presetFor(DisabilityType.none);
      final child = TutorMediaPolicy.forLearner(
          DisabilityType.none, UserRole.child, settings);
      final student = TutorMediaPolicy.forLearner(
          DisabilityType.none, UserRole.student, settings);
      expect(settings.ttsEnabled, isTrue, reason: 'precondition');
      expect(child.speak, isTrue);
      expect(student.speak, isFalse);
    });

    test('Text-to-Speech off silences the prompt for every role', () {
      final settings = AccessibilityPresets.presetFor(DisabilityType.hearing);
      expect(settings.ttsEnabled, isFalse, reason: 'precondition');
      for (final role in [UserRole.child, UserRole.student, UserRole.player]) {
        expect(
          TutorMediaPolicy.forLearner(DisabilityType.hearing, role, settings)
              .speak,
          isFalse,
          reason: '$role',
        );
      }
    });

    test('a null role (no active profile) is safe', () {
      final p = TutorMediaPolicy.forLearner(DisabilityType.none, null,
          AccessibilityPresets.presetFor(DisabilityType.none));
      expect(p.speak, isFalse);
      expect(p.photo, isTrue);
    });
  });

  group('TutorMediaPolicy — defaults', () {
    test('none adds nothing to the plain text question', () {
      expect(TutorMediaPolicy.none.isTextOnly, isTrue);
      expect(TutorMediaPolicy.none.photo, isFalse);
      expect(TutorMediaPolicy.none.sign, isFalse);
      expect(TutorMediaPolicy.none.speak, isFalse);
    });
  });
}
