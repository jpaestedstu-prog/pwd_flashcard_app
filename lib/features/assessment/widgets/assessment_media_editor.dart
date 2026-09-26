import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/accessibility/learner_support.dart';
import '../../../core/services/shared_media_service.dart';
import '../../../core/widgets/media_capture_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../routine/services/routine_media_store.dart';
import '../../routine/widgets/routine_media.dart';
import '../models/assessment_media.dart';
import '../models/assessment_media_presentation.dart';
import '../services/assessment_media_cache.dart';
import '../services/assessment_media_store.dart';
import 'assessment_media_panel.dart';

AppLocalizations _tr(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();

/// A text field's look in this module's sheets — the builder's own style.
///
/// Spelled out rather than left to the theme: the app theme draws no border
/// on an unfocused field, so a bare `OutlineInputBorder` showed an outline
/// only while typing, and the field vanished into the sheet the moment focus
/// left it.
InputDecoration assessmentFieldDecoration(
  BuildContext context, {
  required String label,
  String? helper,
  String? hint,
  String? error,
  Widget? prefixIcon,
}) {
  final hc = HCColor.of(context);
  OutlineInputBorder edge(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecoration(
    labelText: label,
    helperText: helper,
    helperMaxLines: 4,
    hintText: hint,
    errorText: error,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: hc.surface,
    border: edge(hc.border),
    enabledBorder: edge(hc.border),
    focusedBorder: edge(hc.primary, 2),
  );
}

/// Picks one picture — from the camera, the device or a link — for something
/// smaller than a whole media section, such as one answer choice. Returns
/// the value to store (already shared with every device when that worked),
/// or null when the educator cancelled or the pick failed.
///
/// Records what it picked in [ledger], so a cancelled question sheet cleans
/// up after it like the full editor does.
Future<String?> pickAssessmentPicture(
  BuildContext context, {
  required String ownerKey,
  required AssessmentMediaLedger ledger,
  String? ownerProfileId,
}) async {
  const kind = AssessmentMediaKind.photo;
  final canShare =
      (ownerProfileId?.isNotEmpty ?? false) &&
      const SharedMediaService().available;
  FocusManager.instance.primaryFocus?.unfocus();
  final choice = await showModalBottomSheet<_Source>(
    context: context,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MediaSourceSheet(kind: kind, willShare: canShare),
  );
  if (choice == null || !context.mounted) return null;
  if (choice.link != null) return choice.link;
  String? captured;
  if (choice.capture) {
    captured = await captureMedia(context, mode: CaptureMode.photo);
    if (captured == null || !context.mounted) return null;
  }
  final result = captured != null
      ? await const AssessmentMediaStore().adoptCaptured(
          capturedPath: captured,
          ownerKey: ownerKey,
          kind: kind,
        )
      : await const AssessmentMediaStore().pickAndAdopt(
          ownerKey: ownerKey,
          kind: kind,
        );
  if (!context.mounted) return null;
  final t = _tr(context);
  switch (result.status) {
    case MediaPickStatus.cancelled:
      return null;
    case MediaPickStatus.tooLarge:
      AppSnackBar.warning(
        context,
        message: t.assessMediaTooLarge(
          AssessmentMediaStore.maxBytes ~/ (1024 * 1024),
        ),
      );
      return null;
    case MediaPickStatus.failed:
      AppSnackBar.warning(context, message: t.assessMediaPickFailed);
      return null;
    case MediaPickStatus.added:
      break;
  }
  final value = result.value!;
  ledger.adopted(value);
  if (!canShare) return value;
  final shared = await const AssessmentMediaStore().share(
    value,
    ownerProfileId: ownerProfileId!,
  );
  if (shared.status == SharedUploadStatus.shared) {
    ledger.adopted(shared.value);
    return shared.value;
  }
  // Stays on this tablet; the next sync shares it.
  if (context.mounted && shared.status == SharedUploadStatus.failed) {
    AppSnackBar.warning(context, message: t.assessMediaShareFailed);
  }
  return value;
}

/// The order slots are offered in. The sign-language version leads: for a
/// Deaf learner it is the one that carries the words.
const List<AssessmentMediaKind> _editorOrder = [
  AssessmentMediaKind.sign,
  AssessmentMediaKind.photo,
  AssessmentMediaKind.gif,
  AssessmentMediaKind.video,
  AssessmentMediaKind.audio,
];

/// One-line tips about the learners some media is for — "For Ana and Ben: add
/// an FSL video…" — grouped so five Deaf learners make one line, not five.
List<String> assessmentMediaTips(
  AppLocalizations t,
  Iterable<({String name, DisabilityType type, Set<LearnerSupportOption> supports})>
  learners,
) {
  final byAdvice = <AssessmentMediaAdvice, List<String>>{};
  for (final l in learners) {
    final advice = AssessmentMediaAdviceX.forLearner(l.type, l.supports);
    if (advice == null) continue;
    byAdvice.putIfAbsent(advice, () => []).add(l.name);
  }
  return [
    for (final e in byAdvice.entries)
      t.assessMediaTipFor(_names(e.value), _adviceText(t, e.key)),
  ];
}

String _names(List<String> names) {
  if (names.length <= 3) return names.join(', ');
  return '${names.take(3).join(', ')} +${names.length - 3}';
}

String _adviceText(AppLocalizations t, AssessmentMediaAdvice a) =>
    switch (a) {
      AssessmentMediaAdvice.signAndCaption => t.assessMediaTipHearing,
      AssessmentMediaAdvice.soundAndDescription => t.assessMediaTipVisual,
      AssessmentMediaAdvice.onePhoto => t.assessMediaTipCognitive,
      AssessmentMediaAdvice.playsItself => t.assessMediaTipMotor,
      AssessmentMediaAdvice.signPhotoAndDescription => t.assessMediaTipMultiple,
      AssessmentMediaAdvice.captionEverything => t.assessMediaTipWordsOnly,
    };

/// Attach photos, GIFs, video, sound and an FSL video to something an
/// educator is writing — a question, an assignment's instructions, or
/// feedback.
///
/// A picked file is shared with every device the moment it is chosen
/// (`SharedMediaService`, free Firestore plan) and each slot says where it
/// stands — shared, sharing, or still on this tablet only — so an educator
/// never learns from a learner's blank screen that a video did not travel.
/// "Add" buttons rather than five always-open fields: a question sheet is
/// already long, and most questions carry one picture or none.
class AssessmentMediaEditor extends StatefulWidget {
  final AssessmentMedia value;
  final ValueChanged<AssessmentMedia> onChanged;

  /// Names picked files, so they can be traced back to what they belong to.
  final String ownerKey;

  /// Records what this edit picked, for cleanup on save or cancel.
  final AssessmentMediaLedger ledger;

  /// On a question the description must not give the answer away.
  final bool forQuestion;

  /// One-line tips about the learners this is for.
  final List<String> tips;

  /// Heading; defaults to the general one.
  final String? title;

  /// The profile a shared file is uploaded as — the educator writing this.
  /// Null keeps picked files on this tablet only.
  final String? ownerProfileId;

  const AssessmentMediaEditor({
    super.key,
    required this.value,
    required this.onChanged,
    required this.ownerKey,
    required this.ledger,
    this.forQuestion = false,
    this.tips = const [],
    this.title,
    this.ownerProfileId,
  });

  @override
  State<AssessmentMediaEditor> createState() => _AssessmentMediaEditorState();
}

class _AssessmentMediaEditorState extends State<AssessmentMediaEditor> {
  late final TextEditingController _description = TextEditingController(
    text: widget.value.description,
  );
  AssessmentMediaKind? _busy;

  /// Upload progress per slot, 0–1, while a picked file is being shared.
  final Map<AssessmentMediaKind, double> _sharing = {};

  bool get _canShare =>
      (widget.ownerProfileId?.isNotEmpty ?? false) &&
      const SharedMediaService().available;

  @override
  void didUpdateWidget(covariant AssessmentMediaEditor old) {
    super.didUpdateWidget(old);
    // Only an outside reset moves the text; typing already matches.
    if (widget.value.description != _description.text) {
      _description.text = widget.value.description;
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  /// Drops the keyboard's focus before a sheet opens. A route that pops hands
  /// focus back to whatever held it, so without this the question field
  /// re-focused and the keyboard sprang up over the slot just filled — seen
  /// on the tablet after every add and every preview.
  void _releaseFocus() => FocusManager.instance.primaryFocus?.unfocus();

  Future<void> _add(AssessmentMediaKind kind) async {
    if (_busy != null) return;
    _releaseFocus();
    final choice = await showModalBottomSheet<_Source>(
      context: context,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MediaSourceSheet(kind: kind, willShare: _canShare),
    );
    if (choice == null || !mounted) return;
    final t = _tr(context);
    if (choice.link != null) {
      widget.onChanged(widget.value.withSlot(kind, choice.link!));
      return;
    }
    String? captured;
    if (choice.capture) {
      captured = await captureMedia(
        context,
        mode: kind == AssessmentMediaKind.photo
            ? CaptureMode.photo
            : CaptureMode.video,
        title: kind == AssessmentMediaKind.sign
            ? t.assessMediaRecordSignTitle
            : null,
      );
      if (captured == null || !mounted) return;
    }
    setState(() => _busy = kind);
    try {
      final result = captured != null
          ? await const AssessmentMediaStore().adoptCaptured(
              capturedPath: captured,
              ownerKey: widget.ownerKey,
              kind: kind,
            )
          : await const AssessmentMediaStore().pickAndAdopt(
              ownerKey: widget.ownerKey,
              kind: kind,
            );
      if (!mounted) return;
      switch (result.status) {
        case MediaPickStatus.added:
          widget.ledger.adopted(result.value!);
          widget.onChanged(widget.value.withSlot(kind, result.value!));
          unawaited(_share(kind, result.value!));
        case MediaPickStatus.cancelled:
          break;
        case MediaPickStatus.tooLarge:
          AppSnackBar.warning(
            context,
            message: t.assessMediaTooLarge(
              AssessmentMediaStore.maxBytes ~/ (1024 * 1024),
            ),
          );
        case MediaPickStatus.failed:
          AppSnackBar.warning(context, message: t.assessMediaPickFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// Shares the picked file in [kind] and swaps the slot to its `shared://`
  /// value. Whatever happens, the file stays usable on this tablet.
  Future<void> _share(AssessmentMediaKind kind, String fileValue) async {
    if (!_canShare || _sharing.containsKey(kind)) return;
    setState(() => _sharing[kind] = 0);
    final result = await const AssessmentMediaStore().share(
      fileValue,
      ownerProfileId: widget.ownerProfileId!,
      onProgress: (p) {
        if (mounted) setState(() => _sharing[kind] = p);
      },
    );
    final shared = result.status == SharedUploadStatus.shared;
    // The sheet closed, or the slot was replaced or cleared meanwhile: this
    // upload belongs to nothing any more.
    if (!mounted || widget.value.urlFor(kind) != fileValue) {
      if (shared) await const AssessmentMediaStore().discard([result.value]);
      if (mounted) setState(() => _sharing.remove(kind));
      return;
    }
    setState(() => _sharing.remove(kind));
    final t = _tr(context);
    switch (result.status) {
      case SharedUploadStatus.shared:
        widget.ledger.adopted(result.value);
        widget.onChanged(widget.value.withSlot(kind, result.value));
      case SharedUploadStatus.tooLarge:
        AppSnackBar.warning(
          context,
          message: t.assessMediaShareTooLarge(
            SharedMediaService.maxBytes ~/ (1024 * 1024),
          ),
        );
      case SharedUploadStatus.failed:
        AppSnackBar.warning(context, message: t.assessMediaShareFailed);
      case SharedUploadStatus.notOwner:
        AppSnackBar.warning(context, message: t.assessMediaShareNotOwner);
      case SharedUploadStatus.unavailable:
        break;
    }
  }

  void _remove(AssessmentMediaKind kind) =>
      // The file itself is let go of when the edit is saved (the ledger), so
      // a remove followed by a cancel still has its picture.
      widget.onChanged(widget.value.withSlot(kind, ''));

  void _preview(AssessmentMediaKind kind) {
    _releaseFocus();
    showModalBottomSheet<void>(
      context: context,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) {
        final hc = HCColor.of(sheet);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                kind.labelOf(_tr(sheet)),
                style: AppTypography.titleMedium.copyWith(
                  color: hc.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              AssessmentMediaPanel(
                media: AssessmentMedia.none
                    .withSlot(kind, widget.value.urlFor(kind))
                    .withDescription(widget.value.description),
                presentation: AssessmentMediaPresentation.educatorPreview,
                fallbackLabel: kind.labelOf(_tr(sheet)),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(sheet).maybePop(),
                icon: const Icon(Icons.close_rounded),
                label: Text(_tr(sheet).assessMediaClose),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final t = _tr(context);
    final value = widget.value;
    final filled = _editorOrder.where(value.has).toList();
    final empty = _editorOrder.where((k) => !value.has(k)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.perm_media_rounded, color: hc.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title ?? t.assessMediaSectionTitle,
                style: AppTypography.titleSmall.copyWith(
                  color: hc.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          t.assessMediaSectionHelp,
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
        ),
        for (final tip in widget.tips)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.tips_and_updates_rounded,
                  size: 18,
                  color: HCColor.of(context).graphic(AppColors.warning),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tip,
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        for (final kind in filled)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FilledSlot(
              kind: kind,
              value: value.urlFor(kind),
              sharing: _sharing[kind],
              canShare: _canShare,
              onShareNow: () => _share(kind, value.urlFor(kind)),
              onPreview: () => _preview(kind),
              onReplace: () => _add(kind),
              onRemove: () => _remove(kind),
            ),
          ),
        // Buttons rather than chips: a chip keeps its label on one faded
        // line, and "Magdagdag ng GIF na gumagalaw" at a large font on a
        // phone would lose its end. A button's label wraps between words.
        if (empty.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in empty)
                OutlinedButton.icon(
                  onPressed: _busy == null ? () => _add(kind) : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HCColor.of(
                      context,
                    ).readable(assessmentMediaColor(kind)),
                    side: BorderSide(
                      color: assessmentMediaColor(kind).withValues(alpha: 0.5),
                    ),
                  ),
                  icon: _busy == kind
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(assessmentMediaIcon(kind), size: 18),
                  label: Text(t.assessMediaAdd(kind.labelOf(t))),
                ),
            ],
          ),
        if (value.hasAny) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (text) =>
                widget.onChanged(widget.value.withDescription(text)),
            decoration: assessmentFieldDecoration(
              context,
              label: t.assessMediaDescribe,
              helper: widget.forQuestion
                  ? t.assessMediaDescribeHelpQuestion
                  : t.assessMediaDescribeHelp,
            ),
          ),
        ],
      ],
    );
  }
}

/// One attached item: what it is, where it lives, and what can be done.
class _FilledSlot extends StatelessWidget {
  final AssessmentMediaKind kind;
  final String value;

  /// Upload progress while this slot's file is being shared.
  final double? sharing;

  /// Whether a file still on this tablet could be shared from here.
  final bool canShare;
  final VoidCallback onShareNow;
  final VoidCallback onPreview;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  const _FilledSlot({
    required this.kind,
    required this.value,
    required this.sharing,
    required this.canShare,
    required this.onShareNow,
    required this.onPreview,
    required this.onReplace,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final t = _tr(context);
    final color = assessmentMediaColor(kind);
    final onDevice = RoutineMediaStore.isDeviceFile(value);
    final shared = SharedMediaService.isShared(value);
    final progress = sharing;
    final ground = Color.alphaBlend(color.withValues(alpha: 0.06), hc.surface);
    final String where;
    final Color whereColor;
    if (progress != null) {
      where = t.assessMediaSharing((progress * 100).round());
      whereColor = hc.textSecondary;
    } else if (shared) {
      where = t.assessMediaShared;
      whereColor = hc.readableOver(AppColors.success, ground);
    } else if (onDevice) {
      where = canShare ? t.assessMediaNotShared : t.assessMediaOnDevice;
      whereColor = hc.readableOver(AppColors.warning, ground);
    } else {
      where = t.assessMediaLinkReaches;
      whereColor = hc.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: ground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Thumb(kind: kind, value: value),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.labelOf(t),
                      style: AppTypography.labelLarge.copyWith(
                        color: hc.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (shared) ...[
                          Icon(
                            Icons.cloud_done_rounded,
                            size: 14,
                            color: whereColor,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            where,
                            style: AppTypography.labelSmall.copyWith(
                              color: whereColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: progress),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (kind == AssessmentMediaKind.sign)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                t.assessMediaSignHelp,
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ),
          Wrap(
            spacing: 4,
            children: [
              if (onDevice && canShare && progress == null)
                TextButton.icon(
                  onPressed: onShareNow,
                  icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text(t.assessMediaShareNow),
                ),
              TextButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: Text(t.assessMediaPreview),
              ),
              TextButton.icon(
                onPressed: onReplace,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(t.assessMediaReplace),
              ),
              TextButton.icon(
                onPressed: onRemove,
                style: TextButton.styleFrom(
                  foregroundColor: hc.readableOver(hc.error, ground),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(t.assessMediaRemove),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small square showing a picture, or the kind's icon for anything that
/// plays.
class _Thumb extends StatelessWidget {
  final AssessmentMediaKind kind;
  final String value;

  const _Thumb({required this.kind, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = assessmentMediaColor(kind);
    Widget icon() => Icon(assessmentMediaIcon(kind), color: color, size: 28);
    final v = value.trim();
    Widget child;
    if (!kind.isPicture) {
      child = icon();
    } else if (RoutineMediaStore.isDeviceFile(v)) {
      child = Image.file(
        File(RoutineMediaStore.pathOf(v)),
        fit: BoxFit.cover,
        cacheWidth: 160,
        errorBuilder: (_, _, _) => icon(),
      );
    } else if (isAssetMedia(v)) {
      child = Image.asset(
        assetPathOf(v),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => icon(),
      );
    } else if (SharedMediaService.isShared(v)) {
      child = FutureBuilder<File?>(
        future: AssessmentMediaCache.fileFor(v),
        builder: (_, snap) => snap.data == null
            ? icon()
            : Image.file(
                snap.data!,
                fit: BoxFit.cover,
                cacheWidth: 160,
                errorBuilder: (_, _, _) => icon(),
              ),
      );
    } else {
      child = Image.network(
        v,
        fit: BoxFit.cover,
        cacheWidth: 160,
        errorBuilder: (_, _, _) => icon(),
      );
    }
    return ExcludeSemantics(
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// Where a slot's media comes from: the camera, a file on this device, or a
/// link.
class _Source {
  final bool capture;
  final String? link;

  const _Source.device() : capture = false, link = null;
  const _Source.camera() : capture = true, link = null;
  const _Source.link(String this.link) : capture = false;
}

/// "Record with the camera", "Choose from this device" or "Paste a link" for
/// one slot. The camera is offered for photos, videos and FSL videos — the
/// kinds it can make.
class _MediaSourceSheet extends StatefulWidget {
  final AssessmentMediaKind kind;

  /// A picked file will be shared with every device, not kept on this one.
  final bool willShare;

  const _MediaSourceSheet({required this.kind, required this.willShare});

  @override
  State<_MediaSourceSheet> createState() => _MediaSourceSheetState();
}

class _MediaSourceSheetState extends State<_MediaSourceSheet> {
  final _link = TextEditingController();
  String? _error;

  /// The camera makes photos and videos; a GIF or a sound it cannot.
  bool get _cameraMakes => switch (widget.kind) {
    AssessmentMediaKind.photo ||
    AssessmentMediaKind.video ||
    AssessmentMediaKind.sign => true,
    AssessmentMediaKind.gif || AssessmentMediaKind.audio => false,
  };

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _useLink() {
    final v = _link.text.trim();
    final ok = v.startsWith('https://') ||
        v.startsWith('http://') ||
        isAssetMedia(v);
    if (!ok) {
      setState(() => _error = _tr(context).assessMediaLinkInvalid);
      return;
    }
    Navigator.of(context).pop(_Source.link(v));
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final t = _tr(context);
    final label = widget.kind.labelOf(t);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.assessMediaAdd(label),
              style: AppTypography.titleLarge.copyWith(color: hc.textPrimary),
            ),
            if (widget.kind == AssessmentMediaKind.sign) ...[
              const SizedBox(height: 6),
              Text(
                t.assessMediaSignHelp,
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_cameraMakes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      Navigator.of(context).pop(const _Source.camera()),
                  icon: Icon(
                    widget.kind == AssessmentMediaKind.photo
                        ? Icons.photo_camera_rounded
                        : Icons.videocam_rounded,
                  ),
                  label: Text(
                    widget.kind == AssessmentMediaKind.photo
                        ? t.assessMediaTakePhoto
                        : t.assessMediaRecordVideo,
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(const _Source.device()),
              icon: const Icon(Icons.phone_android_rounded),
              label: Text(t.assessMediaFromDevice),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.willShare
                  ? t.assessMediaFromDeviceShared(
                      SharedMediaService.maxBytes ~/ (1024 * 1024),
                    )
                  : t.assessMediaOnDevice,
              style: AppTypography.labelSmall.copyWith(
                color: widget.willShare ? hc.textSecondary : hc.warningText,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _useLink(),
              decoration: assessmentFieldDecoration(
                context,
                label: t.assessMediaPasteLink,
                hint: t.assessMediaLinkHint,
                error: _error,
                prefixIcon: const Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _useLink,
              icon: const Icon(Icons.check_rounded),
              label: Text(t.assessMediaUseLink),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.assessMediaLinkReaches,
              style: AppTypography.labelSmall.copyWith(
                color: hc.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
