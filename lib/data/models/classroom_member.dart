/// Membership row linking a student profile to a classroom.
///
/// Composite primary key on (classroomId, profileId). [displayName] is
/// the student's name as it appears in the teacher's roster — kept
/// separately from `UserProfile.name` so a teacher can dedupe collisions
/// (e.g. "Maria (2)") without rewriting the student's own profile name.
class ClassroomMember {
  final String classroomId;
  final String profileId;
  final String displayName;
  final DateTime joinedAt;

  const ClassroomMember({
    required this.classroomId,
    required this.profileId,
    required this.displayName,
    required this.joinedAt,
  });

  ClassroomMember copyWith({
    String? classroomId,
    String? profileId,
    String? displayName,
    DateTime? joinedAt,
  }) {
    return ClassroomMember(
      classroomId: classroomId ?? this.classroomId,
      profileId: profileId ?? this.profileId,
      displayName: displayName ?? this.displayName,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  /// Snake_case keys to match the Firestore `classroom_members` collection.
  Map<String, dynamic> toJson() => {
        'classroom_id': classroomId,
        'profile_id': profileId,
        'display_name': displayName,
        'joined_at': joinedAt.toIso8601String(),
      };

  factory ClassroomMember.fromJson(Map<String, dynamic> json) {
    return ClassroomMember(
      classroomId: json['classroom_id'] as String,
      profileId: json['profile_id'] as String,
      displayName: json['display_name'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}
