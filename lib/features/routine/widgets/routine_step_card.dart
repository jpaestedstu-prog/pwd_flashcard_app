import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/routine_catalog.dart';
import '../models/routine_models.dart';
import '../models/routine_presentation.dart';
import '../models/routine_timeline.dart';

/// One step of a learner's day, as a card in the routine list.
///
/// Everything about how much this card shows and how it is operated comes from
/// [RoutinePresentation], not from a `DisabilityType` switch here: whether the
/// tick target is a checkbox or a full-width button, whether the instructions
/// are already open, whether a Signs button appears at all.
///
/// A Student's or Child's day runs on the clock ([canTick] false). Their card
/// has nothing to tick — no checkbox, no "Mark as done" — and says where the
/// step stands instead: "Now · until 7:40 PM", "Earlier today", "Not today".
/// A Player ticks their own steps, as before.
class RoutineStepCard extends StatelessWidget {
  final RoutineStep step;
  final bool done;
  final bool isNext;
  final bool filipino;
  final RoutinePresentation presentation;

  /// Whether this step has at least one FSL clip that will actually play.
  /// Resolved by the screen (it needs an async manifest load), so the card
  /// never draws a Signs button that would fail.
  final bool hasSigns;

  final VoidCallback onToggle;
  final VoidCallback onOpen;

  /// Whether the learner ticks this step off themselves. False for a Student
  /// or Child, whose steps are finished when their time ends.
  final bool canTick;

  /// Where the step stands on the clock. Only shown when [canTick] is false.
  final RoutineStepMoment moment;

  /// The step's end as it stands today, when an adult added time or paused
  /// it. Null means its planned end.
  final DateTime? endsAt;

  const RoutineStepCard({
    super.key,
    required this.step,
    required this.done,
    required this.isNext,
    required this.filipino,
    required this.presentation,
    required this.hasSigns,
    required this.onToggle,
    required this.onOpen,
    this.canTick = true,
    this.moment = RoutineStepMoment.upcoming,
    this.endsAt,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final title = RoutineCatalog.titleFor(step, filipino: filipino);
    final note = RoutineCatalog.noteFor(step, filipino: filipino);
    final emoji = RoutineCatalog.emojiFor(step);
    final accent = isNext ? hc.primary : hc.textSecondary;
    final over = canTick ? done : moment == RoutineStepMoment.earlier;
    final momentLabel = canTick
        ? ''
        : routineMomentLabel(step, moment, filipino: filipino, endsAt: endsAt);

    final timeLabel = step.isScheduled
        ? formatStepTime(step)
        : (filipino ? 'Kahit anong oras' : 'Any time');

    final spokenState = canTick
        ? (done
            ? (filipino ? 'tapos na' : 'done')
            : (filipino ? 'hindi pa tapos' : 'not done yet'))
        : routineMomentSpoken(step, moment, filipino: filipino, endsAt: endsAt);

    return Semantics(
      container: true,
      button: true,
      // One label for the whole card: a screen-reader learner hears
      // "Brushing teeth, 6:45 AM, 2 minutes, happening now" rather than
      // sweeping four separate nodes. Curly apostrophes only — a straight
      // quote empties the whole content description on Android.
      label: [
        title,
        timeLabel,
        if (step.hasTimer) _durationLabel(),
        if (spokenState.isNotEmpty) spokenState,
      ].join(', '),
      child: ExcludeSemantics(
        child: Card(
          elevation: isNext ? 3 : 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isNext
                  ? hc.primary.withValues(alpha: 0.6)
                  : hc.textHint.withValues(alpha: 0.25),
              width: isNext ? 2 : 1,
            ),
          ),
          color: over
              ? Color.alphaBlend(
                  AppColors.success.withValues(alpha: 0.12),
                  hc.surface,
                )
              : hc.surface,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 34)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: hc.textPrimary,
                                decoration:
                                    over ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Wrap, not Row: at a 2.0x font scale the time and
                            // duration chips together are wider than a phone.
                            Wrap(
                              spacing: 10,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (momentLabel.isNotEmpty)
                                  _MetaChip(
                                    icon: switch (moment) {
                                      RoutineStepMoment.now =>
                                        Icons.play_circle_rounded,
                                      RoutineStepMoment.earlier =>
                                        Icons.check_circle_rounded,
                                      RoutineStepMoment.paused =>
                                        Icons.pause_circle_rounded,
                                      _ => Icons.do_not_disturb_on_rounded,
                                    },
                                    label: momentLabel,
                                    color: moment == RoutineStepMoment.now
                                        ? hc.primary
                                        : hc.textSecondary,
                                    strong: moment == RoutineStepMoment.now,
                                  ),
                                _MetaChip(
                                  icon: Icons.schedule_rounded,
                                  label: timeLabel,
                                  color: accent,
                                ),
                                if (step.hasTimer)
                                  _MetaChip(
                                    icon: Icons.timer_rounded,
                                    label: _durationLabel(),
                                    color: accent,
                                  ),
                                if (hasSigns && presentation.showFsl)
                                  const _MetaChip(
                                    icon: Icons.sign_language_rounded,
                                    label: 'FSL',
                                    color: AppColors.secondaryDark,
                                  ),
                                for (final kind
                                    in presentation.mediaFor(step).take(3))
                                  _MetaChip(
                                    icon: switch (kind) {
                                      RoutineMediaKind.photo =>
                                        Icons.photo_rounded,
                                      RoutineMediaKind.gif =>
                                        Icons.gif_box_rounded,
                                      RoutineMediaKind.video =>
                                        Icons.play_circle_rounded,
                                      RoutineMediaKind.audio =>
                                        Icons.volume_up_rounded,
                                    },
                                    label: '',
                                    color: accent,
                                  ),
                              ],
                            ),
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                note,
                                style: AppTypography.bodySmall.copyWith(
                                  color: hc.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (canTick && !presentation.largeCompleteTarget)
                        Checkbox(
                          value: done,
                          onChanged: (_) => onToggle(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                    ],
                  ),
                  if (canTick && presentation.largeCompleteTarget) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      // 56 high: the motor / cognitive configurations tick off
                      // from this button alone, so it has to clear the 48 dp
                      // minimum with room for an unsteady tap.
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: onToggle,
                        icon: Icon(
                          done
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                        ),
                        label: Text(
                          done
                              ? (filipino ? 'Tapos na!' : 'Done!')
                              : (filipino ? 'Markahang tapos' : 'Mark as done'),
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              HCColor.of(context).fillFor(done ? AppColors.success : hc.primary),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _durationLabel() => filipino
      ? '${step.durationMinutes} minuto'
      : '${step.durationMinutes} min';
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool strong;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// `7:05 AM` for a scheduled step, empty for an unscheduled one.
///
/// Deliberately not `TimeOfDay.format`, which needs a [BuildContext] and would
/// make this unusable from the pure model tests and from the educator's
/// summary strings.
String formatStepTime(RoutineStep step) {
  if (!step.isScheduled) return '';
  final h = step.hour!;
  final m = step.minute!;
  final suffix = h < 12 ? 'AM' : 'PM';
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  return '$hour12:${m.toString().padLeft(2, '0')} $suffix';
}

/// "Every day" / "Mon, Wed, Fri" for a routine's recurrence.
String formatDays(Set<int> days, {required bool filipino}) {
  if (days.isEmpty) return filipino ? 'Araw-araw' : 'Every day';
  const en = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };
  const fil = {
    1: 'Lun',
    2: 'Mar',
    3: 'Miy',
    4: 'Huw',
    5: 'Biy',
    6: 'Sab',
    7: 'Lin',
  };
  final names = filipino ? fil : en;
  final sorted = days.toList()..sort();
  return sorted.map((d) => names[d] ?? '?').join(', ');
}
