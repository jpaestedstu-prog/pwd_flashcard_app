/// Types of alerts that can be triggered for parent/teacher monitoring.
enum AlertType {
  /// Student accuracy dropped below threshold.
  lowAccuracy,

  /// Student broke their streak (no activity for 1+ days).
  streakBroken,

  /// Student has been inactive for N days.
  inactivity,

  /// An assigned assessment is overdue.
  assignmentOverdue,

  /// Student earned a new achievement.
  achievementEarned,

  /// Student completed an assessment.
  assessmentCompleted,
}

extension AlertTypeX on AlertType {
  String get label => switch (this) {
    AlertType.lowAccuracy => 'Low Accuracy',
    AlertType.streakBroken => 'Streak Broken',
    AlertType.inactivity => 'Inactivity',
    AlertType.assignmentOverdue => 'Assignment Overdue',
    AlertType.achievementEarned => 'Achievement Earned',
    AlertType.assessmentCompleted => 'Assessment Completed',
  };

  String get emoji => switch (this) {
    AlertType.lowAccuracy => '📉',
    AlertType.streakBroken => '🔥',
    AlertType.inactivity => '💤',
    AlertType.assignmentOverdue => '⏰',
    AlertType.achievementEarned => '🏆',
    AlertType.assessmentCompleted => '✅',
  };

  /// Whether this is a negative alert (concerning) vs positive.
  bool get isConcerning => switch (this) {
    AlertType.lowAccuracy => true,
    AlertType.streakBroken => true,
    AlertType.inactivity => true,
    AlertType.assignmentOverdue => true,
    AlertType.achievementEarned => false,
    AlertType.assessmentCompleted => false,
  };
}

/// Configuration for when alerts should be triggered.
class AlertConfig {
  /// Whether alerts are enabled globally.
  final bool enabled;

  /// Minimum accuracy threshold (0.0–1.0). Alert if student falls below.
  final double accuracyThreshold;

  /// Number of inactive days before alerting.
  final int inactivityDays;

  /// Which alert types are enabled.
  final Set<AlertType> enabledTypes;

  const AlertConfig({
    this.enabled = true,
    this.accuracyThreshold = 0.5,
    this.inactivityDays = 3,
    this.enabledTypes = const {
      AlertType.lowAccuracy,
      AlertType.streakBroken,
      AlertType.inactivity,
      AlertType.assignmentOverdue,
      AlertType.achievementEarned,
      AlertType.assessmentCompleted,
    },
  });

  AlertConfig copyWith({
    bool? enabled,
    double? accuracyThreshold,
    int? inactivityDays,
    Set<AlertType>? enabledTypes,
  }) {
    return AlertConfig(
      enabled: enabled ?? this.enabled,
      accuracyThreshold: accuracyThreshold ?? this.accuracyThreshold,
      inactivityDays: inactivityDays ?? this.inactivityDays,
      enabledTypes: enabledTypes ?? this.enabledTypes,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'accuracyThreshold': accuracyThreshold,
    'inactivityDays': inactivityDays,
    'enabledTypes': enabledTypes.map((e) => e.index).toList(),
  };

  factory AlertConfig.fromJson(Map<String, dynamic> json) {
    return AlertConfig(
      enabled: json['enabled'] as bool? ?? true,
      accuracyThreshold: (json['accuracyThreshold'] as num?)?.toDouble() ?? 0.5,
      inactivityDays: json['inactivityDays'] as int? ?? 3,
      enabledTypes: (json['enabledTypes'] as List?)
              ?.map((e) => e as int)
              .where((i) => i >= 0 && i < AlertType.values.length)
              .map((i) => AlertType.values[i])
              .toSet() ??
          AlertType.values.toSet(),
    );
  }
}

/// A single alert instance.
class AlertEntry {
  final String id;
  final AlertType type;
  final String studentProfileId;
  final String studentName;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  const AlertEntry({
    required this.id,
    required this.type,
    required this.studentProfileId,
    required this.studentName,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  AlertEntry markRead() => AlertEntry(
    id: id,
    type: type,
    studentProfileId: studentProfileId,
    studentName: studentName,
    message: message,
    timestamp: timestamp,
    isRead: true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'studentProfileId': studentProfileId,
    'studentName': studentName,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
  };

  factory AlertEntry.fromJson(Map<String, dynamic> json) {
    final typeIndex = json['type'] as int? ?? 0;
    return AlertEntry(
      id: json['id'] as String,
      type: (typeIndex >= 0 && typeIndex < AlertType.values.length)
          ? AlertType.values[typeIndex]
          : AlertType.lowAccuracy,
      studentProfileId: json['studentProfileId'] as String,
      studentName: json['studentName'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}
