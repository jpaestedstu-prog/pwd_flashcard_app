/// Focus Mode models — Pomodoro-style structured learning timer.
library;

/// Preset focus durations.
enum FocusDuration {
  short,
  medium,
  long,
  custom,
}

extension FocusDurationX on FocusDuration {
  String get label => switch (this) {
        FocusDuration.short => '10 min',
        FocusDuration.medium => '20 min',
        FocusDuration.long => '30 min',
        FocusDuration.custom => 'Custom',
      };

  String get labelFilipino => switch (this) {
        FocusDuration.short => '10 min',
        FocusDuration.medium => '20 min',
        FocusDuration.long => '30 min',
        FocusDuration.custom => 'Pasadya',
      };

  String get emoji => switch (this) {
        FocusDuration.short => '⚡',
        FocusDuration.medium => '⏱️',
        FocusDuration.long => '🎯',
        FocusDuration.custom => '⚙️',
      };

  /// Default minutes for non-custom durations.
  int get defaultMinutes => switch (this) {
        FocusDuration.short => 10,
        FocusDuration.medium => 20,
        FocusDuration.long => 30,
        FocusDuration.custom => 15,
      };
}

/// A single completed focus session.
class FocusSession {
  final String id;
  final String profileId;
  final int durationMinutes;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool completed;
  final int starsEarned;

  const FocusSession({
    required this.id,
    required this.profileId,
    required this.durationMinutes,
    required this.startedAt,
    this.endedAt,
    this.completed = false,
    this.starsEarned = 0,
  });

  FocusSession copyWith({
    DateTime? endedAt,
    bool? completed,
    int? starsEarned,
  }) {
    return FocusSession(
      id: id,
      profileId: profileId,
      durationMinutes: durationMinutes,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      completed: completed ?? this.completed,
      starsEarned: starsEarned ?? this.starsEarned,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'durationMinutes': durationMinutes,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'completed': completed,
        'starsEarned': starsEarned,
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      id: json['id'] as String,
      profileId: json['profileId'] as String,
      durationMinutes: json['durationMinutes'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
      completed: json['completed'] as bool? ?? false,
      starsEarned: json['starsEarned'] as int? ?? 0,
    );
  }
}
