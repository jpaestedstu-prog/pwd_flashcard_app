import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/theme/app_colors.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../models/object_scan_models.dart';
import '../services/label_word_mapper.dart';
import '../services/object_labeler.dart';
import '../services/object_scan_discovery_service.dart';
import '../widgets/discovered_word_sheet.dart';
import '../widgets/photo_results_panel.dart';

enum _ScanStatus { initializing, ready, noCamera, permissionDenied, failed }

/// Where the learner is in the photo flow: aiming, waiting for the shutter,
/// or looking at a captured photo with its detected words.
enum _CapturePhase { preview, capturing, reviewing }

/// True when the device exposes both a front and a back lens, so the flip
/// control is worth showing. Pure (no platform channels) so it is unit
/// testable; the actual flip still needs a real camera on-device.
bool hasFrontAndBackCameras(List<CameraDescription> cameras) {
  final hasBack =
      cameras.any((c) => c.lensDirection == CameraLensDirection.back);
  final hasFront =
      cameras.any((c) => c.lensDirection == CameraLensDirection.front);
  return hasBack && hasFront;
}

/// Word Hunt — take a photo of a real object and the bundled on-device
/// ML Kit model turns it into tappable vocabulary words.
///
/// [camerasLoader] and [labelerFactory] exist so widget tests can inject
/// fakes; the real camera and labeler need platform channels.
class ObjectScanScreen extends ConsumerStatefulWidget {
  final Future<List<CameraDescription>> Function() camerasLoader;
  final ObjectLabeler Function() labelerFactory;

  const ObjectScanScreen({
    super.key,
    this.camerasLoader = availableCameras,
    this.labelerFactory = MlKitObjectLabeler.new,
  });

  @override
  ConsumerState<ObjectScanScreen> createState() => _ObjectScanScreenState();
}

class _ObjectScanScreenState extends ConsumerState<ObjectScanScreen>
    with WidgetsBindingObserver {
  late final ObjectLabeler _labeler;
  CameraController? _controller;
  _ScanStatus _status = _ScanStatus.initializing;
  bool _initInFlight = false;

  /// Which lens to open. Defaults to the back camera (the natural choice
  /// for pointing at objects); the flip button toggles it.
  CameraLensDirection _lensDirection = CameraLensDirection.back;

  /// Cameras reported by the device, used to decide whether to offer flip.
  List<CameraDescription> _cameras = const [];
  bool get _canFlip => hasFrontAndBackCameras(_cameras);

  _CapturePhase _phase = _CapturePhase.preview;
  String? _photoPath;
  bool _searching = false;
  List<WordMatch> _photoMatches = const [];
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _labeler = widget.labelerFactory();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _controller = null;
    _labeler.close();
    _deletePhoto();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Never touch a controller that is still initializing: the runtime
      // permission dialog itself sends the app `inactive`, and disposing
      // mid-initialize crashes the plugin with a null-check TypeError on
      // first launch. Once the dialog closes, initialize() resumes.
      if (controller != null && controller.value.isInitialized) {
        controller.dispose();
        _controller = null;
        _status = _ScanStatus.initializing;
      }
    } else if (state == AppLifecycleState.resumed &&
        controller == null &&
        !_initInFlight &&
        _status != _ScanStatus.noCamera) {
      // Re-acquire after backgrounding; also retries after the user grants
      // permission from system settings.
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (_initInFlight) return;
    _initInFlight = true;
    try {
      await _initCameraInner();
    } finally {
      _initInFlight = false;
    }
  }

  Future<void> _initCameraInner() async {
    if (_status != _ScanStatus.initializing) {
      setState(() => _status = _ScanStatus.initializing);
    }
    List<CameraDescription> cameras;
    try {
      cameras = await widget.camerasLoader();
    } on CameraException {
      cameras = const [];
    }
    if (!mounted) return;
    if (cameras.isEmpty) {
      setState(() => _status = _ScanStatus.noCamera);
      return;
    }
    _cameras = cameras;
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == _lensDirection,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      camera,
      // High-resolution stills: the photo is both shown to the learner and
      // fed to ML Kit, so clarity matters. CameraX falls back to the nearest
      // supported size on devices that can't do 1080p.
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    _controller = controller;
    // After every await: if `_controller` no longer points at this
    // controller, dispose()/the lifecycle handler already tore it down —
    // this run is stale and must not dispose it a second time.
    try {
      await controller.initialize();
      if (!mounted || !identical(_controller, controller)) return;
      setState(() => _status = _ScanStatus.ready);
    } on CameraException catch (e) {
      if (!identical(_controller, controller)) return;
      _controller = null;
      controller.dispose();
      if (!mounted) return;
      setState(() => _status = e.code.startsWith('CameraAccess')
          ? _ScanStatus.permissionDenied
          : _ScanStatus.failed);
    } catch (_) {
      // Plugin internals can throw non-CameraException errors (e.g. when
      // the platform side goes away mid-call); show the retry state
      // instead of an unhandled exception.
      if (!identical(_controller, controller)) return;
      _controller = null;
      controller.dispose();
      if (!mounted) return;
      setState(() => _status = _ScanStatus.failed);
    }
  }

  /// Switches between the front and back lens, then re-initializes through
  /// the same guarded path used at startup (a flip is just dispose +
  /// re-init with the other lens).
  Future<void> _flipCamera() async {
    if (_status != _ScanStatus.ready ||
        _phase != _CapturePhase.preview ||
        _initInFlight ||
        !_canFlip) {
      return;
    }
    ref.read(hapticServiceProvider).lightTap();
    _lensDirection = _lensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    _controller?.dispose();
    _controller = null;
    setState(() => _status = _ScanStatus.initializing);
    await _initCamera();
  }

  void _deletePhoto() {
    final path = _photoPath;
    _photoPath = null;
    if (path != null) {
      File(path).delete().ignore();
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _phase != _CapturePhase.preview) {
      return;
    }
    ref.read(hapticServiceProvider).lightTap();
    setState(() => _phase = _CapturePhase.capturing);
    try {
      final shot = await controller.takePicture();
      if (!mounted) {
        File(shot.path).delete().ignore();
        return;
      }
      _deletePhoto();
      setState(() {
        _photoPath = shot.path;
        _phase = _CapturePhase.reviewing;
        _searching = true;
        _photoMatches = const [];
      });
      final labels = await _labeler.labelPhoto(shot.path);
      if (!mounted) return;
      setState(() {
        _photoMatches = LabelWordMapper.matchAll(labels).take(3).toList();
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      _deletePhoto();
      setState(() {
        _phase = _CapturePhase.preview;
        _searching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.wordHuntCameraError),
        ),
      );
    }
  }

  void _retake() {
    ref.read(hapticServiceProvider).lightTap();
    _deletePhoto();
    setState(() {
      _phase = _CapturePhase.preview;
      _searching = false;
      _photoMatches = const [];
    });
  }

  Future<void> _openWord(WordMatch match) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    final profileId = ref.read(profileProvider)?.id;
    final result =
        ObjectScanDiscoveryService.recordDiscovery(profileId, match.card.id);
    if (result.starAwarded) {
      ref.read(progressProvider.notifier).addStars(1);
      ref.read(hapticServiceProvider).celebration();
    } else {
      ref.read(hapticServiceProvider).lightTap();
    }
    // Queue the discovered word for Smart Review (spaced repetition). Profile-
    // scoped and offline; guests have no review queue, so skip them. The Hive
    // write is fire-and-forget — never awaited from widget code.
    if (profileId != null && profileId.isNotEmpty) {
      SpacedRepetitionService.markSeen(
        profileId: profileId,
        wordId: match.card.id,
      );
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DiscoveredWordSheet(
        card: match.card,
        isNewDiscovery: result.isNew,
        starAwarded: result.starAwarded,
      ),
    );
    _sheetOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final photoPath = _photoPath;
    final showPhoto = _phase == _CapturePhase.reviewing && photoPath != null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (showPhoto)
            _PhotoView(path: photoPath)
          else if (_status == _ScanStatus.ready && _controller != null)
            _CameraCover(controller: _controller!)
          else
            _FallbackState(
              status: _status,
              l10n: l10n,
              onRetry: _initCamera,
            ),
          SafeArea(
            child: Column(
              children: [
                _topBar(context, l10n),
                const Spacer(),
                if (showPhoto)
                  SingleChildScrollView(
                    reverse: true,
                    child: PhotoResultsPanel(
                      matches: _photoMatches,
                      searching: _searching,
                      onWordTap: _openWord,
                      onRetake: _retake,
                    ),
                  )
                else if (_status == _ScanStatus.ready)
                  _capturePanel(l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Material(
            color: Colors.black38,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                '📷 ${l10n.wordHuntTitle}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Aiming hint + the big PWD-friendly shutter button.
  Widget _capturePanel(AppLocalizations l10n) {
    final capturing = _phase == _CapturePhase.capturing;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l10n.wordHuntPointCamera,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left slot: flip button when two lenses exist, otherwise an
              // empty box of the same width so the shutter stays centered.
              SizedBox(
                width: 56,
                child: _canFlip
                    ? Semantics(
                        button: true,
                        label: l10n.wordHuntFlipCamera,
                        child: Material(
                          color: Colors.black38,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: capturing ? null : _flipCamera,
                            child: const SizedBox(
                              width: 56,
                              height: 56,
                              child: Icon(
                                Icons.cameraswitch_rounded,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 24),
              Semantics(
                button: true,
                label: l10n.wordHuntTakePhoto,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: capturing ? null : _capturePhoto,
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: capturing
                          ? const Padding(
                              padding: EdgeInsets.all(22),
                              child: CircularProgressIndicator(
                                color: AppColors.bannerWordHuntEnd,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              size: 40,
                              color: AppColors.bannerWordHuntEnd,
                            ),
                    ),
                  ),
                ),
              ),
              // Right slot mirrors the left so the shutter sits centered.
              const SizedBox(width: 24),
              const SizedBox(width: 56),
            ],
          ),
        ],
      ),
    );
  }
}

/// The captured photo, full screen on black so the learner sees exactly
/// what was analyzed.
class _PhotoView extends StatelessWidget {
  final String path;
  const _PhotoView({required this.path});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Camera preview scaled to cover the whole screen without distortion.
class _CameraCover extends StatelessWidget {
  final CameraController controller;
  const _CameraCover({required this.controller});

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return const SizedBox.shrink();
    // previewSize is reported landscape-oriented; swap in portrait so the
    // FittedBox covers the screen on phones and tablets alike.
    final portrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final width = portrait ? previewSize.height : previewSize.width;
    final height = portrait ? previewSize.width : previewSize.height;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: width,
        height: height,
        child: CameraPreview(controller),
      ),
    );
  }
}

class _FallbackState extends StatelessWidget {
  final _ScanStatus status;
  final AppLocalizations l10n;
  final VoidCallback onRetry;
  const _FallbackState({
    required this.status,
    required this.l10n,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (status == _ScanStatus.initializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    final (emoji, message) = switch (status) {
      _ScanStatus.noCamera => ('🚫', l10n.wordHuntNoCamera),
      _ScanStatus.permissionDenied => ('🙈', l10n.wordHuntCameraDenied),
      _ => ('😕', l10n.wordHuntCameraError),
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (status != _ScanStatus.noCamera) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.tryAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
