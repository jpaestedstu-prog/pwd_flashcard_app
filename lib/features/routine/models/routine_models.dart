import '../../../data/models/enums.dart';

/// Minutes a locked routine step waits before it counts as "needs help",
/// unless the educator chose otherwise ([Routine.escalateAfterMinutes]).
const int kRoutineDefaultEscalateMinutes = 15;

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
  custom,

  /// A scheduled moment to say how the learner feels — "Check-in time".
  ///
  /// Appended *after* [custom] because activities persist by index; putting it
  /// anywhere else would re-label every stored custom step. Completing this
  /// step *is* answering the check-in: it cannot be ticked off without a face,
  /// because a check-in marked done with no answer recorded nothing.
  moodCheckIn;

  bool get isCustom => this == RoutineActivity.custom;

  /// Whether this step is a check-in rather than a task.
  bool get isMoodCheckIn => this == RoutineActivity.moodCheckIn;

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

/// How long a step lasts when the educator gave it no length of its own.
///
/// A Student's or Child's step is finished when its time ends, and a
/// locking step lets go of the device at that moment — so every scheduled
/// step needs an end. The builder asks for a duration on a locking step; a
/// step written before that rule existed gets this one.
const int kRoutineDefaultStepMinutes = 10;

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

  /// How many minutes before [hour]:[minute] to send the reminder.
  ///
  /// Zero means "at the time itself". Only meaningful on a scheduled step —
  /// there is nothing to be early for on a step that is merely sequenced.
  /// Five minutes is often the useful setting: a transition warning lands
  /// better than an instruction that arrives the moment the thing is due,
  /// especially for a learner who needs time to switch activity.
  final int remindMinutesBefore;

  /// A disabled step stays in the routine (and keeps its history) but is not
  /// shown to the learner today.
  final bool enabled;

  /// Hold the device on this step from its time until its time ends
  /// ([endsOn]). The learner never taps their way out; see [releaseEarly].
  ///
  /// Only ever consulted when the parent routine's [Routine.lockEnabled] is
  /// on — the routine carries the decision to lock at all, and this is the
  /// per-step exemption for the ones that should not. Meaningless on an
  /// unscheduled step: there is no moment for the lock to start at.
  ///
  /// Defaults to **true** so that switching a routine to locking locks the
  /// whole routine, which is what an educator means by the switch. Steps they
  /// want to leave open are turned off one at a time.
  final bool lockScreen;

  /// Ask the learner how they feel straight after ticking this step off —
  /// "How do you feel after brushing your teeth?".
  ///
  /// Per step, and set by the educator, because *which* moments are worth
  /// asking about is their call: a morning routine where waking up is the
  /// hard part wants the question there, not after every one of six steps.
  /// Meaningless on a [RoutineActivity.moodCheckIn] step, which is a question
  /// already.
  final bool askMood;

  /// Whether an adult may end this step before its time is up.
  ///
  /// Off by default: the learner waits until the step's time ends. On, a
  /// Teacher or Parent can finish it early — "Mark done" from their own
  /// dashboard, or behind the adult check on the learner's tablet. It is
  /// never a control the learner sees.
  final bool releaseEarly;

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
    this.remindMinutesBefore = 0,
    this.enabled = true,
    this.lockScreen = true,
    this.askMood = false,
    this.releaseEarly = false,
  });

  bool get isScheduled => hour != null && minute != null;

  /// Whether this step can hold the device when its time arrives. The routine
  /// still has to be locking — see [Routine.lockingSteps].
  bool get canLock => enabled && lockScreen && isScheduled;

  /// Whether completing this step should ask how the learner feels. A
  /// check-in step never does: it already asked.
  bool get asksMoodAfter => askMood && !activity.isMoodCheckIn;

  bool get hasTimer => durationMinutes > 0;

  /// How long this step's time lasts: its own duration, or
  /// [kRoutineDefaultStepMinutes] when it has none.
  int get lockMinutes =>
      durationMinutes > 0 ? durationMinutes : kRoutineDefaultStepMinutes;

  /// When this step starts on [day]'s date, or null for an unscheduled step.
  DateTime? startsOn(DateTime day) => isScheduled
      ? DateTime(day.year, day.month, day.day, hour!, minute!)
      : null;

  /// When this step's time ends on [day]'s date — its start plus
  /// [lockMinutes] — or null for an unscheduled step. A Student's or Child's
  /// step is finished at this moment, and a locking step lets go of the
  /// device.
  DateTime? endsOn(DateTime day) =>
      startsOn(day)?.add(Duration(minutes: lockMinutes));

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
    int? remindMinutesBefore,
    bool? enabled,
    bool? lockScreen,
    bool? askMood,
    bool? releaseEarly,
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
      remindMinutesBefore: remindMinutesBefore ?? this.remindMinutesBefore,
      enabled: enabled ?? this.enabled,
      lockScreen: lockScreen ?? this.lockScreen,
      askMood: askMood ?? this.askMood,
      releaseEarly: releaseEarly ?? this.releaseEarly,
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
        'remind_minutes_before': remindMinutesBefore,
        'enabled': enabled,
        'lock_screen': lockScreen,
        'ask_mood': askMood,
        'release_early': releaseEarly,
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
      // Clamped rather than trusted: a reminder an hour early is a different
      // activity, not an early warning.
      remindMinutesBefore:
          (json['remind_minutes_before'] as int?)?.clamp(0, 60) ?? 0,
      enabled: (json['enabled'] as bool?) ?? true,
      // Absent on a step written before locking existed. True is the safe
      // default *because* it is gated behind the routine's own switch, which
      // those routines do not have set either — so an old routine still locks
      // nothing until an educator says so.
      lockScreen: (json['lock_screen'] as bool?) ?? true,
      // Absent on every step written before per-step check-ins existed, and
      // on any written by an older build — both mean "don't ask".
      askMood: (json['ask_mood'] as bool?) ?? false,
      // Absent on every step written before early release existed: that
      // learner waits until the time ends, which is the default.
      releaseEarly: (json['release_early'] as bool?) ?? false,
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

  /// Whether the learner's device raises a notification for each scheduled
  /// step. Off by default is the wrong default for a schedule nobody is
  /// nudged toward, so this starts **on** — but it is a per-routine switch
  /// because a bedtime routine and a classroom routine want different
  /// answers, and an adult sitting beside the learner does not need either.
  final bool remindersEnabled;

  /// Whether each scheduled step of this routine holds the learner's device
  /// until it is done — the same full-screen stop as the Alarm and Time Limit
  /// locks, but cleared by finishing the step rather than by a PIN.
  ///
  /// **Off by default, and only ever set by a Teacher or a Parent.** Turning a
  /// routine into a lock changes what the device *is* for that learner, and
  /// doing it silently to every routine that already exists would trap
  /// children whose educator never asked for it. Per-step exemptions live on
  /// [RoutineStep.lockScreen].
  ///
  /// Only meaningful for a Student or Child profile. A Player runs the same
  /// routines as a checklist — see `routineFeatureProvider`.
  final bool lockEnabled;

  /// How long a locked step may wait before the learner is treated as
  /// needing help — the lock screen offers the adult more plainly, and the
  /// educator's dashboard turns the row red and alerts them.
  ///
  /// Zero switches escalation off. Clamped to 45, below the one-hour lock
  /// window, because an escalation that can only fire after the lock has
  /// already lapsed would never fire at all.
  final int escalateAfterMinutes;

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
    this.remindersEnabled = true,
    this.lockEnabled = false,
    this.escalateAfterMinutes = kRoutineDefaultEscalateMinutes,
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

  /// The steps this routine will raise a reminder for.
  ///
  /// Empty unless the routine is enabled *and* reminding; an unscheduled step
  /// never reminds, because there is no time to fire at.
  List<RoutineStep> get remindableSteps {
    if (!enabled || !remindersEnabled) return const [];
    return orderedSteps.where((s) => s.isScheduled).toList();
  }

  /// The steps that may hold the learner's device today, earliest first.
  ///
  /// Empty unless the routine is enabled *and* locking; an unscheduled step
  /// never locks, because there is no moment for the lock to begin at, and a
  /// step the educator exempted never locks either.
  List<RoutineStep> get lockingSteps {
    if (!enabled || !lockEnabled) return const [];
    return orderedSteps.where((s) => s.canLock).toList();
  }

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
    bool? remindersEnabled,
    bool? lockEnabled,
    int? escalateAfterMinutes,
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
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      escalateAfterMinutes: escalateAfterMinutes ?? this.escalateAfterMinutes,
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
        'reminders_enabled': remindersEnabled,
        'lock_enabled': lockEnabled,
        'escalate_after_minutes': escalateAfterMinutes,
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
      // Absent on routines written before reminders existed; those should
      // start reminding rather than stay silent forever.
      remindersEnabled: (json['reminders_enabled'] as bool?) ?? true,
      // Absent on every routine written before locking existed. Those must
      // stay checklists: a routine nobody chose to make a lock must never
      // become one because the app updated.
      lockEnabled: (json['lock_enabled'] as bool?) ?? false,
      escalateAfterMinutes:
          (json['escalate_after_minutes'] as int?)?.clamp(0, 45) ??
              kRoutineDefaultEscalateMinutes,
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
/// One step **as it was scheduled on a particular day**.
///
/// A routine is edited over time: steps are renamed, retimed, hidden and
/// deleted. Scoring last Tuesday against today's routine therefore re-writes
/// history every time an educator changes something — a learner who completed
/// four steps out of four can be shown as 4/6 a week later because two steps
/// were added since.
///
/// This is the frozen record that stops that. It carries only what the history
/// screen needs to score and label the day, and it keeps [activity] plus the
/// overrides rather than a rendered string, so a snapshot taken in English
/// still reads correctly for a Filipino reader later.
class RoutineDayStep {
  final String id;
  final RoutineActivity activity;
  final String title;
  final String titleFilipino;
  final String emoji;

  /// When the step was planned for that day and how long it lasted, as it
  /// stood when the day was frozen. Null [hour] on a step that had no time —
  /// and on every snapshot frozen before times were recorded, which is what
  /// [hasTiming] tells a reader apart.
  final int? hour;
  final int? minute;
  final int durationMinutes;

  /// Whether the step held the learner's device that day.
  final bool locks;

  /// Whether this row was frozen with its time and lock recorded.
  final bool hasTiming;

  const RoutineDayStep({
    required this.id,
    required this.activity,
    this.title = '',
    this.titleFilipino = '',
    this.emoji = '',
    this.hour,
    this.minute,
    this.durationMinutes = 0,
    this.locks = false,
    this.hasTiming = false,
  });

  factory RoutineDayStep.of(RoutineStep step, {bool locks = false}) =>
      RoutineDayStep(
        id: step.id,
        activity: step.activity,
        title: step.title,
        titleFilipino: step.titleFilipino,
        emoji: step.emoji,
        hour: step.hour,
        minute: step.minute,
        durationMinutes: step.durationMinutes,
        locks: locks,
        hasTiming: true,
      );

  /// Rebuilds a shell [RoutineStep] so `RoutineCatalog.titleFor` / `emojiFor`
  /// can localise it exactly as the live screens do — one source of truth for
  /// how a step is named, whether it still exists or not. Carries the frozen
  /// time and length, so a past day is timed as it was planned.
  RoutineStep toStep() => RoutineStep(
        id: id,
        activity: activity,
        title: title,
        titleFilipino: titleFilipino,
        emoji: emoji,
        hour: hour,
        minute: minute,
        durationMinutes: durationMinutes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'activity': activity.index,
        'title': title,
        'title_filipino': titleFilipino,
        'emoji': emoji,
        if (hasTiming) ...{
          'hour': hour,
          'minute': minute,
          'duration_minutes': durationMinutes,
          'locks': locks,
        },
      };

  factory RoutineDayStep.fromJson(Map<String, dynamic> json) {
    int? clamped(Object? raw, int max) =>
        raw is int && raw >= 0 && raw <= max ? raw : null;
    final h = clamped(json['hour'], 23);
    final m = clamped(json['minute'], 59);
    final bothSet = h != null && m != null;
    return RoutineDayStep(
      id: (json['id'] as String?) ?? '',
      activity: RoutineActivity.fromIndex(json['activity']),
      title: (json['title'] as String?) ?? '',
      titleFilipino: (json['title_filipino'] as String?) ?? '',
      emoji: (json['emoji'] as String?) ?? '',
      hour: bothSet ? h : null,
      minute: bothSet ? m : null,
      durationMinutes: (json['duration_minutes'] as int?)?.clamp(0, 600) ?? 0,
      locks: (json['locks'] as bool?) ?? false,
      // The lock flag is always written with the times, so its presence is
      // what says this row was frozen with them.
      hasTiming: json.containsKey('locks'),
    );
  }
}

/// Who excused or approved a step, when, and whether it still stands.
///
/// The record behind "Brushing Teeth — excused by Ma'am Rose at 6:52". A lock
/// that anyone can wave past is only accountable if the waving leaves a trace
/// the educator can read afterwards, so an excuse is never a bare flag.
///
/// Revoking keeps the mark and stamps [revokedAt] rather than deleting it.
/// Two devices hold copies of the same day, and a deletion cannot win a merge
/// against a copy that still has the entry; a later timestamp can.
class RoutineStepMark {
  final DateTime at;
  final String byProfileId;
  final String byName;
  final UserRole? byRole;
  final RoutineMarkSource source;
  final DateTime? revokedAt;
  final String revokedByName;

  const RoutineStepMark({
    required this.at,
    required this.byProfileId,
    required this.byName,
    this.byRole,
    required this.source,
    this.revokedAt,
    this.revokedByName = '',
  });

  bool get isActive => revokedAt == null;

  /// The moment this mark last changed — what a merge compares.
  DateTime get lastChanged {
    final r = revokedAt;
    return r != null && r.isAfter(at) ? r : at;
  }

  RoutineStepMark revoke({required DateTime at, String byName = ''}) =>
      RoutineStepMark(
        at: this.at,
        byProfileId: byProfileId,
        byName: this.byName,
        byRole: byRole,
        source: source,
        revokedAt: at,
        revokedByName: byName,
      );

  /// Whichever of [a] and [b] changed last. Ties keep [a], the local copy.
  static RoutineStepMark? latest(RoutineStepMark? a, RoutineStepMark? b) {
    if (a == null) return b;
    if (b == null) return a;
    return b.lastChanged.isAfter(a.lastChanged) ? b : a;
  }

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'by_profile_id': byProfileId,
        'by_name': byName,
        'by_role': byRole?.index,
        'source': source.name,
        'revoked_at': revokedAt?.toIso8601String(),
        'revoked_by_name': revokedByName,
      };

  static RoutineStepMark? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = raw['at'] is String ? DateTime.tryParse(raw['at'] as String) : null;
    if (at == null) return null;
    final roleIdx = raw['by_role'];
    final sourceName = raw['source'];
    return RoutineStepMark(
      at: at,
      byProfileId: (raw['by_profile_id'] as String?) ?? '',
      byName: (raw['by_name'] as String?) ?? '',
      byRole: roleIdx is int && roleIdx >= 0 && roleIdx < UserRole.values.length
          ? UserRole.values[roleIdx]
          : null,
      source: RoutineMarkSource.values.firstWhere(
        (s) => s.name == sourceName,
        orElse: () => RoutineMarkSource.educator,
      ),
      revokedAt: raw['revoked_at'] is String
          ? DateTime.tryParse(raw['revoked_at'] as String)
          : null,
      revokedByName: (raw['revoked_by_name'] as String?) ?? '',
    );
  }

  static Map<String, RoutineStepMark> mapFromJson(Object? raw) {
    final out = <String, RoutineStepMark>{};
    if (raw is! Map) return out;
    raw.forEach((key, value) {
      final mark = tryFromJson(value);
      if (key is String && mark != null) out[key] = mark;
    });
    return out;
  }

  static Map<String, dynamic> mapToJson(Map<String, RoutineStepMark> marks) =>
      {for (final e in marks.entries) e.key: e.value.toJson()};

  /// Per-key [latest] of two mark maps.
  static Map<String, RoutineStepMark> mergeMaps(
    Map<String, RoutineStepMark> a,
    Map<String, RoutineStepMark> b,
  ) {
    final out = <String, RoutineStepMark>{};
    for (final key in {...a.keys, ...b.keys}) {
      out[key] = latest(a[key], b[key])!;
    }
    return out;
  }
}

/// Where a [RoutineStepMark] was made.
enum RoutineMarkSource {
  /// On the learner's own device, through the adult gate on the lock screen.
  learnerDevice,

  /// By a Teacher or Parent from their own dashboard.
  educator,
}

class RoutineDayLog {
  final String profileId;

  /// Date-only — the time component is always stripped.
  final DateTime day;

  /// Ids of the steps ticked off, across every routine that ran that day.
  /// Step ids are uuids, so they do not collide between routines.
  final Set<String> completedStepIds;

  /// When each tick in [completedStepIds] was made.
  ///
  /// What lets an educator's "start today over" reach a learner's device: a
  /// tick made before [resetAt] no longer counts, one made after it does.
  /// Absent on ticks written before timestamps existed; those count only
  /// until a day is reset.
  final Map<String, DateTime> completedAt;

  /// Steps excused **on this learner's device** through the adult gate.
  /// Excuses an educator grants remotely live in `RoutineDayActions`, a
  /// document the educator can write.
  final Map<String, RoutineStepMark> excused;

  /// When the learner's device first showed the lock for each step — proof
  /// the tablet was on and the lock actually appeared, and the start of
  /// "how long did the lock hold".
  final Map<String, DateTime> lockShownAt;

  /// When the learner's device first treated each locked step as needing
  /// help (see `Routine.escalateAfterMinutes`).
  final Map<String, DateTime> escalatedAt;

  /// The last time this day was started over. Everything recorded before it
  /// is history, not today.
  final DateTime? resetAt;

  /// What was actually scheduled that day, frozen when the learner's device
  /// saw the day.
  final List<RoutineDayStep> scheduled;

  /// When the schedule was frozen, or null if this day was never observed.
  ///
  /// A separate flag rather than "is [scheduled] empty", because **an empty
  /// snapshot is a real answer**: a device that saw the day and found nothing
  /// scheduled has recorded a rest day, which is different from a device that
  /// was switched off and knows nothing. Inferring from emptiness collapsed
  /// those two and pushed known rest days back into being estimates.
  final DateTime? snapshotAt;

  final DateTime updatedAt;

  const RoutineDayLog({
    required this.profileId,
    required this.day,
    this.completedStepIds = const <String>{},
    this.completedAt = const <String, DateTime>{},
    this.excused = const <String, RoutineStepMark>{},
    this.lockShownAt = const <String, DateTime>{},
    this.escalatedAt = const <String, DateTime>{},
    this.resetAt,
    this.scheduled = const <RoutineDayStep>[],
    this.snapshotAt,
    required this.updatedAt,
  });

  /// Whether this day was observed and its schedule frozen.
  ///
  /// Tolerates a row that has steps but no timestamp — that shape cannot be
  /// written any more, but treating it as unrecorded would silently discard a
  /// real schedule.
  bool get hasSnapshot => snapshotAt != null || scheduled.isNotEmpty;

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

  RoutineDayLog _copy({
    Set<String>? completedStepIds,
    Map<String, DateTime>? completedAt,
    Map<String, RoutineStepMark>? excused,
    Map<String, DateTime>? lockShownAt,
    Map<String, DateTime>? escalatedAt,
    DateTime? resetAt,
    bool clearReset = false,
    List<RoutineDayStep>? scheduled,
    DateTime? snapshotAt,
    DateTime? updatedAt,
  }) =>
      RoutineDayLog(
        profileId: profileId,
        day: day,
        completedStepIds: completedStepIds ?? this.completedStepIds,
        completedAt: completedAt ?? this.completedAt,
        excused: excused ?? this.excused,
        lockShownAt: lockShownAt ?? this.lockShownAt,
        escalatedAt: escalatedAt ?? this.escalatedAt,
        resetAt: clearReset ? null : (resetAt ?? this.resetAt),
        scheduled: scheduled ?? this.scheduled,
        snapshotAt: snapshotAt ?? this.snapshotAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  RoutineDayLog toggle(String stepId, {DateTime? at}) =>
      setDone(stepId, !completedStepIds.contains(stepId), at: at);

  /// Marks [stepId] done or not done. Re-marking a done step refreshes its
  /// time, which is what makes a tick made after a reset count again.
  RoutineDayLog setDone(String stepId, bool done, {DateTime? at}) {
    final when = at ?? DateTime.now();
    final ids = Set<String>.from(completedStepIds);
    final times = Map<String, DateTime>.from(completedAt);
    if (done) {
      ids.add(stepId);
      times[stepId] = when;
    } else {
      ids.remove(stepId);
      times.remove(stepId);
    }
    return _copy(completedStepIds: ids, completedAt: times, updatedAt: when);
  }

  RoutineDayLog withExcuse(String stepId, RoutineStepMark mark) =>
      _copy(excused: {...excused, stepId: mark}, updatedAt: mark.lastChanged);

  /// Records that the lock for [stepId] appeared at [at]. The first sighting
  /// wins; later ones return this log unchanged so callers can skip a write.
  RoutineDayLog withLockShown(String stepId, DateTime at) {
    if (lockShownAt.containsKey(stepId)) return this;
    return _copy(lockShownAt: {...lockShownAt, stepId: at}, updatedAt: at);
  }

  /// Records that [stepId] first needed help at [at]. First one wins.
  RoutineDayLog withEscalated(String stepId, DateTime at) {
    if (escalatedAt.containsKey(stepId)) return this;
    return _copy(escalatedAt: {...escalatedAt, stepId: at}, updatedAt: at);
  }

  /// Starts the day over at [at]: every tick, excuse and lock record goes, and
  /// the frozen schedule stays — "do today again" is not "today had no plan".
  RoutineDayLog resetAll({required DateTime at}) => RoutineDayLog(
        profileId: profileId,
        day: day,
        resetAt: at,
        scheduled: scheduled,
        snapshotAt: snapshotAt,
        updatedAt: at,
      );

  /// Drops whatever was recorded at or before [at] — the view of this log
  /// after a reset that happened somewhere else.
  RoutineDayLog applyReset(DateTime at) {
    bool after(DateTime? t) => t != null && t.isAfter(at);
    final ids = completedStepIds.where((id) => after(completedAt[id])).toSet();
    final current = resetAt;
    return RoutineDayLog(
      profileId: profileId,
      day: day,
      completedStepIds: ids,
      completedAt: {
        for (final e in completedAt.entries)
          if (after(e.value)) e.key: e.value,
      },
      excused: {
        for (final e in excused.entries)
          if (after(e.value.lastChanged)) e.key: e.value,
      },
      lockShownAt: {
        for (final e in lockShownAt.entries)
          if (after(e.value)) e.key: e.value,
      },
      escalatedAt: {
        for (final e in escalatedAt.entries)
          if (after(e.value)) e.key: e.value,
      },
      resetAt: current != null && current.isAfter(at) ? current : at,
      scheduled: scheduled,
      snapshotAt: snapshotAt,
      updatedAt: updatedAt,
    );
  }

  /// Returns this log with [steps] frozen as the day's schedule.
  ///
  /// Deliberately **replaces** rather than merges: the snapshot is "what was
  /// scheduled", and a step an educator removed part-way through the day
  /// should stop counting against the learner from the next observation on.
  RoutineDayLog withSchedule(List<RoutineDayStep> steps, {DateTime? at}) =>
      _copy(scheduled: steps, snapshotAt: at ?? DateTime.now());

  /// Two copies of the same day, reconciled.
  ///
  /// * The latest reset applies to **both** sides before anything is joined,
  ///   so a device that never saw the reset cannot smuggle yesterday's-news
  ///   ticks back in.
  /// * Ticks are a union — nothing a learner earns is taken away — keeping the
  ///   latest time per step, so a re-tick after a reset survives it.
  /// * Excuses keep whichever changed last, which is how a revocation wins.
  /// * Lock sightings and escalations keep the earliest: they are "since".
  /// * The frozen schedule is not unioned — two devices would interleave their
  ///   step lists into a schedule neither ever showed — and the local copy
  ///   wins when both have one.
  static RoutineDayLog merge(RoutineDayLog local, RoutineDayLog remote) {
    final a = local.resetAt;
    final b = remote.resetAt;
    final reset = a == null ? b : (b == null || a.isAfter(b) ? a : b);
    final l = reset == null ? local : local.applyReset(reset);
    final r = reset == null ? remote : remote.applyReset(reset);

    DateTime? latestOf(DateTime? x, DateTime? y) =>
        x == null ? y : (y == null || x.isAfter(y) ? x : y);
    DateTime? earliestOf(DateTime? x, DateTime? y) =>
        x == null ? y : (y == null || x.isBefore(y) ? x : y);

    Map<String, DateTime> join(
      Map<String, DateTime> x,
      Map<String, DateTime> y,
      DateTime? Function(DateTime?, DateTime?) pick,
    ) =>
        {
          for (final k in {...x.keys, ...y.keys}) k: pick(x[k], y[k])!,
        };

    return RoutineDayLog(
      profileId: l.profileId.isEmpty ? r.profileId : l.profileId,
      day: l.day,
      completedStepIds: {...l.completedStepIds, ...r.completedStepIds},
      completedAt: join(l.completedAt, r.completedAt, latestOf),
      excused: RoutineStepMark.mergeMaps(l.excused, r.excused),
      lockShownAt: join(l.lockShownAt, r.lockShownAt, earliestOf),
      escalatedAt: join(l.escalatedAt, r.escalatedAt, earliestOf),
      resetAt: reset,
      scheduled: l.hasSnapshot ? l.scheduled : r.scheduled,
      snapshotAt: l.hasSnapshot ? l.snapshotAt : r.snapshotAt,
      updatedAt: l.updatedAt.isAfter(r.updatedAt) ? l.updatedAt : r.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'profile_id': profileId,
        'day': dayStamp,
        'completed_step_ids': completedStepIds.toList()..sort(),
        'completed_at': _dateMapToJson(completedAt),
        'excused': RoutineStepMark.mapToJson(excused),
        'lock_shown_at': _dateMapToJson(lockShownAt),
        'escalated_at': _dateMapToJson(escalatedAt),
        'reset_at': resetAt?.toIso8601String(),
        'scheduled': scheduled.map((s) => s.toJson()).toList(),
        'snapshot_at': snapshotAt?.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory RoutineDayLog.fromJson(Map<String, dynamic> json) {
    final ids =
        (json['completed_step_ids'] as List?)?.whereType<String>().toSet() ??
            const <String>{};
    final dayRaw = json['day'] as String?;
    final parsed = dayRaw == null ? null : DateTime.tryParse(dayRaw);
    final day = parsed ?? DateTime.now();
    final scheduledRaw = json['scheduled'] as List?;
    final scheduled = <RoutineDayStep>[];
    if (scheduledRaw != null) {
      for (final raw in scheduledRaw) {
        if (raw is Map) {
          // One malformed row must not cost the whole day's snapshot.
          try {
            scheduled
                .add(RoutineDayStep.fromJson(Map<String, dynamic>.from(raw)));
          } catch (_) {}
        }
      }
    }
    return RoutineDayLog(
      profileId: (json['profile_id'] as String?) ?? '',
      day: DateTime(day.year, day.month, day.day),
      completedStepIds: ids,
      completedAt: _dateMapFromJson(json['completed_at']),
      excused: RoutineStepMark.mapFromJson(json['excused']),
      lockShownAt: _dateMapFromJson(json['lock_shown_at']),
      escalatedAt: _dateMapFromJson(json['escalated_at']),
      resetAt: json['reset_at'] is String
          ? DateTime.tryParse(json['reset_at'] as String)
          : null,
      scheduled: scheduled,
      snapshotAt: json['snapshot_at'] is String
          ? DateTime.tryParse(json['snapshot_at'] as String)
          : null,
      updatedAt: _parseDate(json['updated_at']),
    );
  }
}

Map<String, dynamic> _dateMapToJson(Map<String, DateTime> map) =>
    {for (final e in map.entries) e.key: e.value.toIso8601String()};

Map<String, DateTime> _dateMapFromJson(Object? raw) {
  final out = <String, DateTime>{};
  if (raw is! Map) return out;
  raw.forEach((key, value) {
    if (key is String && value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) out[key] = parsed;
    }
  });
  return out;
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
