import '../../../data/models/enums.dart';

/// A single study note in the student's notebook.
class NoteEntry {
  final String id;
  final String title;
  final String content;
  final FlashcardCategory? category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVoiceNote;
  final List<String> linkedFlashcardIds;

  const NoteEntry({
    required this.id,
    required this.title,
    required this.content,
    this.category,
    required this.createdAt,
    required this.updatedAt,
    this.isVoiceNote = false,
    this.linkedFlashcardIds = const [],
  });

  NoteEntry copyWith({
    String? id,
    String? title,
    String? content,
    FlashcardCategory? Function()? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isVoiceNote,
    List<String>? linkedFlashcardIds,
  }) {
    return NoteEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category != null ? category() : this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isVoiceNote: isVoiceNote ?? this.isVoiceNote,
      linkedFlashcardIds: linkedFlashcardIds ?? this.linkedFlashcardIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'category': category?.index,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isVoiceNote': isVoiceNote,
    'linkedFlashcardIds': linkedFlashcardIds,
  };

  factory NoteEntry.fromJson(Map<String, dynamic> json) {
    final catIndex = json['category'] as int?;
    return NoteEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: catIndex != null &&
              catIndex >= 0 &&
              catIndex < FlashcardCategory.values.length
          ? FlashcardCategory.values[catIndex]
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isVoiceNote: json['isVoiceNote'] as bool? ?? false,
      linkedFlashcardIds: List<String>.from(
          json['linkedFlashcardIds'] as List? ?? []),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
