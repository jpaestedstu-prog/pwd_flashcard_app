import 'package:flutter/material.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/routine_catalog.dart';
import '../models/routine_models.dart';
import '../services/routine_media_store.dart';
import '../services/routine_sign_launcher.dart';
import '../widgets/routine_media.dart';
import '../widgets/routine_step_card.dart';

/// Opens the step editor and returns the edited step, or null if cancelled.
Future<RoutineStep?> openRoutineStepEditor(
  BuildContext context, {
  required RoutineStep step,
  required bool filipino,
  bool routineLocks = false,
}) {
  return showModalBottomSheet<RoutineStep>(
    context: context,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RoutineStepEditorSheet(
      step: step,
      filipino: filipino,
      routineLocks: routineLocks,
    ),
  );
}

/// Everything an educator can set on one routine step: what it is called, when
/// it happens, how long it lasts, what it says, and — the part the brief is
/// really about — which accessibility content is attached to it.
///
/// The media fields are plain address boxes on purpose. A device picker would
/// be friendlier but would tie a routine's pictures to one phone's storage;
/// an address works from a school's shared drive, from the project's existing
/// Cloudinary media, or from a bundled asset, and it is what makes "use
/// placeholders now, replace them later" a one-field edit rather than a
/// migration. Uploading from the device is the natural next step and is called
/// out in the recommendations.
class RoutineStepEditorSheet extends StatefulWidget {
  final RoutineStep step;
  final bool filipino;

  /// Whether the routine this step belongs to holds the learner's device at
  /// each step's time ([Routine.lockEnabled]).
  ///
  /// Decides only whether the per-step exemption is *shown*. The flag itself
  /// is always edited and always saved — an educator who turns the routine's
  /// lock off and back on again should find the exemptions they set still
  /// there, not silently reset to "everything locks".
  final bool routineLocks;

  const RoutineStepEditorSheet({
    super.key,
    required this.step,
    required this.filipino,
    this.routineLocks = false,
  });

  @override
  State<RoutineStepEditorSheet> createState() => _RoutineStepEditorSheetState();
}

class _RoutineStepEditorSheetState extends State<RoutineStepEditorSheet> {
  late RoutineStep _draft = widget.step;

  late final _title = TextEditingController(text: widget.step.title);
  late final _titleFil = TextEditingController(text: widget.step.titleFilipino);
  late final _emoji = TextEditingController(text: widget.step.emoji);
  late final _note = TextEditingController(text: widget.step.note);
  late final _noteFil = TextEditingController(text: widget.step.noteFilipino);
  late final _photo = TextEditingController(text: widget.step.photoUrl);
  late final _gif = TextEditingController(text: widget.step.gifUrl);
  late final _video = TextEditingController(text: widget.step.videoUrl);
  late final _audio = TextEditingController(text: widget.step.audioUrl);
  late final _sign = TextEditingController(text: widget.step.signWord);

  /// Null while the FSL manifest is still loading.
  bool? _signResolves;

  @override
  void initState() {
    super.initState();
    _checkSign();
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _titleFil,
      _emoji,
      _note,
      _noteFil,
      _photo,
      _gif,
      _video,
      _audio,
      _sign,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _checkSign() async {
    await FslAssetsService.load();
    if (!mounted) return;
    setState(() => _signResolves = RoutineSignLauncher.hasSigns(_collect()));
  }

  /// The step as currently typed. Text controllers are read here rather than
  /// written back on every keystroke, so typing does not rebuild the sheet.
  RoutineStep _collect() => _draft.copyWith(
    title: _title.text.trim(),
    titleFilipino: _titleFil.text.trim(),
    emoji: _emoji.text.trim(),
    note: _note.text.trim(),
    noteFilipino: _noteFil.text.trim(),
    photoUrl: _photo.text.trim(),
    gifUrl: _gif.text.trim(),
    videoUrl: _video.text.trim(),
    audioUrl: _audio.text.trim(),
    signWord: _sign.text.trim(),
  );

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: _draft.isScheduled
          ? TimeOfDay(hour: _draft.hour!, minute: _draft.minute!)
          : now,
    );
    if (picked == null) return;
    setState(() {
      _draft = _draft.copyWith(hour: picked.hour, minute: picked.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = widget.filipino;
    final info = RoutineCatalog.infoFor(_draft.activity);
    final isCustom = _draft.activity.isCustom;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: hc.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    RoutineCatalog.emojiFor(_draft),
                    style: const TextStyle(fontSize: 30),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      RoutineCatalog.titleFor(_draft, filipino: l),
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l ? 'Kanselahin' : 'Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _collect()),
                    child: Text(l ? 'Tapos' : 'Done'),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  // ── Name ──
                  _SectionLabel(l ? 'Pangalan' : 'Name'),
                  TextField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l ? 'Pangalan (English)' : 'Title',
                      hintText: isCustom
                          ? (l
                                ? 'hal. Pagdidilig ng halaman'
                                : 'e.g. Water the plants')
                          : info.label,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _titleFil,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l ? 'Pangalan sa Filipino' : 'Filipino title',
                      hintText: info.labelFilipino,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emoji,
                    maxLength: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l ? 'Emoji' : 'Emoji',
                      hintText: info.emoji,
                      helperText: l
                          ? 'Ito ang malaking larawan kapag walang photo.'
                          : 'This is the big picture when no photo is set.',
                      border: const OutlineInputBorder(),
                    ),
                  ),

                  // ── When & how long ──
                  _SectionLabel(l ? 'Oras' : 'When'),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text(
                            _draft.isScheduled
                                ? formatStepTime(_draft)
                                : (l ? 'Magtakda ng oras' : 'Set a time'),
                          ),
                        ),
                      ),
                      if (_draft.isScheduled)
                        IconButton(
                          tooltip: l ? 'Alisin ang oras' : 'Clear the time',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(
                            () => _draft = _draft.copyWith(clearTime: true),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l
                        ? 'Walang oras = sunod-sunod lang, walang orasan. Mas '
                              'madali ito para sa ilang bata.'
                        : 'No time means the step is sequenced, not clocked — '
                              'often easier for a learner who does not read a clock.',
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.timer_rounded, size: 18, color: hc.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _draft.durationMinutes == 0
                              ? (l ? 'Walang timer' : 'No timer')
                              : (l
                                    ? 'Timer: ${_draft.durationMinutes} minuto'
                                    : 'Timer: ${_draft.durationMinutes} min'),
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _draft.durationMinutes.toDouble().clamp(0, 60),
                    max: 60,
                    divisions: 12,
                    label: _draft.durationMinutes == 0
                        ? (l ? 'wala' : 'off')
                        : '${_draft.durationMinutes}',
                    onChanged: (v) => setState(
                      () =>
                          _draft = _draft.copyWith(durationMinutes: v.round()),
                    ),
                  ),

                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active_rounded,
                        size: 18,
                        color: hc.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _draft.remindMinutesBefore == 0
                              ? (l
                                    ? 'Paalala sa mismong oras'
                                    : 'Remind at the time')
                              : (l
                                    ? 'Paalala ${_draft.remindMinutesBefore} '
                                          'minuto bago'
                                    : 'Remind ${_draft.remindMinutesBefore} min '
                                          'before'),
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _draft.remindMinutesBefore.toDouble().clamp(0, 30),
                    max: 30,
                    divisions: 6,
                    label: _draft.remindMinutesBefore == 0
                        ? (l ? 'sa oras' : 'on time')
                        : '${_draft.remindMinutesBefore}',
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(
                        remindMinutesBefore: v.round(),
                      ),
                    ),
                  ),
                  Text(
                    l
                        ? 'Ang maagang babala ay mas madaling sundan kaysa sa '
                              'paalalang dumarating mismo sa oras.'
                        : 'A few minutes of warning lands better than an '
                              'instruction arriving the moment it is due — '
                              'especially for a learner who needs time to switch '
                              'activity.',
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),

                  // ── Ask how they feel ──
                  // Per step, because *which* moments are worth asking about
                  // is the educator's call. Hidden on a check-in step, which
                  // is a question already. The subtitle is the exact question
                  // the learner will see, so the educator is choosing words,
                  // not a setting.
                  if (!_draft.activity.isMoodCheckIn) ...[
                    const SizedBox(height: 8),
                    // Its own Material: the sheet paints its background on a
                    // DecoratedBox, which would hide the tile's ink (and
                    // trips Flutter's "ListTile ink may be invisible" check).
                    Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _draft.askMood,
                      onChanged: (v) => setState(
                        () => _draft = _draft.copyWith(askMood: v),
                      ),
                      secondary: const Text(
                        '💬',
                        style: TextStyle(fontSize: 22),
                      ),
                      title: Text(
                        l
                            ? 'Tanungin ang nararamdaman pagkatapos'
                            : 'Ask how they feel after this step',
                        style: AppTypography.bodyMedium.copyWith(
                          color: hc.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '“${RoutineCatalog.moodQuestionFor(_draft, filipino: l)}”',
                        style: AppTypography.labelSmall.copyWith(
                          color: hc.textSecondary,
                        ),
                      ),
                    ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      l
                          ? 'Sa oras na ito, may paalala at pop-up na '
                                'magsasabing “Pakigawa na ang iyong check-in '
                                'ngayon.”'
                          : 'At this time the learner gets a notification and '
                                'a pop-up: “Please do your check-in now.”',
                      style: AppTypography.labelSmall.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  ],

                  // ── Does this step hold the device? ──
                  // Only offered when the routine locks at all, and only on a
                  // step with a time — a lock needs a moment to start at.
                  // Off means the step still appears, still reminds and is
                  // still ticked off; it simply does not stop the learner.
                  if (widget.routineLocks && _draft.isScheduled) ...[
                    const SizedBox(height: 8),
                    Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _draft.lockScreen,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(lockScreen: v),
                        ),
                        secondary: const Text(
                          '🔒',
                          style: TextStyle(fontSize: 22),
                        ),
                        title: Text(
                          l
                              ? 'I-lock ang app hanggang tapos ito'
                              : 'Lock the app until this is done',
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _draft.lockScreen
                              ? (l
                                    ? 'Sa ${formatStepTime(_draft)}, ito lang '
                                          'ang makikita ng bata hanggang '
                                          'markahan nilang tapos na.'
                                    : 'At ${formatStepTime(_draft)} this is '
                                          'all the learner can see until they '
                                          'mark it done.')
                              : (l
                                    ? 'Hindi hihinto ang app para sa hakbang '
                                          'na ito — paalala lang.'
                                    : 'This step will not stop the learner — '
                                          'it only reminds.'),
                          style: AppTypography.labelSmall.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // ── Note / spoken cue ──
                  _SectionLabel(l ? 'Paalala at Boses' : 'Note & spoken cue'),
                  TextField(
                    controller: _note,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l ? 'Paalala (English)' : 'Note',
                      hintText: info.audioCue,
                      helperText: l
                          ? 'Ito rin ang binabasa nang malakas sa bata.'
                          : 'This is also what is read aloud to the learner.',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteFil,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l ? 'Paalala sa Filipino' : 'Filipino note',
                      hintText: info.audioCueFilipino,
                      border: const OutlineInputBorder(),
                    ),
                  ),

                  // ── Accessibility media ──
                  _SectionLabel(
                    l
                        ? 'Larawan, GIF, Bidyo at Tunog'
                        : 'Photo, GIF, video & sound',
                  ),
                  Text(
                    l
                        ? 'Opsyonal ang lahat. Kapag walang nakalagay, may '
                              'malinis na placeholder na nakikita ang bata — hindi '
                              'sirang larawan. Puwedeng palitan anumang oras.'
                        : 'All optional. When a slot is empty the learner sees a '
                              'clean placeholder, never a broken image — and any '
                              'slot can be filled in later.',
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final slot in const [
                    (RoutineMediaKind.photo, 'photo'),
                    (RoutineMediaKind.gif, 'gif'),
                    (RoutineMediaKind.video, 'video'),
                    (RoutineMediaKind.audio, 'audio'),
                  ])
                    _MediaField(
                      controller: switch (slot.$1) {
                        RoutineMediaKind.photo => _photo,
                        RoutineMediaKind.gif => _gif,
                        RoutineMediaKind.video => _video,
                        RoutineMediaKind.audio => _audio,
                      },
                      kind: slot.$1,
                      filipino: l,
                      stepId: _draft.id,
                      onChanged: () => setState(() {}),
                    ),

                  const SizedBox(height: 8),
                  _PreviewStrip(step: _collect(), filipino: l),

                  // ── FSL ──
                  _SectionLabel(
                    l ? 'Filipino Sign Language' : 'Filipino Sign Language',
                  ),
                  if (!isCustom && info.signCues.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.sign_language_rounded,
                            size: 18,
                            color: AppColors.secondaryDark,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l
                                  ? 'Nakahandang senyas: '
                                        '${info.signCues.map((c) => c.word).join(' · ')}'
                                  : 'Built-in signs: '
                                        '${info.signCues.map((c) => c.word).join(' · ')}',
                              style: AppTypography.bodySmall.copyWith(
                                color: hc.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: _sign,
                    onChanged: (_) => _checkSign(),
                    decoration: InputDecoration(
                      labelText: l
                          ? 'Palitan ng ibang salitang senyas'
                          : 'Override with one sign word',
                      hintText: l ? 'hal. Water' : 'e.g. Water',
                      helperText: l
                          ? 'Iwanang blangko para gamitin ang nakahandang senyas.'
                          : 'Leave blank to use the built-in signs.',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SignStatus(
                    resolves: _signResolves,
                    hasOverride: _sign.text.trim().isNotEmpty,
                    filipino: l,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        text,
        style: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w700,
          color: hc.primary,
        ),
      ),
    );
  }
}

class _MediaField extends StatefulWidget {
  final TextEditingController controller;
  final RoutineMediaKind kind;
  final bool filipino;
  final VoidCallback onChanged;

  /// Needed to name the copied file, so re-picking replaces rather than
  /// accumulates.
  final String stepId;

  const _MediaField({
    required this.controller,
    required this.kind,
    required this.filipino,
    required this.onChanged,
    required this.stepId,
  });

  @override
  State<_MediaField> createState() => _MediaFieldState();
}

class _MediaFieldState extends State<_MediaField> {
  bool _picking = false;

  TextEditingController get controller => widget.controller;
  RoutineMediaKind get kind => widget.kind;
  bool get filipino => widget.filipino;

  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final slot = await const RoutineMediaStore().pickAndAdopt(
        stepId: widget.stepId,
        kind: kind,
      );
      if (!mounted || slot == null) return;
      // Replacing a device file removes the old copy; a URL belongs to
      // whoever hosts it and is only forgotten, never deleted.
      final previous = controller.text.trim();
      if (RoutineMediaStore.isDeviceFile(previous) && previous != slot) {
        await const RoutineMediaStore().discard(previous);
      }
      controller.text = slot;
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final style = RoutineMediaStyle.of(kind);
    final value = controller.text.trim();
    final filled = value.isNotEmpty;
    final onDevice = RoutineMediaStore.isDeviceFile(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            onChanged: (_) => widget.onChanged(),
            decoration: InputDecoration(
              prefixIcon: Icon(style.icon, color: style.color),
              labelText: style.labelOf(filipino: filipino),
              hintText: filipino
                  ? 'https://… o assets/…'
                  : 'https://… or assets/…',
              helperText: filled ? null : style.emptyHintOf(filipino: filipino),
              suffixIcon: filled
                  ? IconButton(
                      tooltip: filipino ? 'Alisin' : 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () async {
                        if (onDevice) {
                          await const RoutineMediaStore().discard(value);
                        }
                        controller.clear();
                        widget.onChanged();
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _picking ? null : _pick,
                icon: _picking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.phone_android_rounded, size: 18),
                label: Text(
                  filipino ? 'Kumuha sa device' : 'Choose from device',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  onDevice
                      ? (filipino
                            ? 'Nasa tablet na ito lang. Hindi ito makikita ng '
                                  'bata sa ibang device.'
                            : 'On this tablet only — a learner using a different '
                                  'device will not see it.')
                      : (filipino
                            ? 'Ang link ay umaabot sa lahat ng device.'
                            : 'A link reaches every device.'),
                  style: AppTypography.labelSmall.copyWith(
                    color: onDevice ? AppColors.warning : hc.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the learner-facing result of whatever is currently typed, so an
/// educator sees the placeholder they are about to ship rather than imagining
/// it.
class _PreviewStrip extends StatelessWidget {
  final RoutineStep step;
  final bool filipino;

  const _PreviewStrip({required this.step, required this.filipino});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    // The strip's tiles are fixed-size cells, so they have to be told about
    // the font scale — nothing inside a `SizedBox` grows on its own.
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final visual = [
      RoutineMediaKind.photo,
      RoutineMediaKind.gif,
      RoutineMediaKind.video,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          filipino ? 'Makikita ng bata' : 'What the learner will see',
          style: AppTypography.labelMedium.copyWith(
            color: hc.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: routinePreviewTileHeight(scale),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visual.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final kind = visual[i];
              return SizedBox(
                width: routinePreviewTileWidth(scale),
                child: step.hasMedia(kind) && kind != RoutineMediaKind.video
                    ? RoutineImage(
                        url: step.urlFor(kind),
                        kind: kind,
                        stepEmoji: RoutineCatalog.emojiFor(step),
                        filipino: filipino,
                        semanticLabel: RoutineCatalog.titleFor(
                          step,
                          filipino: filipino,
                        ),
                        height: routinePreviewTileHeight(scale),
                      )
                    : step.hasMedia(kind)
                    ? _VideoChip(filipino: filipino)
                    : RoutineMediaPlaceholder(
                        kind: kind,
                        stepEmoji: RoutineCatalog.emojiFor(step),
                        filipino: filipino,
                        compact: true,
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VideoChip extends StatelessWidget {
  final bool filipino;
  const _VideoChip({required this.filipino});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.alphaBlend(hc.primary.withValues(alpha: 0.12), hc.surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hc.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_rounded, size: 36, color: hc.primary),
          const SizedBox(height: 6),
          Text(
            filipino ? 'Bidyo' : 'Video',
            style: AppTypography.labelMedium.copyWith(
              color: hc.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Says plainly whether the sign this step will offer actually plays.
///
/// A Deaf learner's Signs button is the primary control on their step screen,
/// so an educator must be able to see — while editing — that the word they
/// typed resolves to a real clip, rather than finding out from the child.
class _SignStatus extends StatelessWidget {
  final bool? resolves;
  final bool hasOverride;
  final bool filipino;

  const _SignStatus({
    required this.resolves,
    required this.hasOverride,
    required this.filipino,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    if (resolves == null) {
      return Text(
        filipino ? 'Sinusuri ang senyas…' : 'Checking signs…',
        style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
      );
    }
    final ok = resolves!;
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          size: 18,
          color: ok ? AppColors.success : AppColors.warning,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            ok
                ? (filipino
                      ? 'May senyas na mapapanood ang bata sa hakbang na ito.'
                      : 'The learner will be able to watch a sign for this step.')
                : hasOverride
                ? (filipino
                      ? 'Walang FSL na clip para sa salitang iyan. Subukan '
                            'ang isang salita mula sa FSL Dictionary.'
                      : 'No FSL clip for that word. Try a word from the FSL '
                            'Dictionary.')
                : (filipino
                      ? 'Wala pang FSL clip para sa gawaing ito.'
                      : 'No FSL clip is available for this activity yet.'),
            style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
          ),
        ),
      ],
    );
  }
}
