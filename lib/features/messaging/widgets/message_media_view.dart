import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/services/shared_media_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/messaging_models.dart';
import '../services/message_media.dart';

/// The inside of a photo or video bubble.
///
/// The file is fetched through [SharedMediaService.resolve] the first time
/// the bubble is shown (the sender already has it cached), then opened full
/// screen on tap: a photo to look at closely, a sign video to watch — and
/// replay, which is how a signed message is actually read.
class MessageMediaBody extends StatefulWidget {
  final LocalMessage message;
  final bool isFilipino;

  /// Test seam for [SharedMediaService.resolve].
  static Future<File?> Function(String value)? debugResolve;

  const MessageMediaBody({
    super.key,
    required this.message,
    required this.isFilipino,
  });

  @override
  State<MessageMediaBody> createState() => _MessageMediaBodyState();
}

class _MessageMediaBodyState extends State<MessageMediaBody> {
  late Future<File?> _file;

  bool get _isVideo => widget.message.type == MessageType.video;

  @override
  void initState() {
    super.initState();
    _file = _resolve();
  }

  Future<File?> _resolve() {
    final value = widget.message.content;
    return (MessageMediaBody.debugResolve ?? const SharedMediaService().resolve)(
      value,
    );
  }

  void _retry() => setState(() => _file = _resolve());

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final fil = widget.isFilipino;
    final caption = widget.message.caption?.trim() ?? '';

    Widget frame(Widget child) => ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: 200, height: 150, child: child),
    );

    Widget note(IconData icon, String text, {VoidCallback? onTap}) => frame(
      Material(
        color: hc.surface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: hc.textSecondary),
                const SizedBox(height: 6),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelSmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final Widget media;
    if (MessageMedia.isExpired(widget.message)) {
      media = note(
        Icons.hourglass_bottom_rounded,
        _isVideo
            ? (fil
                  ? 'Nag-expire na ang video na ito pagkalipas ng isang linggo.'
                  : 'This video expired after a week.')
            : (fil
                  ? 'Nag-expire na ang larawang ito pagkalipas ng isang linggo.'
                  : 'This photo expired after a week.'),
      );
    } else {
      media = FutureBuilder<File?>(
        future: _file,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return frame(
              ColoredBox(
                color: hc.surface,
                child: const Center(child: CircularProgressIndicator()),
              ),
            );
          }
          final file = snap.data;
          if (file == null) {
            return Semantics(
              button: true,
              onTap: _retry,
              child: note(
                Icons.cloud_off_rounded,
                fil
                    ? 'Hindi pa ito makuha. Pindutin para subukan ulit.'
                    : "Can't load it yet. Tap to try again.",
                onTap: _retry,
              ),
            );
          }
          if (_isVideo) {
            void play() => showMessageVideoPlayer(
              context,
              file: file,
              isFilipino: fil,
              caption: caption,
            );
            // The tap action lives on this node: `excludeSemantics` drops the
            // InkWell's own, and a screen-reader user double-tapping a label
            // with no action got nothing.
            return Semantics(
              button: true,
              label: fil ? 'I-play ang video' : 'Play the video',
              onTap: play,
              excludeSemantics: true,
              child: frame(
                Material(
                  color: Colors.black,
                  child: InkWell(
                    onTap: play,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 56,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          fil ? 'Pindutin para panoorin' : 'Tap to watch',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          void look() =>
              showMessagePhotoViewer(context, file: file, isFilipino: fil);
          return Semantics(
            button: true,
            label: fil ? 'Tingnan ang larawan' : 'Look at the photo',
            onTap: look,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: look,
              child: frame(
                Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: hc.surface,
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: hc.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        media,
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            caption,
            style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
          ),
        ],
      ],
    );
  }
}

/// A photo, full screen, pinch-to-zoom.
Future<void> showMessagePhotoViewer(
  BuildContext context, {
  required File file,
  required bool isFilipino,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(child: Image.file(file)),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                tooltip: isFilipino ? 'Isara' : 'Close',
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A sign video, playing on a loop, with Replay and Close as big buttons.
Future<void> showMessageVideoPlayer(
  BuildContext context, {
  required File file,
  required bool isFilipino,
  String caption = '',
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _VideoPlayerDialog(file: file, isFilipino: isFilipino, caption: caption),
  );
}

class _VideoPlayerDialog extends StatefulWidget {
  final File file;
  final bool isFilipino;
  final String caption;

  const _VideoPlayerDialog({
    required this.file,
    required this.isFilipino,
    required this.caption,
  });

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file);
    _start();
  }

  Future<void> _start() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.play();
    } on Object {
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final fil = widget.isFilipino;
    final ready = _controller.value.isInitialized;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Colors.black,
                child: AspectRatio(
                  aspectRatio: ready ? _controller.value.aspectRatio : 3 / 4,
                  child: _failed
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              fil
                                  ? 'Hindi ma-play ang video na ito.'
                                  : 'This video would not play.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : ready
                      ? VideoPlayer(_controller)
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            if (widget.caption.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                widget.caption,
                style: AppTypography.bodyLarge.copyWith(color: hc.textPrimary),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: ready
                      ? () {
                          _controller.seekTo(Duration.zero);
                          _controller.play();
                        }
                      : null,
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(fil ? 'Ulitin' : 'Replay'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: hc.fillFor(AppColors.primary),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(fil ? 'Isara' : 'Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
