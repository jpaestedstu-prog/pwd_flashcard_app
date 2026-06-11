// Scoring tests spell out default values (base 2, window 20s, elapsed 0)
// on purpose so the arithmetic each case checks is self-documenting.
// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/live_session/models/live_session_models.dart';
import 'package:pwdpwdpwd/features/live_session/services/live_scoring.dart';

/// The scoring engine is the single source of truth for "award stars based on
/// the rules the educator configured". These tests pin every rule + their
/// interactions so the learner devices always agree.
void main() {
  group('LiveScoring.computeStars', () {
    test('an incorrect answer always earns 0, whatever the rules', () {
      const rules = LiveScoringRules(
        baseStars: 5,
        speedBonusMax: 5,
        firstCorrectBonus: 5,
      );
      expect(
        LiveScoring.computeStars(
          rules: rules,
          isCorrect: false,
          isFirstCorrect: true,
          elapsedMs: 0,
        ),
        0,
      );
    });

    test('base stars only when no bonuses are configured', () {
      const rules = LiveScoringRules(baseStars: 3);
      expect(
        LiveScoring.computeStars(
          rules: rules,
          isCorrect: true,
          elapsedMs: 999999,
        ),
        3,
      );
    });

    test('activity points override the base', () {
      const rules = LiveScoringRules(baseStars: 2);
      expect(
        LiveScoring.computeStars(
          rules: rules,
          isCorrect: true,
          activityPoints: 7,
        ),
        7,
      );
    });

    group('speed bonus (linear decay)', () {
      const rules = LiveScoringRules(
        baseStars: 2,
        speedBonusMax: 4,
        speedWindowSec: 20,
      );

      test('instant answer earns the full bonus', () {
        expect(
          LiveScoring.computeStars(rules: rules, isCorrect: true, elapsedMs: 0),
          2 + 4,
        );
      });

      test('quarter-window answer earns 75% of the bonus', () {
        // 5s of a 20s window → fraction 0.75 → 4 * 0.75 = 3.
        expect(
          LiveScoring.computeStars(
            rules: rules,
            isCorrect: true,
            elapsedMs: 5000,
          ),
          2 + 3,
        );
      });

      test('answering at/after the window earns no bonus', () {
        expect(
          LiveScoring.computeStars(
            rules: rules,
            isCorrect: true,
            elapsedMs: 20000,
          ),
          2,
        );
        expect(
          LiveScoring.computeStars(
            rules: rules,
            isCorrect: true,
            elapsedMs: 40000,
          ),
          2,
        );
      });
    });

    group('first-correct bonus', () {
      const rules = LiveScoringRules(baseStars: 2, firstCorrectBonus: 3);

      test('added only when isFirstCorrect is true', () {
        expect(
          LiveScoring.computeStars(
            rules: rules,
            isCorrect: true,
            isFirstCorrect: true,
          ),
          2 + 3,
        );
        expect(
          LiveScoring.computeStars(
            rules: rules,
            isCorrect: true,
          ),
          2,
        );
      });

      test('disabled when the bonus is 0', () {
        const noBonus = LiveScoringRules(baseStars: 2);
        expect(
          LiveScoring.computeStars(
            rules: noBonus,
            isCorrect: true,
            isFirstCorrect: true,
          ),
          2,
        );
      });
    });

    group('per-session cap', () {
      test('clamps a single award to the remaining cap', () {
        const rules = LiveScoringRules(baseStars: 10, sessionCap: 5);
        expect(
          LiveScoring.computeStars(rules: rules, isCorrect: true),
          5,
        );
      });

      test('returns 0 once the cap is already reached', () {
        const rules = LiveScoringRules(baseStars: 10, sessionCap: 5);
        expect(
          LiveScoring.computeStars(
            rules: rules,
            isCorrect: true,
            alreadyEarnedThisSession: 5,
          ),
          0,
        );
      });

      test('caps the combined base + bonuses total', () {
        const rules = LiveScoringRules(
          baseStars: 2,
          speedBonusMax: 4,
          speedWindowSec: 20,
          sessionCap: 5,
        );
        // base 2 + full speed 4 = 6, clamped to remaining 5.
        expect(
          LiveScoring.computeStars(
            rules: rules,
            isCorrect: true,
            elapsedMs: 0,
          ),
          5,
        );
      });

      test('cap of 0 means unlimited', () {
        const rules = LiveScoringRules(baseStars: 8);
        expect(
          LiveScoring.computeStars(
            rules: rules,
            isCorrect: true,
            alreadyEarnedThisSession: 100,
          ),
          8,
        );
      });
    });
  });
}
