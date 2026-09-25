import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/accessibility/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../providers/app_providers.dart';
import '../../routine/services/routine_media_store.dart';
import '../../routine/widgets/routine_media.dart';
import '../models/assessment_media.dart';
import '../models/assessment_media_presentation.dart';
import '../services/assessment_media_cache.dart';

/// Builds a video in place of the plugin, which no test binding provides.
typedef AssessmentVideoBuilder =
    Widget Function(
      BuildContext context,
      String value,
      AssessmentMediaKind kind,
      bool autoplay,
    );

/// Icon for a media kind, shared by the panel, the badges and the editor.
IconData assessmentMediaIcon(AssessmentMediaKind kind) => switch (kind) {
  AssessmentMediaKind.photo => Icons.photo_rounded,
  AssessmentMediaKind.gif => Icons.gif_box_rounded,
  AssessmentMediaKind.video => Icons.play_circle_rounded,
  AssessmentMediaKind.audio => Icons.volume_up_rounded,
  AssessmentMediaKind.sign => Icons.sign_language_rounded,
};

/// Accent for a media kind — the same palette the routine editor uses.
Color assessmentMediaColor(AssessmentMediaKind kind) => switch (kind) {
  AssessmentMediaKind.photo => AppColors.info,
  AssessmentMediaKind.gif => AppColors.secondary,
  AssessmentMediaKind.video => AppColors.primary,
  AssessmentMediaKind.audio => AppColors.success,
  AssessmentMediaKind.sign => AppColors.secondaryDark,
};

/// Straight double quotes turned typographic.
///
/// A `"` anywhere in a semantics label blanks the *whole* label on Android —
/// the Learning Assist row was a nameless switch for months because of one.
/// Descriptions, notes and instructions here are typed by an educator, so
/// every one of them goes through this before it is shown or spoken.
String curlyQuotes(String text) {
  if (!text.contains('"')) return text;
  var open = true;
  return text.replaceAllMapped('"', (_) {
    final mark = open ? '“' : '”';
    open = !open;
    return mark;
  });
}

bool _isFilipino(BuildContext context) =>
    AppLocalizations.of(context)?.localeName.startsWith('fil') ?? false;

AppLocalizations _tr(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();

/// The media an educator attached, shown the way [presentation] says this
/// learner needs it.
///
/// Renders nothing when there is nothing this learner would see, so callers
/// can drop it in unconditionally.
class AssessmentMediaPanel extends ConsumerStatefulWidget {
  final AssessmentMedia media;
  final AssessmentMediaPresentation presentation;

  /// Read to a screen reader for a picture the educator did not describe.
  final String fallbackLabel;

  /// Test seam for the video plugin. Null in the app.
  static AssessmentVideoBuilder? debugVideoBuilder;

  const AssessmentMediaPanel({
    super.key,
    required this.media,
    required this.presentation,
    required this.fallbackLabel,
  });

  @override
  ConsumerState<AssessmentMediaPanel> createState() =>
      _AssessmentMediaPanelState();
}

class _AssessmentMediaPanelState extends ConsumerState<AssessmentMediaPanel> {
  bool _expanded = false;

  bool _reducedMotion() {
    try {
      return ref.read(settingsProvider).reducedMotion ||
          MediaQuery.of(context).disableAnimations;
    } catch (_) {
      // Settings live in a box widget tests often leave closed; a GIF that
      // animates is never worth failing a question over.
      return false;
    }
  }

  Future<void> _readAloud(String text) async {
    try {
      await ref.read(ttsServiceProvider).speak(text);
    } catch (_) {
      // Speech is an extra channel; the words are on screen or in semantics.
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.presentation;
    final kinds = p.kindsFor(widget.media);
    if (kinds.isEmpty) return const SizedBox.shrink();

    final t = _tr(context);
    final description = curlyQuotes(widget.media.trimmedDescription);
    final shown = p.leadOnly && !_expanded ? kinds.take(1).toList() : kinds;
    final hidden = kinds.length - shown.length;
    final label = description.isNotEmpty
        ? description
        : curlyQuotes(widget.fallbackLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kind in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: switch (kind) {
              AssessmentMediaKind.photo ||
              AssessmentMediaKind.gif => _MediaImage(
                value: widget.media.urlFor(kind),
                kind: kind,
                semanticLabel: label,
                pauseAnimation: _reducedMotion(),
              ),
              AssessmentMediaKind.audio => _MediaAudio(
                value: widget.media.urlFor(kind),
                large: p.largeControls,
              ),
              AssessmentMediaKind.video => _MediaBlock(
                kind: kind,
                title: kind.labelOf(t),
                child: _MediaVideo(
                  value: widget.media.urlFor(kind),
                  kind: kind,
                  autoplay: p.autoplayVideo,
                  loop: false,
                  large: p.largeControls,
                  semanticLabel: label,
                ),
              ),
              AssessmentMediaKind.sign => _MediaBlock(
                kind: kind,
                title: p.signSystemDiffers
                    ? '${t.assessMediaSignHeading} · ${t.assessMediaFilmedInFsl}'
                    : t.assessMediaSignHeading,
                child: _MediaVideo(
                  value: widget.media.urlFor(kind),
                  kind: kind,
                  // A sign is watched more than once; it loops quietly.
                  autoplay: p.autoplaySign,
                  loop: true,
                  large: p.largeControls,
                  semanticLabel: t.assessMediaSignHeading,
                ),
              ),
            },
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _expanded = true),
              icon: const Icon(Icons.expand_more_rounded),
              label: Text(t.assessMediaShowMore(hidden)),
            ),
          ),
        if (description.isNotEmpty && (p.showCaptions || p.offerReadAloud))
          _DescriptionBar(
            text: description,
            showText: p.showCaptions,
            onReadAloud: p.offerReadAloud ? () => _readAloud(description) : null,
            large: p.largeControls,
          ),
      ],
    );
  }
}

/// A titled frame around a video, so a learner can tell the sign version from
/// the question's own video at a glance.
class _MediaBlock extends StatelessWidget {
  final AssessmentMediaKind kind;
  final String title;
  final Widget child;

  const _MediaBlock({
    required this.kind,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final color = assessmentMediaColor(kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(assessmentMediaIcon(kind), size: 18, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: AppTypography.labelLarge.copyWith(
                  color: hc.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Caption and/or a read-aloud button for the educator's description.
class _DescriptionBar extends StatelessWidget {
  final String text;
  final bool showText;
  final VoidCallback? onReadAloud;
  final bool large;

  const _DescriptionBar({
    required this.text,
    required this.showText,
    required this.onReadAloud,
    required this.large,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final t = _tr(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(hc.primary.withValues(alpha: 0.06), hc.surface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hc.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showText) ...[
            Row(
              children: [
                Icon(Icons.closed_caption_rounded, size: 18, color: hc.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    t.assessMediaCaption,
                    style: AppTypography.labelMedium.copyWith(
                      color: hc.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: AppTypography.bodyLarge.copyWith(color: hc.textPrimary),
            ),
          ],
          if (onReadAloud != null) ...[
            if (showText) const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onReadAloud,
              icon: const Icon(Icons.record_voice_over_rounded),
              label: Text(t.assessMediaReadAloud),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, large ? 56 : 44),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Says why a piece of media is not showing, in words a learner can act on.
class _MediaUnavailable extends StatelessWidget {
  final AssessmentMediaKind kind;
  final MediaAvailability availability;

  const _MediaUnavailable({required this.kind, required this.availability});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final t = _tr(context);
    final otherDevice = availability == MediaAvailability.otherDevice;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hc.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hc.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            otherDevice ? Icons.tablet_android_rounded : Icons.wifi_off_rounded,
            size: 30,
            color: hc.textHint,
          ),
          const SizedBox(height: 8),
          Text(
            otherDevice
                ? t.assessMediaOnOtherDevice(kind.labelOf(t))
                : t.assessMediaCouldNotLoad(kind.labelOf(t)),
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Pictures ─────────────────────────────────────────────

class _MediaImage extends StatefulWidget {
  final String value;
  final AssessmentMediaKind kind;
  final String semanticLabel;
  final bool pauseAnimation;

  const _MediaImage({
    required this.value,
    required this.kind,
    required this.semanticLabel,
    required this.pauseAnimation,
  });

  @override
  State<_MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<_MediaImage> {
  Future<File?>? _download;

  /// A GIF under Reduced Motion starts still and plays on request.
  late bool _animating = !widget.pauseAnimation;

  String get _v => widget.value.trim();

  @override
  void initState() {
    super.initState();
    if (_v.startsWith('http://') || _v.startsWith('https://')) {
      _download = AssessmentMediaCache.fileFor(_v);
    }
  }

  @override
  void didUpdateWidget(covariant _MediaImage old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _download = _v.startsWith('http') ? AssessmentMediaCache.fileFor(_v) : null;
    }
  }

  Widget _unavailable(MediaAvailability a) =>
      _MediaUnavailable(kind: widget.kind, availability: a);

  Widget _image({BoxFit fit = BoxFit.contain}) {
    if (RoutineMediaStore.isDeviceFile(_v)) {
      return Image.file(
        File(RoutineMediaStore.pathOf(_v)),
        fit: fit,
        errorBuilder: (_, _, _) => _unavailable(MediaAvailability.otherDevice),
      );
    }
    if (isAssetMedia(_v)) {
      return Image.asset(
        assetPathOf(_v),
        fit: fit,
        errorBuilder: (_, _, _) => _unavailable(MediaAvailability.unreachable),
      );
    }
    return FutureBuilder<File?>(
      future: _download,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final file = snap.data;
        if (file != null) {
          return Image.file(
            file,
            fit: fit,
            errorBuilder: (_, _, _) =>
                _unavailable(MediaAvailability.unreachable),
          );
        }
        // The cache could not fetch it; a plain network load is the last try
        // before saying so.
        return Image.network(
          _v,
          fit: fit,
          errorBuilder: (_, _, _) => _unavailable(MediaAvailability.unreachable),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final t = _tr(context);
    final isGif = widget.kind == AssessmentMediaKind.gif;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          image: true,
          button: true,
          label: widget.semanticLabel,
          hint: t.assessMediaTapToEnlarge,
          onTap: () => _enlarge(context),
          child: ExcludeSemantics(
            child: GestureDetector(
              onTap: () => _enlarge(context),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: hc.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: hc.border),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                // TickerMode off freezes an animated image on its current
                // frame — the cheap, honest way to pause a GIF.
                child: TickerMode(
                  enabled: !isGif || _animating,
                  child: _image(),
                ),
              ),
            ),
          ),
        ),
        if (isGif && widget.pauseAnimation)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _animating = !_animating),
              icon: Icon(
                _animating ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(
                _animating
                    ? t.assessMediaStopAnimation
                    : t.assessMediaPlayAnimation,
              ),
            ),
          ),
      ],
    );
  }

  /// Full width with pinch-zoom: a low-vision learner can get right up to the
  /// picture, which a thumbnail in a scrolling test never allowed.
  void _enlarge(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) {
        final hc = HCColor.of(sheet);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hc.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Semantics(
                  image: true,
                  label: widget.semanticLabel,
                  child: ExcludeSemantics(
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: TickerMode(
                        enabled:
                            widget.kind != AssessmentMediaKind.gif || _animating,
                        child: _image(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
}

// ─── Sound ────────────────────────────────────────────────

class _MediaAudio extends StatefulWidget {
  final String value;
  final bool large;

  const _MediaAudio({required this.value, required this.large});

  @override
  State<_MediaAudio> createState() => _MediaAudioState();
}

class _MediaAudioState extends State<_MediaAudio> {
  late final Future<(MediaAvailability, String)> _resolved = _resolve();

  /// The value to play — the downloaded copy of a link, so the sound works
  /// offline — and whether there is anything to play at all.
  Future<(MediaAvailability, String)> _resolve() async {
    final v = widget.value.trim();
    if (isAssetMedia(v)) return (MediaAvailability.ready, v);
    final file = await AssessmentMediaCache.fileFor(v);
    if (file != null) {
      return (
        MediaAvailability.ready,
        '${RoutineMediaStore.filePrefix}${file.path}',
      );
    }
    return (
      RoutineMediaStore.isDeviceFile(v)
          ? MediaAvailability.otherDevice
          : MediaAvailability.unreachable,
      v,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _tr(context);
    return FutureBuilder<(MediaAvailability, String)>(
      future: _resolved,
      builder: (context, snap) {
        final resolved = snap.data;
        if (resolved == null) {
          return const Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (resolved.$1 != MediaAvailability.ready) {
          return _MediaUnavailable(
            kind: AssessmentMediaKind.audio,
            availability: resolved.$1,
          );
        }
        return Row(
          children: [
            Icon(
              assessmentMediaIcon(AssessmentMediaKind.audio),
              color: assessmentMediaColor(AssessmentMediaKind.audio),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Theme(
                data: Theme.of(context).copyWith(
                  outlinedButtonTheme: OutlinedButtonThemeData(
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(0, widget.large ? 56 : 44),
                    ),
                  ),
                ),
                child: Semantics(
                  label: t.assessMediaAudio,
                  child: RoutineAudioButton(
                    url: resolved.$2,
                    filipino: _isFilipino(context),
                    accent: assessmentMediaColor(AssessmentMediaKind.audio),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Video and sign ───────────────────────────────────────

class _MediaVideo extends StatefulWidget {
  final String value;
  final AssessmentMediaKind kind;
  final bool autoplay;
  final bool loop;
  final bool large;
  final String semanticLabel;

  const _MediaVideo({
    required this.value,
    required this.kind,
    required this.autoplay,
    required this.loop,
    required this.large,
    required this.semanticLabel,
  });

  @override
  State<_MediaVideo> createState() => _MediaVideoState();
}

class _MediaVideoState extends State<_MediaVideo> {
  VideoPlayerController? _controller;
  MediaAvailability? _failed;

  @override
  void initState() {
    super.initState();
    if (AssessmentMediaPanel.debugVideoBuilder == null) _open();
  }

  Future<void> _open() async {
    final v = widget.value.trim();
    VideoPlayerController? controller;
    try {
      if (RoutineMediaStore.isDeviceFile(v)) {
        final f = File(RoutineMediaStore.pathOf(v));
        if (!await f.exists()) {
          if (mounted) setState(() => _failed = MediaAvailability.otherDevice);
          return;
        }
        controller = VideoPlayerController.file(f);
      } else if (isAssetMedia(v)) {
        controller = VideoPlayerController.asset(assetPathOf(v));
      } else {
        final file = await AssessmentMediaCache.fileFor(v);
        controller = file != null
            ? VideoPlayerController.file(file)
            : VideoPlayerController.networkUrl(Uri.parse(v));
      }
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(widget.loop);
      if (widget.autoplay) await controller.play();
      controller.addListener(_onTick);
      setState(() => _controller = controller);
    } on Object {
      await controller?.dispose();
      if (mounted) setState(() => _failed = MediaAvailability.unreachable);
    }
  }

  /// Repaints the play overlay when a one-shot video reaches its end.
  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      final atEnd = c.value.position >= c.value.duration &&
          c.value.duration > Duration.zero;
      if (atEnd) await c.seekTo(Duration.zero);
      await c.play();
    }
  }

  Future<void> _replay() async {
    final c = _controller;
    if (c == null) return;
    await c.seekTo(Duration.zero);
    await c.play();
  }

  @override
  Widget build(BuildContext context) {
    final seam = AssessmentMediaPanel.debugVideoBuilder;
    if (seam != null) {
      return seam(context, widget.value, widget.kind, widget.autoplay);
    }
    final failed = _failed;
    if (failed != null) {
      return _MediaUnavailable(kind: widget.kind, availability: failed);
    }
    final hc = HCColor.of(context);
    final t = _tr(context);
    final c = _controller;
    final playing = c?.value.isPlaying ?? false;
    final iconSize = widget.large ? 64.0 : 48.0;

    return Semantics(
      label: widget.semanticLabel,
      child: Container(
        decoration: BoxDecoration(
          color: hc.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hc.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: c != null && c.value.aspectRatio > 0
              ? c.value.aspectRatio
              : 16 / 9,
          child: c == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: _toggle,
                      child: ExcludeSemantics(child: VideoPlayer(c)),
                    ),
                    if (!playing)
                      Center(
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: const CircleBorder(),
                          child: IconButton(
                            iconSize: iconSize,
                            tooltip: t.assessMediaPlay,
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                            ),
                            onPressed: _toggle,
                          ),
                        ),
                      ),
                    PositionedDirectional(
                      end: 10,
                      bottom: 10,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: const CircleBorder(),
                        child: IconButton(
                          iconSize: widget.large ? 32 : 24,
                          tooltip: playing
                              ? t.assessMediaPause
                              : t.assessMediaReplay,
                          icon: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.replay_rounded,
                            color: Colors.white,
                          ),
                          onPressed: playing ? _toggle : _replay,
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

// ─── Badges ───────────────────────────────────────────────

/// A compact row naming which media a tile carries — "Photo · FSL video" —
/// so a learner or an educator can see it before opening anything.
class AssessmentMediaBadges extends StatelessWidget {
  final List<AssessmentMediaKind> kinds;

  const AssessmentMediaBadges({super.key, required this.kinds});

  @override
  Widget build(BuildContext context) {
    if (kinds.isEmpty) return const SizedBox.shrink();
    final t = _tr(context);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final kind in kinds)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: assessmentMediaColor(kind).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  assessmentMediaIcon(kind),
                  size: 14,
                  color: assessmentMediaColor(kind),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    kind.labelOf(t),
                    style: AppTypography.labelSmall.copyWith(
                      color: assessmentMediaColor(kind),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
