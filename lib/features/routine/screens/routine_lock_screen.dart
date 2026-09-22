import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../../../core/services/lock_announcer.dart';
import '../../../core/services/lock_enforcer.dart';
import '../../../core/services/lock_presentation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/lock_announcement_provider.dart';
import '../../../providers/lock_state_provider.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/wall_clock_provider.dart';
import '../../../widgets/adult_gate_dialog.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../models/routine_catalog.dart';
import '../models/routine_models.dart';
import '../models/routine_presentation.dart';
import '../models/routine_timeline.dart';
import '../models/routine_wait_cues.dart';
import '../providers/today_routine_provider.dart';
import '../services/routine_lock_recorder.dart';
import '../services/routine_native_alarms.dart';
import '../services/routine_reminder_scheduler.dart';
import '../services/routine_service.dart';
import '../services/routine_sign_launcher.dart';
import '../widgets/routine_media.dart';
import '../widgets/routine_mood_prompt.dart';
import '../widgets/routine_step_card.dart';
import '../widgets/routine_time_timer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// How long the screen waits before announcing itself. Same reasoning as the
/// time's-up lock: the learner should *see* the step before they hear it.
const Duration _announceDelay = Duration(milliseconds: 400);

/// How long the "your teacher marked it done" notice stays before Home.
/// Long enough to read slowly; short enough not to feel like a second lock.
const Duration _releaseNoticeFor = Duration(milliseconds: 2800);

/// Full-screen "it is time to do this" lock for a "My Day" step.
///
/// The routine twin of `TimeUpLockScreen`, and deliberately the opposite kind
/// of stop. The time's-up lock says *put the device down and fetch an adult*,
/// and only an adult's PIN clears it. This one says *this is what happens
/// now*, and it clears itself when the step's time is over.
///
/// Reached only through [lockRouteFor], which means only when
/// [lockStateProvider] has resolved to a [RoutineStepDue]: a Student or Child
/// whose Teacher or Parent switched their routine to locking
/// ([Routine.lockEnabled]), at a step whose time has come and not yet ended
/// ([RoutineStep.endsOn]). A Player is never sent here.
///
/// There is nothing for the learner to press to leave. The lock lets go by
/// itself when the step's time ends, and until then the screen says until
/// when. Whether the step may end sooner is the educator's call
/// ([RoutineStep.releaseEarly]): when it may, a Teacher or Parent finishes it
/// from their own dashboard, or here by pressing and holding the step's time
/// and passing the adult check — never through a button a child sees.
///
/// **"Switch account"** stays, to hand a shared classroom tablet to the next
/// learner. Not a bypass: choosing this learner again trips the router's lock
/// redirect and puts them straight back here.
class RoutineLockScreen extends ConsumerStatefulWidget {
  const RoutineLockScreen({super.key});

  @override
  ConsumerState<RoutineLockScreen> createState() => _RoutineLockScreenState();
}

class _RoutineLockScreenState extends ConsumerState<RoutineLockScreen>
    with SingleTickerProviderStateMixin {
  /// Channel policy for this learner's accessibility category — which of
  /// chime / haptic / speech / border pulse this lock actually uses. Resolved
  /// once: the learner cannot change their settings from behind a lock.
  late final LockPresentation _lockPresentation;

  /// What the "Please wait" part shows and says for this learner — the
  /// picture timer, First / Then, signs, spoken milestones.
  late final RoutineWaitCues _waitCues;

  /// Whether the wait signs resolve to clips; null until the FSL manifest
  /// has been read.
  bool? _hasWaitSigns;

  /// The last milestone spoken, as `stepId|minutes`, so each is said once.
  String? _spokenMilestone;

  AnimationController? _pulse;
  Timer? _announceTimer;
  bool _announced = false;

  /// Held rather than re-read from `ref`: `ref` is unusable in [dispose], and
  /// the voice has to be stopped there so it never trails onto the next
  /// screen.
  LockAnnouncer? _announcer;

  /// True while a tick or the adult gate is running — and, crucially, while
  /// the question that follows a tick is on screen.
  ///
  /// Ticking the step clears the lock *immediately*: the day log changes,
  /// `lockStateProvider` recomputes to null and every listener below wants to
  /// leave for Home. But the whole point of the lock is that finishing the
  /// step earns the question — and leaving takes the question's route with it,
  /// so "How do you feel after brushing your teeth?" appeared and was
  /// destroyed in the same frame. Nothing navigates while this is set; the
  /// handler re-checks and leaves once the conversation is over.
  bool _busy = false;

  /// The step this screen is showing. Held rather than re-read from the lock
  /// reason on every build, because the reason goes null the moment the step
  /// is ticked and the screen must keep standing behind its own question.
  RoutineStep? _step;

  /// Null until the FSL manifest has been read — unknown, available and
  /// unavailable are three different answers, and a Deaf learner must not be
  /// offered a Signs button that dead-ends.
  bool? _hasSigns;

  /// The step the manifest was resolved for, so a lock that rolls on to the
  /// next step of the day re-resolves rather than reusing the last answer.
  String? _signsFor;

  /// The step this screen has already reported as shown, so the report is
  /// made once per step rather than once per rebuild.
  String? _shownReportedFor;

  /// An educator's approval, excuse or pause that lifted the lock from their
  /// own device, shown briefly before the learner is sent Home.
  ({RoutineReleaseKind kind, String byName})? _releasedBy;
  Timer? _releaseTimer;


  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    // Visible over the tablet's own lock screen while — and only while — this
    // step is holding the device: a sleeping tablet woken by the alarm shows
    // the step, not the PIN pad.
    unawaited(RoutineNativeAlarms.setShowWhenLocked(true));
    _lockPresentation = LockPresentation.forProfile(
      ref.read(profileProvider)?.disabilityType ?? DisabilityType.none,
      ref.read(settingsProvider),
    );
    _waitCues = RoutineWaitCues.forType(
      ref.read(profileProvider)?.disabilityType ?? DisabilityType.none,
    );
    if (_lockPresentation.visualAlert) {
      _pulse = AnimationController(
        vsync: this,
        duration: _lockPresentation.flashPeriod,
      )..repeat(reverse: true);
    }
    _announceTimer = Timer(_announceDelay, _announce);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    unawaited(RoutineNativeAlarms.setShowWhenLocked(false));
    _resumeListener?.dispose();
    _announceTimer?.cancel();
    _releaseTimer?.cancel();
    _pulse?.dispose();
    unawaited(_announcer?.stop());
    super.dispose();
  }

  /// Chime, haptic and the spoken cue, once per appearance.
  void _announce() {
    if (!mounted || _announced) return;
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    final reason = ref.read(lockStateProvider(profile.id));
    if (reason is! RoutineStepDue) return;
    _announced = true;

    final filipino = ref.read(settingsProvider).locale == 'fil';
    final step = reason.step;
    final title = RoutineCatalog.titleFor(step, filipino: filipino);
    final cue = RoutineCatalog.audioCueFor(step, filipino: filipino);
    final LockAnnouncer announcer =
        _announcer ?? ref.read(lockAnnouncerProvider);
    final at = DateTime.now();
    final until = formatStepEnd(
      step,
      end: ref
          .read(routineDayViewProvider(routineDayKey(profile.id, at)))
          .endOf(step, at),
    );

    unawaited(
      announcer.announce(
        presentation: _lockPresentation,
        message: filipino
            ? 'Oras na para sa $title. $cue Magtatapos sa $until.'
            : 'Time for $title. $cue This ends at $until.',
        speakFilipino: filipino,
      ),
    );
  }

  Future<void> _resolveSigns(RoutineStep step) async {
    if (_signsFor == step.id) return;
    _signsFor = step.id;
    await FslAssetsService.load();
    if (!mounted) return;
    setState(() {
      _hasSigns = RoutineSignLauncher.hasSigns(step);
      _hasWaitSigns = _waitCues.signs.isNotEmpty &&
          RoutineSignLauncher.playableCardsFor(_waitCues.signs).isNotEmpty;
    });
  }

  /// "Five minutes left." — once per milestone, for the learners who are
  /// told the time rather than shown it.
  void _speakMilestone(RoutineStep step, DateTime now, DateTime? end) {
    if (!_waitCues.speakMilestones || end == null || _busy) return;
    final start = step.startsOn(now);
    if (start == null) return;
    final milestone = RoutineWaitCues.milestoneFor(
      minutesLeft: minutesUntilEnd(end, now),
      totalMinutes: end.difference(start).inMinutes,
    );
    if (milestone == null) return;
    final key = '${step.id}|$milestone';
    if (_spokenMilestone == key) return;
    _spokenMilestone = key;
    final l = ref.read(settingsProvider).locale == 'fil';
    final message = milestone == 1
        ? (l ? 'Isang minuto na natitira.' : 'One minute left.')
        : (l
            ? '$milestone minuto na natitira.'
            : '$milestone minutes left.');
    final LockAnnouncer announcer =
        _announcer ?? ref.read(lockAnnouncerProvider);
    unawaited(
      announcer.announce(
        presentation: _lockPresentation.warningVariant,
        message: message,
        speakFilipino: l,
      ),
    );
  }

  Future<void> _showWaitSigns(String profileId) async {
    await RoutineSignLauncher.showCues(
      context,
      cues: _waitCues.signs,
      fallbackWord: 'Please',
      filipino: ref.read(settingsProvider).locale == 'fil',
      profileId: profileId,
    );
  }

  /// A check-in step's own question — "How are you feeling right now?".
  ///
  /// Answering records the mood; it does not end the lock. The step is over
  /// when its time is, like every other step.
  Future<void> _checkIn(RoutineStep step) async {
    if (_busy) return;
    setState(() => _busy = true);
    unawaited(_announcer?.stop());
    try {
      await showCheckInPopup(context, ref, step);
    } finally {
      _finish();
    }
  }

  /// An adult's early release, on a step the educator allowed to end early:
  /// press and hold the step's time, pass the adult check, and the step is
  /// finished now. Never a button — a child waiting on a lock should not be
  /// looking at a way out.
  Future<void> _releaseEarly(RoutineStep step, String profileId) async {
    if (_busy || !step.releaseEarly) return;
    setState(() => _busy = true);
    unawaited(_announcer?.stop());
    try {
      // An infinitive phrase, because the gate builds the sentence around it:
      // "Answer this to end Brushing Teeth early." The gate speaks the app's
      // language, so the step's title does too.
      final t = _t(context);
      final title = RoutineCatalog.titleFor(
        step,
        filipino: t.localeName.startsWith('fil'),
      );
      final passed = await requireAdult(
        context,
        ref,
        reason: t.agEndEarly(title),
      );
      if (!passed || !mounted) return;
      final day = DateTime.now();
      await const RoutineService().setStepDone(profileId, day, step.id, true);
      ref.invalidate(routineDayLogProvider(routineDayKey(profileId, day)));
      unawaited(RoutineReminderScheduler.refreshSettled());
    } finally {
      _finish();
    }
  }

  /// Ends a tick or a gate: releases the navigation hold and acts on whatever
  /// the lock state became while it was held.
  ///
  /// Every exit runs through here, so a step that unlocked the device and a
  /// step that handed over to the next one leave the same way.
  void _finish() {
    if (!mounted) return;
    setState(() => _busy = false);
    // A new step means a new announcement.
    _announced = false;
    final next = ref.read(lockStateProvider(_profileId));
    if (next is! RoutineStepDue) _leave(next);
  }

  String get _profileId => ref.read(profileProvider)?.id ?? '';

  /// Leaves for wherever [next] belongs — Home when nothing is locked, the
  /// other lock screen when something that outranks the routine has taken
  /// over. A no-op while a question is on screen; [_finish] retries then.
  void _leave(LockReason? next) {
    if (!mounted || _busy || _releasedBy != null) return;
    unawaited(_announcer?.stop());
    final release = next == null ? _remoteRelease() : null;
    if (release != null) {
      // An adult lifted this lock from their own device. Say so before the
      // screen goes: a lock that vanishes without a word, in the middle of
      // the task it was holding the learner on, reads as a glitch — or as
      // having done something wrong.
      if (_lockPresentation.haptics) unawaited(HapticFeedback.mediumImpact());
      setState(() => _releasedBy = release);
      _releaseTimer = Timer(_releaseNoticeFor, () {
        if (mounted) unawaited(_goOffTheLock('/home'));
      });
      return;
    }
    if (next != null) {
      // Another lock screen: it is a lock too, so nothing is exposed.
      GoRouter.of(context).go(lockRouteFor(next));
      return;
    }
    unawaited(_goOffTheLock('/home'));
  }

  /// Where this screen is waiting to go once the tablet is unlocked, if it
  /// handed the screen back to the PIN pad first.
  String? _leavingFor;
  AppLifecycleListener? _resumeListener;

  /// Leaves for somewhere that is not a lock — never over the tablet's own
  /// lock screen.
  ///
  /// Found on the NDL W09: a step finished over the PIN screen at 23:59 left
  /// the learner's Home standing in front of the PIN pad for several seconds,
  /// because "show over the lock screen" was only turned off in [dispose] —
  /// after the router had already built Home. So it is turned off *first*. If
  /// that moved FlashLearn behind a tablet that is still locked, this screen
  /// stays put (finished, and nothing on it opens the app) and [target] waits
  /// for the app to come back after someone unlocks.
  Future<void> _goOffTheLock(String target) async {
    if (_leavingFor != null) return;
    _leavingFor = target;
    final movedBehind = await RoutineNativeAlarms.setShowWhenLocked(false);
    if (!mounted) return;
    if (!movedBehind) {
      _leavingFor = null;
      GoRouter.of(context).go(target);
      return;
    }
    _resumeListener?.dispose();
    _resumeListener = AppLifecycleListener(
      onResume: () {
        _resumeListener?.dispose();
        _resumeListener = null;
        _leavingFor = null;
        if (!mounted) return;
        // Whatever holds the device now decides, not what held it when the
        // screen went dark.
        final now = ref.read(lockStateProvider(_profileId));
        if (now is RoutineStepDue) {
          unawaited(RoutineNativeAlarms.setShowWhenLocked(true));
          return;
        }
        GoRouter.of(context).go(now == null ? target : lockRouteFor(now));
      },
    );
  }

  /// The educator's approval, excuse or pause that just lifted the held
  /// step, when an educator's action — not the learner, not the clock — is
  /// what lifted the lock.
  ({RoutineReleaseKind kind, String byName})? _remoteRelease() {
    final step = _step;
    if (step == null) return null;
    final view = ref.read(
      routineDayViewProvider(routineDayKey(_profileId, DateTime.now())),
    );
    final approval = view.approval(step.id);
    if (approval != null && approval.source == RoutineMarkSource.educator) {
      return (kind: RoutineReleaseKind.approved, byName: approval.byName);
    }
    final excuse = view.excuse(step.id);
    if (excuse != null && excuse.source == RoutineMarkSource.educator) {
      return (kind: RoutineReleaseKind.excused, byName: excuse.byName);
    }
    if (view.isPaused(step.id)) {
      return (
        kind: RoutineReleaseKind.paused,
        byName: view.adjustment(step.id)?.byName ?? '',
      );
    }
    return null;
  }

  Future<void> _showSigns(RoutineStep step, String profileId) async {
    await RoutineSignLauncher.showSignsFor(
      context,
      step: step,
      filipino: ref.read(settingsProvider).locale == 'fil',
      profileId: profileId,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watched, not read: the subscription is what keeps the autoDispose
    // announcer alive for the life of this screen.
    _announcer = ref.watch(lockAnnouncerProvider);

    final profile = ref.watch(profileProvider);
    if (profile == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) GoRouter.of(context).go('/home');
      });
      return const SizedBox.shrink();
    }

    // Leaves as soon as the reason stops being this one: the step was ticked,
    // an adult excused it, its hour ran out, or something that outranks it
    // (a daily limit, an alarm) took over. One listener rather than a check
    // in every handler, so every one of those paths leaves the same way.
    ref.listen<LockReason?>(lockStateProvider(profile.id), (_, next) {
      if (next is RoutineStepDue) return;
      _leave(next);
    });

    final reason = ref.watch(lockStateProvider(profile.id));
    // The held step wins while a question is open: ticking cleared the lock,
    // and the screen has to keep standing behind the sheet it just raised.
    final step = reason is RoutineStepDue ? reason.step : _step;
    if (step == null) {
      // First build after a hot restart or a deep link straight to the route:
      // the listener above has nothing to fire on, so leave from here.
      WidgetsBinding.instance.addPostFrameCallback((_) => _leave(reason));
      return const SizedBox.shrink();
    }
    _step = step;
    unawaited(_resolveSigns(step));
    // Tells the educator the lock is actually on screen — not merely due. A
    // tablet that is switched off is waiting on a step too, and "the lock is
    // showing" is a claim only this device can make.
    if (_shownReportedFor != step.id && reason is RoutineStepDue) {
      _shownReportedFor = step.id;
      unawaited(
        ref.read(routineLockRecorderProvider).lockShown(profile.id, step.id),
      );
    }

    // The ten-second clock: the countdown moves on its own, and the lock lets
    // go on the minute the step's time ends.
    final now =
        ref.watch(wallClockTickerProvider).valueOrNull ?? DateTime.now();
    // The step's end as it stands today: later when an adult added time.
    final endsAt = ref
        .watch(routineDayViewProvider(routineDayKey(profile.id, now)))
        .endOf(step, now);
    final startsAt = step.startsOn(now);
    if (reason is RoutineStepDue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _speakMilestone(step, now, endsAt);
      });
    }

    final released = _releasedBy;
    if (released != null) {
      return PopScope(
        canPop: false,
        child: AnimatedGradientBackground(
          intensity: 0.22,
          preset: GradientPreset.assessment,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: _ReleasedNotice(
                step: step,
                kind: released.kind,
                byName: released.byName,
                filipino: ref.watch(settingsProvider).locale == 'fil',
              ),
            ),
          ),
        ),
      );
    }

    final hc = HCColor.of(context);
    final l = ref.watch(settingsProvider).locale == 'fil';
    final presentation = ref.watch(routinePresentationProvider);
    final title = RoutineCatalog.titleFor(step, filipino: l);
    final emoji = RoutineCatalog.emojiFor(step);
    final cue = RoutineCatalog.audioCueFor(step, filipino: l);
    final note = RoutineCatalog.noteFor(step, filipino: l);
    final instructions = RoutineCatalog.instructionsFor(step);
    final stills = presentation
        .mediaFor(step)
        .where((k) => k == RoutineMediaKind.photo || k == RoutineMediaKind.gif)
        .toList();
    final isCheckIn = step.activity.isMoodCheckIn;

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      children: [
        // ── What is happening, in one line, before anything else ──
        Semantics(
          header: true,
          child: Text(
            l ? 'Oras na para rito' : 'It is time for this',
            textAlign: TextAlign.center,
            style: AppTypography.labelLarge.copyWith(
              color: hc.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── The step's picture, or its emoji when there is none ──
        if (stills.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: RoutineImage(
              url: step.urlFor(stills.first),
              kind: stills.first,
              stepEmoji: emoji,
              filipino: l,
              semanticLabel: title,
              height: 200,
            ),
          )
        else
          Semantics(
            label: title,
            child: ExcludeSemantics(
              child: Text(
                emoji,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 88, height: 1.1),
                textScaler: const TextScaler.linear(1.0),
              ),
            ),
          ),
        const SizedBox(height: 14),

        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.headlineSmall.copyWith(
            fontWeight: FontWeight.w900,
            color: hc.textPrimary,
          ),
        ),
        if (cue.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            cue,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(color: hc.textSecondary),
          ),
        ],
        if (note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            note,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
          ),
        ],
        const SizedBox(height: 12),
        // Press and hold the time: the adult's early release — only on a step
        // the educator allowed to end early, and only behind the adult check.
        Center(
          child: step.releaseEarly
              ? Semantics(
                  onLongPressHint: l
                      ? 'Para sa nakatatanda: tapusin nang maaga'
                      : 'For adults: end early',
                  child: GestureDetector(
                    onLongPress:
                        _busy ? null : () => _releaseEarly(step, profile.id),
                    child: _TimePill(step: step),
                  ),
                )
              : _TimePill(step: step),
        ),

        // ── The wait, in pictures and signs, for this learner ──
        if (_waitCues.showTimer && startsAt != null && endsAt != null) ...[
          const SizedBox(height: 16),
          Center(
            child: RoutineTimeTimer(
              start: startsAt,
              end: endsAt,
              now: now,
              size: _waitCues.timerSize,
              emoji: '⏳',
            ),
          ),
        ],
        if (_waitCues.firstThen && !isCheckIn) ...[
          const SizedBox(height: 14),
          _FirstThenCard(
            first: step,
            then: _stepAfter(step),
            filipino: l,
          ),
        ],
        if (_hasWaitSigns ?? false) ...[
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _showWaitSigns(profile.id),
              icon: const Icon(Icons.sign_language_rounded),
              label: Text(
                l ? 'Pakiusap, kalmado · FSL' : 'Please, calm · FSL',
              ),
            ),
          ),
        ],

        // ── How to do it. Always expanded here: the learner is being held
        //    on this screen precisely so they can follow it.
        if (instructions.isNotEmpty && !isCheckIn) ...[
          const SizedBox(height: 16),
          _Steps(instructions: instructions, filipino: l),
        ],

        // ── Alternative channels ──
        if ((presentation.showFsl && (_hasSigns ?? false)) ||
            step.hasMedia(RoutineMediaKind.audio)) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              if (presentation.showFsl && (_hasSigns ?? false))
                FilledButton.icon(
                  onPressed: () => _showSigns(step, profile.id),
                  icon: const Icon(Icons.sign_language_rounded),
                  label: Text(l ? 'Panoorin sa FSL' : 'Watch in FSL'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondaryDark,
                    foregroundColor: Colors.white,
                  ),
                ),
              if (step.hasMedia(RoutineMediaKind.audio))
                RoutineAudioButton(
                  url: step.audioUrl,
                  filipino: l,
                  accent: AppColors.success,
                ),
            ],
          ),
        ],

        const SizedBox(height: 8),
      ],
    );

    // ── Until when ──
    // Pinned under the scrolling content, never inside it, so a learner on a
    // short screen or at a large font always sees how long is left. There is
    // nothing to press: the lock lets go by itself.
    final actions = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UnlockCountdown(
            step: step,
            now: now,
            filipino: l,
            endsAt: endsAt,
          ),
          if (isCheckIn) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _checkIn(step),
                icon: const Icon(Icons.chat_bubble_rounded, size: 24),
                label: Text(
                  l ? 'Mag-check in ngayon' : 'Do my check-in',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return PopScope(
      // A lock the back button dismisses is not a lock.
      canPop: false,
      child: AnimatedGradientBackground(
        intensity: 0.22,
        preset: GradientPreset.assessment,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(child: _pulseBorder(body)),
                actions,
                _SwitchAccountBar(
                  filipino: l,
                  // Through the same door as Home: over a locked tablet the
                  // profile picker must not stand in front of the PIN pad.
                  onSwitch: () => unawaited(_goOffTheLock('/profile-switcher')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The step that comes after [step] today and is still ahead — what the
  /// First / Then card names — or null when [step] is the last.
  RoutineStep? _stepAfter(RoutineStep step) {
    final today = ref.watch(todayRoutineProvider);
    final index = today.steps.indexWhere((s) => s.id == step.id);
    if (index < 0) return null;
    for (final s in today.steps.skip(index + 1)) {
      if (today.log?.isDone(s.id) ?? false) continue;
      if (today.excusedIds.contains(s.id)) continue;
      return s;
    }
    return null;
  }

  /// The slow border pulse for learners who cannot hear the chime. Wrapped
  /// rather than painted into the body so the body stays a plain scrollable.
  Widget _pulseBorder(Widget child) {
    final pulse = _pulse;
    if (pulse == null) return child;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, inner) => Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.warning.withValues(
              alpha: 0.25 + pulse.value * 0.6,
            ),
            width: 4,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: inner,
      ),
      child: child,
    );
  }
}

/// "First: brushing teeth. Then: breakfast." — the visual support a
/// learner with a cognitive disability already uses in class, so the wait
/// has an after.
class _FirstThenCard extends StatelessWidget {
  const _FirstThenCard({
    required this.first,
    required this.then,
    required this.filipino,
  });

  final RoutineStep first;
  final RoutineStep? then;
  final bool filipino;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = filipino;
    final firstTitle = RoutineCatalog.titleFor(first, filipino: l);
    final next = then;
    final thenTitle = next == null
        ? (l ? 'Malayang oras' : 'Free time')
        : RoutineCatalog.titleFor(next, filipino: l);
    final thenEmoji = next == null ? '🎉' : RoutineCatalog.emojiFor(next);

    Widget tile(String label, String emoji, String title, bool now) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: now
                  ? hc.primary.withValues(alpha: hc.hc ? 0.28 : 0.14)
                  : hc.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: now ? hc.primary : hc.border,
                width: now ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w900,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 40, height: 1.1),
                  textScaler: const TextScaler.linear(1.0),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );

    final firstLabel = l ? 'Una' : 'First';
    final thenLabel = l ? 'Pagkatapos' : 'Then';
    return Semantics(
      container: true,
      label: '$firstLabel: $firstTitle. $thenLabel: $thenTitle.',
      child: ExcludeSemantics(
        child: Row(
          children: [
            tile(firstLabel, RoutineCatalog.emojiFor(first), firstTitle, true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: hc.textSecondary,
                size: 28,
              ),
            ),
            tile(thenLabel, thenEmoji, thenTitle, false),
          ],
        ),
      ),
    );
  }
}

/// Which adult action lifted a routine lock from another device.
enum RoutineReleaseKind { approved, excused, paused }

/// "6:45 AM" — the step's own time, so the learner is told *why* now.
class _TimePill extends StatelessWidget {
  const _TimePill({required this.step});

  final RoutineStep step;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: hc.primary.withValues(alpha: hc.hc ? 0.30 : 0.14),
        borderRadius: BorderRadius.circular(16),
        border: hc.hc ? Border.all(color: hc.primary, width: 1.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: hc.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              formatStepTime(step),
              style: AppTypography.titleSmall.copyWith(
                color: hc.textPrimary,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The catalog's picture-and-words instructions, always open.
class _Steps extends StatelessWidget {
  const _Steps({required this.instructions, required this.filipino});

  final List<RoutineInstruction> instructions;
  final bool filipino;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hc.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            filipino ? 'Paano ito gawin' : 'How to do it',
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < instructions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Text(
                      instructions[i].emoji,
                      style: const TextStyle(fontSize: 22, height: 1.2),
                      textScaler: const TextScaler.linear(1.0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${i + 1}. ${instructions[i].textOf(filipino: filipino)}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: hc.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Hands a shared tablet on without an adult. Outside the scroll so it is
/// always reachable, exactly like the time's-up lock's own version.
class _SwitchAccountBar extends StatelessWidget {
  const _SwitchAccountBar({required this.filipino, required this.onSwitch});

  final bool filipino;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: TextButton.icon(
        // The profile switcher is lock-exempt, so this actually lands — and
        // picking this learner again re-locks them.
        onPressed: onSwitch,
        icon: const Icon(Icons.switch_account_rounded, size: 20),
        label: Text(
          filipino ? 'Magpalit ng account' : 'Switch account',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          foregroundColor: hc.textSecondary,
        ),
      ),
    );
  }
}

/// "Rose ended Brushing Teeth early." — the lock lifted from an educator's
/// device, said plainly before the learner goes Home.
class _ReleasedNotice extends StatelessWidget {
  const _ReleasedNotice({
    required this.step,
    required this.kind,
    required this.byName,
    required this.filipino,
  });

  final RoutineStep step;
  final RoutineReleaseKind kind;
  final String byName;
  final bool filipino;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = filipino;
    final title = RoutineCatalog.titleFor(step, filipino: l);
    final name = byName;
    final approved = kind == RoutineReleaseKind.approved;
    final message = kind == RoutineReleaseKind.paused
        ? (name.isEmpty
            ? (l
                ? 'Pinahinto sandali ng iyong guro o magulang ang $title. '
                    'Maaari kang magpahinga.'
                : 'Your teacher or parent paused $title. You can take a '
                    'break.')
            : (l
                ? 'Pinahinto sandali ni $name ang $title. Maaari kang '
                    'magpahinga.'
                : '$name paused $title. You can take a break.'))
        : approved
        ? (name.isEmpty
            ? (l
                ? 'Tinapos nang maaga ng iyong guro o magulang ang $title.'
                : 'Your teacher or parent ended $title early.')
            : (l
                ? 'Tinapos nang maaga ni $name ang $title.'
                : '$name ended $title early.'))
        : (name.isEmpty
            ? (l
                ? 'Sabi ng iyong guro o magulang, puwedeng laktawan ang $title '
                    'ngayon.'
                : 'Your teacher or parent says you can skip $title today.')
            : (l
                ? 'Sabi ni $name, puwedeng laktawan ang $title ngayon.'
                : '$name says you can skip $title today.'));
    final next = l ? 'Bumabalik sa Home…' : 'Going back to Home…';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Semantics(
          liveRegion: true,
          container: true,
          label: '$message $next',
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  switch (kind) {
                    RoutineReleaseKind.approved => '✅',
                    RoutineReleaseKind.excused => '👍',
                    RoutineReleaseKind.paused => '⏸️',
                  },
                  style: const TextStyle(fontSize: 72),
                  textScaler: const TextScaler.linear(1.0),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  next,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Please wait. This ends at 7:40 PM." — and how much of the wait is left.
///
/// Measured on the shared ten-second clock from the step's own start and end,
/// so it moves by itself and runs out on the minute the lock lets go. Words
/// for every learner, and a bar beside them for the ones who read a bar.
class _UnlockCountdown extends StatelessWidget {
  const _UnlockCountdown({
    required this.step,
    required this.now,
    required this.filipino,
    this.endsAt,
  });

  final RoutineStep step;
  final DateTime now;
  final bool filipino;

  /// The end as it stands today — later than planned when an adult added
  /// time. Null means the planned end.
  final DateTime? endsAt;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = filipino;
    final start = step.startsOn(now) ?? now;
    final end = endsAt ?? step.endsOn(now) ?? now;
    final total = end.difference(start).inSeconds;
    final left = end.difference(now);
    final leftMinutes = left.isNegative ? 0 : (left.inSeconds / 60).ceil();
    final double fraction =
        total <= 0 ? 1.0 : (1 - left.inSeconds / total).clamp(0.0, 1.0);
    final until = formatStepEnd(step, end: end);
    final headline = l
        ? 'Pakihintay. Magtatapos sa $until.'
        : 'Please wait. This ends at $until.';
    final remaining = leftMinutes <= 1
        ? (l ? 'Malapit na.' : 'Almost there.')
        : (l ? '$leftMinutes minuto natitira' : '$leftMinutes minutes left');

    return Semantics(
      container: true,
      label: '$headline $remaining',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hc.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hc.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    '⏳',
                    style: TextStyle(fontSize: 26),
                    textScaler: TextScaler.linear(1.0),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: hc.textPrimary,
                          ),
                        ),
                        Text(
                          remaining,
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 12,
                  backgroundColor: hc.textHint.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(hc.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
