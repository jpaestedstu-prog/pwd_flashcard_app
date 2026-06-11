import 'package:hive_flutter/hive_flutter.dart';

import '../models/tutor_models.dart';

/// Persists the learner's AI Tutor relationship — chat history, cumulative
/// stats, and today's learning plan — so the tutor *remembers* across sessions.
///
/// Storage mirrors [SpacedRepetitionService]: raw JSON-safe maps/lists in the
/// already-open `progress` Hive box, keyed by profile. No Hive adapters /
/// typeIds are registered, which keeps it migration-free and free-tier (purely
/// on-device, no network).
class TutorMemoryService {
  TutorMemoryService._();

  static const String _boxName = 'progress';

  /// Keep storage bounded — only the most recent messages are persisted.
  static const int maxStoredMessages = 40;

  static Box get _box => Hive.box(_boxName);

  static String _key(String profileId) => 'tutor_$profileId';

  /// Loads the persisted tutor memory for [profileId]. Returns an empty
  /// [TutorMemory] when nothing is stored yet (first visit).
  static TutorMemory getMemory(String profileId) {
    final data = _box.get(_key(profileId));
    if (data == null) return const TutorMemory();
    final map = Map<String, dynamic>.from(data as Map);

    final rawMessages = (map['messages'] as List?) ?? const [];
    final messages = <TutorMessage>[];
    for (final raw in rawMessages) {
      try {
        messages.add(TutorMessage.fromJson(Map<String, dynamic>.from(raw as Map)));
      } catch (_) {
        // Skip any corrupt/legacy entry rather than losing the whole history.
      }
    }

    final stats = map['stats'] == null
        ? const TutorStats()
        : TutorStats.fromJson(Map<String, dynamic>.from(map['stats'] as Map));

    return TutorMemory(
      messages: messages,
      stats: stats,
      lastPlanDate: map['lastPlanDate'] as String?,
      planWordIds:
          (map['planWordIds'] as List?)?.map((e) => e as String).toList() ??
              const [],
    );
  }

  /// Persists [memory], capping the message history to [maxStoredMessages]
  /// (most recent kept).
  static Future<void> saveMemory(String profileId, TutorMemory memory) async {
    final capped = memory.messages.length > maxStoredMessages
        ? memory.messages
            .sublist(memory.messages.length - maxStoredMessages)
        : memory.messages;

    await _box.put(_key(profileId), {
      'messages': capped.map((m) => m.toJson()).toList(),
      'stats': memory.stats.toJson(),
      if (memory.lastPlanDate != null) 'lastPlanDate': memory.lastPlanDate,
      'planWordIds': memory.planWordIds,
    });
  }

  /// Clears a learner's tutor memory (used by data-reset / "start fresh").
  static Future<void> clear(String profileId) async {
    await _box.delete(_key(profileId));
  }

  /// `yyyy-mm-dd` for [date] (local), used as the once-per-day lesson guard.
  static String dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// True when a learning plan has already been completed today.
  static bool lessonDoneToday(TutorMemory memory, {DateTime? now}) =>
      memory.lastPlanDate == dayKey(now ?? DateTime.now());
}
