import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../providers/app_providers.dart';
import '../models/live_session_models.dart';

/// Manages saved live-activity sets (educator-authored quizzes) via Hive's
/// `progress` box. Mirrors `QuizBuilderNotifier` so the persistence shape is
/// consistent across the app.
class LiveActivitySetNotifier extends StateNotifier<List<LiveActivitySet>> {
  final String profileId;

  LiveActivitySetNotifier(this.profileId) : super([]) {
    _load();
  }

  static Box get _box => Hive.box('progress');

  String get _key => 'live_activity_sets_$profileId';

  void _load() {
    final raw = _box.get(_key);
    if (raw == null) {
      state = [];
      return;
    }
    final list = <LiveActivitySet>[];
    for (final e in (raw as List)) {
      try {
        list.add(
          LiveActivitySet.fromJson(Map<String, dynamic>.from(e as Map)),
        );
      } catch (_) {
        continue;
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = list;
  }

  Future<void> _save() async {
    await _box.put(_key, state.map((s) => s.toJson()).toList());
  }

  Future<void> saveSet(LiveActivitySet set) async {
    final idx = state.indexWhere((s) => s.id == set.id);
    if (idx >= 0) {
      final next = [...state];
      next[idx] = set;
      state = next;
    } else {
      state = [set, ...state];
    }
    await _save();
  }

  Future<void> deleteSet(String setId) async {
    state = state.where((s) => s.id != setId).toList();
    await _save();
  }
}

final liveActivitySetProvider =
    StateNotifierProvider<LiveActivitySetNotifier, List<LiveActivitySet>>(
        (ref) {
  final profile = ref.watch(profileProvider);
  return LiveActivitySetNotifier(profile?.id ?? 'default');
});
