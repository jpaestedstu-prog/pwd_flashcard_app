import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/constants/app_constants.dart';

/// Opens the FSL fullscreen video player as a fullscreen dialog.
///
/// [videoFile] — cached on-device file resolved by `FslAssetsService.cachedFileFor`.
/// [wordEnglish] — primary subtitle label.
/// [wordFilipino] — optional secondary subtitle label.
/// [startPosition] — resume from this position (defaults to beginning).
///
/// Returns the playback position when the player is closed so callers can
/// sync their own controller.
Future<Duration?> openFslFullscreenPlayer(
  BuildContext context, {
  required File videoFile,
  required String wordEnglish,
  String wordFilipino = '',
  Duration? startPosition,
}) {
  return Navigator.of(context).push<Duration>(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          FslFullscreenPlayer(
        videoFile: videoFile,
        wordEnglish: wordEnglish,
        wordFilipino: wordFilipino,
        startPosition: startPosition,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: AppConstants.normalDuration,
      reverseTransitionDuration: AppConstants.fastDuration,
    ),
  );
}

/// A deaf-friendly fullscreen video player with portrait↔landscape rotation,
/// gesture controls, progress bar, auto-hiding controls, subtitle labels,
/// speed selector, and visual-only status cues.
class FslFullscreenPlayer extends StatefulWidget {
  final File videoFile;
  final String wordEnglish;
  final String wordFilipino;
  final Duration? startPosition;

  const FslFullscreenPlayer({
    super.key,
    required this.videoFile,
    required this.wordEnglish,
    this.wordFilipino = '',
    this.startPosition,
  });

  @override
  State<FslFullscreenPlayer> createState() => _FslFullscreenPlayerState();
}

class _FslFullscreenPlayerState extends State<FslFullscreenPlayer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;

  // Controls overlay
  bool _showControls = true;
  Timer? _hideControlsTimer;
  static const _controlsHideDelay = Duration(seconds: 3);

  // Subtitles / captions
  bool _showSubtitles = true;

  // Playback speed
  double _playbackSpeed = 1.0;
  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5];
  bool _showSpeedPanel = false;

  // Seek feedback overlay
  String? _seekFeedback; // e.g. "+5s" or "−5s"
  Timer? _seekFeedbackTimer;

  // Speed change feedback
  String? _speedFeedback;
  Timer? _speedFeedbackTimer;

  // Rotation hint (show once)
  bool _showRotationHint = true;

  // Orientation tracking
  bool _isLandscape = false;

  // Pinch-to-zoom
  final TransformationController _transformController =
      TransformationController();

  // Position listener for progress bar rebuild
  late VoidCallback _positionListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Unlock all orientations for this screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Immersive mode — hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller.setLooping(true);
        if (widget.startPosition != null) {
          _controller.seekTo(widget.startPosition!);
        }
        _controller.play();
        _startHideControlsTimer();
      }).catchError((_) {
        if (mounted) setState(() => _hasError = true);
      });

    _positionListener = () {
      if (mounted) setState(() {});
    };
    _controller.addListener(_positionListener);

    // Auto-dismiss rotation hint after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _showRotationHint = false);
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _speedFeedbackTimer?.cancel();
    _controller.removeListener(_positionListener);
    _controller.dispose();
    _transformController.dispose();
    WidgetsBinding.instance.removeObserver(this);

    // Re-lock to portrait & restore system UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Reset pinch-zoom on rotation
    _transformController.value = Matrix4.identity();
  }

  // ─── Controls visibility ─────────────────────────────

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(_controlsHideDelay, () {
      if (mounted && _controller.value.isPlaying) {
        setState(() {
          _showControls = false;
          _showSpeedPanel = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (!_showControls) _showSpeedPanel = false;
    });
    if (_showControls) _startHideControlsTimer();
  }

  // ─── Play / Pause ───────────────────────────────────

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
        _hideControlsTimer?.cancel();
      } else {
        _controller.play();
        _startHideControlsTimer();
      }
    });
  }

  // ─── Seek ───────────────────────────────────────────

  void _seekBy(Duration delta) {
    HapticFeedback.selectionClick();
    final current = _controller.value.position;
    final total = _controller.value.duration;
    var target = current + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > total) target = total;
    _controller.seekTo(target);

    // Show seek feedback
    final secs = delta.inSeconds;
    final label = secs > 0 ? '+${secs}s' : '${secs}s';
    setState(() => _seekFeedback = label);
    _seekFeedbackTimer?.cancel();
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _seekFeedback = null);
    });
    _startHideControlsTimer();
  }

  // ─── Speed ──────────────────────────────────────────

  void _setSpeed(double speed) {
    HapticFeedback.selectionClick();
    setState(() {
      _playbackSpeed = speed;
      _showSpeedPanel = false;
    });
    _controller.setPlaybackSpeed(speed);

    // Show speed feedback
    setState(() => _speedFeedback = '${speed}x');
    _speedFeedbackTimer?.cancel();
    _speedFeedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _speedFeedback = null);
    });
    _startHideControlsTimer();
  }

  // ─── Double-tap: force orientation toggle ───────────

  void _doubleTapRotate() {
    HapticFeedback.mediumImpact();
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      // Re-unlock after a moment so auto-rotate works again
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      });
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      });
    }
  }

  // ─── Replay ─────────────────────────────────────────

  void _replay() {
    HapticFeedback.lightImpact();
    _controller.seekTo(Duration.zero);
    _controller.play();
    _startHideControlsTimer();
  }

  // ─── Close ──────────────────────────────────────────

  void _close() {
    final pos = _controller.value.position;
    Navigator.of(context).pop(pos);
  }

  // ─── Swipe down (landscape → portrait) ──────────────

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isLandscape && details.velocity.pixelsPerSecond.dy > 200) {
      _doubleTapRotate(); // triggers portrait
    }
  }

  // ─── Swipe left/right to seek ───────────────────────

  void _onHorizontalDragEnd(DragEndDetails details) {
    final v = details.velocity.pixelsPerSecond.dx;
    if (v > 300) {
      _seekBy(const Duration(seconds: 5));
    } else if (v < -300) {
      _seekBy(const Duration(seconds: -5));
    }
  }

  // ─── Helpers ────────────────────────────────────────

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ─── Build ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        _isLandscape = orientation == Orientation.landscape;

        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: _toggleControls,
            onDoubleTap: _doubleTapRotate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            onVerticalDragEnd: _onVerticalDragEnd,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ─── Video ──────────────────────
                _buildVideoLayer(),

                // ─── Subtitle label ─────────────
                if (_showSubtitles) _buildSubtitles(),

                // ─── Controls overlay ───────────
                _buildControlsOverlay(),

                // ─── Seek feedback ──────────────
                if (_seekFeedback != null) _buildCenterFeedback(_seekFeedback!),

                // ─── Speed feedback ─────────────
                if (_speedFeedback != null)
                  _buildCenterFeedback(_speedFeedback!),

                // ─── Rotation hint ──────────────
                if (_showRotationHint && !_isLandscape) _buildRotationHint(),

                // ─── Buffering indicator ────────
                if (_initialized && _controller.value.isBuffering)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Video layer ────────────────────────────────────

  Widget _buildVideoLayer() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white54, size: 56),
            const SizedBox(height: 12),
            Text(
              'Unable to load video',
              style: AppTypography.bodyLarge.copyWith(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }

    return Center(
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 1.0,
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }

  // ─── Subtitles ──────────────────────────────────────

  Widget _buildSubtitles() {
    final screenWidth = MediaQuery.of(context).size.width;
    final primarySize = _isLandscape ? screenWidth * 0.03 : 18.0;
    final secondarySize = _isLandscape ? screenWidth * 0.022 : 14.0;
    final bottomPadding = _isLandscape ? 56.0 : 100.0;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomPadding,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.wordEnglish,
                style: AppTypography.titleLarge.copyWith(
                  color: Colors.white,
                  fontSize: primarySize,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.wordFilipino.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  widget.wordFilipino,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white70,
                    fontSize: secondarySize,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Controls overlay ───────────────────────────────

  Widget _buildControlsOverlay() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: AppConstants.fastDuration,
      child: IgnorePointer(
        ignoring: !_showControls,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.6),
              ],
              stops: const [0.0, 0.25, 0.7, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ─── Top bar ───────────────────
                _buildTopBar(),
                const Spacer(),
                // ─── Center play/pause ─────────
                _buildCenterPlayPause(),
                const Spacer(),
                // ─── Speed panel (expandable) ──
                if (_showSpeedPanel) _buildSpeedPanel(),
                // ─── Bottom bar (progress) ─────
                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Top bar ────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Close button
          Semantics(
            button: true,
            label: 'Close fullscreen video',
            child: IconButton(
              onPressed: _close,
              icon: const Icon(Icons.close_rounded),
              color: Colors.white,
              iconSize: 28,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black26,
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
          const Spacer(),
          // Captions toggle
          Semantics(
            button: true,
            label: _showSubtitles ? 'Hide captions' : 'Show captions',
            child: IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _showSubtitles = !_showSubtitles);
                _startHideControlsTimer();
              },
              icon: Icon(
                _showSubtitles
                    ? Icons.closed_caption_rounded
                    : Icons.closed_caption_disabled_rounded,
              ),
              color: Colors.white,
              iconSize: 26,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black26,
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Speed / settings
          Semantics(
            button: true,
            label: 'Playback speed settings',
            child: IconButton(
              onPressed: () {
                setState(() => _showSpeedPanel = !_showSpeedPanel);
                _startHideControlsTimer();
              },
              icon: const Icon(Icons.speed_rounded),
              color: Colors.white,
              iconSize: 26,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black26,
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Center play/pause ──────────────────────────────

  Widget _buildCenterPlayPause() {
    if (!_initialized) return const SizedBox.shrink();

    final isPlaying = _controller.value.isPlaying;
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Semantics(
        button: true,
        label: isPlaying ? 'Pause video' : 'Play video',
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.8),
              width: 3,
            ),
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 40,
          ),
        )
            .animate(
              target: isPlaying ? 0 : 1,
              onPlay: (controller) {
                if (!isPlaying) controller.repeat(reverse: true);
              },
              onComplete: (controller) {
                if (!isPlaying) controller.repeat(reverse: true);
              },
            )
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.08, 1.08),
              duration: 1200.ms,
              curve: Curves.easeInOut,
            ),
      ),
    );
  }

  // ─── Speed panel ────────────────────────────────────

  Widget _buildSpeedPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.speed_rounded, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          ..._speeds.map((speed) {
            final isActive = _playbackSpeed == speed;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Semantics(
                button: true,
                label: 'Set speed to ${speed}x',
                child: GestureDetector(
                  onTap: () => _setSpeed(speed),
                  child: AnimatedContainer(
                    duration: AppConstants.fastDuration,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${speed}x',
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 12,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.3, end: 0);
  }

  // ─── Bottom bar ─────────────────────────────────────

  Widget _buildBottomBar() {
    if (!_initialized) return const SizedBox(height: 48);

    final position = _controller.value.position;
    final duration = _controller.value.duration;
    final progress =
        duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        _isLandscape ? 8 : 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seek bar
          Row(
            children: [
              // Replay
              Semantics(
                button: true,
                label: 'Replay from beginning',
                child: IconButton(
                  onPressed: _replay,
                  icon: const Icon(Icons.replay_rounded),
                  color: Colors.white,
                  iconSize: 22,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ),
              // Play/pause (small, redundant — convenient in bottom bar)
              Semantics(
                button: true,
                label: _controller.value.isPlaying ? 'Pause' : 'Play',
                child: IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  color: Colors.white,
                  iconSize: 26,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Current time
              Text(
                _formatDuration(position),
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              // Progress bar
              Expanded(
                child: Semantics(
                  slider: true,
                  label: 'Video progress',
                  value:
                      '${(progress * 100).round()}%',
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: AppColors.primaryLight,
                      overlayColor: AppColors.primary.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: (value) {
                        final target = Duration(
                          milliseconds:
                              (value * duration.inMilliseconds).round(),
                        );
                        _controller.seekTo(target);
                      },
                      onChangeStart: (_) {
                        _hideControlsTimer?.cancel();
                      },
                      onChangeEnd: (_) {
                        _startHideControlsTimer();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Total time
              Text(
                _formatDuration(duration),
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              // Fullscreen exit / orientation toggle
              Semantics(
                button: true,
                label: _isLandscape
                    ? 'Switch to portrait'
                    : 'Switch to landscape',
                child: IconButton(
                  onPressed: _doubleTapRotate,
                  icon: Icon(
                    _isLandscape
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                  ),
                  color: Colors.white,
                  iconSize: 24,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Center feedback badge ──────────────────────────

  Widget _buildCenterFeedback(String text) {
    return Center(
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            style: AppTypography.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 150.ms)
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
      ),
    );
  }

  // ─── Rotation hint ──────────────────────────────────

  Widget _buildRotationHint() {
    return Positioned(
      bottom: 160,
      left: 0,
      right: 0,
      child: Center(
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.screen_rotation_rounded,
                    color: Colors.white70, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Rotate or double-tap for landscape',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .then(delay: 1500.ms)
              .fadeOut(duration: 600.ms),
        ),
      ),
    );
  }
}
