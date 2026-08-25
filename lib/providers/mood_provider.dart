import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/local/hive_service.dart';
import '../features/mood_tracker/models/mood_context.dart';
import '../features/mood_tracker/models/mood_models.dart';
import 'app_providers.dart';

const _uuid = Uuid();

class MoodNotifier extends StateNotifier<List<MoodEntry>> {
  final String profileId;

  MoodNotifier(this.profileId) : super([]) {
    _load();
  }

  void _load() {
    // Tolerates storage not being ready: an empty history is the right
    // degraded state — nothing is lost, and the next check-in writes
    // normally.
    try {
      state = HiveService.getMoodEntries(profileId);
    } catch (_) {
      state = const [];
    }
  }

  /// Record a new mood check-in.
  ///
  /// [context] names the moment the mood was captured. It is persisted as
  /// [MoodContext.storageKey], which is what the Mood Insights dashboard's
  /// "Mood by Activity" chart reads — before contexts were written, every
  /// entry landed in a single `general` bucket and that chart was one bar.
  Future<MoodEntry> addMood({
    required MoodType mood,
    String? note,
    MoodContext context = MoodContext.general,
  }) async {
    final entry = MoodEntry(
      id: _uuid.v4(),
      profileId: profileId,
      mood: mood,
      note: note,
      timestamp: DateTime.now(),
      activityContext: context.storageKey,
    );
    state = [...state, entry];
    await HiveService.saveMoodEntries(profileId, state);
    return entry;
  }

  /// Replace the mood on an existing entry, keeping its id and timestamp.
  ///
  /// A learner who taps the wrong face wants to correct it, not to file a
  /// second reading of the same moment — correcting in place keeps the day's
  /// history honest.
  Future<void> updateMood(String entryId, MoodType mood, {String? note}) async {
    state = [
      for (final e in state)
        if (e.id == entryId)
          e.copyWith(mood: mood, note: () => note ?? e.note)
        else
          e,
    ];
    await HiveService.saveMoodEntries(profileId, state);
  }

  /// Delete a mood entry
  Future<void> removeMood(String entryId) async {
    state = state.where((e) => e.id != entryId).toList();
    await HiveService.saveMoodEntries(profileId, state);
  }

  /// Check if the user has logged mood today
  bool get hasLoggedToday {
    final now = DateTime.now();
    return state.any((e) =>
        e.timestamp.year == now.year &&
        e.timestamp.month == now.month &&
        e.timestamp.day == now.day);
  }

  /// Get today's latest mood
  MoodEntry? get todaysMood {
    final now = DateTime.now();
    final todayEntries = state
        .where((e) =>
            e.timestamp.year == now.year &&
            e.timestamp.month == now.month &&
            e.timestamp.day == now.day)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return todayEntries.isNotEmpty ? todayEntries.first : null;
  }

  /// Get mood entries for the last N days
  List<MoodEntry> recentEntries(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return state
        .where((e) => e.timestamp.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Get average mood value over the last N days
  double? averageMood(int days) {
    final entries = recentEntries(days);
    if (entries.isEmpty) return null;
    final sum = entries.fold<int>(0, (s, e) => s + e.mood.numericValue);
    return sum / entries.length;
  }

  /// Get entries grouped by date (yyyy-MM-dd)
  Map<String, List<MoodEntry>> get entriesByDate {
    final grouped = <String, List<MoodEntry>>{};
    for (final entry in state) {
      final key =
          '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}-${entry.timestamp.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    return grouped;
  }
}

final moodProvider =
    StateNotifierProvider<MoodNotifier, List<MoodEntry>>((ref) {
  final profile = ref.watch(profileProvider);
  return MoodNotifier(profile?.id ?? '');
});
