import 'enums.dart';

/// Per-child screen-time policy set by a parent or teacher.
///
/// Lives in the Firestore `child_time_limits` collection, with the
/// document id == [childProfileId] so the child's device can read or
/// listen with no extra query. One document per child.
///
/// Distinct from the legacy device-wide [ParentalControls] in
/// `lib/features/parent/models/parental_controls.dart`. The legacy
/// model is preserved for blocked-games / blocked-categories and the
/// other content-filter switches; this per-child variant carries only
/// the fields that the [LockEnforcer] reads.
class ChildTimeLimit {
  /// Profile id of the child this limit applies to.
  final String childProfileId;

  /// Profile id of the parent/teacher who set or last edited the limit.
  final String setterProfileId;

  /// Role of the setter — surfaced in the UI ("set by your teacher").
  final UserRole setterRole;

  /// Maximum minutes of foreground app use per local day. 0 = unlimited.
  final int dailyLimitMinutes;

  /// Whether the daily limit is enforced.
  final bool dailyLimitEnabled;

  /// Whether the time-of-day schedule is enforced.
  final bool scheduleEnabled;

  /// Earliest hour (0-23) when the app is allowed.
  final int allowedStartHour;

  /// Latest hour (0-23, exclusive) when the app is allowed.
  /// Wraps around midnight when [allowedEndHour] <= [allowedStartHour]
  /// (e.g. 22→6 means "10 PM through 6 AM").
  final int allowedEndHour;

  /// ISO weekday numbers (1=Mon..7=Sun) the schedule applies on. An
  /// empty set means "every day"; otherwise the schedule is ignored on
  /// other days (no restriction).
  final Set<int> allowedDays;

  final DateTime updatedAt;

  const ChildTimeLimit({
    required this.childProfileId,
    required this.setterProfileId,
    required this.setterRole,
    this.dailyLimitMinutes = 0,
    this.dailyLimitEnabled = false,
    this.scheduleEnabled = false,
    this.allowedStartHour = 8,
    this.allowedEndHour = 20,
    this.allowedDays = const <int>{},
    required this.updatedAt,
  });

  /// A "no restrictions" sentinel for fresh children — used when no
  /// document exists yet so the [LockEnforcer] returns null without
  /// special-casing.
  factory ChildTimeLimit.empty(String childProfileId) => ChildTimeLimit(
        childProfileId: childProfileId,
        setterProfileId: '',
        setterRole: UserRole.parent,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// Whether either constraint is active (used to skip enforcer work).
  bool get hasAnyConstraint => dailyLimitEnabled || scheduleEnabled;

  ChildTimeLimit copyWith({
    String? childProfileId,
    String? setterProfileId,
    UserRole? setterRole,
    int? dailyLimitMinutes,
    bool? dailyLimitEnabled,
    bool? scheduleEnabled,
    int? allowedStartHour,
    int? allowedEndHour,
    Set<int>? allowedDays,
    DateTime? updatedAt,
  }) {
    return ChildTimeLimit(
      childProfileId: childProfileId ?? this.childProfileId,
      setterProfileId: setterProfileId ?? this.setterProfileId,
      setterRole: setterRole ?? this.setterRole,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      dailyLimitEnabled: dailyLimitEnabled ?? this.dailyLimitEnabled,
      scheduleEnabled: scheduleEnabled ?? this.scheduleEnabled,
      allowedStartHour: allowedStartHour ?? this.allowedStartHour,
      allowedEndHour: allowedEndHour ?? this.allowedEndHour,
      allowedDays: allowedDays ?? this.allowedDays,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Snake_case Firestore shape.
  Map<String, dynamic> toJson() => {
        'child_profile_id': childProfileId,
        'setter_profile_id': setterProfileId,
        'setter_role': setterRole.index,
        'daily_limit_minutes': dailyLimitMinutes,
        'daily_limit_enabled': dailyLimitEnabled,
        'schedule_enabled': scheduleEnabled,
        'allowed_start_hour': allowedStartHour,
        'allowed_end_hour': allowedEndHour,
        'allowed_days': allowedDays.toList()..sort(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ChildTimeLimit.fromJson(Map<String, dynamic> json) {
    final daysRaw = json['allowed_days'] as List?;
    final days = daysRaw == null
        ? const <int>{}
        : daysRaw
            .map((e) => e as int)
            .where((d) => d >= 1 && d <= 7)
            .toSet();
    return ChildTimeLimit(
      childProfileId: json['child_profile_id'] as String,
      setterProfileId: json['setter_profile_id'] as String? ?? '',
      setterRole:
          UserRole.values[(json['setter_role'] as int?) ?? 0],
      dailyLimitMinutes: json['daily_limit_minutes'] as int? ?? 0,
      dailyLimitEnabled: json['daily_limit_enabled'] as bool? ?? false,
      scheduleEnabled: json['schedule_enabled'] as bool? ?? false,
      allowedStartHour: json['allowed_start_hour'] as int? ?? 8,
      allowedEndHour: json['allowed_end_hour'] as int? ?? 20,
      allowedDays: days,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
