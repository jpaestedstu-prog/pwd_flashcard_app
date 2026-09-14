import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../providers/routine_provider.dart';
import '../../../widgets/app_card.dart';
import '../models/routine_catalog.dart';
import '../models/routine_lock_status.dart';
import '../models/routine_models.dart';
import '../services/routine_lock_recorder.dart';
import 'routine_educator_actions.dart';
import 'routine_lock_status_line.dart';

/// "Today's Routines" — the Routine surface on the Teacher and Parent
/// dashboards.
///
/// One row per learner: whether they have a routine at all, how much of
/// today's is done, and a tap straight into their routine manager. The whole
/// row is the button, and the row is present even for a learner with no
/// routine — the "Set one up" state is the entry point that gets the first
/// routine built, and hiding it would leave the feature undiscoverable for
/// exactly the learners who have not got one yet.
///
/// One widget for both educator roles, like every other educator surface —
/// only [learnerNounPlural] changes.
class EducatorRoutineSection extends ConsumerWidget {
  /// Learner profile ids, in roster order, with their display names and
  /// accessibility categories.
  final List<EducatorRoutineLearner> learners;

  /// "children" / "students".
  final String learnerNounPlural;

  /// "child" / "student" — forwarded to the routine manager so its copy
  /// reads correctly for whichever educator opened it.
  final String learnerNoun;

  final bool filipino;

  const EducatorRoutineSection({
    super.key,
    required this.learners,
    required this.learnerNounPlural,
    required this.learnerNoun,
    required this.filipino,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final l = filipino;
    if (learners.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded, color: hc.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l ? 'Mga Routine Ngayon' : "Today's Routines",
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l
                ? 'Pindutin ang isang pangalan para gumawa o baguhin ang '
                    'pang-araw-araw na routine.'
                : 'Tap a name to build or change their daily routine.',
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final learner in learners)
            _RoutineRow(
              learner: learner,
              learnerNoun: learnerNoun,
              filipino: l,
            ),
        ],
      ),
    );
  }
}

/// The learner identity this section needs. A small record type rather than
/// `ChildSummary`, so the section can also be used from a roster that has not
/// computed a full summary.
class EducatorRoutineLearner {
  final String profileId;
  final String name;
  final String avatarEmoji;
  final DisabilityType accessibility;

  const EducatorRoutineLearner({
    required this.profileId,
    required this.name,
    required this.avatarEmoji,
    required this.accessibility,
  });
}

class _RoutineRow extends ConsumerWidget {
  final EducatorRoutineLearner learner;
  final String learnerNoun;
  final bool filipino;

  const _RoutineRow({
    required this.learner,
    required this.learnerNoun,
    required this.filipino,
  });

  void _alertIfNeeded(
    BuildContext context,
    WidgetRef ref,
    RoutineLockSummary summary,
  ) {
    final current = summary.current;
    if (current == null || current.phase != RoutineStepPhase.needsHelp) return;
    final key =
        '${learner.profileId}|${dayStampOf(current.now)}|${current.step.id}';
    final alerted = ref.read(routineHelpAlertedProvider);
    if (alerted.contains(key)) return;
    ref.read(routineHelpAlertedProvider.notifier).state = {...alerted, key};

    final l = filipino;
    final title = RoutineCatalog.titleFor(current.step, filipino: l);
    final minutes = current.minutesWaiting;
    final message = l
        ? 'Kailangan ng tulong si ${learner.name} sa $title ($minutes minuto)'
        : '${learner.name} needs help with $title ($minutes min)';
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
    unawaited(
      ref.read(routineHelpAlerterProvider).alert(
            key: key,
            title: l ? 'Kailangan ng tulong ang isang bata' : 'A learner needs help',
            body: message,
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final l = filipino;
    final today = DateTime.now();

    // The escalation's other half: tell the educator, once, the moment a
    // learner has waited too long — including when the dashboard opens on a
    // learner who already has. The red row says it too; this makes sure it
    // is noticed by someone who is not staring at the row. Watched rather
    // than listened to, so an already-stuck learner counts on the very first
    // frame; the alert itself runs after the frame, where changing state and
    // showing a snackbar are allowed.
    final lockSummary =
        ref.watch(routineLockSummaryProvider(learner.profileId));
    if (lockSummary.needsHelp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _alertIfNeeded(context, ref, lockSummary);
      });
    }
    final routines =
        ref.watch(routineListProvider(learner.profileId)).valueOrNull ??
            const <Routine>[];
    final log = ref
        .watch(routineDayViewProvider(routineDayKey(learner.profileId, today)))
        .effectiveLog;

    final live = routines.where((r) => r.enabled && r.runsOn(today)).toList();
    final steps = [for (final r in live) ...r.orderedSteps];
    final done =
        steps.where((s) => log.completedStepIds.contains(s.id)).length;
    final hasAny = routines.isNotEmpty;

    final subtitle = !hasAny
        ? (l ? 'Wala pang routine — gumawa ng isa' : 'No routine yet — set one up')
        : steps.isEmpty
            ? (l ? 'Walang nakatakda ngayon' : 'Nothing scheduled today')
            : (l
                ? '$done sa ${steps.length} tapos na'
                : '$done of ${steps.length} done');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push(
            '/routine-manage/${learner.profileId}'
            '?name=${Uri.encodeQueryComponent(learner.name)}'
            '&noun=${Uri.encodeQueryComponent(learnerNoun)}'
            '&access=${learner.accessibility.index}',
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: hc.primary.withValues(alpha: 0.15),
                  child: Text(
                    learner.avatarEmoji.isEmpty ? '🙂' : learner.avatarEmoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        learner.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: hc.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall
                            .copyWith(color: hc.textSecondary),
                      ),
                      if (steps.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: done / steps.length,
                            minHeight: 6,
                            backgroundColor:
                                hc.textHint.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation(
                              done == steps.length
                                  ? AppColors.success
                                  : hc.primary,
                            ),
                          ),
                        ),
                      ],
                      // Live, for a learner whose routine locks: what the
                      // device is waiting on, whether it needs help, and
                      // every step an adult excused or marked done today.
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: RoutineLearnerLockStatus(
                          profileId: learner.profileId,
                          filipino: l,
                          actionsFor: (context, status) =>
                              RoutineStepActionBar(
                            childProfileId: learner.profileId,
                            learnerName: learner.name,
                            status: status,
                            filipino: l,
                          ),
                          undoFor: (context, status) => RoutineUndoMarkButton(
                            childProfileId: learner.profileId,
                            status: status,
                            filipino: l,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  hasAny ? Icons.chevron_right_rounded : Icons.add_rounded,
                  color: hc.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
