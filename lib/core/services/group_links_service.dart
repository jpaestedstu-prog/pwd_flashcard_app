import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../data/local/hive_service.dart';
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
/// What was filed is remembered, so each is written once per device. Never
/// throws: a refused or offline write is tried again at the next start.
class GroupLinksService {
  const GroupLinksService();

  static const Duration _timeout = Duration(seconds: 8);

  FirebaseFirestore get _db => FirebaseService.db;

  /// Files the group link and the roster place for [profileId] in
  /// [groupId] (a home group when [family]). [educatorUid] is the device
  /// whose roster to join ([Classroom.teacherUid] / [HomeGroup.ownerUid]);
  /// when it is not known it is read from the group document, which the
  /// link has just made readable. A group from before 1.4.1 may not name
  /// one yet: then only the link is filed, and the roster place waits for
  /// a start after the teacher's app or the backfill has named it.
  Future<void> fileFor({
    required String profileId,
    required String groupId,
    required bool family,
    String? educatorUid,
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

      final placeKey = 'roster_place::${groupId}_$profileId';
      var educator = educatorUid;
      if (educator == null || educator.isEmpty) {
        final group = await _db
            .collection(family ? 'home_groups' : 'classrooms')
            .doc(groupId)
            .get()
            .timeout(_timeout);
        educator = group.data()?[family ? 'owner_uid' : 'teacher_uid']
            as String?;
      }
      if (educator == null || educator.isEmpty) return;
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

  /// Whether this device's profile [profileId] is still in [groupId].
  static bool _stillIn(String profileId, String groupId, bool family) {
    final profile = HiveService.getProfileById(profileId);
    if (profile == null) return false;
    return (family ? profile.homeGroupId : profile.classroomId) == groupId;
  }

  /// Files them for every class and family group this device's own
  /// profiles are in. Run at start, after sign-in.
  Future<void> ensureForDevice() async {
    if (!FirebaseService.isConfigured) return;
    final uid = FirebaseService.currentUid;
    if (uid == null || uid.isEmpty) return;
    try {
      for (final raw in HiveService.getProfiles()) {
        final id = raw['id'] as String?;
        if (id == null) continue;
        final profile = HiveService.getProfileById(id);
        if (profile == null || profile.isGuestPlayer) continue;
        if (profile.ownerUid != uid) continue;
        final classroomId = profile.classroomId;
        if (classroomId != null && classroomId.isNotEmpty) {
          await fileFor(profileId: id, groupId: classroomId, family: false);
        }
        final homeGroupId = profile.homeGroupId;
        if (homeGroupId != null && homeGroupId.isNotEmpty) {
          await fileFor(profileId: id, groupId: homeGroupId, family: true);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('GroupLinksService.ensureForDevice: $e');
    }
  }
}
