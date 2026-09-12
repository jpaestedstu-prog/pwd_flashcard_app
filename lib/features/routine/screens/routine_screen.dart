import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/routine_provider.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/rich_empty_states.dart';
import '../models/routine_models.dart';
import '../providers/today_routine_provider.dart';
import '../models/routine_presentation.dart';
import '../services/routine_service.dart';
import '../services/routine_sign_launcher.dart';
import '../services/routine_completion_flow.dart';
import '../widgets/routine_step_card.dart';
import 'routine_step_screen.dart';

/// The learner's own routine — "My Day".
///
/// Reached from the Routine tile on the Student and Child home screens. Shows
/// every routine an educator has scheduled for today, in time order, with the
/// day's progress and one card per step.
///
/// How much of the day is on screen at once, whether steps are spoken, whether
/// a Signs button appears, and how a step is ticked off all come from
/// [RoutinePresentation] — the learner's accessibility category decides, not
/// this widget.
class RoutineScreen extends ConsumerStatefulWidget {
  /// Whose routine to show. Null means the signed-in profile, which is the
  /// learner opening their own day.
  ///
  /// An educator passes a learner's id to preview exactly what that learner
  /// sees — same screen, read-only, so what they check is what ships.
  final String? profileId;

  /// Display name for the app bar when previewing someone else's day.
  final String? displayName;

  /// The learner's accessibility category, when the caller already knows it.
  ///
  /// An educator's roster carries this, and a roster learner may live only in
  /// the cloud — so passing it beats looking it up among the local profiles,
  /// which would silently fall back to "no accessibility needs" and show the
  /// educator a view their learner will never see.
  final DisabilityType? accessibility;

  /// Preview mode: no ticking, no sounds, no speech. An educator looking at a
  /// learner's day must not be able to complete steps on their behalf — the
  /// day log is the learner's record of what *they* did.
  final bool readOnly;

  const RoutineScreen({
    super.key,
    this.profileId,
    this.displayName,
    this.accessibility,
    this.readOnly = false,
  });

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  /// Step ids with at least one FSL clip that will actually play. Resolved
  /// once, after the manifest loads, so no card ever draws a Signs button
  /// that would dead-end.
  Set<String> _signable = const {};

  /// Show the whole day even when the presentation would collapse it to the
  /// next step. The learner's own choice, not persisted — it is a peek, and
  /// the calm view is what they should come back to.
  bool _showWholeDay = false;

  /// "Today" as of build. Captured once so a rebuild at midnight cannot key
  /// the day-log provider to a different date mid-session.
  late final DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSignAvailability();
  }

  Future<void> _loadSignAvailability() async {
    await FslAssetsService.load();
    if (!mounted) return;
    final routines = ref.read(routineListProvider(_profileId)).valueOrNull;
    if (routines == null) return;
    final ids = <String>{};
    for (final r in routines) {
      for (final s in r.orderedSteps) {
        if (RoutineSignLauncher.hasSigns(s)) ids.add(s.id);
      }
    }
    if (mounted) setState(() => _signable = ids);
  }

  String get _profileId =>
      widget.profileId ?? ref.read(profileProvider)?.id ?? '';

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = ref.watch(settingsProvider).locale == 'fil';
    final profileId = widget.profileId ?? ref.watch(profileProvider)?.id ?? '';

    final presentation = widget.profileId == null
        ? ref.watch(routinePresentationProvider)
        // Previewing someone else's day: their category decides, not the
        // educator's — otherwise a teacher checks a view no learner will see.
        : RoutinePresentation.forType(_previewType(profileId));

    if (profileId.isEmpty) {
      return _shell(
        context,
        l: l,
        child: RichEmptyState(
          emoji: '🗓️',
          title: l ? 'Walang profile' : 'No profile',
          description: l
              ? 'Pumili muna ng profile para makita ang routine.'
              : 'Choose a profile first to see a routine.',
        ),
      );
    }

    final routinesAsync = ref.watch(routineListProvider(profileId));
    final logAsync =
        ref.watch(routineDayLogProvider(routineDayKey(profileId, _today)));
    final log = logAsync.valueOrNull ??
        RoutineDayLog.empty(profileId, _today);

    return _shell(
      context,
      l: l,
      child: routinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => RichEmptyState(
          emoji: '🌤️',
          title: l ? 'Hindi ma-load' : 'Could not load',
          description: l
              ? 'Subukan muli mamaya. Nakaimbak pa rin ang iyong routine.'
              : 'Try again in a moment. Your routine is still saved.',
        ),
        data: (routines) {
          // Freeze what today actually scheduled, the first time this device
          // sees it. Doing it here — rather than only on a tick — is what
          // makes a day the learner *looked at* but did nothing on still
          // score against the right routine later.
          _recordSchedule(profileId, routines);
          final today =
              routines.where((r) => r.enabled && r.runsOn(_today)).toList();
          if (today.isEmpty) {
            return _EmptyDay(
              filipino: l,
              hasAnyRoutine: routines.isNotEmpty,
              // Previewing: the learner plainly *has* an educator — the one
              // reading this. Only the learner's own view consults their
              // profile, which is whose class membership the provider knows.
              hasEducator: widget.profileId != null ||
                  ref.watch(todayRoutineProvider).hasEducator,
            );
          }
          return _dayBody(
            context,
            hc: hc,
            filipino: l,
            routines: today,
            log: log,
            presentation: presentation,
            profileId: profileId,
          );
        },
      ),
    );
  }

  /// Guards against re-freezing on every rebuild: the service is idempotent,
  /// but a build method should not be firing an async write on each frame.
  String? _recordedFor;

  void _recordSchedule(String profileId, List<Routine> routines) {
    // An educator previewing a learner's day must not write to that learner's
    // record — the day log is the learner's own.
    if (widget.readOnly || widget.profileId != null) return;
    if (_recordedFor == profileId) return;
    _recordedFor = profileId;
    unawaited(
      const RoutineService()
          .recordSchedule(profileId, _today, routines)
          .catchError((Object e, StackTrace s) {
        ErrorHandler.report(e, s, 'RoutineRecordSchedule:silent');
        return RoutineDayLog.empty(profileId, _today);
      }),
    );
  }

  DisabilityType _previewType(String profileId) {
    final given = widget.accessibility;
    if (given != null) return given;
    for (final entry in ref.read(allProfilesWithProgressProvider)) {
      if (entry.$1.id == profileId) return entry.$1.disabilityType;
    }
    return DisabilityType.none;
  }

  Widget _shell(
    BuildContext context, {
    required bool l,
    required Widget child,
  }) {
    final hc = HCColor.of(context);
    return AnimatedGradientBackground(
      intensity: 0.22,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const AppBackButton(),
          title: Text(
            widget.displayName != null
                ? (l
                    ? 'Araw ni ${widget.displayName}'
                    : "${widget.displayName}'s Day")
                : (l ? 'Ang Aking Araw' : 'My Day'),
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
        ),
        body: SafeArea(child: child),
      ),
    );
  }

  Widget _dayBody(
    BuildContext context, {
    required HCColor hc,
    required bool filipino,
    required List<Routine> routines,
    required RoutineDayLog log,
    required RoutinePresentation presentation,
    required String profileId,
  }) {
    final allSteps = [for (final r in routines) ...r.orderedSteps];
    final doneCount =
        allSteps.where((s) => log.completedStepIds.contains(s.id)).length;
    final collapse = presentation.showOnlyNextStep && !_showWholeDay;
    final visible = collapse
        ? presentation.visibleSteps(allSteps, log.completedStepIds)
        : allSteps;
    final nextId = allSteps
        .cast<RoutineStep?>()
        .firstWhere(
          (s) => !log.completedStepIds.contains(s!.id),
          orElse: () => null,
        )
        ?.id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _ProgressHeader(
          done: doneCount,
          total: allSteps.length,
          filipino: filipino,
          // The learner's own run only; an educator previewing someone's day
          // is looking at the history screen for that.
          streak: widget.profileId == null
              ? ref.watch(todayRoutineProvider).streak
              : 0,
          routineName: routines.length == 1
              ? (filipino && routines.first.nameFilipino.isNotEmpty
                  ? routines.first.nameFilipino
                  : routines.first.name)
              : null,
        ),
        const SizedBox(height: 16),
        for (final step in visible)
          RoutineStepCard(
            step: step,
            done: log.completedStepIds.contains(step.id),
            isNext: step.id == nextId,
            filipino: filipino,
            presentation: presentation,
            hasSigns: _signable.contains(step.id),
            onToggle: widget.readOnly
                ? () {}
                : () => _toggle(
                    step,
                    log,
                    presentation,
                    filipino,
                    profileId,
                    allSteps,
                  ),
            onOpen: () => _openStep(
              step,
              presentation,
              filipino,
              profileId,
              log.completedStepIds.contains(step.id),
              allSteps,
            ),
          ),
        if (presentation.showOnlyNextStep && allSteps.length > visible.length)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showWholeDay = true),
              icon: const Icon(Icons.expand_more_rounded),
              label: Text(
                filipino
                    ? 'Ipakita ang buong araw (${allSteps.length})'
                    : 'Show the whole day (${allSteps.length})',
              ),
            ),
          ),
        if (_showWholeDay && presentation.showOnlyNextStep)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showWholeDay = false),
              icon: const Icon(Icons.expand_less_rounded),
              label: Text(
                filipino ? 'Isa-isa lang' : 'One step at a time',
              ),
            ),
          ),
        if (doneCount == allSteps.length && allSteps.isNotEmpty) ...[
          const SizedBox(height: 8),
          _DayCompleteBanner(filipino: filipino),
        ],
      ],
    );
  }

  Future<void> _toggle(
    RoutineStep step,
    RoutineDayLog log,
    RoutinePresentation presentation,
    bool filipino,
    String profileId,
    List<RoutineStep> todaysSteps,
  ) async {
    // Only the learner's own day earns questions — an educator previewing it
    // is not the person being asked how they feel, and cannot tick anyway.
    if (widget.readOnly || widget.profileId != null) return;
    // Shared with the step screen's "I did it!" and the Home card's Done
    // button, so all three write, sound, speak, refresh — and ask — alike.
    await RoutineCompletionFlow.complete(
      context: context,
      ref: ref,
      profileId: profileId,
      day: _today,
      step: step,
      todaysSteps: todaysSteps,
      presentation: presentation,
      filipino: filipino,
    );
  }

  Future<void> _openStep(
    RoutineStep step,
    RoutinePresentation presentation,
    bool filipino,
    String profileId,
    bool done,
    List<RoutineStep> todaysSteps,
  ) async {
    // The step screen asks its own questions ("I did it!" runs the same
    // completion flow as the list), so it is handed the whole day to know
    // whether its tick finished it.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoutineStepScreen(
          step: step,
          presentation: presentation,
          profileId: profileId,
          day: _today,
          readOnly: widget.readOnly,
          todaysSteps: todaysSteps,
        ),
      ),
    );
    if (!mounted) return;
    ref.invalidate(routineDayLogProvider(routineDayKey(profileId, _today)));
  }
}

class _ProgressHeader extends StatelessWidget {
  final int done;
  final int total;
  final bool filipino;
  final String? routineName;

  /// Consecutive fully-complete days, rest days skipped. Computed by
  /// [RoutineHistory.streak], which the educator's history screen has always
  /// shown and the learner never saw — so the one person doing the work had
  /// no idea they were on a run.
  final int streak;

  const _ProgressHeader({
    required this.done,
    required this.total,
    required this.filipino,
    required this.streak,
    this.routineName,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final fraction = total == 0 ? 0.0 : done / total;

    return Semantics(
      container: true,
      // The bar's own value is announced by the progress indicator; this label
      // carries the count, which is the part a learner acts on.
      label: filipino
          ? 'Tapos na ang $done sa $total na gawain ngayong araw.'
              '${streak > 0 ? ' $streak araw na sunod-sunod na tapos.' : ''}'
          : '$done of $total activities finished today.'
              '${streak > 0 ? ' $streak day${streak == 1 ? '' : 's'} '
                  'finished in a row.' : ''}',
      child: Card(
        elevation: 0,
        color: hc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: hc.primary.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Row(
                  children: [
                    Text(
                      fraction >= 1 ? '🎉' : '🗓️',
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routineName?.isNotEmpty == true
                                ? routineName!
                                : (filipino ? 'Ngayong Araw' : 'Today'),
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: hc.textPrimary,
                            ),
                          ),
                          Text(
                            filipino
                                ? '$done sa $total tapos na'
                                : '$done of $total done',
                            style: AppTypography.bodySmall.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                          if (streak > 0)
                            Text(
                              filipino
                                  // Filipino numerals take the singular.
                                  ? '🔥 $streak araw na sunod-sunod'
                                  : '🔥 $streak day'
                                        '${streak == 1 ? '' : 's'} in a row',
                              style: AppTypography.labelSmall.copyWith(
                                color: hc.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 12,
                  backgroundColor: hc.textHint.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(
                    fraction >= 1 ? AppColors.success : hc.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCompleteBanner extends StatelessWidget {
  final bool filipino;

  const _DayCompleteBanner({required this.filipino});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppColors.success.withValues(alpha: 0.16),
          hc.surface,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Text('🌟', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            filipino ? 'Tapos na ang buong araw!' : 'The whole day is done!',
            textAlign: TextAlign.center,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            filipino
                ? 'Napakagaling mo ngayong araw.'
                : 'You did every step today. Great work.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final bool filipino;

  /// True when the learner has routines, just none scheduled for today —
  /// a rest day, which is a different message from "nobody has set one up".
  final bool hasAnyRoutine;

  /// Whether anyone is actually in a position to set one up. A Player profile
  /// belongs to no class and no family group, so "your teacher or parent can
  /// set this up" points at nobody — and a promise nobody can keep is worse
  /// than an honest blank.
  final bool hasEducator;

  const _EmptyDay({
    required this.filipino,
    required this.hasAnyRoutine,
    required this.hasEducator,
  });

  @override
  Widget build(BuildContext context) {
    if (hasAnyRoutine) {
      return RichEmptyState(
        emoji: '🌴',
        title: filipino ? 'Walang nakatakda ngayon' : 'Nothing scheduled today',
        description: filipino
            ? 'Walang routine para sa araw na ito. Magpahinga ka muna!'
            : 'You have no routine for today. Enjoy the rest!',
      );
    }
    if (!hasEducator) {
      return RichEmptyState(
        emoji: '🗓️',
        title: filipino ? 'Wala pang routine' : 'No routine yet',
        description: filipino
            ? 'Ang Araw Ko ay nagpapakita ng plano ng araw mo — isa-isang '
                'hakbang, may larawan at oras. Sumali sa isang klase o family '
                'group para makagawa ang guro o magulang mo ng isa para sa iyo.'
            : 'My Day shows your plan for the day — one step at a time, with '
                'pictures and times. Join a class or a family group and your '
                'teacher or parent can build one for you.',
      );
    }
    return RichEmptyState(
      emoji: '🗓️',
      title: filipino ? 'Wala pang routine' : 'No routine yet',
      description: filipino
          ? 'Makakagawa ang iyong guro o magulang ng pang-araw-araw na routine '
              'para sa iyo. Lalabas ito dito kapag handa na.'
          : 'Your teacher or parent can set up a daily routine for you. It '
              'will show up here once they do.',
    );
  }
}
