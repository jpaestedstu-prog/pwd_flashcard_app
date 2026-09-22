import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/theme/app_colors.dart';
import '../controllers/gaze_controller.dart';
import '../models/gaze_models.dart';
import '../providers/gaze_camera_owners.dart';
import '../providers/gaze_settings_provider.dart';
import '../services/gaze_detector.dart';
import '../widgets/gaze_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Experimental **Gaze Control** preview — drive the app hands-free by moving
/// your head toward one of four on-screen targets (dwell to select) or with a
/// deliberate long blink. All work happens in [GazeController]; this screen is
/// just its full-screen visualisation.
///
/// [camerasLoader] and [detectorFactory] are injectable so widget tests can
/// render the camera-less fallback without platform channels.
class GazeControlScreen extends ConsumerStatefulWidget {
  final Future<List<CameraDescription>> Function() camerasLoader;
  final GazeDetector Function()? detectorFactory;

  const GazeControlScreen({
    super.key,
    this.camerasLoader = availableCameras,
    this.detectorFactory,
  });

  @override
  ConsumerState<GazeControlScreen> createState() => _GazeControlScreenState();
}

class _GazeControlScreenState extends ConsumerState<GazeControlScreen> {
  GazeController? _gaze;

  // Selection confirmation banner.
  String? _lastAction;
  int _bannerToken = 0;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(gazeSettingsProvider);
    final gaze = GazeController(
      settings: settings,
      camerasLoader: widget.camerasLoader,
      detectorFactory: widget.detectorFactory,
    );
    gaze.onSelect = _fireSelection;
    gaze.onBlink = () => _fireSelection(GazeZone.none);
    gaze.addListener(_onGazeUpdate);
    _gaze = gaze;
    // Claim the single camera so the shell's background nav-gaze stands down
    // while this full-screen preview owns it.
    gazeCameraOwners.acquire();
    gaze.start();
  }

  @override
  void dispose() {
    _gaze?.removeListener(_onGazeUpdate);
    _gaze?.dispose();
    gazeCameraOwners.release();
    super.dispose();
  }

  void _onGazeUpdate() {
    if (mounted) setState(() {});
  }

  void _fireSelection(GazeZone zone) {
    ref.read(hapticServiceProvider).success();
    final action = _actionFor(zone);
    final token = ++_bannerToken;
    setState(() => _lastAction = action);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _bannerToken == token) {
        setState(() => _lastAction = null);
      }
    });
  }

  String _actionFor(GazeZone zone) {
    switch (zone) {
      case GazeZone.left:
        return _t(context).gzPrevious;
      case GazeZone.right:
        return _t(context).gzNext;
      case GazeZone.up:
        return _t(context).gzHear;
      case GazeZone.down:
        return _t(context).gzFlip;
      case GazeZone.none:
        return _t(context).gzSelect;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gaze = _gaze;
    if (gaze == null) return const SizedBox.shrink();
    final ready = gaze.status == GazeStatus.ready;
    final controller = gaze.cameraController;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (ready && controller != null)
            GazeCameraView(controller: controller)
          else
            _FallbackState(status: gaze.status, onRetry: gaze.start),
          if (ready) ...[
            const ColoredBox(color: Colors.black38),
            _targetsLayer(),
            _centerHud(),
          ],
          SafeArea(child: _topBar(context)),
          if (_lastAction != null) _confirmationBanner(_lastAction!),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Material(
            color: Colors.black45,
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
                color: Colors.black45,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                _t(context).gzPreview,
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

  Widget _targetsLayer() {
    final zone = _gaze!.zone;
    final progress = _gaze!.progress;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: GazeTarget(
                label: _t(context).gzHearWord,
                icon: Icons.volume_up_rounded,
                color: AppColors.info,
                active: zone == GazeZone.up,
                progress: zone == GazeZone.up ? progress : 0,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: GazeTarget(
                label: _t(context).gzFlipCard,
                icon: Icons.flip_rounded,
                color: AppColors.accent,
                active: zone == GazeZone.down,
                progress: zone == GazeZone.down ? progress : 0,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: GazeTarget(
                label: _t(context).vgPrevious,
                icon: Icons.arrow_back_rounded,
                color: AppColors.secondary,
                active: zone == GazeZone.left,
                progress: zone == GazeZone.left ? progress : 0,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: GazeTarget(
                label: _t(context).next,
                icon: Icons.arrow_forward_rounded,
                color: AppColors.success,
                active: zone == GazeZone.right,
                progress: zone == GazeZone.right ? progress : 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerHud() {
    final faceVisible = _gaze!.faceVisible;
    final resting = _gaze!.zone == GazeZone.none;
    return Center(
      child: faceVisible
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: resting ? 18 : 10,
              height: resting ? 18 : 10,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _t(context).gzLook,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
    );
  }

  Widget _confirmationBanner(String action) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 110,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            action,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackState extends StatelessWidget {
  final GazeStatus status;
  final VoidCallback onRetry;
  const _FallbackState({required this.status, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (status == GazeStatus.initializing) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    final (emoji, message) = switch (status) {
      GazeStatus.noCamera => (
          '🚫',
          _t(context).gzNoCamera
        ),
      GazeStatus.permissionDenied => (
          '🙈',
          _t(context).gzPermission
        ),
      _ => ('😕', _t(context).gzCameraFailed),
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
            if (status != GazeStatus.noCamera) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_t(context).gzTryAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
