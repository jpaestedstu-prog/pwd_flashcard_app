import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/local/hive_service.dart';
import '../../data/local/local_repository.dart';
import '../../features/messaging/services/profile_directory_service.dart';
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
  static const String _strongHandlesFlagKey = 'username_migration_v3_done';
  static bool _strengthening = false;
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

    // Not awaited: a round trip or more per profile, and startup waits on
    // this method before it opens the sync pipes. It retries by itself.
    unawaited(_strengthenHandles(settings));
  }

  /// A handle minted before 1.2.3: four digits after the name. That left
  /// 10,000 handles per first name, and every directory entry names its
  /// learner and their disability — few enough for a stranger to try them
  /// all. The six-digit ones (and the UUID fallback) are not matched.
  static bool hasWeakHandle(String? username) =>
      username != null && RegExp(r'-\d{4}$').hasMatch(username);

  /// Phase 3 (1.2.3): gives every profile this device owns a six-digit
  /// handle in place of a four-digit one, and takes the old handle out of
  /// the public directory. Flagged done only once the server has confirmed
  /// every step — an offline launch leaves the old entry findable, so it
  /// simply tries again next time.
  static Future<void> _strengthenHandles(Box<dynamic> settings) async {
    if (_strengthening) return;
    if (settings.get(_strongHandlesFlagKey, defaultValue: false) == true) {
      return;
    }
    if (!FirebaseService.isConfigured) return;
    final uid = FirebaseService.currentUid;
    if (uid == null) return;
    _strengthening = true;
    const repo = LocalRepository();
    final directory = ProfileDirectoryService.instance;
    try {
      var replaced = 0;
      for (final data in HiveService.getProfiles()) {
        final id = data['id'] as String?;
        if (id == null) continue;
        var profile = HiveService.getProfileById(id);
        if (profile == null || profile.isGuestPlayer) continue;
        // A profile another device owns, cached here: its owner replaces it.
        if (profile.ownerUid != null && profile.ownerUid != uid) continue;
        final old = profile.username;
        if (hasWeakHandle(old)) {
          await directory.deleteIfNamesProfile(old!, profile.id);
          await HiveService.saveProfile(profile.copyWith(username: () => null));
          // Re-publishing mints the new handle and claims its entry.
          await repo.saveProfile(HiveService.getProfileById(id)!);
          profile = HiveService.getProfileById(id)!;
          replaced++;
        }
        final handle = profile.username;
        if (handle == null || handle.isEmpty) continue;
        if (!await directory.namesProfileOnServer(handle, profile.id)) {
          await directory.upsert(profile);
          if (!await directory.namesProfileOnServer(handle, profile.id)) {
            throw StateError('no directory entry for ${profile.id} yet');
          }
        }
      }
      await settings.put(_strongHandlesFlagKey, true);
      if (kDebugMode) {
        debugPrint('UsernameMigration v3: replaced $replaced handle(s)');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('UsernameMigration v3: retry next launch ($e)');
    } finally {
      _strengthening = false;
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
