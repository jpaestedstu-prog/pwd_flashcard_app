import 'package:hive_flutter/hive_flutter.dart';

import '../models/sign_interpreter_models.dart';

/// Persists Speech→Sign sessions per profile in the progress box, for the
/// research export (`speech_to_sign_usage.csv`). Mirrors the storage shape
/// used by AdaptiveDifficultyService / mood entries: a JSON list under a
/// per-profile key, capped so the box can't grow without bound.
class SignUsageLogService {
  const SignUsageLogService._();

  static const String _boxName = 'progress';
  static const int _maxEvents = 500;

  static Box get _box => Hive.box(_boxName);

  static String _key(String profileId) => 'sign_usage_$profileId';

  /// All logged events for a profile, oldest first.
  static List<SignUsageEvent> getEvents(String profileId) {
    final raw = _box.get(_key(profileId));
    if (raw == null) return [];
    return (raw as List)
        .map((e) => SignUsageEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Appends one event, pruning the oldest entries past [_maxEvents].
  static Future<void> logEvent(String profileId, SignUsageEvent event) async {
    final events = getEvents(profileId)..add(event);
    final pruned = events.length > _maxEvents
        ? events.sublist(events.length - _maxEvents)
        : events;
    await _box.put(_key(profileId), pruned.map((e) => e.toJson()).toList());
  }
}
