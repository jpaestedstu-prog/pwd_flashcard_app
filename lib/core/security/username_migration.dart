import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/local/hive_service.dart';
import '../../data/local/local_repository.dart';
import '../services/firebase_service.dart';

/// Migration that mints a `username` for every existing profile **and**
/// keeps the cloud directory backfill self-healing.
///
/// Pre-username profiles have `username == null`. The messaging "add
/// friend by username" flow needs every targetable profile to be present
/// in `profile_directory`, so we walk every local profile and re-save
/// it through [LocalRepository.saveProfile] — which mints the handle and
/// upserts the directory entry in the same call.
///
/// **Why two phases (v1 + v2 backfill):** the original v1 sweep ran
/// before Firestore rules were deployed on real installs. The local
/// mints succeeded, but every `profiles/{id}` and `profile_directory/{handle}`
/// cloud write was silently denied — and v1 flipped its done-flag anyway,
/// leaving those profiles unfindable cross-device forever. The v2
/// backfill below re-saves every non-player profile **regardless** of
/// whether it already has a username, which idempotently fills any
/// missing cloud doc the moment rules are live. Each profile is
/// re-saved at most once per device (gated by v2 flag).
///
/// Safe to call before sign-in: when no Anonymous Auth uid is present,
/// directory writes no-op, both flags stay unset, and we retry on the
/// next launch.
class UsernameMigration {
  static const String _migrationFlagKey = 'username_migration_v1_done';
  static const String _backfillFlagKey = 'username_migration_v2_done';
  static const String _settingsBox = 'settings';

  static Future<void> runIfNeeded() async {
    final settings = Hive.box(_settingsBox);

    // Without an auth uid the directory write would no-op; defer until
    // the next launch to keep the directory consistent with local Hive.
    if (FirebaseService.isConfigured &&
        FirebaseService.currentUid == null) {
      if (kDebugMode) {
        debugPrint('UsernameMigration: skipped — no auth uid yet');
      }
      return;
    }

    final raw = HiveService.getProfiles();
    const repo = LocalRepository();

    // Phase 1: mint usernames for any profile still missing one.
    if (settings.get(_migrationFlagKey, defaultValue: false) != true) {
      var minted = 0;
      for (final data in raw) {
        if ((data['username'] as String?)?.isNotEmpty == true) continue;
        final profile = HiveService.getProfileById(data['id'] as String);
        if (profile == null) continue;
        await repo.saveProfile(profile);
        minted++;
      }
      await settings.put(_migrationFlagKey, true);
      if (kDebugMode) {
        debugPrint('UsernameMigration v1: minted $minted handle(s)');
      }
    }

    // Phase 2: idempotent cloud backfill. Republishes every non-player
    // profile so any previously-denied `profiles/{id}` or
    // `profile_directory/{handle}` write lands now that rules are live.
    if (settings.get(_backfillFlagKey, defaultValue: false) != true) {
      var backfilled = 0;
      for (final data in raw) {
        final id = data['id'] as String?;
        if (id == null) continue;
        final profile = HiveService.getProfileById(id);
        if (profile == null || profile.isGuestPlayer) continue;
        await repo.saveProfile(profile);
        backfilled++;
      }
      await settings.put(_backfillFlagKey, true);
      if (kDebugMode) {
        debugPrint('UsernameMigration v2: backfilled $backfilled profile(s)');
      }
    }
  }

  /// Clear the migration flags so the next launch re-runs both phases.
  /// Intended for support flows ("my messaging isn't working") that need
  /// to force a republish across all local profiles.
  static Future<void> forceRerun() async {
    final settings = Hive.box(_settingsBox);
    await settings.delete(_migrationFlagKey);
    await settings.delete(_backfillFlagKey);
  }
}
