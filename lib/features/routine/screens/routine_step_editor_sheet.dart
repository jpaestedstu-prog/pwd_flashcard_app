import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../../../core/services/shared_media_service.dart';
import '../../../core/widgets/media_capture_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/routine_catalog.dart';
import '../models/routine_models.dart';
import '../models/routine_timeline.dart';
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
  String? ownerProfileId,
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
      ownerProfileId: ownerProfileId,
    ),
  );
}

/// Everything an educator can set on one routine step: what it is called, when
/// it happens, how long it lasts, what it says, and — the part the brief is
/// really about — which accessibility content is attached to it.
///
/// Each media slot is one value: an address typed in (a school's shared drive,
/// the project's Cloudinary media, a bundled asset), or a file chosen from the
/// device — which is shared through `SharedMediaService` the moment it is
/// picked, so it reaches the learner's own tablet, and stays usable on this
/// one if it cannot be shared yet. One value per slot is what makes "use
/// placeholders now, replace them later" a one-field edit, not a migration.
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

  /// The educator a picked file is shared as, so it reaches the learner's own
  /// tablet. Null keeps picked files on this tablet only.
  final String? ownerProfileId;

  const RoutineStepEditorSheet({
    super.key,
    required this.step,
    required this.filipino,
    this.routineLocks = false,
    this.ownerProfileId,
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
    // A locking step needs an end — it unlocks when its time is up — so one
    // without a length yet starts at the default the lock would use anyway.
    _draft = _withLockLength(_draft);
    _checkSign();
  }

  /// Whether [step] will hold the learner's device at its time.
  bool _locks(RoutineStep step) =>
      widget.routineLocks && step.isScheduled && step.lockScreen;

  /// [step], given the default length when it locks and has none.
  RoutineStep _withLockLength(RoutineStep step) =>
      _locks(step) && step.durationMinutes == 0
          ? step.copyWith(durationMinutes: kRoutineDefaultStepMinutes)
          : step;

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
      _draft = _withLockLength(
        _draft.copyWith(hour: picked.hour, minute: picked.minute),
      );
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
                        ? 'Kung walang oras, sinusunod ang hakbang ayon sa '
                              'pagkakasunod, hindi ayon sa orasan — kadalasang mas madali para sa batang hindi nagbabasa ng orasan.'
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
                          _locks(_draft)
                              ? (l
                                    ? 'Tatagal ${_draft.durationMinutes} minuto '
                                          '— bubukas ang app sa '
                                          '${formatStepEnd(_draft)}'
                                    : 'Lasts ${_draft.durationMinutes} min — '
                                          'the app unlocks at '
                                          '${formatStepEnd(_draft)}')
                              : _draft.durationMinutes == 0
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
                  // A locking step must end, so its length starts at five
                  // minutes; any other step may have no timer at all.
                  Slider(
                    value: _draft.durationMinutes.toDouble().clamp(
                      _locks(_draft) ? 5 : 0,
                      60,
                    ),
                    min: _locks(_draft) ? 5 : 0,
                    max: 60,
                    divisions: _locks(_draft) ? 11 : 12,
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
                                          'minuto bago ang oras'
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
                          ? 'Sa oras na ito, makatatanggap ang bata ng '
                                'abiso at pop-up: “Pakigawa na ang iyong check-in '
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
                  // step with a time — a lock needs a moment to start at, and
                  // it lets go when the step's time ends. Off means the step
                  // still appears and still reminds; it simply does not stop
                  // the learner.
                  if (widget.routineLocks && _draft.isScheduled) ...[
                    const SizedBox(height: 8),
                    Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _draft.lockScreen,
                        onChanged: (v) => setState(
                          () => _draft = _withLockLength(
                            _draft.copyWith(lockScreen: v),
                          ),
                        ),
                        secondary: const Text(
                          '🔒',
                          style: TextStyle(fontSize: 22),
                        ),
                        title: Text(
                          l
                              ? 'I-lock ang app hanggang sa pagtatapos ng oras nito'
                              : 'Lock the app until this step’s time ends',
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _draft.lockScreen
                              ? (l
                                    ? 'Mula ${formatStepTime(_draft)} hanggang '
                                          '${formatStepEnd(_draft)}, ito lang '
                                          'ang makikita ng bata. Kusang bubukas '
                                          'ang app.'
                                    : 'From ${formatStepTime(_draft)} to '
                                          '${formatStepEnd(_draft)} this is all '
                                          'the learner sees. The app unlocks by '
                                          'itself.')
                              : (l
                                    ? 'Hindi mapapahinto ang bata sa hakbang '
                                          'na ito — paalala lang.'
                                    : 'This step will not stop the learner — '
                                          'it only reminds.'),
                          style: AppTypography.labelSmall.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    // ── Can an adult end it early? ──
                    // The learner never sees a button either way; this only
                    // decides whether a Teacher or Parent may finish the step
                    // before its time is up.
                    if (_draft.lockScreen)
                      Material(
                        type: MaterialType.transparency,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _draft.releaseEarly,
                          onChanged: (v) => setState(
                            () => _draft = _draft.copyWith(releaseEarly: v),
                          ),
                          secondary: const Text(
                            '🗝️',
                            style: TextStyle(fontSize: 22),
                          ),
                          title: Text(
                            l
                                ? 'Maaaring tapusin nang maaga ng nakatatanda'
                                : 'Can be released early',
                            style: AppTypography.bodyMedium.copyWith(
                              color: hc.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            _draft.releaseEarly
                                ? (l
                                      ? 'Maaaring tapusin ito ng guro o magulang '
                                            'bago ang ${formatStepEnd(_draft)} — '
                                            'mula sa kanilang dashboard, o sa '
                                            'tablet ng bata sa pagdiin nang '
                                            'matagal sa oras ng hakbang.'
                                      : 'A teacher or parent can end it before '
                                            '${formatStepEnd(_draft)} — from '
                                            'their dashboard, or on the '
                                            'learner’s tablet by pressing and '
                                            'holding the step’s time.')
                                : (l
                                      ? 'Kailangang maghintay ang bata hanggang '
                                            '${formatStepEnd(_draft)}.'
                                      : 'The learner waits until '
                                            '${formatStepEnd(_draft)}.'),
                            style: AppTypography.labelSmall.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                  // ── Note / spoken cue ──
                  _SectionLabel(l ? 'Tala at Binibigkas na Paalala' : 'Note & spoken cue'),
                  TextField(
                    controller: _note,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l ? 'Tala (English)' : 'Note',
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
                      labelText: l ? 'Tala sa Filipino' : 'Filipino note',
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
                      ownerProfileId: widget.ownerProfileId,
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

  /// Who a picked file is shared as; null keeps it on this tablet.
  final String? ownerProfileId;

  const _MediaField({
    required this.controller,
    required this.kind,
    required this.filipino,
    required this.onChanged,
    required this.stepId,
    this.ownerProfileId,
  });

  @override
  State<_MediaField> createState() => _MediaFieldState();
}

class _MediaFieldState extends State<_MediaField> {
  bool _picking = false;

  /// Upload progress while a picked file is being shared.
  double? _sharing;

  bool get _canShare =>
      (widget.ownerProfileId?.isNotEmpty ?? false) &&
      const SharedMediaService().available;

  /// Shares the picked file behind [fileValue] so the learner's own tablet
  /// can show it, and swaps the field to the `shared://` value. A file that
  /// cannot be shared now stays usable on this tablet.
  Future<void> _share(String fileValue) async {
    if (!_canShare || _sharing != null) return;
    setState(() => _sharing = 0);
    final path = RoutineMediaStore.pathOf(fileValue);
    final dot = path.lastIndexOf('.');
    final result = await const SharedMediaService().upload(
      File(path),
      ownerProfileId: widget.ownerProfileId!,
      ext: dot == -1 ? 'bin' : path.substring(dot + 1),
      onProgress: (p) {
        if (mounted) setState(() => _sharing = p);
      },
    );
    if (!mounted || controller.text.trim() != fileValue) {
      // Replaced or cleared meanwhile: this upload belongs to nothing.
      if (result.ok) await const RoutineMediaStore().discard(result.value!);
      if (mounted) setState(() => _sharing = null);
      return;
    }
    setState(() => _sharing = null);
    if (!result.ok) return;
    await const RoutineMediaStore().discard(fileValue);
    controller.text = result.value!;
    widget.onChanged();
  }

  TextEditingController get controller => widget.controller;
  RoutineMediaKind get kind => widget.kind;
  bool get filipino => widget.filipino;

  /// The camera makes photos and videos; a GIF or a sound it cannot.
  bool get _cameraMakes =>
      kind == RoutineMediaKind.photo || kind == RoutineMediaKind.video;

  /// Fills the slot from a file on the device, or — with [camera] — from the
  /// in-app camera, so an educator can film the step then and there.
  Future<void> _pick({bool camera = false}) async {
    if (_picking) return;
    String? captured;
    if (camera) {
      captured = await captureMedia(
        context,
        mode: kind == RoutineMediaKind.photo
            ? CaptureMode.photo
            : CaptureMode.video,
      );
      if (captured == null || !mounted) return;
    }
    setState(() => _picking = true);
    try {
      final slot = captured != null
          ? await const RoutineMediaStore().adopt(
              sourcePath: captured,
              stepId: widget.stepId,
              kind: kind,
            )
          : await const RoutineMediaStore().pickAndAdopt(
              stepId: widget.stepId,
              kind: kind,
            );
      if (captured != null) {
        try {
          await File(captured).delete();
        } on Object {
          // The camera's own temp file; the OS reclaims it anyway.
        }
      }
      if (!mounted || slot == null) return;
      // Replacing a device file removes the old copy; a URL belongs to
      // whoever hosts it and is only forgotten, never deleted.
      final previous = controller.text.trim();
      final ownsPrevious = RoutineMediaStore.isDeviceFile(previous) ||
          SharedMediaService.isShared(previous);
      if (ownsPrevious && previous != slot) {
        await const RoutineMediaStore().discard(previous);
      }
      controller.text = slot;
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
    final picked = controller.text.trim();
    if (mounted && RoutineMediaStore.isDeviceFile(picked)) {
      await _share(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final style = RoutineMediaStyle.of(kind);
    final value = controller.text.trim();
    final filled = value.isNotEmpty;
    final onDevice = RoutineMediaStore.isDeviceFile(value);
    final shared = SharedMediaService.isShared(value);
    final sharing = _sharing;
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
                        if (onDevice || shared) {
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
                  filipino ? 'Pumili mula sa device' : 'Choose from device',
                ),
              ),
              if (_cameraMakes) ...[
                const SizedBox(width: 6),
                IconButton.outlined(
                  tooltip: kind == RoutineMediaKind.photo
                      ? (filipino
                            ? 'Kumuha ng larawan gamit ang camera'
                            : 'Take a photo with the camera')
                      : (filipino
                            ? 'Mag-record gamit ang camera'
                            : 'Record with the camera'),
                  onPressed: _picking ? null : () => _pick(camera: true),
                  icon: Icon(
                    kind == RoutineMediaKind.photo
                        ? Icons.photo_camera_rounded
                        : Icons.videocam_rounded,
                    size: 20,
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sharing != null
                      ? (filipino
                            ? 'Ibinabahagi… ${(sharing * 100).round()}%'
                            : 'Sharing… ${(sharing * 100).round()}%')
                      : shared
                      ? (filipino
                            ? 'Naibahagi na — makikita sa bawat device.'
                            : 'Shared — reaches every device.')
                      : onDevice
                      ? (filipino
                            ? 'Nasa tablet na ito lang. Hindi ito makikita ng '
                                  'bata sa ibang device.'
                            : 'On this tablet only — a learner using a different '
                                  'device will not see it.')
                      : (filipino
                            ? 'Makikita ang link sa bawat device.'
                            : 'A link reaches every device.'),
                  style: AppTypography.labelSmall.copyWith(
                    color: shared
                        ? AppColors.success
                        : onDevice
                        ? AppColors.warning
                        : hc.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (sharing != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(value: sharing),
            )
          else if (onDevice && _canShare)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _share(value),
                icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                label: Text(filipino ? 'Ibahagi ngayon' : 'Share now'),
              ),
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
          filipino ? 'Ang makikita ng bata' : 'What the learner will see',
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
