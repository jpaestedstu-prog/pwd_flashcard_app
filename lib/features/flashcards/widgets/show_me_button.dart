import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/services/action_clip_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/models.dart';
import 'media_sheet_layout.dart';

/// "Show Me" — opens a short looping clip of the vocabulary word in motion.
/// Visual demonstrations are far clearer than written text, especially for
/// action words like *run*, *clap*, or *jump*.
///
/// Clips are resolved (downloaded + cached) on demand by [ActionClipService];
/// MP4 plays as a looping video and GIF as a looping image.
Future<void> showActionClipSheet(BuildContext context, Flashcard card) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    // Let the sheet grow taller than the default half-screen cap and manage its
    // own height; [MediaSheetLayout] keeps it within 92% of the screen and
    // scrolls if needed, so landscape never overflows.
    isScrollControlled: true,
    builder: (_) => _ShowMeSheet(card: card),
  );
}

/// A compact pill that launches the "Show Me" clip. Renders nothing when no
/// clip source is configured for [card], so it's safe to drop in unconditionally.
class ShowMeButton extends StatelessWidget {
  final Flashcard card;
  final EdgeInsetsGeometry padding;

  const ShowMeButton({
    super.key,
    required this.card,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    if (!ActionClipService.hasClip(card)) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: 'Show me ${card.wordEnglish}',
      child: Material(
        color: AppColors.secondary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => showActionClipSheet(context, card),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_circle_fill_rounded,
                  size: context.scaleIcon(20),
                  color: AppColors.secondaryDark,
                ),
                const SizedBox(width: 6),
                Text(
                  'Show Me',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.secondaryDark,
                    fontWeight: FontWeight.w700,
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

class _ShowMeSheet extends StatefulWidget {
  final Flashcard card;
  const _ShowMeSheet({required this.card});

  @override
  State<_ShowMeSheet> createState() => _ShowMeSheetState();
}

class _ShowMeSheetState extends State<_ShowMeSheet> {
  VideoPlayerController? _controller;
  ActionClip? _clip;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    await ActionClipService.load();
    final clip = await ActionClipService.resolveClip(widget.card);
    if (!mounted) return;

    if (clip == null) {
      setState(() {
        _loading = false;
        _error = true;
      });
      return;
    }

    if (clip.isGif) {
      // Animated GIF — Image.file loops it on its own.
      setState(() {
        _clip = clip;
        _loading = false;
      });
      return;
    }

    final controller = VideoPlayerController.file(clip.file);
    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.setLooping(true);
      controller.play();
      setState(() {
        _clip = clip;
        _controller = controller;
        _loading = false;
      });
    } catch (_) {
      controller.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MediaSheetLayout(
      icon: Icons.smart_display_rounded,
      title: 'Show Me — ${widget.card.wordEnglish}',
      caption: widget.card.definition ?? widget.card.exampleSentence,
      mediaBuilder: (_) => _buildMedia(context),
    );
  }

  Widget _buildMedia(BuildContext context) {
    final hc = HCColor.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error || _clip == null) {
      return Center(
        child: Text(
          "This clip isn't available right now.",
          style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    final clip = _clip!;
    if (clip.isGif) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          clip.file,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
    }

    final controller = _controller!;
    final aspect = controller.value.aspectRatio == 0
        ? 1.0
        : controller.value.aspectRatio;
    return Center(
      child: AspectRatio(
        aspectRatio: aspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GestureDetector(
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
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
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
