import '../../data/local/seed_data.dart';
import '../../data/local/spaced_repetition_service.dart';
import 'notification_service.dart';

/// Bridges spaced-repetition data with the notification system.
///
/// Call [scheduleIfNeeded] after a learning session ends or when the user
/// updates their reminder preferences.  The service counts how many words
/// need review and schedules a daily notification with a personalised body.
class ReviewReminderService {
  ReviewReminderService._();

  /// Threshold below which a word is considered "weak".
  static const double weakThreshold = 0.6;

  /// Count how many words need review for a profile.
  ///
  /// A word "needs review" if it has been attempted at least twice and
  /// accuracy is below [weakThreshold], **or** it has high priority
  /// (weak + stale) according to the spaced repetition algorithm.
  static int countWordsToReview(String profileId) {
    final allCards = SeedData.allFlashcards;
    final weak = SpacedRepetitionService.getWeakWords(
      profileId: profileId,
      allCards: allCards,
    );
    return weak.length;
  }

  /// Count the top-priority review words regardless of accuracy threshold.
  /// These are the words the smart review screen would show.
  static int countDueWords(String profileId, {int limit = 10}) {
    final allCards = SeedData.allFlashcards;
    final review = SpacedRepetitionService.getReviewWords(
      profileId: profileId,
      allCards: allCards,
      count: limit,
    );
    return review.length;
  }

  /// Schedule (or cancel) the vocabulary review notification based on
  /// the current weak-word count and user preferences.
  ///
  /// When [enabled] is `false` the existing reminder is cancelled.
  static Future<void> scheduleIfNeeded({
    required String profileId,
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    if (!enabled) {
      await NotificationService.cancelVocabReviewReminder();
      return;
    }

    final weakCount = countWordsToReview(profileId);

    await NotificationService.scheduleVocabReviewReminder(
      hour: hour,
      minute: minute,
      weakWordCount: weakCount,
    );
  }
}
