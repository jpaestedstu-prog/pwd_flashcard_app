import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/motion.dart';
import 'package:pwdpwdpwd/data/local/daily_challenge.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/models.dart';

void main() {
  group('AppSettings — learning-mode fields', () {
    test('defaults: slow-motion off, mission size 4, assist on', () {
      const s = AppSettings();
      expect(s.slowMotionEnabled, false);
      expect(s.dailyMissionSize, 4);
      expect(s.learningAssistEnabled, true);
    });

    test('copyWith sets new fields without disturbing others', () {
      const s = AppSettings();
      final u = s.copyWith(
        slowMotionEnabled: true,
        dailyMissionSize: 5,
        learningAssistEnabled: false,
      );
      expect(u.slowMotionEnabled, true);
      expect(u.dailyMissionSize, 5);
      expect(u.learningAssistEnabled, false);
      // Untouched fields preserved.
      expect(u.fontScale, 1.0);
      expect(u.reducedMotion, false);
      expect(u.ttsSpeed, 0.5);
    });
  });

  group('Motion — slow-motion multiplier', () {
    const full = Duration(milliseconds: 400);

    test('no flags → full duration', () {
      const m = Motion(reducedMotion: false);
      expect(m.duration(full), full);
      expect(m.optional(full), full);
    });

    test('slow-motion → ~2× duration', () {
      const m = Motion(reducedMotion: false, slowMotion: true);
      expect(m.duration(full), full * Motion.slowFactor);
      expect(m.optional(full), full * Motion.slowFactor);
    });

    test('reduced-motion takes priority over slow-motion', () {
      const m = Motion(reducedMotion: true, slowMotion: true);
      // Capped, never stretched.
      expect(m.duration(full), Motion.reducedCap);
      expect(m.optional(full), Duration.zero);
    });

    test('reduced-motion keeps already-short durations', () {
      const m = Motion(reducedMotion: true);
      const short = Duration(milliseconds: 50);
      expect(m.duration(short), short);
    });
  });

  group('DailyChallenge — Daily Mission', () {
    test('todaysWords returns the requested count of distinct cards', () {
      final words = DailyChallenge.todaysWords(4);
      expect(words.length, 4);
      expect(words.map((w) => w.id).toSet().length, 4); // all distinct
    });

    test('todaysWords is deterministic within the same day', () {
      final a = DailyChallenge.todaysWords(5).map((w) => w.id).toList();
      final b = DailyChallenge.todaysWords(5).map((w) => w.id).toList();
      expect(a, b);
    });

    test('todaysWords clamps to the available pool and handles 0', () {
      final big = DailyChallenge.todaysWords(100000);
      expect(big.length, SeedData.allFlashcards.length);
      expect(DailyChallenge.todaysWords(0), isEmpty);
    });

    test('generateChoices(count: 4) yields 4 options incl. the answer', () {
      final card = SeedData.allFlashcards.first;
      final choices = DailyChallenge.generateChoices(card, count: 4);
      expect(choices.length, 4);
      expect(choices, contains(card.wordFilipino));
    });

    test('distractors never duplicate the correct Filipino word', () {
      // So a 50/50 hint can always remove two genuinely wrong options.
      for (final card in SeedData.allFlashcards.take(25)) {
        final choices = DailyChallenge.generateChoices(card, count: 4);
        final wrong =
            choices.where((c) => c != card.wordFilipino).toList();
        expect(wrong.length, greaterThanOrEqualTo(2),
            reason: 'need ≥2 wrong options for a 50/50 on ${card.id}');
      }
    });

    test('generateChoices default count stays 3 (back-compat)', () {
      final card = SeedData.allFlashcards.first;
      expect(DailyChallenge.generateChoices(card).length, 3);
    });
  });
}
