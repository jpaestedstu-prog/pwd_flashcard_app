import 'mood_models.dart';

/// A learner's recent wellbeing, reduced to what a caregiver can act on.
///
/// Mood data existed only in the learner's own screens and the research CSV.
/// A parent or teacher — the people who would actually do something about a
/// run of hard days — had no way to see it at all.
///
/// Deliberately a *pattern*, never the raw entries: [MoodEntry.note] is the
/// learner writing to themselves, and it is not surfaced here or anywhere on
/// an educator screen. What a caregiver gets is how often the learner checked
/// in, how they have mostly felt, and whether the last week contains enough
/// low days to be worth a conversation.
class MoodSummary {
  /// Number of check-ins inside the window.
  final int entryCount;

  /// The mood recorded most often in the window. Null when [entryCount] is 0.
  final MoodType? dominantMood;

  /// The most recent mood recorded. Null when [entryCount] is 0.
  final MoodType? latestMood;

  /// Mean of [MoodTypeX.numericValue] across the window, 1–6. Null when empty.
  final double? averageValue;

  /// How many entries in the window were [MoodType.sad] or
  /// [MoodType.frustrated].
  final int lowCount;

  const MoodSummary({
    this.entryCount = 0,
    this.dominantMood,
    this.latestMood,
    this.averageValue,
    this.lowCount = 0,
  });

  static const MoodSummary empty = MoodSummary();

  bool get hasData => entryCount > 0;

  /// Moods that count as a hard day.
  static const Set<MoodType> lowMoods = {
    MoodType.sad,
    MoodType.frustrated,
  };

  /// Whether the window holds enough hard days to be worth raising.
  ///
  /// Three in a week, not one: a single bad afternoon is a normal week, and a
  /// caregiver surface that lights up every time a child is briefly cross
  /// teaches people to ignore it. Requires at least three check-ins so a
  /// learner who logged once, sadly, is not flagged on a sample of one.
  bool get needsAttention => entryCount >= 3 && lowCount >= 3;

  /// Build a summary from [entries] recorded within the last [days].
  ///
  /// [now] is injectable so the window is testable.
  factory MoodSummary.fromEntries(
    List<MoodEntry> entries, {
    int days = 7,
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days));
    final window = entries
        .where((e) => e.timestamp.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (window.isEmpty) return MoodSummary.empty;

    final counts = <MoodType, int>{};
    var sum = 0;
    var low = 0;
    for (final e in window) {
      counts[e.mood] = (counts[e.mood] ?? 0) + 1;
      sum += e.mood.numericValue;
      if (lowMoods.contains(e.mood)) low++;
    }

    // Ties break toward the *lower* mood: when a learner logged three happy
    // and three sad days, "mostly sad" is the reading a caregiver should see.
    MoodType? dominant;
    var best = -1;
    for (final entry in counts.entries) {
      final isBetter = entry.value > best ||
          (entry.value == best &&
              dominant != null &&
              entry.key.numericValue < dominant.numericValue);
      if (isBetter) {
        dominant = entry.key;
        best = entry.value;
      }
    }

    return MoodSummary(
      entryCount: window.length,
      dominantMood: dominant,
      latestMood: window.last.mood,
      averageValue: sum / window.length,
      lowCount: low,
    );
  }

  /// One short line for a roster card, in the caregiver's language.
  String labelOf({required bool isFilipino}) {
    final mood = dominantMood;
    if (mood == null) {
      return isFilipino ? 'Walang mood check-in' : 'No mood check-ins';
    }
    final name = mood.labelOf(isFilipino: isFilipino);
    return isFilipino ? 'Kadalasan: $name' : 'Mostly $name';
  }
}
