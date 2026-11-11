import 'package:flutter/material.dart';
import '../../../core/widgets/fit_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/wall_clock_provider.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../widgets/shared_widgets.dart';
import '../../gaze_control/providers/gaze_home_grid.dart';
import '../../gaze_control/widgets/gaze_home_tiles.dart';
import '../../mood_tracker/models/mood_models.dart';
import '../../mood_tracker/models/mood_presentation.dart';
import '../../mood_tracker/services/quick_mood_check_in.dart';
import '../../routine/models/routine_catalog.dart';
import '../../routine/models/routine_timeline.dart';
import '../../routine/models/routine_models.dart';
import '../../routine/models/routine_presentation.dart';
import '../../routine/providers/today_routine_provider.dart';
import '../../routine/services/routine_completion_flow.dart';
import '../../routine/widgets/routine_time_timer.dart';

/// One of the two "Today" cards on a learner's home: a full-width card
/// holding a single pane, directly under the stats banner.
///
/// **My Day** comes first and **Mood Check-In** second — two cards, not two
/// halves of one. They shared a card at first, and that made the routine and
/// the check-in read as one thing to get through. They are not one thing: a
/// routine is a schedule with times and ticks that an adult set, while the
/// check-in is a question the learner can answer at any moment of any day.
/// The routine asks its own mood questions as it goes — after a step, at a
/// scheduled check-in, when the day is done (see `routine_mood_prompt.dart`) —
/// so the standalone question belongs beside it rather than inside it.
///
/// The split also buys each pane the full width, which is where six faces and
/// a Done button actually fit. Side by side they were two squeezed columns
/// that ellipsised exactly the words carrying the information and shrank
/// exactly the buttons that had to stay big.
///
/// Each pane is its own tap target and its own **gaze / voice cell**: they
/// open different screens, and a learner driving the D-pad must be able to
/// reach Mood without passing through My Day. So are the controls inside
/// them — each mood face, My Day's Done button — or a D-pad could open the
/// card but never do what a finger does on it. The home screen registers
/// those rows, in the order the eye goes down the cards, and hands each pane
/// its rows — see [TodayDayPane] / [TodayMoodPane].
class TodayCard extends StatelessWidget {
  const TodayCard({super.key, required this.child});

  /// The gaze-wrapped [TodayDayPane] or [TodayMoodPane].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return AppCard(
      color: hc.surface,
      borderRadius: 20,
      padding: const EdgeInsets.all(8),
      child: child,
    );
  }
}

// ─── Mood half ────────────────────────────────────────

/// True while a check-in from Home's faces is being saved, so a learner who
/// presses twice files one entry. A provider rather than the pane's own state
/// because a face's D-pad stop belongs to the host screen, and a press there
/// has to see the same flag as a tap.
final _moodSavingProvider = StateProvider<bool>((ref) => false);

/// The Mood half of [TodayCard]: today's face if the learner has checked in,
/// an invitation if not — and either way, the faces themselves, so a check-in
/// costs one tap from Home.
class TodayMoodPane extends ConsumerStatefulWidget {
  const TodayMoodPane({
    super.key,
    required this.onOpen,
    this.title = 'Mood Check-In',
    this.gazeRow,
    this.gazeFaceRow,
  });

  /// Opens the full Mood Check-In screen.
  final VoidCallback onOpen;

  /// Heading, so the Child home can keep its own friendlier wording
  /// ("My Feelings") while sharing the card. Must match the gaze / voice cell
  /// label the host screen registers, or a learner would hear one name and
  /// have to say another.
  final String title;

  /// The D-pad row the host registered for opening the screen, ringed around
  /// the header. Null while no D-pad is in use.
  final int? gazeRow;

  /// The D-pad row the host registered for [faceCells], one stop per face.
  /// Null while no D-pad is in use.
  final int? gazeFaceRow;

  /// Records [mood] as today's check-in and says so: what pressing a face
  /// does, whether a finger pressed it or its D-pad stop ([faceCells]).
  static Future<void> checkIn(
    BuildContext context,
    WidgetRef ref,
    MoodType mood,
  ) async {
    final saving = ref.read(_moodSavingProvider.notifier);
    if (saving.state) return;
    saving.state = true;
    final bool ok;
    try {
      ok = await QuickMoodCheckIn.record(ref, mood: mood);
    } finally {
      // Through the notifier, which outlives the widget that asked.
      if (saving.mounted) saving.state = false;
    }
    if (!context.mounted) return;
    final isFilipino = ref.read(settingsProvider).locale == 'fil';
    if (!ok) {
      AppSnackBar.error(
        context,
        message: isFilipino
            ? 'Hindi na-save ang mood. Subukan ulit.'
            : 'Could not save your mood. Please try again.',
      );
      return;
    }
    AppSnackBar.success(
      context,
      message: isFilipino
          ? 'Na-record ang mood! ${mood.emoji}'
          : 'Mood recorded! ${mood.emoji}',
    );
  }

  /// The faces' D-pad stops, left to right, for the host screen to register
  /// as one row straight under this card's own and hand back as
  /// [gazeFaceRow]. Each does what tapping its face does. Named by the
  /// feeling alone: that is what the controller says on a press, and what a
  /// learner says to choose it by voice ("sad" — a spoken word of under four
  /// letters has to match a whole label).
  static List<GazeTileCell> faceCells(BuildContext context, WidgetRef ref) {
    final isFilipino = ref.watch(settingsProvider).locale == 'fil';
    return [
      for (final mood in ref.watch(moodPresentationProvider).choices)
        GazeTileCell(
          label: mood.labelOf(isFilipino: isFilipino),
          opens: false,
          onActivate: () => checkIn(context, ref, mood),
        ),
    ];
  }

  @override
  ConsumerState<TodayMoodPane> createState() => _TodayMoodPaneState();
}

class _TodayMoodPaneState extends ConsumerState<TodayMoodPane> {
  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final isFilipino = ref.watch(settingsProvider).locale == 'fil';
    final presentation = ref.watch(moodPresentationProvider);
    final todays = ref.watch(todaysMoodProvider);

    final checkedIn = todays != null;
    final tint = checkedIn
        ? (hc.isDark ? todays.mood.darkColor : todays.mood.color)
        : AppColors.bannerMoodStart;

    return _TodayPane(
      onOpen: widget.onOpen,
      // The mood label is already bilingual; the tile titles around it on Home
      // are not, so only the half that has a translation gets one.
      title: widget.title,
      subtitle: checkedIn
          ? (isFilipino
                ? 'Pakiramdam: ${todays.mood.labelFilipino}'
                : 'Feeling ${todays.mood.label}')
          : (isFilipino ? 'Kumusta ka ngayon?' : 'How are you today?'),
      emoji: checkedIn ? todays.mood.emoji : '😊',
      tint: tint,
      done: checkedIn,
      openSemanticLabel: isFilipino
          ? (checkedIn
                ? 'Check-in ng damdamin. ${todays.mood.labelFilipino} ka '
                      'ngayon. Buksan para sa tala at kasaysayan.'
                : 'Check-in ng damdamin. Hindi ka pa nag-check in ngayon. '
                      'Buksan para sa tala at kasaysayan.')
          : checkedIn
          ? 'Mood check-in. Today you feel '
                '${todays.mood.labelOf(isFilipino: isFilipino)}. '
                'Open for a note and your history.'
          : 'Mood check-in. You have not checked in today. '
                'Open for a note and your history.',
      gazeRow: widget.gazeRow,
      action: _MoodFaces(
        choices: presentation.choices,
        selected: todays?.mood,
        isFilipino: isFilipino,
        enabled: !ref.watch(_moodSavingProvider),
        onPick: (mood) => TodayMoodPane.checkIn(context, ref, mood),
        gazeRow: widget.gazeFaceRow,
      ),
    );
  }
}

/// The quick-pick faces. Exactly the set the learner's accessibility category
/// is offered on the full screen ([MoodPresentation.choices]) — a shortcut
/// that quietly offered a different vocabulary would skew the very data the
/// insights are drawn from.
class _MoodFaces extends StatelessWidget {
  const _MoodFaces({
    required this.choices,
    required this.selected,
    required this.isFilipino,
    required this.enabled,
    required this.onPick,
    this.gazeRow,
  });

  final List<MoodType> choices;
  final MoodType? selected;
  final bool isFilipino;
  final bool enabled;
  final ValueChanged<MoodType> onPick;

  /// See [TodayMoodPane.gazeFaceRow]: face `i` is the stop at column `i`.
  final int? gazeRow;

  @override
  Widget build(BuildContext context) {
    const spacing = 6.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The faces grow to fill the row. A full-width card has room to
        // spare — on a tablet these were 44dp circles adrift in 600dp of
        // card — and a bigger target is strictly better for the learners a
        // 44dp one serves worst. Clamped at both ends: never below the 44
        // minimum (the Wrap breaks the row instead), and never so large that
        // six feelings read as six buttons.
        //
        // The 3 + 3 cap this used to need is gone with the side-by-side
        // layout it existed for; a full-width card takes all six in one row.
        final n = choices.length;
        final width = constraints.maxWidth;
        final size = width.isFinite
            ? ((width - spacing * (n - 1)) / n).clamp(44.0, 64.0)
            : (n <= 3 ? 52.0 : 44.0);
        // Pressed through a box 48 across at the least, whatever size the
        // face is drawn: on a phone, where six share the card, a face is a
        // 44dp circle, under the minimum target. The gaps give way first, so
        // the six still share one row.
        final target = size < 48 ? 48.0 : size;
        final gap = width.isFinite && n > 1
            ? ((width - target * n) / (n - 1)).clamp(0.0, spacing)
            : spacing;

        return Wrap(
          spacing: gap,
          runSpacing: spacing,
          alignment: WrapAlignment.center,
          children: [
            for (final (i, mood) in choices.indexed)
              _gazeStop(
                i,
                _MoodFaceButton(
                  mood: mood,
                  size: size,
                  target: target,
                  selected: mood == selected,
                  isFilipino: isFilipino,
                  onTap: enabled ? () => onPick(mood) : null,
                ),
              ),
          ],
        );
      },
    );
  }

  /// [face] with the D-pad's ring while its stop is focused.
  Widget _gazeStop(int i, Widget face) {
    final row = gazeRow;
    if (row == null) return face;
    return GazeFocusable(row: row, col: i, expand: false, child: face);
  }
}

class _MoodFaceButton extends StatelessWidget {
  const _MoodFaceButton({
    required this.mood,
    required this.size,
    required this.target,
    required this.selected,
    required this.isFilipino,
    required this.onTap,
  });

  final MoodType mood;

  /// The face's drawn size.
  final double size;

  /// The size it is pressed through: [size], or 48 when that is smaller.
  final double target;

  final bool selected;
  final bool isFilipino;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final label = mood.labelOf(isFilipino: isFilipino);
    final tint = hc.hc
        ? hc.primary
        : (hc.isDark ? mood.darkColor : mood.color);

    // One node: the label, and the InkWell's press and focus with it. The
    // words inside are excluded, not the InkWell — excluding that took the
    // press and the focus too, so a browser's screen reader could neither
    // land on a face nor choose it.
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: selected
          ? (isFilipino
                ? '$label. Ito ang pakiramdam mo ngayon.'
                : '$label. This is how you feel today.')
          : (isFilipino
                ? 'Piliin ang $label'
                : 'Check in as $label'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: ExcludeSemantics(
            child: SizedBox.square(
              dimension: target,
              child: Center(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: selected ? 0.40 : 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? tint : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    mood.emoji,
                    textAlign: TextAlign.center,
                    // A fixed size with even leading: emoji fonts have tall
                    // metrics, and letting this grow with the learner's font
                    // setting is what pushes a face out of its own circle.
                    style: TextStyle(
                      fontSize: size * 0.46,
                      height: 1.0,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                    textScaler: const TextScaler.linear(1.0),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── My Day half ──────────────────────────────────────

/// The **My Day** card: how much of today's routine is ticked off, what is
/// next and when it was due, the streak, today's routine mood, and a Done
/// button for the next step.
///
/// The mood chip is the "+ Mood" half of this card. It is not a second
/// check-in control — the Mood Check-In card below owns that — it is the
/// answer the *routine* collected: how brushing teeth felt, or how the day
/// felt once it was finished. That is the pairing worth showing on a
/// schedule.
class TodayDayPane extends ConsumerStatefulWidget {
  const TodayDayPane({
    super.key,
    required this.onOpen,
    this.title = 'My Day',
    this.gazeRow,
    this.gazeDoneRow,
  });

  /// Opens the full "My Day" screen.
  final VoidCallback onOpen;

  /// Heading; see [TodayMoodPane.title].
  final String title;

  /// See [TodayMoodPane.gazeRow].
  final int? gazeRow;

  /// The D-pad row the host registered for [doneCell]. Null while no D-pad
  /// is in use, or when there is no Done button.
  final int? gazeDoneRow;

  /// The Done button's D-pad stop, for the host screen to register as a row
  /// straight under this card's own and hand back as [gazeDoneRow] — or null
  /// where the card draws no Done button: a Student's or Child's day runs on
  /// the clock, and a finished day has no next step. The same test the card
  /// itself makes, so a stop never exists without its button.
  static GazeTileCell? doneCell(BuildContext context, WidgetRef ref) {
    if (ref.watch(routineRunsOnClockProvider)) return null;
    final today = ref.watch(todayRoutineProvider);
    final next = today.nextStep;
    if (next == null) return null;
    return GazeTileCell(
      label: _doneLabel(next, ref.watch(settingsProvider).locale == 'fil'),
      opens: false,
      onActivate: () => complete(context, ref, today, next),
    );
  }

  /// Ticks [step] off: what the Done button does, whether a finger pressed
  /// it or its D-pad stop ([doneCell]). The same flow as the "My Day" list
  /// and the step screen: a check-in step is answered rather than ticked, a
  /// step marked "ask how they feel" asks its question, and finishing the
  /// day asks how it went.
  static Future<void> complete(
    BuildContext context,
    WidgetRef ref,
    TodayRoutine today,
    RoutineStep step,
  ) async {
    final ticking = ref.read(_dayTickingProvider.notifier);
    if (ticking.state) return;
    final profileId = ref.read(profileProvider)?.id;
    if (profileId == null) return;
    ticking.state = true;
    try {
      await RoutineCompletionFlow.complete(
        context: context,
        ref: ref,
        profileId: profileId,
        day: DateTime.now(),
        step: step,
        todaysSteps: today.steps,
        presentation: ref.read(routinePresentationProvider),
        filipino: ref.read(settingsProvider).locale == 'fil',
      );
    } finally {
      if (ticking.mounted) ticking.state = false;
    }
  }

  @override
  ConsumerState<TodayDayPane> createState() => _TodayDayPaneState();
}

/// True while My Day's Done is being saved; see [_moodSavingProvider].
final _dayTickingProvider = StateProvider<bool>((ref) => false);

/// What the Done button is called, to a screen reader and on its D-pad stop.
/// A check-in is answered, not ticked, so its button says so.
String _doneLabel(RoutineStep step, bool isFilipino) {
  if (step.activity.isMoodCheckIn) {
    return isFilipino ? 'Gawin na ang check-in ngayon' : 'Do your check-in now';
  }
  final title = RoutineCatalog.titleFor(step, filipino: isFilipino);
  return isFilipino ? 'Tapos na ang $title' : 'Mark $title as done';
}

class _TodayDayPaneState extends ConsumerState<TodayDayPane> {
  @override
  Widget build(BuildContext context) {
    final isFilipino = ref.watch(settingsProvider).locale == 'fil';
    final today = ref.watch(todayRoutineProvider);
    // Ticks every 10 s, which is what makes "overdue" arrive on its own
    // instead of on the learner's next navigation.
    final now =
        ref.watch(wallClockTickerProvider).valueOrNull ?? DateTime.now();

    // A Student's or Child's day runs on the clock: nothing to tick, and the
    // card says what is on now rather than what is "done".
    final clock = ref.watch(routineRunsOnClockProvider);
    final current = clock ? today.currentStep(now) : null;
    // A step an adult paused is still today's step: it shows, frozen.
    final paused = clock && current == null ? today.pausedStep(now) : null;
    final onNow = current ?? paused;
    final next = onNow ?? today.nextStep;
    // A step can only be late when the learner is the one who finishes it.
    final overdue = !clock && today.isOverdue(now);
    // Today's answer to one of My Day's own questions (a step, a scheduled
    // check-in, the end of the day) — never a plain Home check-in, which
    // belongs to the card below and says nothing about the routine.
    final routineMood = ref.watch(todaysRoutineMoodProvider);

    final String subtitle;
    final startsNext = today.startsNext(filipino: isFilipino);
    if (today.isEmpty && startsNext != null) {
      // A routine made this morning after its steps' times: it has been set
      // up, it just has nothing left today.
      subtitle = isFilipino ? 'Magsisimula $startsNext' : 'Starts $startsNext';
    } else if (today.isEmpty) {
      // An empty day is not a failure, and it is also not a dead end: name
      // who can fill it when there *is* somebody, and say nothing more when
      // there is not. A Player profile has no teacher to ask.
      subtitle = today.hasEducator
          ? (isFilipino
                ? 'Hilingin sa guro o magulang'
                : 'Ask your teacher or parent')
          : (isFilipino ? 'Walang nakatakda ngayon' : 'Nothing planned today');
    } else if (today.allDone || (onNow == null && today.nextStep == null)) {
      // All done — or every step still open was excused by an adult. Either
      // way the day is over, and "Step 13 of 13" would name a step that is
      // not coming.
      subtitle = clock
          ? (isFilipino ? 'Iyan ang lahat ngayon 🎉' : 'That’s all for today 🎉')
          : (isFilipino ? 'Tapos na lahat! 🎉' : 'All done! 🎉');
    } else if (clock) {
      final at = (today.done + 1).clamp(1, today.total);
      subtitle = isFilipino
          ? 'Hakbang $at sa ${today.total}'
          : 'Step $at of ${today.total}';
    } else {
      subtitle = isFilipino
          ? '${today.done} sa ${today.total} tapos'
          : '${today.done} of ${today.total} done';
    }

    return _TodayPane(
      onOpen: widget.onOpen,
      title: widget.title,
      subtitle: subtitle,
      emoji: next == null
          ? (today.isEmpty ? '🗓️' : '🎉')
          : RoutineCatalog.emojiFor(next),
      tint: AppColors.bannerRoutineStart,
      done: today.allDone,
      // A ring only where there is a plan to be part-way through.
      progress: today.fraction,
      // The streak the history screen has always computed and nobody ever
      // showed the learner. Rest days are skipped, so a Mon/Wed/Fri routine
      // does not lose it every Tuesday.
      streak: today.streak,
      moodChip: routineMood == null
          ? null
          : _RoutineMoodChip(mood: routineMood.mood),
      openSemanticLabel: _daySemantics(
        today,
        isFilipino,
        overdue,
        routineMood,
        clock: clock,
        current: current,
        paused: paused,
        now: now,
      ),
      gazeRow: widget.gazeRow,
      action: next == null
          ? null
          : _dayAction(today, next, onNow, now, isFilipino, overdue, clock),
    );
  }

  /// The next or current step, and — for a Student's or Child's step that
  /// is on now — a picture of its time running out.
  Widget _dayAction(
    TodayRoutine today,
    RoutineStep next,
    RoutineStep? onNow,
    DateTime now,
    bool isFilipino,
    bool overdue,
    bool clock,
  ) {
    final isPaused = onNow != null && today.isPaused(onNow.id);
    final endsAt = onNow == null ? null : today.endOf(onNow, now);
    final row = _NextStepRow(
      step: next,
      isFilipino: isFilipino,
      overdue: overdue,
      busy: ref.watch(_dayTickingProvider),
      // A Student or Child has nothing to press: the row only says what is
      // on now, or next.
      onDone: clock
          ? null
          : () => TodayDayPane.complete(context, ref, today, next),
      isNow: onNow != null,
      paused: isPaused,
      endsAt: endsAt,
      gazeRow: widget.gazeDoneRow,
    );
    final start = onNow?.startsOn(now);
    if (onNow == null || start == null || endsAt == null) return row;
    // Bigger for the learners whose day is shown one step at a time: the
    // picture is doing the telling there.
    final big = ref.watch(routinePresentationProvider).showOnlyNextStep;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RoutineNowCountdown(
            start: start,
            end: endsAt,
            now: now,
            filipino: isFilipino,
            emoji: RoutineCatalog.emojiFor(onNow),
            paused: isPaused,
            timerSize: big ? 104 : 76,
          ),
        ),
        row,
      ],
    );
  }

  String _daySemantics(
    TodayRoutine today,
    bool isFilipino,
    bool overdue,
    MoodEntry? routineMood, {
    bool clock = false,
    RoutineStep? current,
    RoutineStep? paused,
    DateTime? now,
  }) {
    // Spoken, so it follows the language setting like the text it stands for.
    final l = isFilipino;
    final head = l ? 'Ang Aking Araw.' : 'My Day.';
    final open = l ? ' Buksan ang iyong araw.' : ' Open your day.';
    final startsNext = today.startsNext(filipino: l);
    if (today.isEmpty && startsNext != null) {
      return l
          ? '$head Magsisimula ang iyong routine $startsNext.$open'
          : '$head Your routine starts $startsNext.$open';
    }
    if (today.isEmpty) {
      if (l) {
        return today.hasEducator
            ? '$head Walang nakatakda ngayon — puwede itong ayusin ng iyong '
                  'guro o magulang.$open'
            : '$head Walang nakatakda ngayon.$open';
      }
      return today.hasEducator
          ? 'My Day. Nothing is scheduled for today — your teacher or parent '
                'can set one up. Open your day.'
          : 'My Day. Nothing is scheduled for today. Open your day.';
    }
    // The chip sits inside the header's excluded subtree, so this sentence is
    // the only way the mood reaches a screen reader.
    final feeling = routineMood?.mood.labelOf(isFilipino: isFilipino);
    final mood = routineMood == null
        ? ''
        : (routineMood.routineStepTitle == null
              ? (l
                    ? ' Sabi mo, $feeling ang araw na ito.'
                    : ' You said today felt $feeling.')
              : (l
                    ? ' $feeling ka pagkatapos ng '
                          '${routineMood.routineStepTitle}.'
                    : ' You felt $feeling '
                          'after ${routineMood.routineStepTitle}.'));
    // "1 days finished in a row" is the kind of thing a screen reader says
    // out loud, so it gets a plural.
    final streak = today.streak > 0
        ? (l
              ? ' ${today.streak} araw na sunod-sunod na natapos.'
              : ' ${today.streak} day${today.streak == 1 ? '' : 's'} '
                    'finished in a row.')
        : '';
    if (today.allDone) {
      if (clock) {
        return l
            ? '$head Iyan ang lahat ngayon.$streak$mood$open'
            : 'My Day. That’s all for today.$streak$mood Open your day.';
      }
      return l
          ? '$head Tapos na ang lahat ng ${today.total} hakbang.'
                '$streak$mood$open'
          : 'My Day. All ${today.total} steps are done.$streak$mood '
                'Open your day.';
    }
    if (current != null) {
      final title = RoutineCatalog.titleFor(current, filipino: isFilipino);
      final at = now ?? DateTime.now();
      final end = today.endOf(current, at);
      final left = end == null
          ? ''
          : ' ${RoutineNowCountdown.leftLabel(end: end, now: at, filipino: l)}.';
      return l
          ? '$head Ngayon: $title, hanggang '
                '${formatStepEnd(current, end: end)}.$left$streak$mood$open'
          : 'My Day. Now: $title, until ${formatStepEnd(current, end: end)}.'
                '$left$streak$mood Open your day.';
    }
    if (paused != null) {
      final title = RoutineCatalog.titleFor(paused, filipino: isFilipino);
      return l
          ? '$head Nakahinto: $title. Ang iyong guro o magulang ang '
                'magpapatuloy nito.$streak$mood$open'
          : 'My Day. Paused: $title. Your teacher or parent will start it '
                'again.$streak$mood Open your day.';
    }
    final next = today.nextStep;
    if (next == null) {
      // Not all done, nothing running or paused, and no next step: every step
      // still open was excused by an adult. There is nothing more today —
      // found on the NDL W09, where this was a null check that took the whole
      // Home card down (and its "Something went wrong" snackbar with it).
      return l
          ? '$head Iyan ang lahat ngayon.$streak$mood$open'
          : 'My Day. That’s all for today.$streak$mood Open your day.';
    }
    final title = RoutineCatalog.titleFor(next, filipino: isFilipino);
    final when = next.isScheduled
        ? (l
              ? ' sa ${_clock(next)}${overdue ? ', lampas na sa oras' : ''}'
              : ' at ${_clock(next)}${overdue ? ', overdue' : ''}')
        : '';
    if (l) {
      if (clock) return '$head Susunod: $title$when.$streak$mood$open';
      return '$head ${today.done} sa ${today.total} hakbang ang tapos. '
          'Susunod: $title$when.$streak$mood$open';
    }
    if (clock) return 'My Day. Next: $title$when.$streak$mood Open your day.';
    return 'My Day. ${today.done} of ${today.total} steps done. '
        'Next: $title$when.$streak$mood Open your day.';
  }
}

/// The next step, its time, and the button that ticks it off.
class _NextStepRow extends StatelessWidget {
  const _NextStepRow({
    required this.step,
    required this.isFilipino,
    required this.overdue,
    required this.busy,
    required this.onDone,
    this.isNow = false,
    this.paused = false,
    this.endsAt,
    this.gazeRow,
  });

  final RoutineStep step;
  final bool isFilipino;
  final bool overdue;
  final bool busy;

  /// See [TodayDayPane.gazeDoneRow].
  final int? gazeRow;

  /// [button] with the D-pad's ring while its stop is focused.
  Widget _gazeStop(Widget button) {
    final row = gazeRow;
    if (row == null) return button;
    return GazeFocusable(row: row, col: 0, expand: false, child: button);
  }

  /// Null for a Student or Child: nothing to tick, so no button.
  final VoidCallback? onDone;

  /// The step's time is running now (a Student's or Child's current step).
  final bool isNow;

  /// An adult paused the step that is on now.
  final bool paused;

  /// The step's end as it stands today; null means its planned end.
  final DateTime? endsAt;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final title = RoutineCatalog.titleFor(step, filipino: isFilipino);
    final late = overdue && !hc.hc;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Excluded from semantics: the pane's own label already reads
        // "Next: Brushing Teeth at 6:45, overdue", and a second node saying
        // the same fragments is one more thing to swipe past.
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (step.isScheduled) ...[
                Icon(
                  overdue
                      ? Icons.running_with_errors_rounded
                      : Icons.schedule_rounded,
                  size: 14,
                  color: late ? HCColor.of(context).graphic(AppColors.error) : hc.textSecondary,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  isNow && paused
                      ? '${isFilipino ? 'Nakahinto' : 'Paused'}: $title'
                      : isNow
                      ? '${isFilipino ? 'Ngayon' : 'Now'}: $title · '
                            '${isFilipino ? 'hanggang' : 'until'} '
                            '${formatStepEnd(step, end: endsAt)}'
                      : step.isScheduled
                      ? '${isFilipino ? 'Susunod' : 'Next'}: $title · '
                            '${_clock(step)}'
                      : '${isFilipino ? 'Susunod' : 'Next'}: $title',
                  style: AppTypography.labelSmall.copyWith(
                    color: late ? HCColor.of(context).errorText : hc.textSecondary,
                    fontWeight: late ? FontWeight.w700 : FontWeight.w500,
                  ),
                  // Whole: a step's title is the learner's next thing to do.
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        if (onDone != null) ...[
          const SizedBox(height: 6),
          _gazeStop(
            Semantics(
              container: true,
              enabled: !busy,
              button: true,
              label: _doneLabel(step, isFilipino),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: busy ? null : onDone,
                  borderRadius: BorderRadius.circular(22),
                  child: ExcludeSemantics(
                    child: Container(
                      // 44 high, so the one control a learner is meant to hit from
                      // Home clears the minimum target on every profile.
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: hc.primary.withValues(alpha: hc.hc ? 0.30 : 0.16),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: hc.primary, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            step.activity.isMoodCheckIn
                                ? Icons.chat_bubble_rounded
                                : Icons.check_rounded,
                            size: 18,
                            color: hc.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              step.activity.isMoodCheckIn
                                  ? (isFilipino ? 'Mag-check in' : 'Check in')
                                  : (isFilipino ? 'Tapos na' : 'Done'),
                              style: AppTypography.labelMedium.copyWith(
                                color: hc.primary,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// `6:45 AM`, without pulling a locale-aware formatter into a card.
String _clock(RoutineStep step) {
  final h = step.hour!;
  final m = step.minute!.toString().padLeft(2, '0');
  final suffix = h < 12 ? 'AM' : 'PM';
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  return '$hour12:$m $suffix';
}

// ─── Shared pane shell ────────────────────────────────

/// The shared shell of both cards: a tinted emoji badge, a title, one line of
/// live state, and the card's own control beneath it.
class _TodayPane extends StatelessWidget {
  const _TodayPane({
    required this.onOpen,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.tint,
    required this.openSemanticLabel,
    this.action,
    this.done = false,
    this.progress,
    this.streak = 0,
    this.moodChip,
    this.gazeRow,
  });

  final VoidCallback onOpen;
  final String title;
  final String subtitle;
  final String emoji;
  final Color tint;

  /// Label for the "open the full screen" target — the header, not the pane.
  final String openSemanticLabel;

  /// The D-pad row that opens the full screen, ringed around the header
  /// alone: around the whole pane it took in the faces and the Done button,
  /// which have stops of their own, and pressing would not do what the ring
  /// seemed to promise.
  final int? gazeRow;

  /// The half's in-place control (mood faces / Done button). Sits *outside*
  /// the open-the-screen tap target: a learner reaching for a face must never
  /// land on a navigation instead.
  final Widget? action;

  /// Draws the small "done" check on the badge.
  final bool done;

  /// 0–1 completion ring around the badge, or null for no ring.
  final double? progress;

  /// Consecutive complete days, shown as a chip next to the title when > 0.
  final int streak;

  /// Today's routine mood, as a chip beside the streak. Null shows nothing —
  /// a day nobody has been asked about yet has no face to report.
  final Widget? moodChip;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    final badge = _Badge(
      emoji: emoji,
      tint: tint,
      done: done,
      progress: progress,
    );
    final titleRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Two lines before it is cut: "Check-in ng Damdamin" lost its end
        // beside the streak on a phone (3 Nov).
        Flexible(
          child: FitText(
            title,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: hc.textPrimary,
            ),
          ),
        ),
        if (streak > 0) ...[
          const SizedBox(width: 6),
          _StreakChip(streak: streak),
        ],
        if (moodChip != null) ...[
          const SizedBox(width: 6),
          moodChip!,
        ],
      ],
    );
    final subtitleText = Text(
      subtitle,
      style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
    );

    final header = Semantics(
      container: true,
      button: true,
      label: openSemanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(14),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  badge,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [titleRow, subtitleText],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: hc.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final row = gazeRow;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (row == null)
          header
        else
          GazeFocusable(row: row, col: 0, expand: false, child: header),
        if (action != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
            child: action,
          ),
      ],
    );
  }
}

/// "🔥 3" — consecutive complete days.
class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: hc.hc ? 0.30 : 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '🔥 $streak',
        style: AppTypography.labelSmall.copyWith(
          color: hc.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        maxLines: 1,
      ),
    );
  }
}

/// "🙂" — how My Day's own questions were answered today.
class _RoutineMoodChip extends StatelessWidget {
  const _RoutineMoodChip({required this.mood});

  final MoodType mood;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final tint = hc.hc ? hc.primary : (hc.isDark ? mood.darkColor : mood.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: hc.hc ? 0.32 : 0.20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        mood.emoji,
        // Fixed size with even leading: emoji fonts have tall metrics, and
        // letting this grow with the font setting is what pushes a chip out
        // of a title row.
        style: const TextStyle(
          fontSize: 13,
          height: 1.0,
          leadingDistribution: TextLeadingDistribution.even,
        ),
        textScaler: const TextScaler.linear(1.0),
        maxLines: 1,
      ),
    );
  }
}

/// The emoji badge: a tinted circle, an optional completion ring, and an
/// optional "done" check.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.emoji,
    required this.tint,
    required this.done,
    this.progress,
  });

  final String emoji;
  final Color tint;
  final bool done;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    // High contrast paints its own ink; elsewhere the tint is the point.
    final ring = hc.hc ? hc.primary : tint;

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (progress != null)
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                strokeWidth: 4,
                backgroundColor: hc.border,
                valueColor: AlwaysStoppedAnimation<Color>(ring),
              ),
            ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ring.withValues(alpha: hc.hc ? 0.22 : 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              emoji,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                height: 1.0,
                leadingDistribution: TextLeadingDistribution.even,
              ),
              textScaler: const TextScaler.linear(1.0),
            ),
          ),
          if (done)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: hc.surface, width: 2),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 11,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
