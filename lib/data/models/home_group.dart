import 'enums.dart';

/// A home group owned by a parent (the family equivalent of a classroom).
///
/// Children join by entering [code]. The code can be regenerated without
/// changing [id], so existing memberships survive a code reset. Mirrors
/// the [Classroom] model so the join-code / membership infrastructure can
/// be reused with minimal duplication.
class HomeGroup {
  final String id;
  final String code;
  final String name;
  /// `profile_id` of the parent who owns the group. We key on profileId
  /// (not auth uid) to match how classrooms reference their teacher,
  /// which lets the same security-rule helper pattern work for both.
  final String ownerProfileId;

  /// Accessibility audience this group serves. Chosen by the parent at
  /// creation time and auto-assigned to every child who joins via [code],
  /// mirroring [Classroom.accessibility]. Defaults to [DisabilityType.none]
  /// for legacy groups that predate this field.
  final DisabilityType accessibility;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HomeGroup({
    required this.id,
    required this.code,
    required this.name,
    required this.ownerProfileId,
    this.accessibility = DisabilityType.none,
    required this.createdAt,
    required this.updatedAt,
  });

  HomeGroup copyWith({
    String? id,
    String? code,
    String? name,
    String? ownerProfileId,
    DisabilityType? accessibility,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HomeGroup(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      ownerProfileId: ownerProfileId ?? this.ownerProfileId,
      accessibility: accessibility ?? this.accessibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Snake_case keys to match the Firestore `home_groups` collection.
  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'owner_profile_id': ownerProfileId,
        'accessibility': accessibility.index,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory HomeGroup.fromJson(Map<String, dynamic> json) {
    return HomeGroup(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      ownerProfileId: json['owner_profile_id'] as String,
      accessibility: DisabilityType.values[
          ((json['accessibility'] as int?) ?? DisabilityType.none.index)
              .clamp(0, DisabilityType.values.length - 1)],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
