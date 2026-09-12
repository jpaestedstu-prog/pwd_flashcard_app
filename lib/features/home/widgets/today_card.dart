import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/wall_clock_provider.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../widgets/shared_widgets.dart';
import '../../mood_tracker/models/mood_models.dart';
import '../../mood_tracker/models/mood_presentation.dart';
import '../../mood_tracker/services/quick_mood_check_in.dart';
import '../../routine/models/routine_catalog.dart';
import '../../routine/models/routine_models.dart';
import '../../routine/models/routine_presentation.dart';
import '../../routine/providers/today_routine_provider.dart';
import '../../routine/services/routine_completion_flow.dart';

/// "Today" — the learner's **Mood Check-In** and their **My Day** routine in
/// one card, directly under the stats banner on Home.
///
/// The two used to be small, dead tiles buried in the "Personal & Wellbeing"
/// group near the bottom of the page: identical whether or not the learner had
/// checked in, and whether or not an adult had scheduled anything for them.
/// They belong together — both answer "what is today like for me?" — and both
/// are only useful if they show *state*.
///
/// Each half is now also **actionable in place**: the faces record a check-in
/// without a screen change, and Done ticks the next routine step. That is the
/// point of the promotion. A daily habit dies at the navigation step, and for
/// the learners this app is built for that step is the expensive part — so the
/// card does the common thing and the full screens keep the rest (a written
/// note, correcting yesterday, the history, the step instructions and signs).
///
/// The two halves stay **separate tap targets and separate gaze / voice
/// cells**: they open different screens, and a learner driving the D-pad must
/// be able to reach Mood without passing through My Day. The home screen
/// therefore builds each pane as its own gaze entry and hands the wrapped
/// widgets in — see [TodayMoodPane] / [TodayDayPane].
class TodayCard extends StatelessWidget {
  const TodayCard({super.key, required this.mood, required this.day});

  /// The gaze-wrapped [TodayMoodPane].
  final Widget mood;

  /// The gaze-wrapped [TodayDayPane].
  final Widget day;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return AppCard(
      color: hc.surface,
      borderRadius: 20,
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Side by side only while both halves can still hold a headline, a
          // line of state and their row of controls. Below that — a narrow
          // phone, or a learner on the big-font setting — they stack, because
          // two squeezed columns ellipsise exactly the words that carry the
          // information and shrink exactly the buttons that must stay big.
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final stacked = constraints.maxWidth < 420 || scale > 1.25;

          if (stacked) {
            return _TodayLayout(
              vertical: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  mood,
                  Divider(height: 9, thickness: 1.5, color: hc.border),
                  day,
                ],
              ),
            );
          }

          return _TodayLayout(
            vertical: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: mood),
                Container(width: 1.5, height: 96, color: hc.border),
                Expanded(child: day),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Carries the card's chosen orientation down to the panes.
///
/// The panes are constructed by the home screen (they have to be — each one is
/// a gaze cell, and gaze cells must be registered in the screen's own build so
/// their row order matches the visual order), but the orientation is only
/// known inside the card's [LayoutBuilder]. An inherited widget is how the
/// later answer reaches the earlier-built child.
class _TodayLayout extends InheritedWidget {
  const _TodayLayout({required this.vertical, required super.child});

  final bool vertical;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TodayLayout>()?.vertical ??
      false;

  @override
  bool updateShouldNotify(_TodayLayout oldWidget) =>
      oldWidget.vertical != vertical;
}

// ─── Mood half ────────────────────────────────────────

/// The Mood half of [TodayCard]: today's face if the learner has checked in,
/// an invitation if not — and either way, the faces themselves, so a check-in
/// costs one tap from Home.
class TodayMoodPane extends ConsumerStatefulWidget {
  const TodayMoodPane({
    super.key,
    required this.onOpen,
    this.title = 'Mood Check-In',
  });

  /// Opens the full Mood Check-In screen.
  final VoidCallback onOpen;

  /// Heading, so the Child home can keep its own friendlier wording
  /// ("My Feelings") while sharing the card. Must match the gaze / voice cell
  /// label the host screen registers, or a learner would hear one name and
  /// have to say another.
  final String title;

  @override
  ConsumerState<TodayMoodPane> createState() => _TodayMoodPaneState();
}

class _TodayMoodPaneState extends ConsumerState<TodayMoodPane> {
  /// True while a write is in flight, so a learner who taps twice does not
  /// file two entries.
  bool _saving = false;

  Future<void> _pick(MoodType mood) async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await QuickMoodCheckIn.record(ref, mood: mood);
    if (!mounted) return;
    setState(() => _saving = false);
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
      openSemanticLabel: checkedIn
          ? 'Mood check-in. Today you feel '
                '${todays.mood.labelOf(isFilipino: isFilipino)}. '
                'Open for a note and your history.'
          : 'Mood check-in. You have not checked in today. '
                'Open for a note and your history.',
      action: _MoodFaces(
        choices: presentation.choices,
        selected: todays?.mood,
        isFilipino: isFilipino,
        enabled: !_saving,
        onPick: _pick,
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
  });

  final List<MoodType> choices;
  final MoodType? selected;
  final bool isFilipino;
  final bool enabled;
  final ValueChanged<MoodType> onPick;

  @override
  Widget build(BuildContext context) {
    // Fewer faces buy bigger targets. The three-way set is exactly the one
    // given to the cognitive / multiple-disability categories, who are also
    // the learners a 44px target serves worst. Nothing shrinks below 44 to
    // make a row fit — the row wraps instead.
    final size = choices.length <= 3 ? 52.0 : 44.0;
    const spacing = 6.0;

    final faces = Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.center,
      children: [
        for (final mood in choices)
          _MoodFaceButton(
            mood: mood,
            size: size,
            selected: mood == selected,
            isFilipino: isFilipino,
            onTap: enabled ? () => onPick(mood) : null,
          ),
      ],
    );

    // Six faces are ~5dp too wide for half a portrait tablet, so the Wrap
    // broke them 5 + 1 — which reads as a mistake rather than a grid. Cap the
    // row at three and it breaks 3 + 3 on purpose. Only in the side-by-side
    // layout: stacked, the full width takes all six in one row.
    if (_TodayLayout.of(context) && choices.length > 3) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: size * 3 + spacing * 2),
          child: faces,
        ),
      );
    }
    return faces;
  }
}

class _MoodFaceButton extends StatelessWidget {
  const _MoodFaceButton({
    required this.mood,
    required this.size,
    required this.selected,
    required this.isFilipino,
    required this.onTap,
  });

  final MoodType mood;
  final double size;
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

    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? (isFilipino
                ? '$label. Ito ang pakiramdam mo ngayon.'
                : '$label. This is how you feel today.')
          : (isFilipino
                ? 'Piliin ang $label'
                : 'Check in as $label'),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
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
              // A fixed size with even leading: emoji fonts have tall metrics,
              // and letting this grow with the learner's font setting is what
              // pushes a face out of its own circle.
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
    );
  }
}

// ─── My Day half ──────────────────────────────────────

/// The My Day half of [TodayCard]: how much of today's routine is ticked off,
/// what is next and when it was due, the streak, and a Done button for the
/// next step.
class TodayDayPane extends ConsumerStatefulWidget {
  const TodayDayPane({super.key, required this.onOpen, this.title = 'My Day'});

  /// Opens the full "My Day" screen.
  final VoidCallback onOpen;

  /// Heading; see [TodayMoodPane.title].
  final String title;

  @override
  ConsumerState<TodayDayPane> createState() => _TodayDayPaneState();
}

class _TodayDayPaneState extends ConsumerState<TodayDayPane> {
  bool _ticking = false;

  Future<void> _done(TodayRoutine today, RoutineStep step) async {
    if (_ticking) return;
    final profileId = ref.read(profileProvider)?.id;
    if (profileId == null) return;
    setState(() => _ticking = true);

    // The same flow as the "My Day" list and the step screen: a check-in step
    // is answered rather than ticked, a step marked "ask how they feel" asks
    // its question, and finishing the day asks how it went.
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
    if (mounted) setState(() => _ticking = false);
  }

  @override
  Widget build(BuildContext context) {
    final isFilipino = ref.watch(settingsProvider).locale == 'fil';
    final today = ref.watch(todayRoutineProvider);
    // Ticks every 10 s, which is what makes "overdue" arrive on its own
    // instead of on the learner's next navigation.
    final now =
        ref.watch(wallClockTickerProvider).valueOrNull ?? DateTime.now();

    final next = today.nextStep;
    final overdue = today.isOverdue(now);

    final String subtitle;
    if (today.isEmpty) {
      // An empty day is not a failure, and it is also not a dead end: name
      // who can fill it when there *is* somebody, and say nothing more when
      // there is not. A Player profile has no teacher to ask.
      subtitle = today.hasEducator
          ? (isFilipino
                ? 'Hilingin sa guro o magulang'
                : 'Ask your teacher or parent')
          : (isFilipino ? 'Walang nakatakda ngayon' : 'Nothing planned today');
    } else if (today.allDone) {
      subtitle = isFilipino ? 'Tapos na lahat! 🎉' : 'All done! 🎉';
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
      openSemanticLabel: _daySemantics(today, isFilipino, overdue),
      action: next == null
          ? null
          : _NextStepRow(
              step: next,
              isFilipino: isFilipino,
              overdue: overdue,
              busy: _ticking,
              onDone: () => _done(today, next),
            ),
    );
  }

  String _daySemantics(TodayRoutine today, bool isFilipino, bool overdue) {
    if (today.isEmpty) {
      return today.hasEducator
          ? 'My Day. Nothing is scheduled for today — your teacher or parent '
                'can set one up. Open your day.'
          : 'My Day. Nothing is scheduled for today. Open your day.';
    }
    // "1 days finished in a row" is the kind of thing a screen reader says
    // out loud, so it gets a plural.
    final streak = today.streak > 0
        ? ' ${today.streak} day${today.streak == 1 ? '' : 's'} '
              'finished in a row.'
        : '';
    if (today.allDone) {
      return 'My Day. All ${today.total} steps are done.$streak '
          'Open your day.';
    }
    final next = today.nextStep!;
    final title = RoutineCatalog.titleFor(next, filipino: isFilipino);
    final when = next.isScheduled
        ? ' at ${_clock(next)}${overdue ? ', overdue' : ''}'
        : '';
    return 'My Day. ${today.done} of ${today.total} steps done. '
        'Next: $title$when.$streak Open your day.';
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
  });

  final RoutineStep step;
  final bool isFilipino;
  final bool overdue;
  final bool busy;
  final VoidCallback onDone;

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
                  color: late ? AppColors.error : hc.textSecondary,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  step.isScheduled
                      ? '${isFilipino ? 'Susunod' : 'Next'}: $title · '
                            '${_clock(step)}'
                      : '${isFilipino ? 'Susunod' : 'Next'}: $title',
                  style: AppTypography.labelSmall.copyWith(
                    color: late ? AppColors.error : hc.textSecondary,
                    fontWeight: late ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          // A check-in is answered, not ticked, so its button says so.
          label: step.activity.isMoodCheckIn
              ? (isFilipino
                    ? 'Gawin na ang check-in ngayon'
                    : 'Do your check-in now')
              : (isFilipino ? 'Tapos na ang $title' : 'Mark $title as done'),
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: busy ? null : onDone,
              borderRadius: BorderRadius.circular(22),
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

/// The shared shell of both halves: a tinted emoji badge, a title, one line of
/// live state, and the half's own control. Laid out as a column when the card
/// is side-by-side and as a row when it has stacked.
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
  });

  final VoidCallback onOpen;
  final String title;
  final String subtitle;
  final String emoji;
  final Color tint;

  /// Label for the "open the full screen" target — the header, not the pane.
  final String openSemanticLabel;

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

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final vertical = _TodayLayout.of(context);

    final badge = _Badge(
      emoji: emoji,
      tint: tint,
      done: done,
      progress: progress,
    );
    final titleRow = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          vertical ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            title,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: hc.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (streak > 0) ...[
          const SizedBox(width: 6),
          _StreakChip(streak: streak),
        ],
      ],
    );
    final subtitleText = Text(
      subtitle,
      style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: vertical ? TextAlign.center : TextAlign.start,
    );

    final header = Semantics(
      button: true,
      label: openSemanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: vertical
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      badge,
                      const SizedBox(height: 8),
                      titleRow,
                      const SizedBox(height: 2),
                      subtitleText,
                    ],
                  )
                : Row(
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
                      Icon(
                        Icons.chevron_right_rounded,
                        color: hc.textSecondary,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
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
