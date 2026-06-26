import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/accessibility/haptic_service.dart';
import '../../../core/accessibility/sound_service.dart';
import '../../../core/services/celebration_service.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/accessible_celebration_overlay.dart';
import '../../../widgets/game_widgets.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../games/widgets/fsl_empty_state.dart';
import '../../gaze_control/providers/gaze_camera_owners.dart';

/// Lifecycle of the front camera used for the practice mirror.
enum _CamStatus { initializing, ready, noCamera, permissionDenied, failed }

/// FSL "Sign It!" — production-practice mode.
///
/// Unlike the Sign→Word / Word→Sign games (which test *recognition*), this
/// mode practises *production*: the learner watches a reference FSL sign and
/// copies it in a live front-camera mirror, then self-assesses ("I got it" /
/// "Not yet"). There is no automatic sign recognition — the project bundles no
/// hand/pose model — so grading is honest self-report, optionally verified by
/// an educator later. The camera is optional: if it is unavailable or the
/// permission is denied, the learner can still watch and practise from the
/// reference video alone.
class SignItScreen extends ConsumerStatefulWidget {
  final List<FlashcardCategory> categories;

  /// Camera enumerator — injectable so widget tests can supply fakes; the real
  /// camera needs platform channels.
  final Future<List<CameraDescription>> Function() camerasLoader;

  const SignItScreen({
    super.key,
    this.categories = const [],
    this.camerasLoader = availableCameras,
  });

  @override
  ConsumerState<SignItScreen> createState() => _SignItScreenState();
}

class _SignItScreenState extends ConsumerState<SignItScreen>
    with WidgetsBindingObserver {
  static const int _maxRounds = 10;

  final _random = Random();
  List<Flashcard> _cards = const [];
  int _currentRound = 0;
  int _gotItCount = 0;
  bool _loading = true;
  bool _showResult = false;

  // Reference sign video.
  VideoPlayerController? _videoController;
  bool _videoReady = false;

  // Practice mirror camera (preview only in this phase — no recording).
  CameraController? _cameraController;
  _CamStatus _camStatus = _CamStatus.initializing;
  bool _camInitInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // One camera at a time: stand the background nav-gaze camera down while
    // the practice mirror is open (mirrors Word Hunt / gaze control).
    gazeCameraOwners.acquire();
    _initCards();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.dispose();
    _cameraController?.dispose();
    gazeCameraOwners.release();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _cameraController;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _videoController?.pause();
      // Only tear down a fully-initialized controller — disposing one mid
      // initialize (the permission dialog itself sends `inactive`) crashes the
      // plugin. See the same guard in Word Hunt.
      if (cam != null && cam.value.isInitialized) {
        cam.dispose();
        _cameraController = null;
        _camStatus = _CamStatus.initializing;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_videoReady) _videoController?.play();
      if (_cameraController == null &&
          !_camInitInFlight &&
          _camStatus != _CamStatus.noCamera) {
        _initCamera();
      }
    }
  }

  // ─── Setup ─────────────────────────────────────────────

  Future<void> _initCards() async {
    final availability = await FslAssetsService.load();
    var source = List.of(availability.cardsWithVideo);
    if (widget.categories.isNotEmpty) {
      source =
          source.where((c) => widget.categories.contains(c.category)).toList();
    }
    if (source.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    source.shuffle(_random);
    _cards = source.take(_maxRounds).toList();
    await _prepareVideo();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _prepareVideo() async {
    _videoController?.dispose();
    _videoController = null;
    _videoReady = false;
    if (_currentRound >= _cards.length) return;

    final card = _cards[_currentRound];
    // Log the reference-sign view for progress/analytics, same as the other
    // FSL surfaces.
    final profile = ref.read(profileProvider);
    if (profile != null) {
      HiveService.recordFslVideoView(
        profile.id,
        card.category.label,
        card.wordEnglish,
      );
    }

    final source = await FslAssetsService.videoSourceFor(card);
    if (source == null) {
      if (mounted) setState(() => _videoReady = false);
      return;
    }
    final controller = source.createController();
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted || !identical(_videoController, controller)) return;
      controller.setLooping(true);
      controller.play();
      setState(() => _videoReady = true);
    } catch (_) {
      if (mounted) setState(() => _videoReady = false);
    }
  }

  Future<void> _initCamera() async {
    if (_camInitInFlight) return;
    _camInitInFlight = true;
    try {
      List<CameraDescription> cameras;
      try {
        cameras = await widget.camerasLoader();
      } on CameraException {
        cameras = const [];
      }
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _camStatus = _CamStatus.noCamera);
        return;
      }
      // Front lens for a self-mirror; fall back to whatever exists.
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _cameraController = controller;
      try {
        await controller.initialize();
        if (!mounted || !identical(_cameraController, controller)) return;
        setState(() => _camStatus = _CamStatus.ready);
      } on CameraException catch (e) {
        if (!identical(_cameraController, controller)) return;
        _cameraController = null;
        controller.dispose();
        if (!mounted) return;
        setState(() => _camStatus = e.code.startsWith('CameraAccess')
            ? _CamStatus.permissionDenied
            : _CamStatus.failed);
      } catch (_) {
        if (!identical(_cameraController, controller)) return;
        _cameraController = null;
        controller.dispose();
        if (!mounted) return;
        setState(() => _camStatus = _CamStatus.failed);
      }
    } finally {
      _camInitInFlight = false;
    }
  }

  // ─── Flow ──────────────────────────────────────────────

  void _replay() {
    final c = _videoController;
    if (c != null && c.value.isInitialized) {
      c.seekTo(Duration.zero);
      c.play();
    }
    ref.read(hapticServiceProvider).lightTap();
  }

  void _confirm(bool gotIt) {
    if (gotIt) {
      _gotItCount++;
      ref.read(soundServiceProvider).playCorrect();
      ref.read(hapticServiceProvider).success();
    } else {
      ref.read(hapticServiceProvider).lightTap();
    }
    if (_currentRound < _cards.length - 1) {
      setState(() {
        _currentRound++;
        _videoReady = false;
      });
      _prepareVideo();
    } else {
      _saveProgress();
      AccessibleCelebrationOverlay.show(
        context: context,
        ref: ref,
        type: CelebrationType.gameComplete,
      );
      setState(() => _showResult = true);
    }
  }

  int get _rounds => _cards.length;

  int get _starsEarned {
    if (_rounds == 0) return 0;
    final pct = _gotItCount / _rounds;
    if (pct >= 0.9) return 3;
    if (pct >= 0.7) return 2;
    if (pct >= 0.5) return 1;
    return 0;
  }

  void _saveProgress() {
    final categories = _cards.map((c) => c.category).toSet().toList();
    ref.read(progressProvider.notifier).recordGameResult(
          gameType: GameType.fslPractice,
          score: _gotItCount,
          total: _rounds,
          starsEarned: _starsEarned,
          categoriesPlayed: categories,
        );
  }

  void _restart() {
    setState(() {
      _currentRound = 0;
      _gotItCount = 0;
      _showResult = false;
      _videoReady = false;
      _cards = List.of(_cards)..shuffle(_random);
    });
    _prepareVideo();
  }

  void _exit() => context.go('/games/fsl-practice');

  // ─── UI ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: _exit,
          ),
          title: const Text('Sign It!'),
        ),
        body: const ShimmerPageSkeleton(),
      );
    }

    if (_cards.isEmpty) {
      return FslEmptyStateScaffold(title: 'Sign It!', onClose: _exit);
    }

    if (_showResult) {
      return CelebrationOverlay(
        show: true,
        child: Scaffold(
          body: Center(
            child: GameResultDialog(
              score: _gotItCount,
              total: _rounds,
              starsEarned: _starsEarned,
              footnote: 'Self-assessed signs',
              onPlayAgain: _restart,
              onExit: _exit,
            ),
          ),
        ),
      );
    }

    final card = _cards[_currentRound];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: _exit,
        ),
        title: Text('Sign It!  •  ${_currentRound + 1}/$_rounds'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 20, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text('$_gotItCount',
                        style: AppTypography.labelLarge
                            .copyWith(color: AppColors.success)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Progress
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentRound + 1) / _rounds,
                  minHeight: 6,
                  backgroundColor:
                      AppColors.primaryLight.withValues(alpha: 0.3),
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),

              // Word prompt
              _WordPrompt(card: card),
              const SizedBox(height: 12),

              // Split: reference video + live mirror. Side-by-side in
              // landscape / on wide screens, stacked in portrait.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > constraints.maxHeight;
                    final reference = _ReferencePanel(
                      controller: _videoController,
                      ready: _videoReady,
                      onReplay: _replay,
                    );
                    final mirror = _MirrorPanel(
                      status: _camStatus,
                      controller: _cameraController,
                    );
                    final children = [
                      Expanded(child: reference),
                      SizedBox(width: wide ? 12 : 0, height: wide ? 0 : 12),
                      Expanded(child: mirror),
                    ];
                    return wide
                        ? Row(children: children)
                        : Column(children: children);
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Self-assessment controls
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirm(false),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Not yet'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => _confirm(true),
                      icon: const Icon(Icons.thumb_up_rounded),
                      label: const Text('I got it!'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.success,
                      ),
                    ),
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

/// The target word, shown bilingually above the practice panels.
class _WordPrompt extends StatelessWidget {
  const _WordPrompt({required this.card});
  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Semantics(
      header: true,
      label: 'Sign this word: ${card.wordEnglish}, ${card.wordFilipino}',
      child: Column(
        children: [
          Text(
            'Watch, then sign it back!',
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              card.wordEnglish,
              style: AppTypography.headlineSmall
                  .copyWith(fontWeight: FontWeight.w800, color: hc.textPrimary),
            ),
          ),
          Text(
            card.wordFilipino,
            style: AppTypography.titleSmall
                .copyWith(color: const Color(0xFF7C4DFF)),
          ),
        ],
      ),
    );
  }
}

/// Looping reference-sign video with a replay control and a shimmer
/// placeholder while it loads (or a graceful note if it can't play).
class _ReferencePanel extends StatelessWidget {
  const _ReferencePanel({
    required this.controller,
    required this.ready,
    required this.onReplay,
  });

  final VideoPlayerController? controller;
  final bool ready;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return _PracticePanel(
      label: 'Reference',
      icon: Icons.sign_language_rounded,
      accent: const Color(0xFF7C4DFF),
      footer: TextButton.icon(
        onPressed: ready ? onReplay : null,
        icon: const Icon(Icons.replay_rounded, size: 18),
        label: const Text('Replay'),
        style: TextButton.styleFrom(foregroundColor: const Color(0xFF7C4DFF)),
      ),
      child: ready && controller != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: controller!.value.aspectRatio == 0
                    ? 1
                    : controller!.value.aspectRatio,
                child: VideoPlayer(controller!),
              ),
            )
          : Container(
              color: AppColors.surfaceVariant,
              child: ShimmerLoading(
                child: Center(
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    size: 48,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Live front-camera mirror, or a friendly fallback when the camera is
/// unavailable / denied so the learner can still practise from the reference.
class _MirrorPanel extends StatelessWidget {
  const _MirrorPanel({required this.status, required this.controller});

  final _CamStatus status;
  final CameraController? controller;

  @override
  Widget build(BuildContext context) {
    final ready = status == _CamStatus.ready &&
        controller != null &&
        controller!.value.isInitialized;

    return _PracticePanel(
      label: 'You',
      icon: Icons.videocam_rounded,
      accent: const Color(0xFF00BFA5),
      child: ready
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              // Mirror horizontally so it reads like a real mirror while the
              // learner copies the sign.
              child: Transform.flip(
                flipX: true,
                child: CameraPreview(controller!),
              ),
            )
          : _CameraFallback(status: status),
    );
  }
}

class _CameraFallback extends StatelessWidget {
  const _CameraFallback({required this.status});
  final _CamStatus status;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final (IconData icon, String message) = switch (status) {
      _CamStatus.initializing => (
          Icons.hourglass_top_rounded,
          'Starting camera…',
        ),
      _CamStatus.permissionDenied => (
          Icons.no_photography_rounded,
          'Camera permission off.\nYou can still watch and practise!',
        ),
      _CamStatus.noCamera => (
          Icons.videocam_off_rounded,
          'No camera found.\nJust watch and practise the sign!',
        ),
      _ => (
          Icons.videocam_off_rounded,
          'Camera unavailable.\nJust watch and practise the sign!',
        ),
    };
    return Container(
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: hc.textSecondary),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style:
                    AppTypography.bodySmall.copyWith(color: hc.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared framed panel (label chip on top, media in the middle, optional
/// footer) used by both the reference video and the camera mirror so they
/// look like a matched pair.
class _PracticePanel extends StatelessWidget {
  const _PracticePanel({
    required this.label,
    required this.icon,
    required this.accent,
    required this.child,
    this.footer,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 2),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelMedium
                    .copyWith(color: accent, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: Center(child: child)),
          ?footer,
        ],
      ),
    );
  }
}
