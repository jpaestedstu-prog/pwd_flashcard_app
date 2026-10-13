import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../data/local/hive_service.dart';
import '../../data/models/classroom.dart';
import '../../data/models/home_group.dart';
import 'firebase_service.dart';

/// What a learner's device files for each class or family group it is in.
///
/// * The **group link** `group_readers/{group}_{uid}`, naming one of this
///   device's profiles in the group. Since 1.4.1 the rules let a device read
///   its classmates (the leaderboard), the class or family document and the
///   group's roster only through it.
/// * The learner's place on the teacher's or parent's **roster**
///   (`educator_rosters/{their uid}`), which that device's 30-learner queries
///   and the tests it sets are checked against.
///
/// Filed on joining, and at every start for each group this device's
/// profiles are in (one that joined before 1.4.1, or was restored here).
/// What was filed is remembered, so each is written once per device. The
/// start also refreshes this device's copy of the group document: what the
/// learner's screens read from it (whether a test may be retaken) was
/// otherwise frozen at the moment they joined. Never throws: a refused or
/// offline write is tried again at the next start.
class GroupLinksService {
  const GroupLinksService();

  static const Duration _timeout = Duration(seconds: 8);

  FirebaseFirestore get _db => FirebaseService.db;

  /// Files the group link and the roster place for [profileId] in
  /// [groupId] (a home group when [family]), and refreshes the cached group.
  /// [educatorUid] is the device whose roster to join when the group
  /// document cannot say ([Classroom.teacherUid] / [HomeGroup.ownerUid]); a
  /// group from before 1.4.1 may name none yet, and then the roster place
  /// waits for a start after the teacher's app or the backfill has named it.
  /// [groups] shares group documents already read in this run.
  Future<void> fileFor({
    required String profileId,
    required String groupId,
    required bool family,
    String? educatorUid,
    Map<String, Map<String, dynamic>?>? groups,
  }) async {
    if (!FirebaseService.isConfigured) return;
    final uid = FirebaseService.currentUid;
    if (uid == null || uid.isEmpty || profileId.isEmpty || groupId.isEmpty) {
      return;
    }
    final linkKey = 'group_link::${groupId}_$uid';
    try {
      // One link per device and group: a second profile in the same group
      // keeps the link that names the first, while that one is still in it.
      final linked = HiveService.getSetting(linkKey) as String?;
      if (linked == null || !_stillIn(linked, groupId, family)) {
        await _db.collection('group_readers').doc('${groupId}_$uid').set({
          'group_id': groupId,
          'profile_id': profileId,
          'kind': family ? 'family' : 'class',
          'updated_at': FieldValue.serverTimestamp(),
        }).timeout(_timeout);
        await HiveService.saveSetting(linkKey, profileId);
      }

      // The group document, readable now through the link.
      final cache = groups ?? <String, Map<String, dynamic>?>{};
      final key = '${family ? 'family' : 'class'}/$groupId';
      if (!cache.containsKey(key)) {
        final snap = await _db
            .collection(family ? 'home_groups' : 'classrooms')
            .doc(groupId)
            .get()
            .timeout(_timeout);
        cache[key] = snap.data();
        await refreshGroupCopy(snap.data(), family: family);
      }
      final named = cache[key]?[family ? 'owner_uid' : 'teacher_uid'];
      final educator = named is String && named.isNotEmpty ? named : educatorUid;
      if (educator == null || educator.isEmpty) return;

      final placeKey = 'roster_place::${groupId}_$profileId';
      if (HiveService.getSetting(placeKey) == educator) return;
      await _db.collection('educator_rosters').doc(educator).set({
        'learners': {profileId: uid},
        'via': {profileId: groupId},
        'learner': profileId,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(_timeout);
      await HiveService.saveSetting(placeKey, educator);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GroupLinksService.fileFor($groupId, $profileId): $e');
      }
    }
  }

  /// Replaces this device's copy of a group with [data], the document as
  /// the server has it. A malformed one leaves the old copy.
  @visibleForTesting
  static Future<void> refreshGroupCopy(
    Map<String, dynamic>? data, {
    required bool family,
  }) async {
    if (data == null) return;
    try {
      if (family) {
        await HiveService.cacheHomeGroup(HomeGroup.fromJson(data));
      } else {
        await HiveService.cacheClassroom(Classroom.fromJson(data));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('GroupLinksService: group copy: $e');
    }
  }

  /// Whether this device's profile [profileId] is still in [groupId].
  static bool _stillIn(String profileId, String groupId, bool family) {
    final profile = HiveService.getProfileById(profileId);
    if (profile == null) return false;
    return (family ? profile.homeGroupId : profile.classroomId) == groupId;
  }

  /// Files them for every class and family group this device's own
  /// profiles are in, and refreshes its copy of each. Run at start, after
  /// sign-in.
  Future<void> ensureForDevice() async {
    if (!FirebaseService.isConfigured) return;
    final uid = FirebaseService.currentUid;
    if (uid == null || uid.isEmpty) return;
    final groups = <String, Map<String, dynamic>?>{};
    try {
      for (final raw in HiveService.getProfiles()) {
        final id = raw['id'] as String?;
        if (id == null) continue;
        final profile = HiveService.getProfileById(id);
        if (profile == null || profile.isGuestPlayer) continue;
        if (profile.ownerUid != uid) continue;
        final classroomId = profile.classroomId;
        if (classroomId != null && classroomId.isNotEmpty) {
          await fileFor(
            profileId: id,
            groupId: classroomId,
            family: false,
            groups: groups,
          );
        }
        final homeGroupId = profile.homeGroupId;
        if (homeGroupId != null && homeGroupId.isNotEmpty) {
          await fileFor(
            profileId: id,
            groupId: homeGroupId,
            family: true,
            groups: groups,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('GroupLinksService.ensureForDevice: $e');
    }
  }
}
