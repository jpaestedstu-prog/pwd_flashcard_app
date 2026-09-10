import '../../../data/models/enums.dart';

/// One activity a daily routine can be built from.
///
/// Persisted **by index** (Firestore + Hive both store the int), so entries
/// may only ever be appended — exactly like [FlashcardCategory]. The catalog
/// in `routine_catalog.dart` carries everything human-facing about each one:
/// emoji, bilingual label, default time, visual instruction steps and the FSL
/// sign cues.
///
/// [custom] is the escape hatch the brief asked for ("other customizable
/// activities"): the educator supplies the title, emoji and media themselves
/// and nothing is inherited from the catalog.
enum RoutineActivity {
  morningRoutine,
  brushingTeeth,
  breakfast,
  lunch,
  breakTime,
  napTime,
  dinner,
  bathTime,
  gettingDressed,
  schoolTime,
  homework,
  playTime,
  exercise,
  bedtime,
  custom;

  bool get isCustom => this == RoutineActivity.custom;

  /// Safe decode for a persisted index — an unknown value (a routine written
  /// by a newer build, synced down to an older one) degrades to [custom]
  /// rather than throwing and taking the whole routine list with it.
  static RoutineActivity fromIndex(Object? raw) {
    if (raw is! int || raw < 0 || raw >= RoutineActivity.values.length) {
      return RoutineActivity.custom;
    }
    return RoutineActivity.values[raw];
  }
}

/// The four media channels a routine step can carry, in the order they are
/// offered to an educator and rendered to a learner.
///
/// Every slot is optional and every slot has a designed placeholder — the
/// brief's "use placeholders initially if the actual media is not yet
/// available", made a first-class state rather than an empty box.
enum RoutineMediaKind {
  photo,
  gif,
  video,
  audio;

  /// True when this channel carries nothing for a learner who cannot hear.
  bool get isAudioOnly => this == RoutineMediaKind.audio;

  /// True when this channel carries nothing for a learner who cannot see.
  bool get isVisualOnly => this != RoutineMediaKind.audio;
}

/// One step of a routine — "Brush your teeth", at 07:10, for 3 minutes.
///
/// A step is deliberately shallow: it holds the *addresses* of its media
/// rather than the bytes, so a routine document stays small enough to sync
/// over a classroom connection and so media can be swapped later without
/// touching the routine's shape. An empty URL is not an error state; it means
/// "show the placeholder", and the placeholder is designed to read as
/// "an adult can add a picture here", not as breakage.
class RoutineStep {
  final String id;

  final RoutineActivity activity;

  /// Overrides the catalog label. Empty means "use the catalog's".
  /// Required in practice for [RoutineActivity.custom], which has no catalog
  /// entry to fall back to — `RoutineCatalog.titleFor` handles that.
  final String title;
  final String titleFilipino;

  /// Emoji override, used mostly by custom activities. Empty = catalog's.
  final String emoji;

  /// Clock time, 0-23 / 0-59. Null when the step is sequenced but not timed —
  /// a valid and common shape for a cognitive-accessibility routine, where
  /// "after breakfast" is meaningful and "07:20" is not.
  final int? hour;
  final int? minute;

  /// Countdown length in minutes. Zero means no timer is offered.
  final int durationMinutes;

  /// The educator's own words for this step, shown under the title.
  final String note;
  final String noteFilipino;

  /// Media addresses. Empty string = not supplied yet = placeholder.
  final String photoUrl;
  final String gifUrl;
  final String videoUrl;
  final String audioUrl;

  /// FSL sign to show for this step, as a flashcard English word. Empty means
  /// "use the catalog's sign cues for [activity]".
  final String signWord;

  /// A disabled step stays in the routine (and keeps its history) but is not
  /// shown to the learner today.
  final bool enabled;

  const RoutineStep({
    required this.id,
    required this.activity,
    this.title = '',
    this.titleFilipino = '',
    this.emoji = '',
    this.hour,
    this.minute,
    this.durationMinutes = 0,
    this.note = '',
    this.noteFilipino = '',
    this.photoUrl = '',
    this.gifUrl = '',
    this.videoUrl = '',
    this.audioUrl = '',
    this.signWord = '',
    this.enabled = true,
  });

  bool get isScheduled => hour != null && minute != null;

  bool get hasTimer => durationMinutes > 0;

  /// Minutes since midnight, or null for an unscheduled step. Sorting keys off
  /// this, so an unscheduled step keeps its authored position instead of being
  /// yanked to the top of the day.
  int? get minutesOfDay => isScheduled ? hour! * 60 + minute! : null;

  String urlFor(RoutineMediaKind kind) => switch (kind) {
        RoutineMediaKind.photo => photoUrl,
        RoutineMediaKind.gif => gifUrl,
        RoutineMediaKind.video => videoUrl,
        RoutineMediaKind.audio => audioUrl,
      };

  bool hasMedia(RoutineMediaKind kind) => urlFor(kind).trim().isNotEmpty;

  /// Every channel this step actually carries. Empty for a freshly created
  /// step, which is the normal starting point — the catalog's emoji and
  /// visual instructions still give it a full visual presentation.
  List<RoutineMediaKind> get suppliedMedia =>
      RoutineMediaKind.values.where(hasMedia).toList();

  RoutineStep copyWith({
    String? id,
    RoutineActivity? activity,
    String? title,
    String? titleFilipino,
    String? emoji,
    int? hour,
    int? minute,
    bool clearTime = false,
    int? durationMinutes,
    String? note,
    String? noteFilipino,
    String? photoUrl,
    String? gifUrl,
    String? videoUrl,
    String? audioUrl,
    String? signWord,
    bool? enabled,
  }) {
    return RoutineStep(
      id: id ?? this.id,
      activity: activity ?? this.activity,
      title: title ?? this.title,
      titleFilipino: titleFilipino ?? this.titleFilipino,
      emoji: emoji ?? this.emoji,
      hour: clearTime ? null : (hour ?? this.hour),
      minute: clearTime ? null : (minute ?? this.minute),
      durationMinutes: durationMinutes ?? this.durationMinutes,
      note: note ?? this.note,
      noteFilipino: noteFilipino ?? this.noteFilipino,
      photoUrl: photoUrl ?? this.photoUrl,
      gifUrl: gifUrl ?? this.gifUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      signWord: signWord ?? this.signWord,
      enabled: enabled ?? this.enabled,
    );
  }

  /// Sets one media channel from a single call, so the editor does not need a
  /// four-way switch at every call site.
  RoutineStep withMedia(RoutineMediaKind kind, String url) => switch (kind) {
        RoutineMediaKind.photo => copyWith(photoUrl: url),
        RoutineMediaKind.gif => copyWith(gifUrl: url),
        RoutineMediaKind.video => copyWith(videoUrl: url),
        RoutineMediaKind.audio => copyWith(audioUrl: url),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'activity': activity.index,
        'title': title,
        'title_filipino': titleFilipino,
        'emoji': emoji,
        'hour': hour,
        'minute': minute,
        'duration_minutes': durationMinutes,
        'note': note,
        'note_filipino': noteFilipino,
        'photo_url': photoUrl,
        'gif_url': gifUrl,
        'video_url': videoUrl,
        'audio_url': audioUrl,
        'sign_word': signWord,
        'enabled': enabled,
      };

  factory RoutineStep.fromJson(Map<String, dynamic> json) {
    int? clamped(Object? raw, int max) {
      if (raw is! int || raw < 0 || raw > max) return null;
      return raw;
    }

    final h = clamped(json['hour'], 23);
    final m = clamped(json['minute'], 59);
    final bothSet = h != null && m != null;
    return RoutineStep(
      id: (json['id'] as String?) ?? '',
      activity: RoutineActivity.fromIndex(json['activity']),
      title: (json['title'] as String?) ?? '',
      titleFilipino: (json['title_filipino'] as String?) ?? '',
      emoji: (json['emoji'] as String?) ?? '',
      // Half a time is no time: a step with an hour but no minute would sort
      // as "00 past" and read as scheduled when it never was.
      hour: bothSet ? h : null,
      minute: bothSet ? m : null,
      durationMinutes: (json['duration_minutes'] as int?)?.clamp(0, 600) ?? 0,
      note: (json['note'] as String?) ?? '',
      noteFilipino: (json['note_filipino'] as String?) ?? '',
      photoUrl: (json['photo_url'] as String?) ?? '',
      gifUrl: (json['gif_url'] as String?) ?? '',
      videoUrl: (json['video_url'] as String?) ?? '',
      audioUrl: (json['audio_url'] as String?) ?? '',
      signWord: (json['sign_word'] as String?) ?? '',
      enabled: (json['enabled'] as bool?) ?? true,
    );
  }
}

/// A named, repeating plan of [RoutineStep]s for one learner.
///
/// Lives in the Firestore `routines` collection with a Hive mirror, the same
/// shape as `child_alarms`: the educator writes it, the learner's device
/// streams it, and both sides read the cache when offline.
class Routine {
  final String id;

  /// Profile id of the Student or Child this routine is for.
  final String childProfileId;

  /// Profile id of the parent or teacher who authored it. The security rules
  /// check ownership of this field, and the learner's UI shows "from your
  /// teacher" / "from your parent" from [setterRole].
  final String setterProfileId;
  final UserRole setterRole;

  final String name;
  final String nameFilipino;

  /// ISO weekdays (1 = Monday … 7 = Sunday) the routine runs on. Empty means
  /// every day — the same convention as `ChildAlarm.daysOfWeek`, so an
  /// educator who has met one has met both.
  final Set<int> daysOfWeek;

  final List<RoutineStep> steps;

  final bool enabled;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Routine({
    required this.id,
    required this.childProfileId,
    required this.setterProfileId,
    required this.setterRole,
    required this.name,
    this.nameFilipino = '',
    this.daysOfWeek = const <int>{},
    this.steps = const <RoutineStep>[],
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isEveryDay => daysOfWeek.isEmpty;

  /// Whether this routine is scheduled for [day]'s weekday.
  bool runsOn(DateTime day) => isEveryDay || daysOfWeek.contains(day.weekday);

  /// The steps a learner actually sees: enabled only, clock-scheduled ones
  /// first in time order, then the unscheduled ones in authored order.
  ///
  /// The sort is stable, so two scheduled steps at the same minute keep their
  /// authored order — which is what an educator means by putting one above
  /// the other.
  List<RoutineStep> get orderedSteps {
    final live = steps.where((s) => s.enabled).toList();
    final scheduled = live.where((s) => s.isScheduled).toList()
      ..sort((a, b) => a.minutesOfDay!.compareTo(b.minutesOfDay!));
    // Unscheduled steps sink below the timetable rather than colliding
    // with 00:00, and keep the order the educator dragged them into.
    final loose = live.where((s) => !s.isScheduled).toList();
    return [...scheduled, ...loose];
  }

  /// Every step including disabled ones, in the order the editor shows them.
  List<RoutineStep> get editorSteps => List.unmodifiable(steps);

  int get stepCount => steps.where((s) => s.enabled).length;

  Routine copyWith({
    String? id,
    String? childProfileId,
    String? setterProfileId,
    UserRole? setterRole,
    String? name,
    String? nameFilipino,
    Set<int>? daysOfWeek,
    List<RoutineStep>? steps,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Routine(
      id: id ?? this.id,
      childProfileId: childProfileId ?? this.childProfileId,
      setterProfileId: setterProfileId ?? this.setterProfileId,
      setterRole: setterRole ?? this.setterRole,
      name: name ?? this.name,
      nameFilipino: nameFilipino ?? this.nameFilipino,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      steps: steps ?? this.steps,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Snake_case to match the Firestore `routines` collection. `owner_uid` is
  /// stamped at write time by `RoutineService`.
  Map<String, dynamic> toJson() => {
        'id': id,
        'child_profile_id': childProfileId,
        'setter_profile_id': setterProfileId,
        'setter_role': setterRole.index,
        'name': name,
        'name_filipino': nameFilipino,
        'days_of_week': daysOfWeek.toList()..sort(),
        'steps': steps.map((s) => s.toJson()).toList(),
        'enabled': enabled,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Routine.fromJson(Map<String, dynamic> json) {
    final daysRaw = json['days_of_week'] as List?;
    final days = daysRaw == null
        ? const <int>{}
        : daysRaw.whereType<int>().where((d) => d >= 1 && d <= 7).toSet();
    final stepsRaw = json['steps'] as List?;
    final steps = <RoutineStep>[];
    if (stepsRaw != null) {
      for (final raw in stepsRaw) {
        if (raw is Map) {
          // One malformed step must not cost the learner the whole routine.
          try {
            steps.add(RoutineStep.fromJson(Map<String, dynamic>.from(raw)));
          } catch (_) {}
        }
      }
    }
    final roleIdx = json['setter_role'];
    return Routine(
      id: (json['id'] as String?) ?? '',
      childProfileId: (json['child_profile_id'] as String?) ?? '',
      setterProfileId: (json['setter_profile_id'] as String?) ?? '',
      setterRole:
          roleIdx is int && roleIdx >= 0 && roleIdx < UserRole.values.length
              ? UserRole.values[roleIdx]
              : UserRole.parent,
      name: (json['name'] as String?) ?? '',
      nameFilipino: (json['name_filipino'] as String?) ?? '',
      daysOfWeek: days,
      steps: steps,
      enabled: (json['enabled'] as bool?) ?? true,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }
}

/// What a learner completed on one calendar day.
///
/// Keyed by `<profileId>_<yyyy-mm-dd>` so a day is addressable without a
/// query, which is what makes the offline path cheap: the learner's device
/// writes its own day locally and the educator reads the same key.
class RoutineDayLog {
  final String profileId;

  /// Date-only — the time component is always stripped.
  final DateTime day;

  /// Ids of the steps ticked off, across every routine that ran that day.
  /// Step ids are uuids, so they do not collide between routines.
  final Set<String> completedStepIds;

  final DateTime updatedAt;

  const RoutineDayLog({
    required this.profileId,
    required this.day,
    this.completedStepIds = const <String>{},
    required this.updatedAt,
  });

  factory RoutineDayLog.empty(String profileId, DateTime day) => RoutineDayLog(
        profileId: profileId,
        day: DateTime(day.year, day.month, day.day),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  String get key => dayKeyFor(profileId, day);

  /// `yyyy-mm-dd` for the calendar day this log covers.
  String get dayStamp => dayStampOf(day);

  bool isDone(String stepId) => completedStepIds.contains(stepId);

  /// How much of [routine] this log accounts for, 0.0–1.0. A routine with no
  /// live steps reads as 0, never as "complete" — an empty plan is not an
  /// achievement, and showing a full ring for one would be a reward the child
  /// did not earn.
  double progressFor(Routine routine) {
    final live = routine.orderedSteps;
    if (live.isEmpty) return 0;
    final done = live.where((s) => completedStepIds.contains(s.id)).length;
    return done / live.length;
  }

  int doneCountFor(Routine routine) =>
      routine.orderedSteps.where((s) => completedStepIds.contains(s.id)).length;

  RoutineDayLog toggle(String stepId) {
    final next = Set<String>.from(completedStepIds);
    if (!next.add(stepId)) next.remove(stepId);
    return RoutineDayLog(
      profileId: profileId,
      day: day,
      completedStepIds: next,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'profile_id': profileId,
        'day': dayStamp,
        'completed_step_ids': completedStepIds.toList()..sort(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory RoutineDayLog.fromJson(Map<String, dynamic> json) {
    final ids =
        (json['completed_step_ids'] as List?)?.whereType<String>().toSet() ??
            const <String>{};
    final dayRaw = json['day'] as String?;
    final parsed = dayRaw == null ? null : DateTime.tryParse(dayRaw);
    final day = parsed ?? DateTime.now();
    return RoutineDayLog(
      profileId: (json['profile_id'] as String?) ?? '',
      day: DateTime(day.year, day.month, day.day),
      completedStepIds: ids,
      updatedAt: _parseDate(json['updated_at']),
    );
  }
}

/// `yyyy-mm-dd` for [day], from the **local** calendar fields.
String dayStampOf(DateTime day) {
  final y = day.year.toString().padLeft(4, '0');
  final m = day.month.toString().padLeft(2, '0');
  final d = day.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Document id / Hive key for one learner's day. Stable across time zones
/// because it is built from the local calendar fields, not from an epoch.
String dayKeyFor(String profileId, DateTime day) =>
    '${profileId}_${dayStampOf(day)}';

DateTime _parseDate(Object? raw) {
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
