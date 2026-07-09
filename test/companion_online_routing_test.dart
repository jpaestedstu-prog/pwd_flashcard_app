import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/tutor_engine.dart';

/// The companion only routes a question to the optional online model when
/// [TutorEngine.isFreeForm] is true. This pins that boundary so structured,
/// interactive help never silently leaves the offline engine.
void main() {
  group('TutorEngine.isFreeForm — online routing boundary', () {
    test('structured / interactive intents stay on the offline engine', () {
      const structured = [
        'give me a quiz',
        'test me',
        'lesson please',
        "what's today's lesson",
        'I want to practice',
        'can I review',
        'show my progress',
        'what is my score',
        'can I get a hint',
        'help me',
        'favorites',
        'I like animals', // liking + category
        'tell me about animals', // category mention
        'gusto ko ng mga hayop', // Filipino category mention
      ];
      for (final q in structured) {
        expect(TutorEngine.isFreeForm(q), isFalse, reason: q);
      }
    });

    test('open-ended questions are eligible for the online model', () {
      // NB: matching is substring-based to stay identical to the engine's own
      // routing (e.g. "airplanes" contains "plan" → the engine treats it as a
      // lesson-plan request, so it is deliberately NOT free-form).
      const openEnded = [
        'why is the sky blue?',
        'how do rainbows appear',
        'what is a volcano',
        'tell me a fun thing',
      ];
      for (final q in openEnded) {
        expect(TutorEngine.isFreeForm(q), isTrue, reason: q);
      }
    });
  });
}
