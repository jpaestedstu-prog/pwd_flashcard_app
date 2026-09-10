import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/routine_catalog.dart';
import '../models/routine_models.dart';
import '../services/routine_media_store.dart';

/// Everything about showing a routine step's media — and about showing its
/// *absence* well, which is most of the work.
///
/// The brief asked for photos, GIFs and videos "with placeholders initially,
/// designed so these can easily be replaced or uploaded later". That shapes
/// this file:
///
///  * A URL is the only thing a step stores, so replacing media is editing one
///    text field — no migration, no re-upload of the routine.
///  * `assets/…` paths and `http(s)://` URLs are both accepted, so bundled
///    art and hosted media work through the same field. The project already
///    hosts its media on Cloudinary; a routine photo pasted from there works
///    with no new plumbing.
///  * A missing photo renders [RoutineMediaPlaceholder], which says what
///    *would* be here and stays on-brand — never a broken-image glyph, and
///    never an empty box a learner reads as "the app is broken".

/// Copy and iconography for one media channel.
class RoutineMediaStyle {
  final IconData icon;
  final String label;
  final String labelFilipino;
  final String emptyHint;
  final String emptyHintFilipino;
  final Color color;

  const RoutineMediaStyle({
    required this.icon,
    required this.label,
    required this.labelFilipino,
    required this.emptyHint,
    required this.emptyHintFilipino,
    required this.color,
  });

  String labelOf({required bool filipino}) => filipino ? labelFilipino : label;
  String emptyHintOf({required bool filipino}) =>
      filipino ? emptyHintFilipino : emptyHint;

  static RoutineMediaStyle of(RoutineMediaKind kind) => switch (kind) {
        RoutineMediaKind.photo => const RoutineMediaStyle(
            icon: Icons.photo_rounded,
            label: 'Photo',
            labelFilipino: 'Larawan',
            emptyHint: 'A photo of this step can be added here.',
            emptyHintFilipino:
                'Maaaring magdagdag dito ng larawan ng hakbang na ito.',
            color: AppColors.info,
          ),
        RoutineMediaKind.gif => const RoutineMediaStyle(
            icon: Icons.gif_box_rounded,
            label: 'GIF',
            labelFilipino: 'GIF',
            emptyHint: 'A short looping GIF can be added here.',
            emptyHintFilipino: 'Maaaring magdagdag dito ng maikling GIF.',
            color: AppColors.secondary,
          ),
        RoutineMediaKind.video => const RoutineMediaStyle(
            icon: Icons.play_circle_rounded,
            label: 'Video',
            labelFilipino: 'Bidyo',
            emptyHint: 'A demonstration video can be added here.',
            emptyHintFilipino:
                'Maaaring magdagdag dito ng bidyong nagpapakita ng hakbang.',
            color: AppColors.primary,
          ),
        RoutineMediaKind.audio => const RoutineMediaStyle(
            icon: Icons.volume_up_rounded,
            label: 'Sound',
            labelFilipino: 'Tunog',
            emptyHint: 'A recorded voice cue can be added here.',
            emptyHintFilipino:
                'Maaaring magdagdag dito ng naitalang boses na paalala.',
            color: AppColors.success,
          ),
      };
}

/// True when [url] points at a bundled asset rather than the network.
bool isAssetMedia(String url) {
  final u = url.trim();
  return u.startsWith('assets/') || u.startsWith('asset://');
}

/// Normalises the `asset://` form callers may paste.
String assetPathOf(String url) {
  final u = url.trim();
  return u.startsWith('asset://') ? u.substring('asset://'.length) : u;
}

/// Height of one tile in the step editor's "what the learner will see" strip.
///
/// Scales with the OS font setting. A fixed height overflowed by 30 px the
/// moment the placeholder's caption wrapped to a second line — a
/// `SliverGridDelegate`-style constant does not grow with the text inside it,
/// and this caption is exactly the kind that wraps.
double routinePreviewTileHeight(double textScale) =>
    (150 * textScale.clamp(1.0, 2.0)).clamp(150.0, 240.0);

/// Width of one tile in that strip. Grows a little with the font so a
/// two-word caption is not forced onto four lines.
double routinePreviewTileWidth(double textScale) =>
    (130 * textScale.clamp(1.0, 1.6)).clamp(130.0, 200.0);

/// The designed stand-in for media that has not been supplied yet.
///
/// Deliberately *not* a grey box: it names the channel, explains in one line
/// what would go here, and keeps the step's own emoji as the visual anchor so
/// a learner who cannot read still gets a picture of the activity. That last
/// part is the reason this is a placeholder and not an omission — the emoji is
/// real visual content, available for every step from day one.
class RoutineMediaPlaceholder extends StatelessWidget {
  final RoutineMediaKind kind;
  final String stepEmoji;
  final bool filipino;

  /// Squeezes the layout for use inside a small tile.
  final bool compact;

  const RoutineMediaPlaceholder({
    super.key,
    required this.kind,
    required this.stepEmoji,
    required this.filipino,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final style = RoutineMediaStyle.of(kind);
    final label = style.labelOf(filipino: filipino);

    return Semantics(
      container: true,
      label: filipino
          ? '$label: wala pang nakalagay. ${style.emptyHintOf(filipino: true)}'
          : '$label not added yet. ${style.emptyHintOf(filipino: false)}',
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 20),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              style.color.withValues(alpha: 0.08),
              hc.surface,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: style.color.withValues(alpha: 0.35),
              // Dashed would be nicer; a soft solid rim reads as "reserved"
              // without needing a custom painter.
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Flexible, not a bare Text: the emoji is decoration here and
              // may give up height to the caption, which is the part that
              // actually says what is missing.
              Flexible(
                child: Text(
                  stepEmoji,
                  style: TextStyle(fontSize: compact ? 26 : 44),
                ),
              ),
              SizedBox(height: compact ? 4 : 10),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(style.icon, size: 16, color: style.color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        filipino
                            ? '$label — malapit nang idagdag'
                            : '$label coming soon',
                        textAlign: TextAlign.center,
                        // Two lines is enough to say it; a third only ever
                        // appears at a big font scale, where it is what
                        // pushes the tile past its height.
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMedium.copyWith(
                          color: style.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 6),
                Text(
                  style.emptyHintOf(filipino: filipino),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A photo or GIF for a routine step, from an asset or the network.
///
/// Both kinds go through the same widget because a GIF *is* an image to
/// Flutter — the distinction exists for the educator (who is choosing what to
/// supply) and for the label, not for the decoder.
class RoutineImage extends StatelessWidget {
  final String url;
  final RoutineMediaKind kind;
  final String stepEmoji;
  final bool filipino;

  /// Alt text. A routine photo is content, not decoration: a learner using a
  /// screen reader must be told what the picture shows.
  final String semanticLabel;

  final double? height;

  const RoutineImage({
    super.key,
    required this.url,
    required this.kind,
    required this.stepEmoji,
    required this.filipino,
    required this.semanticLabel,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return RoutineMediaPlaceholder(
        kind: kind,
        stepEmoji: stepEmoji,
        filipino: filipino,
      );
    }

    Widget failed() => RoutineMediaPlaceholder(
          kind: kind,
          stepEmoji: stepEmoji,
          filipino: filipino,
        );

    final image = RoutineMediaStore.isDeviceFile(trimmed)
        ? Image.file(
            File(RoutineMediaStore.pathOf(trimmed)),
            height: height,
            fit: BoxFit.cover,
            // A picked file can vanish — the educator moved it, or Android
            // reclaimed the copy. Falling back to the placeholder keeps the
            // step visual rather than showing a broken box.
            errorBuilder: (_, _, _) => failed(),
          )
        : isAssetMedia(trimmed)
        ? Image.asset(
            assetPathOf(trimmed),
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => failed(),
          )
        : Image.network(
            trimmed,
            height: height,
            fit: BoxFit.cover,
            // A slow classroom connection must not leave a blank rectangle:
            // the placeholder keeps the step's emoji on screen while the real
            // picture arrives, so the step never has *no* visual.
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : failed(),
            errorBuilder: (_, _, _) => failed(),
          );

    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(width: double.infinity, child: image),
        ),
      ),
    );
  }
}

/// Plays a routine step's audio cue.
///
/// Owns one [AudioPlayer] for its lifetime and stops it on dispose, so leaving
/// a step mid-cue does not leave a voice playing over the next screen.
class RoutineAudioButton extends StatefulWidget {
  final String url;
  final bool filipino;
  final Color accent;

  const RoutineAudioButton({
    super.key,
    required this.url,
    required this.filipino,
    required this.accent,
  });

  @override
  State<RoutineAudioButton> createState() => _RoutineAudioButtonState();
}

class _RoutineAudioButtonState extends State<RoutineAudioButton> {
  AudioPlayer? _player;
  bool _playing = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final player = _player ??= AudioPlayer();
    if (_playing) {
      await player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    player.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _playing = false);
    });
    try {
      final u = widget.url.trim();
      await player.play(
        RoutineMediaStore.isDeviceFile(u)
            ? DeviceFileSource(RoutineMediaStore.pathOf(u))
            : isAssetMedia(u)
                // AssetSource is rooted at `assets/`, so the prefix has to go.
                ? AssetSource(assetPathOf(u).replaceFirst('assets/', ''))
                : UrlSource(u),
      );
    } on Object {
      // Audio is an alternative channel, never the only one — a cue that will
      // not play should reset the button, not raise an error over the step.
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.filipino;
    return OutlinedButton.icon(
      onPressed: _toggle,
      icon: Icon(_playing ? Icons.stop_rounded : Icons.volume_up_rounded),
      label: Text(
        _playing ? (l ? 'Ihinto' : 'Stop') : (l ? 'Pakinggan' : 'Listen'),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: widget.accent,
        side: BorderSide(color: widget.accent.withValues(alpha: 0.5)),
      ),
    );
  }
}

/// Opens [url] in a looping video sheet.
///
/// [onFsl] — when non-null — draws the **FSL button** the brief asked for
/// directly on the video: "for videos intended for deaf or hard-of-hearing
/// users, add an FSL button so users can access Filipino Sign Language
/// versions of the content". It sits beside Replay, not behind a menu,
/// because for a Deaf learner it is the primary control on this sheet.
Future<void> showRoutineVideoSheet(
  BuildContext context, {
  required String url,
  required String title,
  required String cacheKey,
  required bool filipino,
  VoidCallback? onFsl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _RoutineVideoSheet(
      url: url,
      title: title,
      cacheKey: cacheKey,
      filipino: filipino,
      onFsl: onFsl,
    ),
  );
}

class _RoutineVideoSheet extends StatefulWidget {
  final String url;
  final String title;
  final String cacheKey;
  final bool filipino;
  final VoidCallback? onFsl;

  const _RoutineVideoSheet({
    required this.url,
    required this.title,
    required this.cacheKey,
    required this.filipino,
    this.onFsl,
  });

  @override
  State<_RoutineVideoSheet> createState() => _RoutineVideoSheetState();
}

class _RoutineVideoSheetState extends State<_RoutineVideoSheet> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final raw = widget.url.trim();
    VideoPlayerController? controller;
    try {
      if (RoutineMediaStore.isDeviceFile(raw)) {
        controller =
            VideoPlayerController.file(File(RoutineMediaStore.pathOf(raw)));
      } else if (isAssetMedia(raw)) {
        controller = VideoPlayerController.asset(assetPathOf(raw));
      } else {
        // Reuse the FSL resolver: it downloads once and replays from disk
        // afterwards, keyed by the step rather than the URL — so a routine
        // video keeps working offline and survives the URL being swapped for
        // a better recording later.
        final source = await FslAssetsService.videoSourceForUrl(
          raw,
          cacheKey: widget.cacheKey,
        );
        controller = source?.createController() ??
            VideoPlayerController.networkUrl(Uri.parse(raw));
      }
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.play();
      setState(() {
        _controller = controller;
        _initialized = true;
      });
    } on Object {
      await controller?.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = widget.filipino;
    final controller = _controller;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
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
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: hc.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: _initialized && controller != null
                      ? controller.value.aspectRatio
                      : 16 / 9,
                  child: _failed
                      ? Container(
                          color: hc.surfaceVariant,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            l
                                ? 'Hindi ma-load ang bidyo. Subukan muli kapag may internet.'
                                : 'This video could not be loaded. Try again when you are online.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                        )
                      : controller == null
                          ? Container(
                              color: hc.surfaceVariant,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(),
                            )
                          : GestureDetector(
                              onTap: () => setState(() {
                                controller.value.isPlaying
                                    ? controller.pause()
                                    : controller.play();
                              }),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  VideoPlayer(controller),
                                  if (!controller.value.isPlaying)
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 34,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (widget.onFsl != null)
                    // The FSL button, on the video itself.
                    FilledButton.icon(
                      onPressed: () {
                        controller?.pause();
                        widget.onFsl!();
                      },
                      icon: const Icon(Icons.sign_language_rounded),
                      label: Text(l ? 'FSL' : 'FSL'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondaryDark,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: controller == null
                        ? null
                        : () {
                            controller.seekTo(Duration.zero);
                            controller.play();
                            setState(() {});
                          },
                    icon: const Icon(Icons.replay_rounded),
                    label: Text(l ? 'Ulitin' : 'Replay'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(l ? 'Isara' : 'Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a photo or GIF full-width in a sheet, so a learner can look at it
/// properly rather than at a thumbnail.
Future<void> showRoutineImageSheet(
  BuildContext context, {
  required RoutineStep step,
  required RoutineMediaKind kind,
  required String title,
  required bool filipino,
}) {
  return showModalBottomSheet<void>(
    context: context,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      final hc = HCColor.of(context);
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
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
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hc.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                RoutineImage(
                  url: step.urlFor(kind),
                  kind: kind,
                  stepEmoji: RoutineCatalog.emojiFor(step),
                  filipino: filipino,
                  semanticLabel: title,
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                  label: Text(filipino ? 'Isara' : 'Close'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
