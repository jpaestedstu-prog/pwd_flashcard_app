import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'pin_auth_service.dart';

/// One-shot migration from plaintext `pin` → salted PBKDF2 `pinHash`.
///
/// Idempotency is enforced by three independent guards (any one is enough):
///   1. The settings flag [_migrationFlagKey] short-circuits subsequent runs.
///   2. Per-profile guard: skip if `pinHash` is already set.
///   3. After hashing, the legacy `pin` field is wiped so a forced re-run
///      cannot re-hash an already-hashed value.
class PinMigration {
  static const String _migrationFlagKey = 'pin_migration_v1_done';
  static const String _profilesBox = 'profiles';
  static const String _settingsBox = 'settings';

  static Future<void> runIfNeeded() async {
    final settings = Hive.box(_settingsBox);
    if (settings.get(_migrationFlagKey, defaultValue: false) == true) return;

    final profileBox = Hive.box(_profilesBox);
    final raw = profileBox.get('profiles', defaultValue: <dynamic>[]) as List;
    final profiles = List<Map<String, dynamic>>.from(
      raw.map((e) => Map<String, dynamic>.from(e as Map)),
    );

    var changed = false;
    for (final p in profiles) {
      // Already migrated — skip.
      if (p['pinHash'] != null) continue;

      final legacyPin = p['pin'] as String?;
      if (legacyPin == null) continue;
      if (legacyPin.length != 4) {
        if (kDebugMode) {
          debugPrint(
              'PinMigration: skipping profile ${p['id']} — malformed PIN');
        }
        continue;
      }

      final salt = PinAuthService.generateSalt();
      p['pinHash'] = PinAuthService.hashPin(legacyPin, salt);
      p['pinSalt'] = salt;
      p['pinHashAlgorithm'] = PinAuthService.algorithmId;
      p['pin'] = null;
      p['failedAttempts'] = (p['failedAttempts'] as int?) ?? 0;
      changed = true;
    }

    if (changed) {
      await profileBox.put('profiles', profiles);
    }
    await settings.put(_migrationFlagKey, true);
  }
}
