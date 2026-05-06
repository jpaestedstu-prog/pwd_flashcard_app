/// Parent-Teacher Notes — shared notes between educators and parents
/// about a student's learning progress and behaviour.
library;

enum NoteCategory {
  general,
  progress,
  behaviour,
  suggestion,
  concern,
}

extension NoteCategoryX on NoteCategory {
  String get label => switch (this) {
        NoteCategory.general => 'General',
        NoteCategory.progress => 'Progress',
        NoteCategory.behaviour => 'Behaviour',
        NoteCategory.suggestion => 'Suggestion',
        NoteCategory.concern => 'Concern',
      };

  String get labelFilipino => switch (this) {
        NoteCategory.general => 'Pangkalahatan',
        NoteCategory.progress => 'Pag-unlad',
        NoteCategory.behaviour => 'Pag-uugali',
        NoteCategory.suggestion => 'Mungkahi',
        NoteCategory.concern => 'Alalahanin',
      };

  String get emoji => switch (this) {
        NoteCategory.general => '📝',
        NoteCategory.progress => '📈',
        NoteCategory.behaviour => '🌟',
        NoteCategory.suggestion => '💡',
        NoteCategory.concern => '⚠️',
      };
}

/// A shared note between parent and teacher about a student.
class ParentTeacherNote {
  final String id;
  final String authorProfileId;
  final String authorName;
  final String studentProfileId;
  final String content;
  final NoteCategory category;
  final DateTime createdAt;
  final bool isRead;

  const ParentTeacherNote({
    required this.id,
    required this.authorProfileId,
    required this.authorName,
    required this.studentProfileId,
    required this.content,
    this.category = NoteCategory.general,
    required this.createdAt,
    this.isRead = false,
  });

  ParentTeacherNote copyWith({
    bool? isRead,
  }) {
    return ParentTeacherNote(
      id: id,
      authorProfileId: authorProfileId,
      authorName: authorName,
      studentProfileId: studentProfileId,
      content: content,
      category: category,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorProfileId': authorProfileId,
        'authorName': authorName,
        'studentProfileId': studentProfileId,
        'content': content,
        'category': category.index,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

  factory ParentTeacherNote.fromJson(Map<String, dynamic> json) {
    final catIndex = json['category'] as int? ?? 0;
    return ParentTeacherNote(
      id: json['id'] as String,
      authorProfileId: json['authorProfileId'] as String,
      authorName: json['authorName'] as String? ?? 'Unknown',
      studentProfileId: json['studentProfileId'] as String,
      content: json['content'] as String,
      category: (catIndex >= 0 && catIndex < NoteCategory.values.length)
          ? NoteCategory.values[catIndex]
          : NoteCategory.general,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}
