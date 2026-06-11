import 'package:hive_flutter/hive_flutter.dart';

import 'claude_brain.dart';

/// Device-level configuration for the LLM tutor brain, stored in the
/// `settings` box and managed from the educator-gated settings screen.
///
/// Threat model (documented decision): the API key is stored in the
/// app-private Hive settings box, which is plaintext on a rooted device.
/// Accepted for the thesis deployment because (a) the key belongs to the
/// supervising educator and is spend-capped per day, (b) the study tablets
/// are school-managed, and (c) adding flutter_secure_storage means a new
/// native plugin whose Kotlin 2.2.x compatibility must be verified first —
/// flagged as a follow-up, not a blocker.
class TutorBrainSettings {
  TutorBrainSettings._();

  static const String _boxName = 'settings';
  static Box get _box => Hive.box(_boxName);

  static const String _enabledKey = 'tutor_llm_enabled';
  static const String _apiKeyKey = 'tutor_llm_api_key';
  static const String _modelKey = 'tutor_llm_model';
  static const String _capKey = 'tutor_llm_daily_cap';
  static const String _turnsKey = 'tutor_llm_turns';

  /// Default ceiling on LLM calls per calendar day (cost control on the
  /// educator's key; ~400 output tokens per turn).
  static const int defaultDailyCap = 40;

  static bool get isEnabled => _box.get(_enabledKey) as bool? ?? false;
  static Future<void> setEnabled(bool value) => _box.put(_enabledKey, value);

  static String get apiKey => _box.get(_apiKeyKey) as String? ?? '';
  static Future<void> setApiKey(String value) =>
      _box.put(_apiKeyKey, value.trim());

  static String get model {
    final stored = _box.get(_modelKey) as String?;
    return ClaudeBrain.supportedModels.containsKey(stored)
        ? stored!
        : ClaudeBrain.defaultModel;
  }

  static Future<void> setModel(String value) => _box.put(_modelKey, value);

  static int get dailyCap => _box.get(_capKey) as int? ?? defaultDailyCap;
  static Future<void> setDailyCap(int value) => _box.put(_capKey, value);

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  /// LLM turns spent today (device-wide, resets on date change).
  static int get turnsToday {
    final raw = _box.get(_turnsKey);
    if (raw is! Map) return 0;
    if (raw['date'] != _today()) return 0;
    return (raw['count'] as num?)?.toInt() ?? 0;
  }

  static bool get canSpendTurn => turnsToday < dailyCap;

  static Future<void> spendTurn() =>
      _box.put(_turnsKey, {'date': _today(), 'count': turnsToday + 1});
}
