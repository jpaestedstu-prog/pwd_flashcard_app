import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
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

  group('markSeen (Word Hunt → review queue)', () {
    const profileId = 'sr-markseen-test';
    final card = SeedData.allFlashcards.firstWhere((c) => c.id == 'cr13');

    setUpAll(() async {
      Hive.init('./build/test_cache/spaced_repetition');
      if (!Hive.isBoxOpen('progress')) await Hive.openBox('progress');
    });

    setUp(() => Hive.box('progress').clear());
    tearDownAll(() async => Hive.deleteFromDisk());

    test('tracks a scanned word without recording an attempt', () {
      SpacedRepetitionService.markSeen(profileId: profileId, wordId: card.id);

      final accs = SpacedRepetitionService.getWordAccuracies(profileId);
      expect(accs.containsKey(card.id), isTrue);
      // Seen, but never tested: counts stay at zero so stats stay truthful.
      expect(accs[card.id]!.total, 0);
      expect(accs[card.id]!.correct, 0);

      final summary = SpacedRepetitionService.getSummary(profileId);
      expect(summary.totalAttempted, 0);
    });

    test('a scanned word surfaces in the review queue', () {
      SpacedRepetitionService.markSeen(profileId: profileId, wordId: card.id);

      final review = SpacedRepetitionService.getReviewWords(
        profileId: profileId,
        allCards: SeedData.allFlashcards,
        count: 5,
      );
      // A just-seen, untested word (priority 1.0) outranks never-seen words
      // (priority 0.8), so it leads the queue.
      expect(review.first.id, card.id);
    });

    test('refreshes lastSeen but preserves accuracy on a tested word',
        () async {
      await SpacedRepetitionService.recordWordAttempt(
        profileId: profileId,
        wordId: card.id,
        wasCorrect: true,
      );
      final before = SpacedRepetitionService.getWordAccuracies(profileId);
      expect(before[card.id]!.total, 1);
      expect(before[card.id]!.correct, 1);

      SpacedRepetitionService.markSeen(profileId: profileId, wordId: card.id);

      final after = SpacedRepetitionService.getWordAccuracies(profileId);
      // Counts untouched; the attempt history is not corrupted by a scan.
      expect(after[card.id]!.total, 1);
      expect(after[card.id]!.correct, 1);
    });
  });
}
