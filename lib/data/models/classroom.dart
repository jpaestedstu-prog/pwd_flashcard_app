import 'enums.dart';

/// A classroom owned by a teacher (or parent acting as a teacher).
///
/// Students join by entering [code]. The code can be regenerated without
/// changing [id], so existing memberships survive a code reset.
class Classroom {
  final String id;
  final String code;
  final String name;
  final String teacherId;

  /// Accessibility audience this class serves. Chosen by the teacher at
  /// creation time and auto-assigned to every student who joins via [code]
  /// (see `post_join_setup_screen.dart`), so learners no longer self-select
  /// in a wizard. Defaults to [DisabilityType.none] for legacy classes that
  /// predate this field.
  final DisabilityType accessibility;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Classroom({
    required this.id,
    required this.code,
    required this.name,
    required this.teacherId,
    this.accessibility = DisabilityType.none,
    required this.createdAt,
    required this.updatedAt,
  });

  Classroom copyWith({
    String? id,
    String? code,
    String? name,
    String? teacherId,
    DisabilityType? accessibility,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Classroom(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      teacherId: teacherId ?? this.teacherId,
      accessibility: accessibility ?? this.accessibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Snake_case keys to match the Firestore `classrooms` collection.
  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'teacher_id': teacherId,
        'accessibility': accessibility.index,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Classroom.fromJson(Map<String, dynamic> json) {
    return Classroom(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      teacherId: json['teacher_id'] as String,
      accessibility: DisabilityType.values[
          ((json['accessibility'] as int?) ?? DisabilityType.none.index)
              .clamp(0, DisabilityType.values.length - 1)],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
