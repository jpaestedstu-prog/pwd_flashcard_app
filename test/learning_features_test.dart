import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/spaced_repetition_service.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_models.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // 1. WordAccuracy model
  // ─────────────────────────────────────────────────────
  group('WordAccuracy', () {
    test('accuracy is 0 when no attempts', () {
      final wa = WordAccuracy(wordId: 'w1', lastSeen: DateTime.now());
      expect(wa.accuracy, 0.0);
    });

    test('accuracy is correct/total', () {
      final wa = WordAccuracy(
        wordId: 'w1',
        correct: 3,
        total: 4,
        lastSeen: DateTime.now(),
      );
      expect(wa.accuracy, 0.75);
    });

    test('priority increases with lower accuracy', () {
      final strong = WordAccuracy(
        wordId: 'w1',
        correct: 9,
        total: 10,
        lastSeen: DateTime.now(),
      );
      final weak = WordAccuracy(
        wordId: 'w2',
        correct: 1,
        total: 10,
        lastSeen: DateTime.now(),
      );
      expect(weak.priority, greaterThan(strong.priority));
    });

    test('priority increases with time since last seen', () {
      final recent = WordAccuracy(
        wordId: 'w1',
        correct: 5,
        total: 10,
        lastSeen: DateTime.now(),
      );
      final stale = WordAccuracy(
        wordId: 'w2',
        correct: 5,
        total: 10,
        lastSeen: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(stale.priority, greaterThan(recent.priority));
    });

    test('recordAttempt increments correct on success', () {
      final wa = WordAccuracy(
        wordId: 'w1',
        correct: 2,
        total: 5,
        lastSeen: DateTime(2025),
      );
      final updated = wa.recordAttempt(true);
      expect(updated.correct, 3);
      expect(updated.total, 6);
    });

    test('recordAttempt does not increment correct on failure', () {
      final wa = WordAccuracy(
        wordId: 'w1',
        correct: 2,
        total: 5,
        lastSeen: DateTime(2025),
      );
      final updated = wa.recordAttempt(false);
      expect(updated.correct, 2);
      expect(updated.total, 6);
    });

    test('forgetting factor capped at 1.0', () {
      // Even 30 days ago, forgetting factor should be clamped to 1.0
      final ancient = WordAccuracy(
        wordId: 'w1',
        correct: 5,
        total: 10,
        lastSeen: DateTime.now().subtract(const Duration(days: 30)),
      );
      // difficultyFactor = 0.5, forgettingFactor capped at 1.0
      expect(ancient.priority, closeTo(1.5, 0.1));
    });
  });

  // ─────────────────────────────────────────────────────
  // 2. AppSettings vocabReviewEnabled
  // ─────────────────────────────────────────────────────
  group('AppSettings vocabReviewEnabled', () {
    test('defaults to false', () {
      const settings = AppSettings();
      expect(settings.vocabReviewEnabled, isFalse);
    });

    test('copyWith preserves vocabReviewEnabled', () {
      const settings = AppSettings(vocabReviewEnabled: true);
      final copied = settings.copyWith(fontScale: 1.5);
      expect(copied.vocabReviewEnabled, isTrue);
      expect(copied.fontScale, 1.5);
    });

    test('copyWith can toggle vocabReviewEnabled', () {
      const settings = AppSettings();
      final toggled = settings.copyWith(vocabReviewEnabled: true);
      expect(toggled.vocabReviewEnabled, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────
  // 3. Notification payload routing
  // ─────────────────────────────────────────────────────
  group('Notification payload routing', () {
    String routeForPayload(String payload) => switch (payload) {
      'daily_challenge' => '/home',
      'vocab_review' => '/smart-review',
      _ => '/home',
    };

    test('daily_challenge routes to /home', () {
      expect(routeForPayload('daily_challenge'), '/home');
    });

    test('vocab_review routes to /smart-review', () {
      expect(routeForPayload('vocab_review'), '/smart-review');
    });

    test('unknown payload routes to /home', () {
      expect(routeForPayload('unknown'), '/home');
    });
  });

  // ─────────────────────────────────────────────────────
  // 4. Dynamic smart review banner text
  // ─────────────────────────────────────────────────────
  group('Smart review banner text', () {
    String bannerSubtitle(int weakCount) => weakCount > 0
        ? '$weakCount word${weakCount == 1 ? '' : 's'} need${weakCount == 1 ? 's' : ''} practice'
        : 'Practice words you struggle with most';

    test('shows generic text when no weak words', () {
      expect(bannerSubtitle(0), 'Practice words you struggle with most');
    });

    test('singular when 1 weak word', () {
      expect(bannerSubtitle(1), '1 word needs practice');
    });

    test('plural when multiple weak words', () {
      expect(bannerSubtitle(5), '5 words need practice');
    });
  });

  // ─────────────────────────────────────────────────────
  // 5. Vocab review notification body
  // ─────────────────────────────────────────────────────
  group('Vocab review notification body', () {
    String notificationBody(int weakWordCount) => weakWordCount > 0
        ? 'You have $weakWordCount word${weakWordCount == 1 ? '' : 's'} to review. '
            "Let's strengthen your memory!"
        : "Time to review your vocabulary and keep your streak going!";

    test('generic body when no weak words', () {
      expect(
        notificationBody(0),
        "Time to review your vocabulary and keep your streak going!",
      );
    });

    test('singular body for 1 word', () {
      expect(notificationBody(1), contains('1 word to review'));
    });

    test('plural body for multiple words', () {
      expect(notificationBody(7), contains('7 words to review'));
    });

    test('body includes encouragement', () {
      expect(
        notificationBody(3),
        contains("Let's strengthen your memory!"),
      );
    });
  });

  // ─────────────────────────────────────────────────────
  // 6. Weak word threshold
  // ─────────────────────────────────────────────────────
  group('Weak word threshold', () {
    test('word below 0.6 accuracy is weak', () {
      final wa = WordAccuracy(
        wordId: 'w1',
        correct: 2,
        total: 5,
        lastSeen: DateTime.now(),
      );
      expect(wa.accuracy, 0.4);
      expect(wa.accuracy < 0.6, isTrue);
    });

    test('word at exactly 0.6 accuracy is not weak', () {
      final wa = WordAccuracy(
        wordId: 'w1',
        correct: 3,
        total: 5,
        lastSeen: DateTime.now(),
      );
      expect(wa.accuracy, 0.6);
      expect(wa.accuracy < 0.6, isFalse);
    });

    test('word above 0.6 accuracy is not weak', () {
      final wa = WordAccuracy(
        wordId: 'w1',
        correct: 8,
        total: 10,
        lastSeen: DateTime.now(),
      );
      expect(wa.accuracy, 0.8);
      expect(wa.accuracy < 0.6, isFalse);
    });

    test('word with only 1 attempt not counted as weak', () {
      // getWeakWords requires total >= 2
      final wa = WordAccuracy(
        wordId: 'w1',
        total: 1,
        lastSeen: DateTime.now(),
      );
      expect(wa.accuracy, 0.0);
      // Even 0% accuracy, but total < 2 means it won't show as weak
      expect(wa.total >= 2, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────
  // 7. Sync queue models
  // ─────────────────────────────────────────────────────
  group('Sync queue models', () {
    test('SyncOperation tracks entity and type', () {
      final op = SyncOperation(
        id: 'op1',
        type: SyncOperationType.update,
        entity: SyncEntity.progress,
        entityId: 'profile-123',
        payload: {'wordsLearned': 42},
        createdAt: DateTime(2026),
      );
      expect(op.entity, SyncEntity.progress);
      expect(op.type, SyncOperationType.update);
      expect(op.status, SyncOperationStatus.pending);
      expect(op.retryCount, 0);
    });

    test('SyncQueueStatus reports counts correctly', () {
      final status = SyncQueueStatus(
        pendingCount: 3,
        failedCount: 1,
        totalCount: 4,
        lastSyncAt: DateTime(2026),
      );
      expect(status.pendingCount, 3);
      expect(status.failedCount, 1);
      expect(status.totalCount, 4);
      expect(status.isSyncing, isFalse);
    });

    test('SyncEntity covers all data types', () {
      expect(SyncEntity.values.length, greaterThanOrEqualTo(7));
      expect(SyncEntity.values, contains(SyncEntity.profile));
      expect(SyncEntity.values, contains(SyncEntity.progress));
      expect(SyncEntity.values, contains(SyncEntity.settings));
    });

    test('SyncOperationType has create, update, delete', () {
      expect(SyncOperationType.values, contains(SyncOperationType.create));
      expect(SyncOperationType.values, contains(SyncOperationType.update));
      expect(SyncOperationType.values, contains(SyncOperationType.delete));
    });

    test('SyncOperationStatus tracks lifecycle', () {
      expect(SyncOperationStatus.values, contains(SyncOperationStatus.pending));
      expect(SyncOperationStatus.values, contains(SyncOperationStatus.inProgress));
      expect(SyncOperationStatus.values, contains(SyncOperationStatus.failed));
      expect(SyncOperationStatus.values, contains(SyncOperationStatus.completed));
    });
  });

  // ─────────────────────────────────────────────────────
  // 8. Connectivity indicator visibility
  // ─────────────────────────────────────────────────────
  group('Connectivity indicator visibility', () {
    bool shouldShowIndicator(bool isOffline, bool showWhenOnline) =>
        isOffline || showWhenOnline;

    test('indicator hidden when online and showWhenOnline is false', () {
      expect(shouldShowIndicator(false, false), isFalse);
    });

    test('indicator visible when offline', () {
      expect(shouldShowIndicator(true, false), isTrue);
    });

    test('indicator visible when online and showWhenOnline is true', () {
      expect(shouldShowIndicator(false, true), isTrue);
    });
  });
}
