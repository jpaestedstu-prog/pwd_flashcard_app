import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// What a learner's `profiles/{id}` document may hold. Any signed-in user who
/// knows the id can read it (a teacher's roster, a friend's name, the
/// recovery flow), so it carries only what other devices use.
///
/// Until 1.4.1 the class and family-group joins also copied the PIN hash, its
/// salt and algorithm, the birth date and the grade level there. No version
/// ever read them back from the cloud (each device keeps its own), so they
/// were only an exposure: a 4-digit PIN falls to a brute force of its salted
/// hash in moments.
abstract final class ProfileCloudFields {
  /// Never written to the cloud. Every profile write removes them from the
  /// document, for copies an older version left there.
  static const private = <String>[
    'pin_hash',
    'pin_salt',
    'pin_hash_algorithm',
    'birth_date',
    'grade_level',
  ];

  /// Deletes for [private], for a merge write.
  static Map<String, Object> removals() => {
    for (final field in private) field: FieldValue.delete(),
  };

  /// The profile a learner's device writes when it joins a class, or a family
  /// group when [family]. Written with merge: the rules find a learner's
  /// teacher through `classroom_id` and their parent through
  /// `home_group_id`, and a join used to replace the whole document.
  static Map<String, Object?> forJoin(
    UserProfile profile, {
    required bool family,
  }) => {
    'id': profile.id,
    'name': profile.name,
    'role': profile.role.index,
    'avatar_index': profile.avatarIndex,
    'created_at': profile.createdAt.toIso8601String(),
    'disability_type': profile.disabilityType.index,
    if (family)
      'home_group_id': profile.homeGroupId
    else
      'classroom_id': profile.classroomId,
    'learning_level': profile.learningLevel?.index,
    'is_guest_player': profile.isGuestPlayer,
    'owner_uid': profile.ownerUid,
    ...removals(),
  };
}
