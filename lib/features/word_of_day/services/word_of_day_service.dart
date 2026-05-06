import '../../../data/local/seed_data.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../core/constants/flashcard_emojis.dart';
import '../models/word_of_day_models.dart';

/// Service that deterministically picks a Word of the Day from the
/// seed flashcard pool. Uses the day-of-year so every user sees the
/// same word on the same calendar day.
class WordOfDayService {
  WordOfDayService._();

  /// Returns today's Word of the Day.
  static WordOfDay today() {
    final allCards = SeedData.allFlashcards;
    if (allCards.isEmpty) {
      return WordOfDay(
        wordEnglish: 'Hello',
        wordFilipino: 'Kamusta',
        emoji: '👋',
        category: 'Greetings',
        date: DateTime.now(),
      );
    }

    final now = DateTime.now();
    // Use day-of-year to pick a card deterministically, cycling every year.
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final index = dayOfYear % allCards.length;
    final card = allCards[index];

    return WordOfDay(
      wordEnglish: card.wordEnglish,
      wordFilipino: card.wordFilipino,
      exampleSentence: card.exampleSentence,
      emoji: FlashcardEmojis.forId(card.id),
      category: card.category.label,
      date: now,
    );
  }

  /// Whether the user has already marked today's word as learned.
  static bool hasLearnedToday(String profileId) {
    final key = _dateKey(DateTime.now());
    final history = HiveService.getWordOfDayHistory(profileId);
    return history.any((r) => r.dateKey == key && r.learned);
  }

  /// Mark today's word as learned.
  static Future<void> markLearned(String profileId) async {
    final word = today();
    final key = _dateKey(DateTime.now());
    final history = HiveService.getWordOfDayHistory(profileId);

    // Don't add duplicate
    if (history.any((r) => r.dateKey == key)) return;

    history.add(WordOfDayRecord(
      dateKey: key,
      wordEnglish: word.wordEnglish,
      learned: true,
    ));

    // Keep only the last 90 days
    if (history.length > 90) {
      history.removeRange(0, history.length - 90);
    }

    await HiveService.saveWordOfDayHistory(profileId, history);
  }

  /// How many words this user has learned via Word of the Day.
  static int totalLearned(String profileId) {
    return HiveService.getWordOfDayHistory(profileId)
        .where((r) => r.learned)
        .length;
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
