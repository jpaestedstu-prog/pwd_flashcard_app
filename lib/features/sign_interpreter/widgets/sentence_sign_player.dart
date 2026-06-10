import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/sign_interpreter_models.dart';

/// Plays a glossed sentence as a sequence of FSL videos with captions.
///
/// Matched items play their sign video; unmatched items (and matched items
/// whose download failed) show a short "no sign yet" placeholder card so the
/// sentence rhythm is preserved. All matched videos are resolved up front —
/// with a per-word progress indicator — so playback never stalls mid-sentence
/// on a download.
///
/// Reusable beyond the interpreter screen: stories or flashcards can hand it
/// any word list glossed via SignGlossService.
class SentenceSignPlayer extends StatefulWidget {
  final List<SignPlayItem> items;
  final VoidCallback? onFinished;

  const SentenceSignPlayer({super.key, required this.items, this.onFinished});

  @override
  State<SentenceSignPlayer> createState() => _SentenceSignPlayerState();
}

class _SentenceSignPlayerState extends State<SentenceSignPlayer> {
  /// item index → resolved source (matched items only; absent = failed).
  final Map<int, VideoSource> _sources = {};

  bool _preparing = true;
  int _resolvedCount = 0;

  int _currentIndex = 0;
  bool _finished = false;
  bool _paused = false;

  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _advancedFromCurrent = false;

  Timer? _placeholderTimer;
  double _playbackSpeed = 1.0;
  static const _speeds = [0.5, 0.75, 1.0];
  static const _placeholderDuration = Duration(milliseconds: 1600);

  int get _matchedTotal => widget.items.where((i) => i.isMatched).length;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(SentenceSignPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      _disposePlayback();
      _sources.clear();
      _resolvedCount = 0;
      _currentIndex = 0;
      _finished = false;
      _paused = false;
      _preparing = true;
      _prepare();
    }
  }

  @override
  void dispose() {
    _disposePlayback();
    super.dispose();
  }

  void _disposePlayback() {
    _placeholderTimer?.cancel();
    _placeholderTimer = null;
    _controller?.dispose();
    _controller = null;
    _videoReady = false;
  }

  // ─── Preparation (resolve all videos up front) ────────

  Future<void> _prepare() async {
    final items = widget.items;
    for (var i = 0; i < items.length; i++) {
      final entry = items[i].entry;
      if (entry == null) continue;
      try {
        final source = await FslAssetsService.videoSourceForEntry(entry);
        if (!mounted || !identical(items, widget.items)) return;
        if (source != null) _sources[i] = source;
      } catch (_) {
        // Treated as a placeholder during playback.
      }
      if (!mounted || !identical(items, widget.items)) return;
      setState(() => _resolvedCount++);
    }
    if (!mounted) return;
    setState(() => _preparing = false);
    if (widget.items.isNotEmpty) _playIndex(0);
  }

  // ─── Playback sequencing ──────────────────────────────

  void _playIndex(int index) {
    _disposePlayback();
    setState(() {
      _currentIndex = index;
      _finished = false;
      _paused = false;
      _advancedFromCurrent = false;
    });

    final source = _sources[index];
    if (source == null) {
      _startPlaceholderTimer();
      return;
    }

    final controller = source.createController();
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted || _controller != controller) return;
      controller.setLooping(false);
      controller.setPlaybackSpeed(_playbackSpeed);
      controller.addListener(_onVideoTick);
      setState(() => _videoReady = true);
      controller.play();
    }).catchError((_) {
      if (!mounted || _controller != controller) return;
      // Failed late — fall back to the placeholder card.
      _controller = null;
      controller.dispose();
      _startPlaceholderTimer();
      setState(() {});
    });
  }

  void _onVideoTick() {
    final controller = _controller;
    if (controller == null || _advancedFromCurrent) return;
    final value = controller.value;
    if (value.duration > Duration.zero &&
        !value.isPlaying &&
        value.position >= value.duration) {
      _advancedFromCurrent = true;
      _advance();
    }
  }

  void _startPlaceholderTimer() {
    _placeholderTimer?.cancel();
    _placeholderTimer = Timer(_placeholderDuration, () {
      if (mounted && !_paused) _advance();
    });
  }

  void _advance() {
    final next = _currentIndex + 1;
    if (next < widget.items.length) {
      _playIndex(next);
    } else {
      _disposePlayback();
      setState(() => _finished = true);
      widget.onFinished?.call();
    }
  }

  void _togglePause() {
    if (_finished) {
      _playIndex(0);
      return;
    }
    setState(() => _paused = !_paused);
    final controller = _controller;
    if (controller != null) {
      _paused ? controller.pause() : controller.play();
    } else if (!_paused) {
      _startPlaceholderTimer();
    } else {
      _placeholderTimer?.cancel();
    }
  }

  void _setSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _controller?.setPlaybackSpeed(speed);
  }

  // ─── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final hc = HCColor.of(context);

    if (_preparing) {
      return _buildPreparing(hc);
    }

    final item = widget.items[_currentIndex];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── Stage: video or placeholder ───────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            color: Colors.black,
            constraints: const BoxConstraints(maxHeight: 300),
            width: double.infinity,
            child: _finished
                ? _buildFinished()
                : _sources.containsKey(_currentIndex) && _controller != null
                    ? _buildVideo()
                    : _buildPlaceholder(item),
          ),
        ),
        const SizedBox(height: 10),

        // ─── Caption ───────────────────────────────────
        if (!_finished) ...[
          Text(
            item.displayEnglish,
            style: AppTypography.headlineSmall.copyWith(
              color: hc.textPrimary,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          if (item.displayFilipino.isNotEmpty)
            Text(
              item.displayFilipino,
              style: AppTypography.bodyMedium.copyWith(
                color: hc.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8),
        ],

        // ─── Word chips (tap to jump) ──────────────────
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) => _buildWordChip(i, hc),
          ),
        ),
        const SizedBox(height: 8),

        // ─── Controls ──────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed:
                  _currentIndex > 0 ? () => _playIndex(_currentIndex - 1) : null,
              icon: const Icon(Icons.skip_previous_rounded),
              iconSize: 30,
              tooltip: 'Previous word',
            ),
            const SizedBox(width: 4),
            Semantics(
              button: true,
              label: _finished
                  ? 'Replay sentence'
                  : _paused
                      ? 'Resume'
                      : 'Pause',
              child: FilledButton(
                onPressed: _togglePause,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                ),
                child: Icon(
                  _finished
                      ? Icons.replay_rounded
                      : _paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _currentIndex < widget.items.length - 1 && !_finished
                  ? _advance
                  : null,
              icon: const Icon(Icons.skip_next_rounded),
              iconSize: 30,
              tooltip: 'Next word',
            ),
            const SizedBox(width: 12),
            ..._speeds.map((speed) {
              final active = _playbackSpeed == speed;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: Text('${speed}x'),
                  selected: active,
                  onSelected: (_) => _setSpeed(speed),
                  labelStyle: AppTypography.labelSmall.copyWith(
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildPreparing(HCColor hc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(
            'Getting signs ready… $_resolvedCount / $_matchedTotal',
            style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildVideo() {
    final controller = _controller!;
    if (!_videoReady) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );
  }

  Widget _buildPlaceholder(SignPlayItem item) {
    return SizedBox(
      height: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✋', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 8),
          Text(
            item.displayEnglish,
            style: AppTypography.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            item.isMatched ? 'Video unavailable' : 'No sign for this word yet',
            style: AppTypography.bodySmall.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildFinished() {
    return SizedBox(
      height: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 8),
          Text(
            'All done!',
            style: AppTypography.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap replay to watch again',
            style: AppTypography.bodySmall.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildWordChip(int i, HCColor hc) {
    final item = widget.items[i];
    final isCurrent = i == _currentIndex && !_finished;
    final color = item.isMatched ? AppColors.success : hc.textSecondary;
    return Semantics(
      button: true,
      label: 'Play sign for ${item.displayEnglish}',
      child: GestureDetector(
        onTap: () => _playIndex(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isCurrent
                ? color.withValues(alpha: 0.25)
                : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCurrent ? color : color.withValues(alpha: 0.3),
              width: isCurrent ? 2 : 1,
            ),
          ),
          child: Text(
            item.displayEnglish,
            style: AppTypography.labelMedium.copyWith(
              color: hc.textPrimary,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
