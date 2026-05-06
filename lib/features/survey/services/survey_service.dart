import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/survey_models.dart';

/// Manages SUS survey responses in Hive storage.
class SurveyService {
  const SurveyService._();

  static const String _boxName = 'progress';
  static Box get _box => Hive.box(_boxName);
  static const _uuid = Uuid();

  /// Save a completed SUS survey result.
  static Future<void> saveSurveyResult(SusSurveyResult result) async {
    final key = 'sus_surveys_${result.profileId}';
    final raw = _box.get(key, defaultValue: <dynamic>[]) as List;
    final surveys = List<Map<String, dynamic>>.from(
      raw.map((e) => Map<String, dynamic>.from(e as Map)),
    );
    surveys.add(result.toJson());
    await _box.put(key, surveys);
  }

  /// Get all SUS survey results for a profile.
  static List<SusSurveyResult> getSurveyResults(String profileId) {
    final key = 'sus_surveys_$profileId';
    final raw = _box.get(key, defaultValue: <dynamic>[]) as List;
    return raw.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return SusSurveyResult.fromJson(map);
    }).toList();
  }

  /// Get the most recent SUS survey result, or null.
  static SusSurveyResult? getLatestResult(String profileId) {
    final results = getSurveyResults(profileId);
    if (results.isEmpty) return null;
    results.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return results.first;
  }

  /// Check if the user has already completed a survey.
  static bool hasCompletedSurvey(String profileId) {
    return getSurveyResults(profileId).isNotEmpty;
  }

  /// Create a new result with a generated ID.
  static SusSurveyResult createResult({
    required String profileId,
    required List<int> responses,
    String? feedback,
  }) {
    return SusSurveyResult(
      id: _uuid.v4(),
      profileId: profileId,
      completedAt: DateTime.now(),
      responses: responses,
      feedback: feedback,
    );
  }

  /// Get all survey results across all students (for research export).
  static List<SusSurveyResult> getAllResults() {
    final results = <SusSurveyResult>[];
    final box = Hive.box(_boxName);
    for (final key in box.keys) {
      if (key is String && key.startsWith('sus_surveys_')) {
        final raw = box.get(key, defaultValue: <dynamic>[]) as List;
        for (final e in raw) {
          try {
            results.add(SusSurveyResult.fromJson(
              Map<String, dynamic>.from(e as Map),
            ));
          } catch (_) {
            continue;
          }
        }
      }
    }
    return results;
  }
}
