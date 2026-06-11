import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/smileyometer_models.dart';

/// Manages student Smileyometer responses in Hive storage.
///
/// Mirrors [SurveyService] but keyed per learner under `smiley_<profileId>`.
class SmileyometerService {
  const SmileyometerService._();

  static const String _boxName = 'progress';
  static Box get _box => Hive.box(_boxName);
  static const _uuid = Uuid();

  /// Save a completed Smileyometer result.
  static Future<void> saveResult(SmileyometerResult result) async {
    final key = 'smiley_${result.profileId}';
    final raw = _box.get(key, defaultValue: <dynamic>[]) as List;
    final results = List<Map<String, dynamic>>.from(
      raw.map((e) => Map<String, dynamic>.from(e as Map)),
    );
    results.add(result.toJson());
    await _box.put(key, results);
  }

  /// Get all Smileyometer results for a learner profile.
  static List<SmileyometerResult> getResults(String profileId) {
    final key = 'smiley_$profileId';
    final raw = _box.get(key, defaultValue: <dynamic>[]) as List;
    return raw.map((e) {
      return SmileyometerResult.fromJson(Map<String, dynamic>.from(e as Map));
    }).toList();
  }

  /// Whether the learner has submitted at least one Smileyometer.
  static bool hasCompleted(String profileId) =>
      getResults(profileId).isNotEmpty;

  /// Create a new result with a generated ID.
  static SmileyometerResult createResult({
    required String profileId,
    required List<int> ratings,
  }) {
    return SmileyometerResult(
      id: _uuid.v4(),
      profileId: profileId,
      completedAt: DateTime.now(),
      ratings: ratings,
    );
  }

  /// All Smileyometer results across all learners (for research export).
  static List<SmileyometerResult> getAllResults() {
    final results = <SmileyometerResult>[];
    for (final key in _box.keys) {
      if (key is String && key.startsWith('smiley_')) {
        final raw = _box.get(key, defaultValue: <dynamic>[]) as List;
        for (final e in raw) {
          try {
            results.add(
              SmileyometerResult.fromJson(Map<String, dynamic>.from(e as Map)),
            );
          } catch (_) {
            continue;
          }
        }
      }
    }
    return results;
  }
}
