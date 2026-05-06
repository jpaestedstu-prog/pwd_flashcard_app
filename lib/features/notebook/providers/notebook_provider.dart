import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../providers/app_providers.dart';
import '../models/notebook_models.dart';
import '../../../data/models/enums.dart';

/// Manages notebook notes via Hive's progress box.
class NotebookNotifier extends StateNotifier<List<NoteEntry>> {
  final String profileId;

  NotebookNotifier(this.profileId) : super([]) {
    _load();
  }

  static Box get _box => Hive.box('progress');

  String get _key => 'notebook_$profileId';

  void _load() {
    final raw = _box.get(_key);
    if (raw == null) {
      state = [];
      return;
    }
    final list = <NoteEntry>[];
    for (final e in (raw as List)) {
      try {
        list.add(NoteEntry.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (_) {
        continue;
      }
    }
    // Sort newest first
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = list;
  }

  Future<void> _save() async {
    await _box.put(_key, state.map((n) => n.toJson()).toList());
  }

  Future<void> addNote(NoteEntry note) async {
    state = [note, ...state];
    await _save();
  }

  Future<void> updateNote(NoteEntry note) async {
    state = [
      for (final n in state)
        if (n.id == note.id) note else n,
    ];
    // Re-sort after update
    final sorted = List.of(state)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = sorted;
    await _save();
  }

  Future<void> deleteNote(String noteId) async {
    state = state.where((n) => n.id != noteId).toList();
    await _save();
  }

  /// Filter notes by category; null returns all.
  List<NoteEntry> filterByCategory(FlashcardCategory? category) {
    if (category == null) return state;
    return state.where((n) => n.category == category).toList();
  }

  /// Search notes by title or content (case-insensitive).
  List<NoteEntry> search(String query) {
    if (query.isEmpty) return state;
    final q = query.toLowerCase();
    return state.where((n) =>
        n.title.toLowerCase().contains(q) ||
        n.content.toLowerCase().contains(q)).toList();
  }
}

final notebookProvider =
    StateNotifierProvider<NotebookNotifier, List<NoteEntry>>((ref) {
  final profile = ref.watch(profileProvider);
  return NotebookNotifier(profile?.id ?? 'default');
});
