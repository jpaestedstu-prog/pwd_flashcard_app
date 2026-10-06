import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/firebase_service.dart';

/// Whether a membership snapshot still counts as "the learner is a member".
///
/// Rows present: yes. No rows, from the server: no — the educator removed
/// them. No rows, read only from this device's cache: still yes. Offline, a
/// cache that never held the row (a profile set up on another tablet) or has
/// since dropped it (Firestore's cache is size-limited, and the assessment
/// media shares it) reads as "no rows" too, and treating that as a removal
/// signed learners out of their class at a school with no Wi-Fi. The real
/// removal still lands: the server's empty snapshot follows as soon as the
/// tablet is online.
bool membershipStillHolds({required bool hasRows, required bool fromCache}) =>
    hasRows || fromCache;

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
/// snapshot proving the row is gone — from the server, not the cache (see
/// [membershipStillHolds]).
final classroomMembershipExistsProvider =
    StreamProvider.family<bool, String>((ref, profileId) {
  if (!FirebaseService.isConfigured) return Stream.value(true);
  return FirebaseService.db
      .collection('classroom_members')
      .where('profile_id', isEqualTo: profileId)
      .snapshots()
      .map(
        (s) => membershipStillHolds(
          hasRows: s.docs.isNotEmpty,
          fromCache: s.metadata.isFromCache,
        ),
      );
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
      .map(
        (s) => membershipStillHolds(
          hasRows: s.docs.isNotEmpty,
          fromCache: s.metadata.isFromCache,
        ),
      );
});
