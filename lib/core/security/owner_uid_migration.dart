import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/local/hive_service.dart';
import '../../data/local/local_repository.dart';
import '../services/firebase_service.dart';

/// One-shot migration that claims pre-auth profiles for the device's
/// anonymous-auth uid.
///
/// Profiles created before [FirebaseService.signInAnonymously] landed
/// have no `ownerUid`. The new Firestore rules check `owner_uid` on
/// every owner-scoped write, so we re-save each unowned profile through
/// [LocalRepository.saveProfile] — which auto-stamps the current uid
/// and pushes a merge to Firestore so the remote doc gains `owner_uid`
/// too.
///
/// Idempotency is enforced by a Hive flag plus the per-profile null check.
/// Safe to call before sign-in (no-op if uid is null) — the next launch
/// after auth completes will pick up the work.
class OwnerUidMigration {
  static const String _migrationFlagKey = 'owner_uid_migration_v1_done';
  static const String _settingsBox = 'settings';

  static Future<void> runIfNeeded() async {
    final settings = Hive.box(_settingsBox);
    if (settings.get(_migrationFlagKey, defaultValue: false) == true) return;

    final uid = FirebaseService.currentUid;
    if (uid == null) {
      // Auth didn't complete (offline first launch, or Auth disabled).
      // Leave the flag unset so we retry on the next boot.
      if (kDebugMode) {
        debugPrint('OwnerUidMigration: skipped — no auth uid yet');
      }
      return;
    }

    final raw = HiveService.getProfiles();
    const repo = LocalRepository();
    var migrated = 0;

    for (final data in raw) {
      if (data['ownerUid'] != null) continue;
      final profile = HiveService.getProfileById(data['id'] as String);
      if (profile == null) continue;
      // Player-mode profiles never reach the cloud; just stamp locally
      // so the field is non-null going forward.
      await repo.saveProfile(profile);
      migrated++;
    }

    await settings.put(_migrationFlagKey, true);
    if (kDebugMode) {
      debugPrint('OwnerUidMigration: claimed $migrated profile(s) for $uid');
    }
  }
}
