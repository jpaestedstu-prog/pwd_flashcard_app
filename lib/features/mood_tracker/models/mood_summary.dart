import 'mood_context.dart';
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

  /// Check-ins in the window that belong to "My Day" — a question after one
  /// step, a scheduled check-in, or the day-end question (see
  /// [isRoutineMoodContext]).
  ///
  /// Separated out because these are the check-ins an adult can act on
  /// *directly*: every other one says how the learner felt, these say how a
  /// routine **they set** felt. "Mostly sad after brushing teeth, four times
  /// this week" is a conversation; "mostly sad" on its own is a mystery.
  final int routineCount;

  /// The mood recorded most often across [routineCount], or null when 0.
  final MoodType? routineDominantMood;

  /// How each moment of the day felt — one row per step asked about (and one
  /// for the day-end question), busiest first.
  final List<StepMood> stepMoods;

  const MoodSummary({
    this.entryCount = 0,
    this.dominantMood,
    this.latestMood,
    this.averageValue,
    this.lowCount = 0,
    this.routineCount = 0,
    this.routineDominantMood,
    this.stepMoods = const <StepMood>[],
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
    final routineCounts = <MoodType, int>{};
    // Keyed by the frozen step title; '' is the day-end question, which is
    // about the whole day rather than one step.
    final byStep = <String, Map<MoodType, int>>{};
    var sum = 0;
    var low = 0;
    for (final e in window) {
      counts[e.mood] = (counts[e.mood] ?? 0) + 1;
      sum += e.mood.numericValue;
      if (lowMoods.contains(e.mood)) low++;
      final ctx = MoodContextX.fromKey(e.activityContext);
      if (isRoutineMoodContext(ctx)) {
        routineCounts[e.mood] = (routineCounts[e.mood] ?? 0) + 1;
        final key = ctx == MoodContext.afterRoutine
            ? ''
            : (e.routineStepTitle ?? '').trim();
        final tally = byStep.putIfAbsent(key, () => <MoodType, int>{});
        tally[e.mood] = (tally[e.mood] ?? 0) + 1;
      }
    }

    final stepMoods = [
      for (final entry in byStep.entries)
        StepMood(
          title: entry.key,
          dominant: _dominantOf(entry.value)!,
          count: entry.value.values.fold(0, (a, b) => a + b),
        ),
    ]..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.title.compareTo(b.title);
      });

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
      routineCount: routineCounts.values.fold(0, (a, b) => a + b),
      routineDominantMood: _dominantOf(routineCounts),
      stepMoods: stepMoods,
    );
  }

  /// Most frequent mood in [counts], ties breaking toward the lower mood for
  /// the same reason [dominantMood] does.
  static MoodType? _dominantOf(Map<MoodType, int> counts) {
    MoodType? best;
    var bestCount = -1;
    for (final entry in counts.entries) {
      final isBetter = entry.value > bestCount ||
          (entry.value == bestCount &&
              best != null &&
              entry.key.numericValue < best.numericValue);
      if (isBetter) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }

  /// Whether any check-in in the window belonged to "My Day".
  bool get hasRoutineMoods => routineCount > 0;

  /// One line pairing the routine with how it felt, or null when the learner
  /// answered none of its questions in the window.
  String? routineLabelOf({required bool isFilipino}) {
    final mood = routineDominantMood;
    if (mood == null) return null;
    final name = mood.labelOf(isFilipino: isFilipino);
    return isFilipino
        ? 'Check-in sa Araw Ko: kadalasan $name ($routineCount)'
        : 'My Day check-ins: mostly $name ($routineCount)';
  }

  /// The moment of the day that feels worst — the step whose answers are
  /// mostly [lowMoods] — or null when no step does.
  ///
  /// Only a *low* mood qualifies. "Hardest: breakfast (mostly Okay)" would
  /// send a caregiver looking for a problem that is not there.
  StepMood? get hardestStep {
    StepMood? worst;
    for (final s in stepMoods) {
      if (s.isDayEnd || !lowMoods.contains(s.dominant)) continue;
      if (worst == null ||
          s.dominant.numericValue < worst.dominant.numericValue ||
          (s.dominant.numericValue == worst.dominant.numericValue &&
              s.count > worst.count)) {
        worst = s;
      }
    }
    return worst;
  }

  /// "Hardest: Brushing Teeth (mostly Sad)", or null.
  String? hardestStepLabelOf({required bool isFilipino}) {
    final s = hardestStep;
    if (s == null) return null;
    final name = s.dominant.labelOf(isFilipino: isFilipino);
    return isFilipino
        ? 'Pinakamahirap: ${s.title} (kadalasan $name)'
        : 'Hardest: ${s.title} (mostly $name)';
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


/// How one moment of "My Day" has felt: the step's title as the learner saw it,
/// the answer given most often, and how many answers there were.
class StepMood {
  const StepMood({
    required this.title,
    required this.dominant,
    required this.count,
  });

  /// The step's frozen title, or '' for the day-end question.
  final String title;
  final MoodType dominant;
  final int count;

  /// The day-end question ("You finished your day!") rather than one step.
  bool get isDayEnd => title.isEmpty;

  /// The row's name for a reader.
  String labelOf({required bool isFilipino}) => isDayEnd
      ? (isFilipino ? 'Pagtatapos ng araw' : 'Finishing the day')
      : title;
}
