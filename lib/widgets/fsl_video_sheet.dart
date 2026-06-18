import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/services/fsl_assets_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/responsive_utils.dart';
import '../l10n/app_localizations.dart';
import 'app_action_bar.dart';
import 'fsl_fullscreen_player.dart';
import 'shimmer_loading.dart';

/// Presents the FSL sign-language clip for [wordEnglish] in a modal bottom
/// sheet with an inline, looping video player (speed selector, replay, close,
/// and a fullscreen button).
///
/// This is the single shared entry point for "watch this in Filipino Sign
/// Language" across the app — Flashcards → Cards and Stories both call it so
/// the two surfaces behave identically. The sheet owns the player lifecycle;
/// callers only resolve a [VideoSource] (e.g. via
/// [FslAssetsService.videoSourceFor] or [FslAssetsService.videoSourceForUrl])
/// and hand it over.
///
/// [wordFilipino] is optional; when supplied it is forwarded to the fullscreen
/// player so its subtitle shows both languages (Flashcards pass English only,
/// Stories pass both — neither changes this sheet's own layout).
Future<void> showFslVideoSheet(
  BuildContext context, {
  required VideoSource videoSource,
  required String wordEnglish,
  String wordFilipino = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => FslVideoSheet(
      videoSource: videoSource,
      wordEnglish: wordEnglish,
      wordFilipino: wordFilipino,
    ),
  );
}

/// Shows the friendly "no FSL video available yet" bottom sheet for
/// [wordEnglish]. Shared by every surface that can fail to resolve a clip so
/// the unavailable path looks the same everywhere (a SnackBar would be easy to
/// miss for Deaf / hard-of-hearing learners relying on the visual signing path).
Future<void> showFslUnavailableSheet(
  BuildContext context, {
  required String wordEnglish,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    // Scroll-controlled so the sheet isn't clamped to ~9/16 of the screen,
    // which would clip its content on short phones and at large font scales.
    isScrollControlled: true,
    builder: (context) => _FslUnavailableSheet(wordEnglish: wordEnglish),
  );
}

// ─── FSL Video Bottom Sheet ───────────────────────────
class FslVideoSheet extends StatefulWidget {
  final VideoSource videoSource;
  final String wordEnglish;
  final String wordFilipino;

  const FslVideoSheet({
    super.key,
    required this.videoSource,
    required this.wordEnglish,
    this.wordFilipino = '',
  });

  @override
  State<FslVideoSheet> createState() => _FslVideoSheetState();
}

class _FslVideoSheetState extends State<FslVideoSheet> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  double _playbackSpeed = 1.0;

  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5];

  @override
  void initState() {
    super.initState();
    _controller = widget.videoSource.createController()
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() => _initialized = true);
              _controller.setLooping(true);
              _controller.play();
            }
          })
          .catchError((_) {
            if (mounted) setState(() => _hasError = true);
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
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
          // Drag handle
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: hc.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sign_language_rounded,
                color: AppColors.secondaryDark,
                size: context.scaleIcon(24),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'FSL — ${widget.wordEnglish}',
                  style: AppTypography.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Video player
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: _initialized
                  ? _controller.value.aspectRatio
                  : 16 / 9,
              child: _hasError
                  ? Container(
                      color: AppColors.surfaceVariant,
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.unableToLoadVideo,
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : _initialized
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        });
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(_controller),
                          if (!_controller.value.isPlaying)
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: context.scaleIcon(36),
                              ),
                            ),
                          // Fullscreen button
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: GestureDetector(
                              onTap: () async {
                                final wasPlaying = _controller.value.isPlaying;
                                final pos = _controller.value.position;
                                _controller.pause();
                                final returnPos = await openFslFullscreenPlayer(
                                  context,
                                  videoSource: widget.videoSource,
                                  wordEnglish: widget.wordEnglish,
                                  wordFilipino: widget.wordFilipino,
                                  startPosition: pos,
                                );
                                if (returnPos != null && mounted) {
                                  _controller.seekTo(returnPos);
                                }
                                if (wasPlaying && mounted) {
                                  _controller.play();
                                }
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.fullscreen_rounded,
                                  color: Colors.white,
                                  size: context.scaleIcon(22),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      color: AppColors.surfaceVariant,
                      child: ShimmerLoading(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_circle_outline_rounded,
                                size: context.scaleIcon(48),
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 8),
                              const ShimmerBox(width: 100, height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Playback speed selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.speed_rounded,
                size: context.scaleIcon(18),
                color: hc.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.speed,
                style: AppTypography.labelSmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              ..._speeds.map((speed) {
                final isActive = _playbackSpeed == speed;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _playbackSpeed = speed);
                      _controller.setPlaybackSpeed(speed);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.secondary
                            : hc.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${speed}x',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive ? Colors.white : hc.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          // Replay & Close — equal-width cells that stack on a narrow width
          // (or XL font scale) instead of overflowing horizontally.
          AppActionBar(
            equalWidth: true,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  _controller.seekTo(Duration.zero);
                  _controller.play();
                },
                icon: const Icon(Icons.replay_rounded),
                label: Text(AppLocalizations.of(context)!.replay),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.close),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── "No FSL video yet" Bottom Sheet ──────────────────
class _FslUnavailableSheet extends StatelessWidget {
  final String wordEnglish;

  const _FslUnavailableSheet({required this.wordEnglish});

  @override
  Widget build(BuildContext context) {
    // SafeArea + scroll wrapper keeps the sheet usable at any font scale /
    // device height: it sizes to its content and only scrolls if the content
    // would otherwise be taller than the screen (e.g. XL accessibility fonts
    // on a small phone), so nothing is ever clipped.
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: HCColor.of(context).surface,
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
                  color: HCColor.of(
                    context,
                  ).textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.secondaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sign_language_rounded,
                  size: context.scaleIcon(40),
                  color: AppColors.secondaryDark,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.filipinoSignLanguage,
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'No FSL video available yet for "$wordEnglish".',
                style: AppTypography.bodyMedium.copyWith(
                  color: HCColor.of(context).textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.gotIt),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
