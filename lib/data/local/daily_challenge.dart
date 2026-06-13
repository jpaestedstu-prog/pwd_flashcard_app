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

  /// Returns [count] deterministic, distinct words for today's "Daily Mission"
  /// — the bite-sized session that replaced the single daily word.
  ///
  /// Every user sees the same set on a given calendar day, and the set is
  /// stable for the whole day (seeded by year+month+day). [count] is clamped
  /// to the available card pool. The list preserves a stable order so callers
  /// can index into it across rebuilds.
  static List<Flashcard> todaysWords(int count) {
    final all = SeedData.allFlashcards;
    if (all.isEmpty || count <= 0) return const [];
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final n = count > all.length ? all.length : count;
    // Deterministic shuffle of indices by the day-seed, then take the first n.
    final indices = List<int>.generate(all.length, (i) => i)..shuffle(Random(seed));
    return [for (final i in indices.take(n)) all[i]];
  }

  /// Generates multiple-choice options: one correct answer plus distractors,
  /// shuffled. [count] is the total number of options (default 3). Distractors
  /// are drawn from other cards and never duplicate the correct answer's
  /// Filipino word, so a 50/50 hint can always remove genuinely wrong options.
  static List<String> generateChoices(Flashcard correct, {int count = 3}) {
    final pool = SeedData.allFlashcards
        .where((c) => c.id != correct.id && c.wordFilipino != correct.wordFilipino)
        .toList();
    final rng = Random(correct.id.hashCode);
    pool.shuffle(rng);
    final wanted = count < 1 ? 1 : count;
    final distractorCount =
        (wanted - 1) > pool.length ? pool.length : (wanted - 1);
    final distractors =
        pool.take(distractorCount).map((c) => c.wordFilipino).toList();
    final choices = [correct.wordFilipino, ...distractors];
    choices.shuffle(rng);
    return choices;
  }

  /// Check if the user has already completed today's challenge.
  static bool hasCompletedToday(String profileId) {
    return HiveService.getDailyChallengeDate(profileId) == _todayKey();
  }

  /// Mark today's challenge/mission as completed and record the result.
  ///
  /// Idempotent for a given calendar day: the first completion of the day
  /// counts (advancing or resetting the streak); later calls are a no-op and
  /// return `false`. This keeps the streak and stars from being double-counted
  /// when more than one surface can complete the day (e.g. the home-screen
  /// quick card and this full mission). Callers should only award stars when
  /// this returns `true`.
  static Future<bool> markCompleted(String profileId, bool correct) async {
    if (hasCompletedToday(profileId)) return false;
    await HiveService.saveDailyChallengeDate(profileId, _todayKey());
    if (correct) {
      await HiveService.incrementDailyChallengeStreak(profileId);
    } else {
      await HiveService.resetDailyChallengeStreak(profileId);
    }
    return true;
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
