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

  /// Play the alarm chime when the lock appears. On by default: the
  /// chime is aimed at the adult in the room as much as at the child,
  /// so it stays on even for hearing profiles unless turned off here.
  final bool alarmSoundEnabled;

  /// Speak the hand-off message after the chime. The learner's own
  /// Text-to-Speech setting and their accessibility profile can still
  /// suppress it — see [LockPresentation.forProfile].
  final bool voiceMessageEnabled;

  /// Free-text name the parent/teacher wants the child addressed to —
  /// "Teacher Ana", "Dad", "Lola". Wins over [guardianHonorific] when
  /// non-empty so families and schools aren't forced into Ma'am / Sir /
  /// Mommy / Daddy.
  final String guardianPreferredName;

  /// Honorific derived from the setter's role + avatar at save time
  /// ("Ma'am", "Sir", "Mommy", "Daddy"). Stamped on the document by the
  /// educator's device because the child's device usually can't read the
  /// educator profile — see [GuardianAddress].
  final String guardianHonorific;

  /// Filipino Sign Language clip of the hand-off message, shown on the
  /// lock screen for hearing (and multiple-disability) profiles. Empty
  /// falls back to the built-in clip for this child's hand-off figure —
  /// see [LockMediaDefaults.timesUpFslVideoUrls].
  final String fslVideoUrl;

  /// Warn the child before the lock actually lands, instead of letting the
  /// lock screen be the first thing they know about it.
  final bool warningEnabled;

  /// How many minutes of notice the warning gives. Clamped to
  /// [minWarningMinutes]–[maxWarningMinutes] on read, because a value of 0
  /// would fire the warning at the same instant as the lock and anything
  /// beyond half an hour stops reading as "nearly time".
  final int warningMinutes;

  final DateTime updatedAt;

  /// Bounds for [warningMinutes]. One minute is the shortest notice that
  /// is still useful; thirty is the longest that still means "soon".
  static const int minWarningMinutes = 1;
  static const int maxWarningMinutes = 30;

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
    this.alarmSoundEnabled = true,
    this.voiceMessageEnabled = true,
    this.guardianPreferredName = '',
    this.guardianHonorific = '',
    this.fslVideoUrl = '',
    this.warningEnabled = true,
    this.warningMinutes = 5,
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

  /// [warningMinutes] brought into range. Everything that schedules or
  /// renders the warning reads this, never the raw field, so a document
  /// written by an older or buggier client can't produce a warning that
  /// fires at the same moment as the lock.
  int get effectiveWarningMinutes =>
      warningMinutes.clamp(minWarningMinutes, maxWarningMinutes);

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
    bool? alarmSoundEnabled,
    bool? voiceMessageEnabled,
    String? guardianPreferredName,
    String? guardianHonorific,
    String? fslVideoUrl,
    bool? warningEnabled,
    int? warningMinutes,
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
      alarmSoundEnabled: alarmSoundEnabled ?? this.alarmSoundEnabled,
      voiceMessageEnabled: voiceMessageEnabled ?? this.voiceMessageEnabled,
      guardianPreferredName:
          guardianPreferredName ?? this.guardianPreferredName,
      guardianHonorific: guardianHonorific ?? this.guardianHonorific,
      fslVideoUrl: fslVideoUrl ?? this.fslVideoUrl,
      warningEnabled: warningEnabled ?? this.warningEnabled,
      warningMinutes: warningMinutes ?? this.warningMinutes,
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
    'alarm_sound_enabled': alarmSoundEnabled,
    'voice_message_enabled': voiceMessageEnabled,
    'guardian_preferred_name': guardianPreferredName,
    'guardian_honorific': guardianHonorific,
    'fsl_video_url': fslVideoUrl,
    'warning_enabled': warningEnabled,
    'warning_minutes': warningMinutes,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory ChildTimeLimit.fromJson(Map<String, dynamic> json) {
    final daysRaw = json['allowed_days'] as List?;
    final days = daysRaw == null
        ? const <int>{}
        : daysRaw.map((e) => e as int).where((d) => d >= 1 && d <= 7).toSet();
    return ChildTimeLimit(
      childProfileId: json['child_profile_id'] as String,
      setterProfileId: json['setter_profile_id'] as String? ?? '',
      setterRole: UserRole.values[(json['setter_role'] as int?) ?? 0],
      dailyLimitMinutes: json['daily_limit_minutes'] as int? ?? 0,
      dailyLimitEnabled: json['daily_limit_enabled'] as bool? ?? false,
      scheduleEnabled: json['schedule_enabled'] as bool? ?? false,
      allowedStartHour: json['allowed_start_hour'] as int? ?? 8,
      allowedEndHour: json['allowed_end_hour'] as int? ?? 20,
      allowedDays: days,
      // Documents written before the hand-off announcement existed have
      // none of these keys. Defaulting the two switches to `true` means
      // an existing limit starts announcing itself on the next launch,
      // which is the behaviour educators asked for — the lock was
      // previously silent.
      alarmSoundEnabled: json['alarm_sound_enabled'] as bool? ?? true,
      voiceMessageEnabled: json['voice_message_enabled'] as bool? ?? true,
      guardianPreferredName: json['guardian_preferred_name'] as String? ?? '',
      guardianHonorific: json['guardian_honorific'] as String? ?? '',
      fslVideoUrl: json['fsl_video_url'] as String? ?? '',
      // Same reasoning as the two switches above: a document written
      // before the warning existed should start giving notice rather
      // than keep letting the lock arrive unannounced.
      warningEnabled: json['warning_enabled'] as bool? ?? true,
      warningMinutes: json['warning_minutes'] as int? ?? 5,
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
