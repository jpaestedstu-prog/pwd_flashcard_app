/// Per-day "minutes spent in the app" counter for one child.
///
/// Written by the child's device through [ActiveTimeTracker] every
/// minute (Hive) and every 5 minutes (Firestore, debounced). Read by
/// the [LockEnforcer] to compare against [ChildTimeLimit.dailyLimitMinutes]
/// and by the parent dashboard's "X / Y min today" pill.
///
/// Keyed by `${childProfileId}_${dayKey}` so daily aggregation is a
/// document-id read with no query.
class ActiveTimeLog {
  final String profileId;

  /// Local-time day key in `yyyy-MM-dd`. Storing the formatted string
  /// (rather than computing from a `DateTime` field) means the doc id
  /// can be derived without timezone work at read-time.
  final String dayKey;

  /// Minutes of foreground app use on this day. Monotonically increases
  /// during the day; never decreases (we throw away decremental writes).
  final int minutesUsed;

  /// When the counter was last incremented. Used to debounce Firestore
  /// writes to one every five minutes.
  final DateTime lastIncrementAt;

  const ActiveTimeLog({
    required this.profileId,
    required this.dayKey,
    this.minutesUsed = 0,
    required this.lastIncrementAt,
  });

  /// Doc-id used in both Hive and Firestore.
  String get docId => '${profileId}_$dayKey';

  ActiveTimeLog copyWith({
    String? profileId,
    String? dayKey,
    int? minutesUsed,
    DateTime? lastIncrementAt,
  }) {
    return ActiveTimeLog(
      profileId: profileId ?? this.profileId,
      dayKey: dayKey ?? this.dayKey,
      minutesUsed: minutesUsed ?? this.minutesUsed,
      lastIncrementAt: lastIncrementAt ?? this.lastIncrementAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'child_profile_id': profileId,
        'day_key': dayKey,
        'minutes_used': minutesUsed,
        'last_increment_at': lastIncrementAt.toIso8601String(),
      };

  factory ActiveTimeLog.fromJson(Map<String, dynamic> json) {
    return ActiveTimeLog(
      profileId: json['child_profile_id'] as String,
      dayKey: json['day_key'] as String,
      minutesUsed: json['minutes_used'] as int? ?? 0,
      lastIncrementAt:
          DateTime.tryParse(json['last_increment_at'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Build a `yyyy-MM-dd` key for [now] in the local timezone.
  static String dayKeyFor(DateTime now) {
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
