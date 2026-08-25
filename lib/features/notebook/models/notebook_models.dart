import '../../../data/models/enums.dart';

/// A note that does not exist yet, pre-filled from wherever the learner
/// started writing it.
///
/// The notebook could only ever be entered from its own "New Note" button, so
/// a note about a word was always written away from the word — the learner had
/// to leave the card, open the notebook, and type the word again from memory.
/// This carries that context across, and is what makes
/// [NoteEntry.linkedFlashcardIds] get filled in without the learner going
/// looking for the picker.
///
/// Passed as go_router `extra`. The editor route accepts either this or a
/// [NoteEntry]; see the `is` checks there — an unexpected `extra` type must
/// never throw or silently render the wrong screen.
class NoteDraft {
  /// Pre-filled title, so writing about "Rice" does not start by typing
  /// "Rice".
  final String? title;

  /// Files the note under the word's own category by default.
  final FlashcardCategory? category;

  /// The cards this note is about.
  final List<String> linkedFlashcardIds;

  const NoteDraft({
    this.title,
    this.category,
    this.linkedFlashcardIds = const [],
  });
}

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
