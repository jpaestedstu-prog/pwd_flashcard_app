import 'dart:math';
import '../models/models.dart';
import 'seed_data.dart';
import 'hive_service.dart';

/// Manages the "Daily Word Challenge" — a rotating word each day with
/// a mini 3-option quiz that awards bonus stars.
class DailyChallenge {
  DailyChallenge._();

  /// Returns a deterministic daily word based on the date.
  /// Uses a hash of year+month+day so every user sees the same word each day.
  static Flashcard todaysWord() {
    final all = SeedData.allFlashcards;
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final index = seed % all.length;
    return all[index];
  }

  /// Generates 3 choices (one correct + 2 distractors) for the quiz.
  static List<String> generateChoices(Flashcard correct) {
    final all = SeedData.allFlashcards
        .where((c) => c.id != correct.id)
        .toList();
    final rng = Random(correct.id.hashCode);
    all.shuffle(rng);
    final distractors = all.take(2).map((c) => c.wordFilipino).toList();
    final choices = [correct.wordFilipino, ...distractors];
    choices.shuffle(rng);
    return choices;
  }

  /// Check if the user has already completed today's challenge.
  static bool hasCompletedToday(String profileId) {
    return HiveService.getDailyChallengeDate(profileId) == _todayKey();
  }

  /// Mark today's challenge as completed and record the result.
  static Future<void> markCompleted(String profileId, bool correct) async {
    await HiveService.saveDailyChallengeDate(profileId, _todayKey());
    if (correct) {
      await HiveService.incrementDailyChallengeStreak(profileId);
    } else {
      await HiveService.resetDailyChallengeStreak(profileId);
    }
  }

  /// Get the current daily challenge streak.
  static int getStreak(String profileId) {
    return HiveService.getDailyChallengeStreak(profileId);
  }

  /// Returns "2025-02-13" style key for today.
  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
