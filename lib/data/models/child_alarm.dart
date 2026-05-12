import 'enums.dart';
import 'alarm_action.dart';

/// An alarm scheduled by a parent or teacher for a specific child.
///
/// Lives in the Firestore `child_alarms` collection. The child's device
/// streams these in real time and reschedules them via `AlarmScheduler`
/// → `flutter_local_notifications`.
///
/// Repeating: an alarm fires every week on each day in [daysOfWeek] at
/// [hour]:[minute] local time. An empty [daysOfWeek] means "every day".
class ChildAlarm {
  /// Document id in Firestore.
  final String id;

  /// Profile id of the child this alarm targets.
  final String childProfileId;

  /// Profile id of the parent/teacher who created or last edited the
  /// alarm. Used by the security rules' `ownsProfile()` check and for
  /// the parent's "alarms I've set" view.
  final String setterProfileId;

  /// Role of the setter — surfaces in the UI as "from your teacher" /
  /// "from your parent" so the child sees who scheduled the alarm.
  final UserRole setterRole;

  /// Human-readable label, e.g. "Bedtime", "Homework time".
  final String label;

  /// 0-23.
  final int hour;

  /// 0-59.
  final int minute;

  /// ISO weekday numbers (1 = Monday … 7 = Sunday) when the alarm fires.
  /// Empty set means "every day".
  final Set<int> daysOfWeek;

  /// What to do when the alarm fires. See [AlarmAction].
  final AlarmAction action;

  /// When false, the alarm is preserved in Firestore but not scheduled
  /// on the device — gives parents a quick toggle without re-creating.
  final bool enabled;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ChildAlarm({
    required this.id,
    required this.childProfileId,
    required this.setterProfileId,
    required this.setterRole,
    required this.label,
    required this.hour,
    required this.minute,
    this.daysOfWeek = const <int>{},
    this.action = AlarmAction.notifyOnly,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  ChildAlarm copyWith({
    String? id,
    String? childProfileId,
    String? setterProfileId,
    UserRole? setterRole,
    String? label,
    int? hour,
    int? minute,
    Set<int>? daysOfWeek,
    AlarmAction? action,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChildAlarm(
      id: id ?? this.id,
      childProfileId: childProfileId ?? this.childProfileId,
      setterProfileId: setterProfileId ?? this.setterProfileId,
      setterRole: setterRole ?? this.setterRole,
      label: label ?? this.label,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      action: action ?? this.action,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Snake_case to match the Firestore `child_alarms` collection. The
  /// `owner_uid` field is stamped at write time by the service layer.
  Map<String, dynamic> toJson() => {
        'id': id,
        'child_profile_id': childProfileId,
        'setter_profile_id': setterProfileId,
        'setter_role': setterRole.index,
        'label': label,
        'hour': hour,
        'minute': minute,
        'days_of_week': daysOfWeek.toList()..sort(),
        'action': action.index,
        'enabled': enabled,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ChildAlarm.fromJson(Map<String, dynamic> json) {
    final daysRaw = json['days_of_week'] as List?;
    final days = daysRaw == null
        ? const <int>{}
        : daysRaw
            .map((e) => e as int)
            .where((d) => d >= 1 && d <= 7)
            .toSet();
    return ChildAlarm(
      id: json['id'] as String,
      childProfileId: json['child_profile_id'] as String,
      setterProfileId: json['setter_profile_id'] as String,
      setterRole: UserRole.values[(json['setter_role'] as int?) ?? 0],
      label: json['label'] as String? ?? '',
      hour: json['hour'] as int? ?? 0,
      minute: json['minute'] as int? ?? 0,
      daysOfWeek: days,
      action: AlarmActionJson.fromJson(json['action']),
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Whether this alarm should fire on the given weekday (1=Mon .. 7=Sun).
  bool firesOn(int isoWeekday) {
    if (daysOfWeek.isEmpty) return true;
    return daysOfWeek.contains(isoWeekday);
  }
}
