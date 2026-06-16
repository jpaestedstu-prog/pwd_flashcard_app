import 'package:flutter/material.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../widgets/fsl_fullscreen_player.dart';

/// A self-contained "watch in Filipino Sign Language" control for the Stories
/// feature.
///
/// Tapping it resolves [pageUrl] (a Streamable share page) to a cached video
/// via [FslAssetsService.videoSourceForUrl] and opens the fullscreen FSL
/// player. It owns its own loading state, so it can be dropped into a story
/// page or a quiz option row without the parent screen coordinating a loading
/// overlay. A failed/unavailable clip surfaces as a SnackBar and leaves the
/// rest of the screen fully usable.
///
/// Crucially this is **independent of the Text-to-Speech setting**: Deaf and
/// hard-of-hearing learners typically run with TTS off, yet still need the
/// sign-language path — so callers must NOT gate this button on `ttsEnabled`.
///
/// Two shapes:
///   • [compact] = false → a labelled "Watch in FSL" chip, for a story page or
///     a quiz question prompt.
///   • [compact] = true  → a single sign-language icon button, sized to sit at
///     the trailing edge of a quiz answer-option row without crowding it.
class StoryFslButton extends StatefulWidget {
  /// Streamable (or other) share-page URL for the sign-language clip.
  final String pageUrl;

  /// Stable, unique on-disk cache key for this clip (e.g.
  /// `story_s_a01_q0_o1`). Lets the resolved file survive Streamable URL
  /// rotations and replay offline.
  final String cacheKey;

  /// Primary caption shown over the video (the sentence / question / option
  /// text the clip signs).
  final String label;

  /// Optional secondary caption (e.g. the other language).
  final String secondaryLabel;

  /// Accent colour — usually the story category colour.
  final Color color;

  /// Icon-only trailing button (true) vs. a full labelled chip (false).
  final bool compact;

  const StoryFslButton({
    super.key,
    required this.pageUrl,
    required this.cacheKey,
    required this.label,
    this.secondaryLabel = '',
    required this.color,
    this.compact = false,
  });

  @override
  State<StoryFslButton> createState() => _StoryFslButtonState();
}

class _StoryFslButtonState extends State<StoryFslButton> {
  bool _loading = false;

  Future<void> _play() async {
    // Guard against double taps queuing two downloads / stacked players.
    if (_loading) return;
    setState(() => _loading = true);

    VideoSource? source;
    try {
      source = await FslAssetsService.videoSourceForUrl(
        widget.pageUrl,
        cacheKey: widget.cacheKey,
      );
    } catch (_) {
      source = null;
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (source == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'FSL video is unavailable right now. Please check your '
            'connection and try again.',
          ),
        ),
      );
      return;
    }

    await openFslFullscreenPlayer(
      context,
      videoSource: source,
      wordEnglish: widget.label,
      wordFilipino: widget.secondaryLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Semantics(
        button: true,
        label: 'Watch this choice in Filipino Sign Language',
        child: IconButton(
          onPressed: _loading ? null : _play,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          color: widget.color,
          tooltip: 'Watch in FSL',
          iconSize: context.scaleIcon(22),
          icon: _loading
              ? SizedBox(
                  width: context.scaleIcon(18),
                  height: context.scaleIcon(18),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                  ),
                )
              : const Icon(Icons.sign_language_rounded),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Watch in Filipino Sign Language',
      child: ExcludeSemantics(
        child: OutlinedButton.icon(
          onPressed: _loading ? null : _play,
          icon: _loading
              ? SizedBox(
                  width: context.scaleIcon(20),
                  height: context.scaleIcon(20),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                  ),
                )
              : Icon(Icons.sign_language_rounded, size: context.scaleIcon(22)),
          label: Text(
            'Watch in FSL',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMedium.copyWith(
              color: widget.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.color,
            side: BorderSide(
              color: widget.color.withValues(alpha: 0.6),
              width: 1.5,
            ),
            // 56dp floor keeps the target above the 48dp accessibility minimum
            // and matches the LanguageReplayBar buttons it sits beside.
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
