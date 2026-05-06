import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/spaced_repetition_service.dart';

void main() {
  group('WordAccuracy', () {
    test('initial accuracy is zero', () {
      final wa = WordAccuracy(
        wordId: 'test',
        lastSeen: DateTime.now(),
      );
      expect(wa.accuracy, 0.0);
      expect(wa.correct, 0);
      expect(wa.total, 0);
    });

    test('accuracy calculated correctly', () {
      final wa = WordAccuracy(
        wordId: 'test',
        correct: 3,
        total: 4,
        lastSeen: DateTime.now(),
      );
      expect(wa.accuracy, 0.75);
    });

    test('recordAttempt increments correctly on correct answer', () {
      final wa = WordAccuracy(
        wordId: 'test',
        correct: 2,
        total: 3,
        lastSeen: DateTime(2025),
      );
      final updated = wa.recordAttempt(true);
      expect(updated.correct, 3);
      expect(updated.total, 4);
      expect(updated.wordId, 'test');
    });

    test('recordAttempt increments correctly on wrong answer', () {
      final wa = WordAccuracy(
        wordId: 'test',
        correct: 2,
        total: 3,
        lastSeen: DateTime(2025),
      );
      final updated = wa.recordAttempt(false);
      expect(updated.correct, 2); // unchanged
      expect(updated.total, 4);   // incremented
    });

    test('priority is higher for low accuracy words', () {
      final now = DateTime.now();
      final highAccuracy = WordAccuracy(
        wordId: 'good',
        correct: 9,
        total: 10,
        lastSeen: now,
      );
      final lowAccuracy = WordAccuracy(
        wordId: 'bad',
        correct: 1,
        total: 10,
        lastSeen: now,
      );
      expect(lowAccuracy.priority, greaterThan(highAccuracy.priority));
    });

    test('priority is higher for words not seen recently', () {
      final recent = WordAccuracy(
        wordId: 'recent',
        correct: 5,
        total: 10,
        lastSeen: DateTime.now(),
      );
      final stale = WordAccuracy(
        wordId: 'stale',
        correct: 5,
        total: 10,
        lastSeen: DateTime.now().subtract(const Duration(days: 5)),
      );
      expect(stale.priority, greaterThan(recent.priority));
    });

    test('priority forgetting factor clamps at 3 days', () {
      final threeDays = WordAccuracy(
        wordId: 'a',
        correct: 5,
        total: 10,
        lastSeen: DateTime.now().subtract(const Duration(days: 3)),
      );
      final tenDays = WordAccuracy(
        wordId: 'b',
        correct: 5,
        total: 10,
        lastSeen: DateTime.now().subtract(const Duration(days: 10)),
      );
      // Both should have forgettingFactor clamped to 1.0
      expect(threeDays.priority, closeTo(tenDays.priority, 0.05));
    });
  });
}
