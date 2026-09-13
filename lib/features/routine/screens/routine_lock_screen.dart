import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/tts_service.dart';
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
import '../../../widgets/adult_gate_dialog.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../models/routine_catalog.dart';
import '../models/routine_models.dart';
import '../models/routine_presentation.dart';
import '../providers/routine_lock_skip_provider.dart';
import '../services/routine_completion_flow.dart';
import '../services/routine_sign_launcher.dart';
import '../widgets/routine_media.dart';
import '../widgets/routine_step_card.dart';
import '../widgets/routine_step_timer.dart';

/// How long the screen waits before announcing itself. Same reasoning as the
/// time's-up lock: the learner should *see* the step before they hear it.
const Duration _announceDelay = Duration(milliseconds: 400);

/// Full-screen "it is time to do this" lock for a "My Day" step.
///
/// The routine twin of `TimeUpLockScreen`, and deliberately the opposite kind
/// of stop. The time's-up lock says *put the device down and fetch an adult*,
/// and only an adult's PIN clears it. This one says *do this one thing first*,
/// and the learner clears it themselves by doing it — then the app asks how it
/// felt, which is the other half of the moment the lock was created for.
///
/// Reached only through [lockRouteFor], which means only when
/// [lockStateProvider] has resolved to a [RoutineStepDue]: a Student or Child
/// whose Teacher or Parent switched their routine to locking
/// ([Routine.lockEnabled]), at a step whose time has come and gone by less
/// than [kRoutineLockWindow]. A Player is never sent here.
///
/// Two ways out besides doing the step, and both are deliberate:
///
///  * **"Ask a grown-up"** runs the standard adult gate and then excuses the
///    step for today ([RoutineLockSkips]). A child can be ill, out of the
///    house, or nowhere near a toothbrush, and a lock a learner physically
///    cannot clear would be a broken tablet rather than a routine. The step is
///    *not* ticked — the history keeps telling the truth about the morning.
///  * **"Switch account"** hands a shared classroom tablet to the next
///    learner. Not a bypass: choosing this learner again trips the router's
///    lock redirect and puts them straight back here.
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

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _lockPresentation = LockPresentation.forProfile(
      ref.read(profileProvider)?.disabilityType ?? DisabilityType.none,
      ref.read(settingsProvider),
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
    _announceTimer?.cancel();
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

    unawaited(
      announcer.announce(
        presentation: _lockPresentation,
        message: filipino
            ? 'Oras na para sa $title. $cue'
            : 'Time for $title. $cue',
        speakFilipino: filipino,
      ),
    );
  }

  Future<void> _resolveSigns(RoutineStep step) async {
    if (_signsFor == step.id) return;
    _signsFor = step.id;
    await FslAssetsService.load();
    if (!mounted) return;
    setState(() => _hasSigns = RoutineSignLauncher.hasSigns(step));
  }

  /// "I did it!" — tick the step, then ask how it felt.
  ///
  /// The tick is what clears the lock: [lockStateProvider] recomputes off the
  /// day log, finds this step done, and either moves on to the next step that
  /// is due or returns null and sends the learner home. Nothing here navigates
  /// on its own, so the lock and the router can never disagree about whether
  /// it is still up.
  Future<void> _didIt(RoutineStep step, String profileId) async {
    if (_busy) return;
    setState(() => _busy = true);
    unawaited(_announcer?.stop());
    try {
      await RoutineCompletionFlow.complete(
        context: context,
        ref: ref,
        profileId: profileId,
        day: DateTime.now(),
        step: step,
        // The lock only ever knows about its own step, so the day-end
        // question is left to "My Day" — and `alwaysAskMood` means this tap
        // has already earned a question of its own.
        todaysSteps: null,
        presentation: ref.read(routinePresentationProvider),
        filipino: ref.read(settingsProvider).locale == 'fil',
        alwaysAskMood: true,
      );
    } finally {
      _finish();
    }
  }

  /// "Ask a grown-up" — adult gate, then excuse this step for today.
  Future<void> _askGrownUp(RoutineStep step, String profileId) async {
    if (_busy) return;
    setState(() => _busy = true);
    unawaited(_announcer?.stop());
    try {
      // An infinitive phrase, because the gate builds the sentence around it:
      // "Answer this to skip Brushing Teeth for today." The dialog is English
      // only, so the step's English title goes in whatever the app locale is.
      final title = RoutineCatalog.titleFor(step, filipino: false);
      final passed = await requireAdult(
        context,
        ref,
        reason: 'to skip $title for today',
      );
      if (!passed || !mounted) return;
      await ref
          .read(routineLockSkipProvider(profileId).notifier)
          .skip(step.id);
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
    if (!mounted || _busy) return;
    unawaited(_announcer?.stop());
    GoRouter.of(context).go(next == null ? '/home' : lockRouteFor(next));
  }

  /// The step's countdown reached zero: say so in the channels this learner
  /// uses. A Deaf learner feels it, a learner who reads with their ears hears
  /// it, and everyone sees the timer turn green.
  ///
  /// It does not tick the step. Running the timer is not the same as brushing,
  /// and the learner is the one who says they did it.
  Future<void> _onTimerDone() async {
    if (!mounted) return;
    final presentation = ref.read(routinePresentationProvider);
    final filipino = ref.read(settingsProvider).locale == 'fil';
    if (_lockPresentation.haptics) unawaited(HapticFeedback.heavyImpact());
    if (presentation.playSoundCues) {
      await ref.read(soundServiceProvider).playComplete();
    }
    if (!mounted) return;
    if (presentation.speakOnOpen || presentation.announceProgress) {
      final tts = ref.read(ttsServiceProvider);
      await (filipino
          ? tts.speakFilipino('Tapos na ang oras. Pindutin ang Tapos na.')
          : tts.speakEnglish('Time is up. Tap I did it.'));
    }
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
            l ? 'Oras na para dito' : 'It is time for this',
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
        Center(child: _TimePill(step: step)),

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

        // ── The timer: "brush for two minutes" as something to watch ──
        // Keyed by step, so a lock that rolls on to the next step of the day
        // starts that step's timer fresh instead of inheriting a half-run one.
        if (step.hasTimer && !isCheckIn) ...[
          const SizedBox(height: 16),
          RoutineStepTimer(
            key: ValueKey('lock-timer-${step.id}'),
            durationMinutes: step.durationMinutes,
            asBar: presentation.timerAsBar,
            filipino: l,
            onFinished: _onTimerDone,
          ),
        ],

        const SizedBox(height: 24),

        // ── The way out: doing it ──
        SizedBox(
          height: 64,
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _didIt(step, profile.id),
            icon: Icon(
              isCheckIn
                  ? Icons.chat_bubble_rounded
                  : Icons.check_circle_rounded,
              size: 28,
            ),
            label: Text(
              isCheckIn
                  ? (l ? 'Mag-check in ngayon' : 'Do my check-in')
                  : (l ? 'Tapos na!' : 'I did it!'),
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
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _busy ? null : () => _askGrownUp(step, profile.id),
          icon: const Icon(Icons.pan_tool_alt_rounded, size: 20),
          label: Text(
            l ? 'Tanungin ang nakatatanda' : 'Ask a grown-up',
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: hc.textSecondary,
          ),
        ),
      ],
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
                _SwitchAccountBar(filipino: l),
              ],
            ),
          ),
        ),
      ),
    );
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
  const _SwitchAccountBar({required this.filipino});

  final bool filipino;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: TextButton.icon(
        // The profile switcher is lock-exempt, so this actually lands — and
        // picking this learner again re-locks them.
        onPressed: () => GoRouter.of(context).go('/profile-switcher'),
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
