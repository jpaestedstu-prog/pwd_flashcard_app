import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/hive_service.dart';

import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/routine_provider.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../../../widgets/app_back_button.dart';
import '../models/routine_catalog.dart';
import '../models/routine_models.dart';
import '../models/routine_presentation.dart';
import '../services/routine_service.dart';
import '../services/routine_completion_flow.dart';
import '../widgets/routine_mood_prompt.dart';
import '../services/routine_sign_launcher.dart';
import '../widgets/routine_media.dart';
import '../widgets/routine_step_card.dart';
import '../widgets/routine_step_timer.dart';

/// One routine step, full screen: its picture, its visual instructions, its
/// media, its signs, its timer, and the button that ticks it off.
///
/// This is where the brief's accessibility list actually lands — sounds and
/// audio cues, FSL content, visual instructions, photos, GIFs, videos — and
/// where [RoutinePresentation] decides which of them lead.
class RoutineStepScreen extends ConsumerStatefulWidget {
  final RoutineStep step;
  final RoutinePresentation presentation;
  final String profileId;
  final DateTime day;
  final bool readOnly;

  /// Today's whole day, when the caller knows it — lets "I did it!" tell
  /// whether it finished the day and so ask how the day went. Null when the
  /// screen is opened on its own; the day-end question is then left to the
  /// list.
  final List<RoutineStep>? todaysSteps;

  const RoutineStepScreen({
    super.key,
    required this.step,
    required this.presentation,
    required this.profileId,
    required this.day,
    this.readOnly = false,
    this.todaysSteps,
  });

  @override
  ConsumerState<RoutineStepScreen> createState() => _RoutineStepScreenState();
}

class _RoutineStepScreenState extends ConsumerState<RoutineStepScreen> {
  RoutineStep get _step => widget.step;
  RoutinePresentation get _p => widget.presentation;

  /// Null until the FSL manifest has been read. Three states matter here:
  /// unknown (no button yet), available, and unavailable (no button ever) —
  /// a Deaf learner must not be given a Signs button that dead-ends.
  bool? _hasSigns;

  /// The TTS service, captured the first time this screen speaks.
  ///
  /// Held rather than read from `ref` at teardown: Riverpod forbids `ref`
  /// once the element is disposed, and reading it there threw
  /// "Cannot use ref after the widget was disposed" for exactly the learners
  /// who depend on the spoken cue — the ones whose policy speaks on open.
  TtsService? _tts;

  /// The TTS service, resolved once and remembered so [dispose] can stop it
  /// without touching `ref`.
  TtsService get _speaker {
    final existing = _tts;
    if (existing != null) return existing;
    final resolved = ref.read(ttsServiceProvider);
    _tts = resolved;
    return resolved;
  }

  @override
  void initState() {
    super.initState();
    _resolveSigns();
    // After the first frame: speaking during initState races the route
    // transition, and on some devices the utterance is cut off by it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakOnOpen());
  }

  @override
  void dispose() {
    // Stop any cue still playing — walking back to the day list with a voice
    // still reading the last step is disorienting, especially for the learners
    // who rely on that voice.
    _tts?.stop();
    super.dispose();
  }

  Future<void> _resolveSigns() async {
    await FslAssetsService.load();
    if (!mounted) return;
    setState(() => _hasSigns = RoutineSignLauncher.hasSigns(_step));
  }

  Future<void> _speakOnOpen() async {
    if (!_p.speakOnOpen || widget.readOnly || !mounted) return;
    final filipino = ref.read(settingsProvider).locale == 'fil';
    final title = RoutineCatalog.titleFor(_step, filipino: filipino);
    final cue = RoutineCatalog.audioCueFor(_step, filipino: filipino);
    final tts = _speaker;
    await (filipino
        ? tts.speakFilipino('$title. $cue')
        : tts.speakEnglish('$title. $cue'));
  }

  Future<void> _onTimerDone() async {
    final filipino = ref.read(settingsProvider).locale == 'fil';
    if (_p.playSoundCues) {
      await ref.read(soundServiceProvider).playComplete();
    }
    if (_p.speakOnOpen || _p.announceProgress) {
      final tts = _speaker;
      await (filipino
          ? tts.speakFilipino('Tapos na ang oras.')
          : tts.speakEnglish('Time is up.'));
    }
  }

  Future<void> _showSigns() async {
    final filipino = ref.read(settingsProvider).locale == 'fil';
    await RoutineSignLauncher.showSignsFor(
      context,
      step: _step,
      filipino: filipino,
      profileId: widget.profileId,
    );
  }

  Future<void> _toggleDone(bool wasDone) async {
    // A check-in step is answered, not ticked: its "done" opens the check-in,
    // and the step only completes when a face is chosen. Everything else ticks
    // and then asks whatever question the step earns — the same flow the list
    // and the Home card run, so the learner meets one set of rules.
    if (_step.activity.isMoodCheckIn || _step.asksMoodAfter) {
      await RoutineCompletionFlow.complete(
        context: context,
        ref: ref,
        profileId: widget.profileId,
        day: widget.day,
        step: _step,
        todaysSteps: widget.todaysSteps,
        presentation: _p,
        filipino: ref.read(settingsProvider).locale == 'fil',
      );
      if (!mounted) return;
      final nowDone = HiveService.getRoutineDayLog(
        widget.profileId,
        widget.day,
      ).isDone(_step.id);
      // Back to the list once the step is really done — not when a check-in
      // was put off with "Later", which leaves the learner where they were.
      if (nowDone && !wasDone) Navigator.of(context).maybePop();
      return;
    }

    await const RoutineService()
        .toggleStep(widget.profileId, widget.day, _step.id);
    if (!mounted) return;
    ref.invalidate(
      routineDayLogProvider(routineDayKey(widget.profileId, widget.day)),
    );
    if (wasDone) return;
    final filipino = ref.read(settingsProvider).locale == 'fil';
    if (_p.playSoundCues) {
      await ref.read(soundServiceProvider).playCorrect();
    }
    if (_p.announceProgress) {
      final tts = _speaker;
      await (filipino
          ? tts.speakFilipino('Magaling!')
          : tts.speakEnglish('Well done!'));
    }
    // Ticking the last step here finishes the day just as it does on the
    // list, so it asks the same day-end question.
    final steps = widget.todaysSteps;
    if (mounted && steps != null && steps.isNotEmpty) {
      final log = HiveService.getRoutineDayLog(widget.profileId, widget.day);
      if (steps.every((s) => log.isDone(s.id))) {
        await showRoutineMoodPrompt(context, ref);
      }
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = ref.watch(settingsProvider).locale == 'fil';
    final title = RoutineCatalog.titleFor(_step, filipino: l);
    final note = RoutineCatalog.noteFor(_step, filipino: l);
    final emoji = RoutineCatalog.emojiFor(_step);
    final instructions = RoutineCatalog.instructionsFor(_step);
    final media = _p.mediaFor(_step);
    final done = ref
        .watch(routineDayViewProvider(
            routineDayKey(widget.profileId, widget.day)))
        .isDone(_step.id);

    return AnimatedGradientBackground(
      intensity: 0.2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const AppBackButton(),
          title: Text(
            title,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // ── The picture: real media when supplied, the designed
              //    placeholder when not. Either way the step has a visual.
              _HeroMedia(
                step: _step,
                presentation: _p,
                filipino: l,
                emoji: emoji,
                title: title,
                onFsl: (_hasSigns ?? false) && _p.showFsl ? _showSigns : null,
              ),
              const SizedBox(height: 16),

              // ── When and how long ──
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (_step.isScheduled)
                    _InfoPill(
                      icon: Icons.schedule_rounded,
                      label: formatStepTime(_step),
                      color: hc.primary,
                    ),
                  if (_step.hasTimer)
                    _InfoPill(
                      icon: Icons.timer_rounded,
                      label: l
                          ? '${_step.durationMinutes} minuto'
                          : '${_step.durationMinutes} min',
                      color: AppColors.info,
                    ),
                ],
              ),

              if (note.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Panel(
                  title: l ? 'Tala' : 'Note',
                  icon: Icons.sticky_note_2_rounded,
                  child: Text(
                    note,
                    style: AppTypography.bodyMedium
                        .copyWith(color: hc.textPrimary),
                  ),
                ),
              ],

              // ── Visual instructions ──
              if (instructions.isNotEmpty) ...[
                const SizedBox(height: 14),
                _InstructionPanel(
                  instructions: instructions,
                  filipino: l,
                  startExpanded: _p.instructionsExpanded,
                ),
              ],

              // ── Accessibility controls: signs, sound, other media ──
              const SizedBox(height: 14),
              _Panel(
                title: l ? 'Tulong sa Gawain' : 'Ways to follow this step',
                icon: Icons.accessibility_new_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        // FSL — only when this learner's policy includes it
                        // AND a clip will actually play.
                        if (_p.showFsl && (_hasSigns ?? false))
                          FilledButton.icon(
                            onPressed: _showSigns,
                            icon: const Icon(Icons.sign_language_rounded),
                            label: Text(l ? 'Panoorin sa FSL' : 'Watch in FSL'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.secondaryDark,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        // Speak the cue. Always offered, whatever the
                        // presentation: a learner who wants to hear the step
                        // read out should never have to change a setting.
                        OutlinedButton.icon(
                          onPressed: () => _speakCue(l),
                          icon: const Icon(Icons.record_voice_over_rounded),
                          label: Text(l ? 'Basahin ito para sa akin' : 'Read it to me'),
                        ),
                        if (_step.hasMedia(RoutineMediaKind.audio))
                          RoutineAudioButton(
                            url: _step.audioUrl,
                            filipino: l,
                            accent: AppColors.success,
                          ),
                        for (final kind in media)
                          if (kind != RoutineMediaKind.audio)
                            OutlinedButton.icon(
                              onPressed: () => _openMedia(kind, title, l),
                              icon: Icon(RoutineMediaStyle.of(kind).icon),
                              label: Text(
                                RoutineMediaStyle.of(kind)
                                    .labelOf(filipino: l),
                              ),
                            ),
                      ],
                    ),
                    if (_p.showFsl && (_hasSigns ?? false)) ...[
                      const SizedBox(height: 8),
                      Text(
                        (l ? 'Mga senyas: ' : 'Signs: ') +
                            RoutineSignLauncher.cueSummary(_step),
                        style: AppTypography.labelSmall
                            .copyWith(color: hc.textSecondary),
                      ),
                    ],
                    if (media.isEmpty &&
                        !_step.hasMedia(RoutineMediaKind.audio)) ...[
                      const SizedBox(height: 10),
                      Text(
                        l
                            ? 'Wala pang larawan o bidyo dito. Maaari itong '
                                'idagdag ng iyong guro o magulang.'
                            : 'No photo or video here yet. Your teacher or '
                                'parent can add one.',
                        style: AppTypography.bodySmall
                            .copyWith(color: hc.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Timer ──
              if (_step.hasTimer) ...[
                const SizedBox(height: 14),
                RoutineStepTimer(
                  key: ValueKey('step-timer-${_step.id}'),
                  durationMinutes: _step.durationMinutes,
                  asBar: _p.timerAsBar,
                  filipino: l,
                  enabled: !widget.readOnly,
                  onFinished: _onTimerDone,
                ),
              ],

              const SizedBox(height: 20),
              if (!widget.readOnly)
                SizedBox(
                  height: 60,
                  child: FilledButton.icon(
                    onPressed: () => _toggleDone(done),
                    icon: Icon(
                      done
                          ? Icons.undo_rounded
                          : Icons.check_circle_rounded,
                      size: 26,
                    ),
                    label: Text(
                      done
                          ? (l ? 'Hindi pa pala tapos' : 'Not done after all')
                          : _step.activity.isMoodCheckIn
                          ? (l ? 'Mag-check in ngayon' : 'Do my check-in')
                          : (l ? 'Tapos na!' : 'I did it!'),
                      style: AppTypography.titleSmall
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: done ? hc.textHint : AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                )
              else
                Center(
                  child: Text(
                    l
                        ? 'Preview lamang — ang bata ang magmamarka nito.'
                        : 'Preview only — the learner ticks this off themselves.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall
                        .copyWith(color: hc.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _speakCue(bool filipino) async {
    final title = RoutineCatalog.titleFor(_step, filipino: filipino);
    final cue = RoutineCatalog.audioCueFor(_step, filipino: filipino);
    final tts = _speaker;
    await (filipino
        ? tts.speakFilipino('$title. $cue')
        : tts.speakEnglish('$title. $cue'));
  }

  Future<void> _openMedia(
    RoutineMediaKind kind,
    String title,
    bool filipino,
  ) async {
    if (kind == RoutineMediaKind.video) {
      await showRoutineVideoSheet(
        context,
        url: _step.videoUrl,
        title: title,
        cacheKey: 'routine_step_${_step.id}',
        filipino: filipino,
        // The FSL button on the video itself, for Deaf and hard-of-hearing
        // learners — the brief's explicit requirement.
        onFsl: (_hasSigns ?? false) && _p.showFsl ? _showSigns : null,
      );
      return;
    }
    await showRoutineImageSheet(
      context,
      step: _step,
      kind: kind,
      title: title,
      filipino: filipino,
    );
  }
}

/// The step's lead visual: its first media channel if it has one, otherwise
/// the placeholder — which still shows the activity emoji at size, so the step
/// always has a picture.
class _HeroMedia extends StatelessWidget {
  final RoutineStep step;
  final RoutinePresentation presentation;
  final bool filipino;
  final String emoji;
  final String title;
  final VoidCallback? onFsl;

  const _HeroMedia({
    required this.step,
    required this.presentation,
    required this.filipino,
    required this.emoji,
    required this.title,
    this.onFsl,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final visual = presentation
        .mediaFor(step)
        .where((k) => k != RoutineMediaKind.audio)
        .toList();

    if (visual.isEmpty) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                hc.primary.withValues(alpha: 0.10),
                hc.surface,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: hc.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Semantics(
                  label: title,
                  child: ExcludeSemantics(
                    child: Text(emoji, style: const TextStyle(fontSize: 84)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (onFsl != null) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onFsl,
              icon: const Icon(Icons.sign_language_rounded),
              label: Text(filipino ? 'FSL' : 'FSL'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondaryDark,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      );
    }

    final lead = visual.first;
    if (lead == RoutineMediaKind.video) {
      // A video is not auto-played in the page: it opens in the sheet, where
      // the FSL button lives beside it.
      return _VideoPoster(
        emoji: emoji,
        title: title,
        filipino: filipino,
        onPlay: () => showRoutineVideoSheet(
          context,
          url: step.videoUrl,
          title: title,
          cacheKey: 'routine_step_${step.id}',
          filipino: filipino,
          onFsl: onFsl,
        ),
        onFsl: onFsl,
      );
    }
    return RoutineImage(
      url: step.urlFor(lead),
      kind: lead,
      stepEmoji: emoji,
      filipino: filipino,
      semanticLabel: title,
      height: 220,
    );
  }
}

class _VideoPoster extends StatelessWidget {
  final String emoji;
  final String title;
  final bool filipino;
  final VoidCallback onPlay;
  final VoidCallback? onFsl;

  const _VideoPoster({
    required this.emoji,
    required this.title,
    required this.filipino,
    required this.onPlay,
    this.onFsl,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Column(
      children: [
        InkWell(
          onTap: onPlay,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                hc.primary.withValues(alpha: 0.12),
                hc.surface,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: hc.primary.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 10),
                Icon(Icons.play_circle_rounded, size: 48, color: hc.primary),
                const SizedBox(height: 6),
                Text(
                  filipino ? 'Panoorin ang bidyo' : 'Watch the video',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onFsl != null) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onFsl,
            icon: const Icon(Icons.sign_language_rounded),
            label: const Text('FSL'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondaryDark,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }
}

class _InstructionPanel extends StatefulWidget {
  final List<RoutineInstruction> instructions;
  final bool filipino;
  final bool startExpanded;

  const _InstructionPanel({
    required this.instructions,
    required this.filipino,
    required this.startExpanded,
  });

  @override
  State<_InstructionPanel> createState() => _InstructionPanelState();
}

class _InstructionPanelState extends State<_InstructionPanel> {
  late bool _open = widget.startExpanded;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = widget.filipino;
    return _Panel(
      title: l ? 'Paano ito gawin' : 'How to do it',
      icon: Icons.format_list_numbered_rounded,
      trailing: IconButton(
        tooltip: _open
            ? (l ? 'Itago' : 'Hide')
            : (l ? 'Ipakita' : 'Show'),
        icon: Icon(
          _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          color: hc.textSecondary,
        ),
        onPressed: () => setState(() => _open = !_open),
      ),
      child: !_open
          ? Text(
              l
                  ? '${widget.instructions.length} hakbang'
                  : '${widget.instructions.length} steps',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            )
          : Column(
              children: [
                for (var i = 0; i < widget.instructions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The number and the emoji together: the numeral for
                        // a learner who reads, the picture for one who does
                        // not, and neither depends on the other.
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: hc.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: AppTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: hc.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.instructions[i].emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.instructions[i].textOf(filipino: l),
                            style: AppTypography.bodyMedium
                                .copyWith(color: hc.textPrimary),
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

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.textHint.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: hc.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
