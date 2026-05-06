import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../providers/app_providers.dart';
import '../models/custom_quiz_models.dart';

/// Manages saved custom quizzes via Hive's progress box.
class QuizBuilderNotifier extends StateNotifier<List<CustomQuiz>> {
  final String profileId;

  QuizBuilderNotifier(this.profileId) : super([]) {
    _load();
  }

  static Box get _box => Hive.box('progress');

  String get _key => 'custom_quizzes_$profileId';

  void _load() {
    final raw = _box.get(_key);
    if (raw == null) {
      state = [];
      return;
    }
    final list = <CustomQuiz>[];
    for (final e in (raw as List)) {
      try {
        list.add(CustomQuiz.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (_) {
        continue;
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = list;
  }

  Future<void> _save() async {
    await _box.put(_key, state.map((q) => q.toJson()).toList());
  }

  Future<void> addQuiz(CustomQuiz quiz) async {
    state = [quiz, ...state];
    await _save();
  }

  Future<void> deleteQuiz(String quizId) async {
    state = state.where((q) => q.id != quizId).toList();
    await _save();
  }
}

final quizBuilderProvider =
    StateNotifierProvider<QuizBuilderNotifier, List<CustomQuiz>>((ref) {
  final profile = ref.watch(profileProvider);
  return QuizBuilderNotifier(profile?.id ?? 'default');
});
