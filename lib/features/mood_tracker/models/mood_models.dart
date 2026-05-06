import 'package:flutter/material.dart';

/// Mood options for check-in
enum MoodType {
  happy,
  excited,
  neutral,
  tired,
  sad,
  frustrated,
}

extension MoodTypeX on MoodType {
  String get label => switch (this) {
        MoodType.happy => 'Happy',
        MoodType.excited => 'Excited',
        MoodType.neutral => 'Okay',
        MoodType.tired => 'Tired',
        MoodType.sad => 'Sad',
        MoodType.frustrated => 'Frustrated',
      };

  String get labelFilipino => switch (this) {
        MoodType.happy => 'Masaya',
        MoodType.excited => 'Excited',
        MoodType.neutral => 'Ayos lang',
        MoodType.tired => 'Pagod',
        MoodType.sad => 'Malungkot',
        MoodType.frustrated => 'Frustrated',
      };

  String get emoji => switch (this) {
        MoodType.happy => '😊',
        MoodType.excited => '🤩',
        MoodType.neutral => '😐',
        MoodType.tired => '😴',
        MoodType.sad => '😢',
        MoodType.frustrated => '😤',
      };

  Color get color => switch (this) {
        MoodType.happy => const Color(0xFFFFD54F),
        MoodType.excited => const Color(0xFFFF8A65),
        MoodType.neutral => const Color(0xFF90CAF9),
        MoodType.tired => const Color(0xFFB0BEC5),
        MoodType.sad => const Color(0xFF80DEEA),
        MoodType.frustrated => const Color(0xFFEF5350),
      };

  Color get darkColor => switch (this) {
        MoodType.happy => const Color(0xFFFBC02D),
        MoodType.excited => const Color(0xFFE64A19),
        MoodType.neutral => const Color(0xFF42A5F5),
        MoodType.tired => const Color(0xFF78909C),
        MoodType.sad => const Color(0xFF26C6DA),
        MoodType.frustrated => const Color(0xFFC62828),
      };

  IconData get icon => switch (this) {
        MoodType.happy => Icons.sentiment_satisfied_alt_rounded,
        MoodType.excited => Icons.celebration_rounded,
        MoodType.neutral => Icons.sentiment_neutral_rounded,
        MoodType.tired => Icons.bedtime_rounded,
        MoodType.sad => Icons.sentiment_dissatisfied_rounded,
        MoodType.frustrated => Icons.sentiment_very_dissatisfied_rounded,
      };

  /// Numeric value for charting (1 = worst, 6 = best)
  int get numericValue => switch (this) {
        MoodType.frustrated => 1,
        MoodType.sad => 2,
        MoodType.tired => 3,
        MoodType.neutral => 4,
        MoodType.happy => 5,
        MoodType.excited => 6,
      };
}

/// A single mood check-in entry
class MoodEntry {
  final String id;
  final String profileId;
  final MoodType mood;
  final String? note;
  final DateTime timestamp;
  final String? activityContext; // e.g. 'after_game', 'start_session', 'end_session'

  const MoodEntry({
    required this.id,
    required this.profileId,
    required this.mood,
    this.note,
    required this.timestamp,
    this.activityContext,
  });

  MoodEntry copyWith({
    String? id,
    String? profileId,
    MoodType? mood,
    String? Function()? note,
    DateTime? timestamp,
    String? Function()? activityContext,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      mood: mood ?? this.mood,
      note: note != null ? note() : this.note,
      timestamp: timestamp ?? this.timestamp,
      activityContext:
          activityContext != null ? activityContext() : this.activityContext,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'mood': mood.index,
        'note': note,
        'timestamp': timestamp.toIso8601String(),
        'activityContext': activityContext,
      };

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    final moodIndex = json['mood'] as int;
    return MoodEntry(
      id: json['id'] as String,
      profileId: json['profileId'] as String,
      mood: (moodIndex >= 0 && moodIndex < MoodType.values.length)
          ? MoodType.values[moodIndex]
          : MoodType.neutral,
      note: json['note'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      activityContext: json['activityContext'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
