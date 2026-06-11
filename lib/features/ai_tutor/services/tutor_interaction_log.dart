import 'package:hive_flutter/hive_flutter.dart';

import '../models/tutor_brain_models.dart';

/// Persists every tutor-brain interaction (rule AND llm) per profile for the
/// `tutor_interactions.csv` research export — enables the rule-vs-LLM
/// engagement sub-study. Same storage shape as the other per-profile logs:
/// a capped JSON list in the progress box.
class TutorInteractionLog {
  TutorInteractionLog._();

  static const String _boxName = 'progress';
  static const int _maxEvents = 300;

  static Box get _box => Hive.box(_boxName);

  static String _key(String profileId) => 'tutor_interactions_$profileId';

  static List<TutorInteractionEvent> getEvents(String profileId) {
    final raw = _box.get(_key(profileId));
    if (raw == null) return [];
    return (raw as List)
        .map((e) => TutorInteractionEvent.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> log(
    String profileId,
    TutorInteractionEvent event,
  ) async {
    final events = getEvents(profileId)..add(event);
    final pruned = events.length > _maxEvents
        ? events.sublist(events.length - _maxEvents)
        : events;
    await _box.put(_key(profileId), pruned.map((e) => e.toJson()).toList());
  }
}
