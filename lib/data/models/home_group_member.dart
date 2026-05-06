/// Membership row linking a child profile to a home group.
///
/// Composite primary key on (homeGroupId, profileId). [displayName] is the
/// child's name as it appears in the parent's roster — kept separately from
/// `UserProfile.name` so the parent can dedupe collisions (e.g. siblings
/// with the same first name) without rewriting the child's profile.
class HomeGroupMember {
  final String homeGroupId;
  final String profileId;
  final String displayName;
  final DateTime joinedAt;

  const HomeGroupMember({
    required this.homeGroupId,
    required this.profileId,
    required this.displayName,
    required this.joinedAt,
  });

  HomeGroupMember copyWith({
    String? homeGroupId,
    String? profileId,
    String? displayName,
    DateTime? joinedAt,
  }) {
    return HomeGroupMember(
      homeGroupId: homeGroupId ?? this.homeGroupId,
      profileId: profileId ?? this.profileId,
      displayName: displayName ?? this.displayName,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  /// Snake_case keys to match the Firestore `home_group_members` collection.
  Map<String, dynamic> toJson() => {
        'home_group_id': homeGroupId,
        'profile_id': profileId,
        'display_name': displayName,
        'joined_at': joinedAt.toIso8601String(),
      };

  factory HomeGroupMember.fromJson(Map<String, dynamic> json) {
    return HomeGroupMember(
      homeGroupId: json['home_group_id'] as String,
      profileId: json['profile_id'] as String,
      displayName: json['display_name'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}
