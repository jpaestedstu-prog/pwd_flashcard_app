import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/classroom.dart';
import '../models/classroom_member.dart';
import '../remote/firestore_repository.dart';
import '../repository.dart';
import '../../core/services/firebase_service.dart';
import '../../features/messaging/services/profile_directory_service.dart';
import '../../features/messaging/services/username_generator.dart';
import 'hive_service.dart';

/// Local (on-device) implementation of [DataRepository] backed by Hive.
///
/// Writes go to Hive **first** (offline-first guarantee) and then to
/// Firestore directly when [FirebaseService.isConfigured] — no sync
/// queue, no replay delay. Cloud failures are logged and don't break
/// the local write.
///
/// Player-mode profiles (`isGuestPlayer == true`) are never written
/// remotely — they exist only in the user's local Hive box.
class LocalRepository implements DataRepository {
  const LocalRepository();

  /// Singleton remote handle. Used directly so that any cloud failure
  /// is observable in the same call as the local write — there is no
  /// background queue to silently drop changes.
  static const FirestoreRepository _remote = FirestoreRepository();

  /// Run [op] as a fire-and-forget remote write. Local data is already
  /// safe by the time this is called; cloud failures are logged but not
  /// re-thrown so the UI continues smoothly.
  ///
  /// The op is deliberately **not awaited**. A Firestore write returns a
  /// Future that only completes on server acknowledgement, so awaiting it
  /// meant every caller blocked forever while offline — which froze the
  /// profile switcher: `setProfile` never returned, so the screen never
  /// navigated and tapping a profile silently did nothing with no error to
  /// show for it. Offline-first means the local write is the commit; the
  /// cloud push is an echo. Firestore preserves per-client write ordering,
  /// so later mutations still reach the server behind this one.
  ///
  /// Returns a completed Future so the existing `await` at each call site
  /// stays correct and simply resolves immediately.
  Future<void> _remoteWrite(
      String label, Future<void> Function() op) async {
    if (!FirebaseService.isConfigured) return;
    unawaited(op().catchError((Object e, StackTrace stack) {
      if (kDebugMode) {
        debugPrint('LocalRepository remote write failed ($label): $e');
        debugPrint(stack.toString());
      }
    }));
  }

  // ─── Profiles ──────────────────────────────────────────

  @override
  Future<List<UserProfile>> getProfiles() async {
    final raw = HiveService.getProfiles();
    return raw
        .map((data) => HiveService.getProfileById(data['id'] as String))
        .whereType<UserProfile>()
        .toList();
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    // Stamp the device's anonymous-auth uid the first time a profile is
    // saved. Covers both new profile creation and the migration of pre-auth
    // profiles — every profile-save site flows through this method.
    final uid = FirebaseService.currentUid;
    var stamped = (profile.ownerUid == null && uid != null)
        ? profile.copyWith(ownerUid: () => uid)
        : profile;

    // Mint a messaging handle if this profile doesn't have one yet. The
    // generator checks the live `profile_directory` for collisions, so a
    // resolved handle is safe to claim in the same save cycle. Skipped
    // for player-mode profiles, which never reach the directory.
    if ((stamped.username == null || stamped.username!.isEmpty) &&
        !stamped.isGuestPlayer) {
      try {
        final handle =
            await UsernameGenerator.generateUniqueHandle(stamped.name);
        stamped = stamped.copyWith(username: () => handle);
      } catch (e) {
        // Directory lookup failed (offline / rules). Fall back to a
        // local-only handle so the profile is still creatable; the
        // username migration will reconcile on the next launch.
        stamped = stamped.copyWith(
            username: () => UsernameGenerator.generateHandle(stamped.name));
        if (kDebugMode) {
          debugPrint('LocalRepository.saveProfile: handle fallback ($e)');
        }
      }
    }

    await HiveService.saveProfile(stamped);
    // Player-mode profiles never reach the cloud.
    if (stamped.isGuestPlayer) return;
    // Only push profiles this device owns. A teacher/parent can view (and
    // therefore locally cache) a class member's profile owned by another
    // user; the security rules correctly deny non-owner writes, which
    // otherwise surface as `permission-denied` noise on back-navigation.
    // Cache such foreign profiles locally, but never remote-write them.
    if (uid != null && stamped.ownerUid != null && stamped.ownerUid != uid) {
      return;
    }
    await _remoteWrite('saveProfile', () => _remote.saveProfile(stamped));
    // Publish to the public messaging directory so other devices can
    // resolve this profile by username or by id.
    await _remoteWrite('profileDirectoryUpsert',
        () => ProfileDirectoryService.instance.upsert(stamped));
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    // Snapshot the profile so we can decide whether to push the remote
    // delete *before* we wipe it locally — guest profiles never reached
    // Firestore in the first place.
    final wasGuest =
        HiveService.getProfileById(profileId)?.isGuestPlayer ?? false;
    await HiveService.deleteProfile(profileId);
    if (wasGuest) return;
    await _remoteWrite(
        'deleteProfile', () => _remote.deleteProfile(profileId));
  }

  @override
  Future<String?> getActiveProfileId() async =>
      HiveService.getActiveProfileId();

  @override
  Future<void> setActiveProfileId(String id) async {
    await HiveService.setActiveProfileId(id);
    // Active profile is a per-device concern; no remote sync needed.
  }

  // ─── Settings ──────────────────────────────────────────

  @override
  Future<AppSettings> getSettings() async => HiveService.getSettings();

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await HiveService.saveSettings(settings);
    await _remoteWrite('saveSettings', () => _remote.saveSettings(settings));
  }

  // ─── Progress ──────────────────────────────────────────

  @override
  Future<LearningProgress> getProgress(String profileId) async =>
      HiveService.getProgress(profileId);

  @override
  Future<void> saveProgress(LearningProgress progress) async {
    await HiveService.saveProgress(progress);
    await _remoteWrite('saveProgress', () => _remote.saveProgress(progress));
  }

  // ─── Custom Cards ──────────────────────────────────────

  @override
  Future<List<Flashcard>> getCustomCards() async =>
      HiveService.getCustomCards();

  @override
  Future<void> saveCustomCard(Flashcard card) async {
    await HiveService.saveCustomCard(card);
    await _remoteWrite('saveCustomCard', () => _remote.saveCustomCard(card));
  }

  @override
  Future<void> deleteCustomCard(String cardId) async {
    await HiveService.deleteCustomCard(cardId);
    await _remoteWrite(
        'deleteCustomCard', () => _remote.deleteCustomCard(cardId));
  }

  // ─── Achievements ─────────────────────────────────────

  @override
  Future<Set<String>> getUnlockedAchievements(String profileId) async =>
      HiveService.getUnlockedAchievements(profileId);

  @override
  Future<void> saveUnlockedAchievements(
      String profileId, Set<String> achievementIds) async {
    await HiveService.saveUnlockedAchievements(profileId, achievementIds);
    await _remoteWrite('saveUnlockedAchievements',
        () => _remote.saveUnlockedAchievements(profileId, achievementIds));
  }

  // ─── Shop ─────────────────────────────────────────────

  @override
  Future<Set<String>> getPurchasedItems(String profileId) async =>
      HiveService.getPurchasedItems(profileId);

  @override
  Future<void> savePurchasedItems(
      String profileId, Set<String> itemIds) async {
    await HiveService.savePurchasedItems(profileId, itemIds);
    await _remoteWrite('savePurchasedItems',
        () => _remote.savePurchasedItems(profileId, itemIds));
  }

  @override
  Future<String?> getEquippedItem(String profileId, String type) async =>
      HiveService.getEquippedItem(profileId, type);

  @override
  Future<void> saveEquippedItem(
      String profileId, String type, String? itemId) async {
    await HiveService.saveEquippedItem(profileId, type, itemId);
    await _remoteWrite('saveEquippedItem',
        () => _remote.saveEquippedItem(profileId, type, itemId));
  }

  // ─── Tutorial / Daily Challenge ───────────────────────

  @override
  Future<bool> hasSeenTutorial(String profileId) async =>
      HiveService.hasSeenTutorial(profileId);

  @override
  Future<void> markTutorialSeen(String profileId) async {
    await HiveService.markTutorialSeen(profileId);
    await _remoteWrite(
        'markTutorialSeen', () => _remote.markTutorialSeen(profileId));
  }

  @override
  Future<String?> getDailyChallengeDate(String profileId) async =>
      HiveService.getDailyChallengeDate(profileId);

  @override
  Future<void> saveDailyChallengeDate(String profileId, String date) async {
    await HiveService.saveDailyChallengeDate(profileId, date);
    await _remoteWrite('saveDailyChallengeDate',
        () => _remote.saveDailyChallengeDate(profileId, date));
  }

  @override
  Future<int> getDailyChallengeStreak(String profileId) async =>
      HiveService.getDailyChallengeStreak(profileId);

  // ─── Aggregate ────────────────────────────────────────

  @override
  Future<List<(UserProfile, LearningProgress)>>
      getAllProfilesWithProgress() async =>
          HiveService.getAllProfilesWithProgress();

  // ─── Session Analytics ────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getSessionLogs(String profileId) async =>
      HiveService.getSessionLogs(profileId);

  @override
  Future<void> addSessionLog(
      String profileId, Map<String, dynamic> session) async {
    await HiveService.addSessionLog(profileId, session);
    await _remoteWrite('addSessionLog',
        () => _remote.addSessionLog(profileId, session));
  }

  // ─── Classrooms ────────────────────────────────────────

  @override
  Future<Classroom> createClassroom(Classroom classroom) async {
    await HiveService.cacheClassroom(classroom);
    await _remoteWrite(
        'createClassroom', () => _remote.createClassroom(classroom));
    return classroom;
  }

  @override
  Future<Classroom?> getClassroomById(String classroomId) async {
    return HiveService.getCachedClassroom(classroomId);
  }

  @override
  Future<Classroom?> getClassroomByCode(String code) async {
    return HiveService.getCachedClassroomByCode(code);
  }

  @override
  Future<List<Classroom>> getClassroomsByTeacher(String teacherId) async {
    return HiveService.getClassroomsByTeacher(teacherId);
  }

  @override
  Future<void> updateClassroom(Classroom classroom) async {
    await HiveService.cacheClassroom(classroom);
    await _remoteWrite(
        'updateClassroom', () => _remote.updateClassroom(classroom));
  }

  @override
  Future<void> deleteClassroom(String classroomId) async {
    await HiveService.deleteClassroomLocal(classroomId);
    await _remoteWrite(
        'deleteClassroom', () => _remote.deleteClassroom(classroomId));
  }

  @override
  Future<void> addMember(ClassroomMember member) async {
    await HiveService.addMemberLocal(member);
    await _remoteWrite('addMember', () => _remote.addMember(member));
  }

  @override
  Future<List<ClassroomMember>> listMembers(String classroomId) async {
    return HiveService.getMembers(classroomId);
  }

  @override
  Future<void> removeMember(String classroomId, String profileId) async {
    await HiveService.removeMemberLocal(classroomId, profileId);
    await _remoteWrite('removeMember',
        () => _remote.removeMember(classroomId, profileId));
  }

  // ─── Data Management ──────────────────────────────────

  @override
  Future<void> clearAllData() async {
    await HiveService.clearAllData();
  }
}
