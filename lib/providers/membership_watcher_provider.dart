import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/firebase_service.dart';

/// Live boolean: does the learner profile [profileId] still have a
/// `classroom_members` row? Emits `true` while at least one membership
/// exists, `false` once the row is deleted by the teacher.
///
/// Used by [MembershipEvictionGate] on the learner's device so a teacher
/// pressing "Remove from class" results in the learner being signed out
/// of that profile and shown the membership-removed screen.
///
/// On devices where Firebase isn't configured (single-device demo, or
/// an offline launch), the stream short-circuits to `Stream.value(true)`
/// so we never spuriously evict. Real eviction requires a Firestore
/// snapshot proving the row is gone.
final classroomMembershipExistsProvider =
    StreamProvider.family<bool, String>((ref, profileId) {
  if (!FirebaseService.isConfigured) return Stream.value(true);
  return FirebaseService.db
      .collection('classroom_members')
      .where('profile_id', isEqualTo: profileId)
      .snapshots()
      .map((s) => s.docs.isNotEmpty);
});

/// Mirror for home-group memberships. Same semantics as
/// [classroomMembershipExistsProvider] — used by the parent-side
/// eviction flow.
final homeGroupMembershipExistsProvider =
    StreamProvider.family<bool, String>((ref, profileId) {
  if (!FirebaseService.isConfigured) return Stream.value(true);
  return FirebaseService.db
      .collection('home_group_members')
      .where('profile_id', isEqualTo: profileId)
      .snapshots()
      .map((s) => s.docs.isNotEmpty);
});
