/// A Word of the Day entry shown to the student each day.
class WordOfDay {
  final String wordEnglish;
  final String wordFilipino;
  final String? exampleSentence;
  final String emoji;
  final String category;
  final DateTime date;

  const WordOfDay({
    required this.wordEnglish,
    required this.wordFilipino,
    this.exampleSentence,
    required this.emoji,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'wordEnglish': wordEnglish,
        'wordFilipino': wordFilipino,
        'exampleSentence': exampleSentence,
        'emoji': emoji,
        'category': category,
        'date': date.toIso8601String(),
      };

  factory WordOfDay.fromJson(Map<String, dynamic> json) {
    return WordOfDay(
      wordEnglish: json['wordEnglish'] as String,
      wordFilipino: json['wordFilipino'] as String,
      exampleSentence: json['exampleSentence'] as String?,
      emoji: json['emoji'] as String? ?? '📝',
      category: json['category'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
    );
  }
}

/// Tracks which Word of the Day entries the user has viewed / learned.
class WordOfDayHistory {
  final String profileId;
  final List<WordOfDayRecord> records;

  const WordOfDayHistory({
    required this.profileId,
    this.records = const [],
  });

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'records': records.map((r) => r.toJson()).toList(),
      };

  factory WordOfDayHistory.fromJson(Map<String, dynamic> json) {
    return WordOfDayHistory(
      profileId: json['profileId'] as String,
      records: (json['records'] as List?)
              ?.map((r) =>
                  WordOfDayRecord.fromJson(Map<String, dynamic>.from(r as Map)))
              .toList() ??
          [],
    );
  }
}

/// A single day's record of whether the word was viewed/learned.
class WordOfDayRecord {
  final String dateKey; // yyyy-MM-dd
  final String wordEnglish;
  final bool learned;

  const WordOfDayRecord({
    required this.dateKey,
    required this.wordEnglish,
    this.learned = false,
  });

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'wordEnglish': wordEnglish,
        'learned': learned,
      };

  factory WordOfDayRecord.fromJson(Map<String, dynamic> json) {
    return WordOfDayRecord(
      dateKey: json['dateKey'] as String,
      wordEnglish: json['wordEnglish'] as String,
      learned: json['learned'] as bool? ?? false,
    );
  }
}
