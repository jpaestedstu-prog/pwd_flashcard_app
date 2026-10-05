import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../controllers/gaze_controller.dart';
import '../models/gaze_settings.dart';
import '../providers/gaze_settings_provider.dart';
import '../services/gaze_detector.dart';
import '../services/gaze_metrics.dart';
import '../widgets/gaze_traversal_scope.dart';
import '../widgets/gaze_widgets.dart';

/// **Set my resting position.** The learner sits the way they usually do and
/// looks at the middle of the screen; two seconds of keeping still later,
/// that head position is what every movement is measured from.
///
/// Gaze assumed every learner rests looking straight at the camera. A learner
/// whose head naturally rests turned or tilted — common in a wheelchair, or
/// with the tablet propped to one side — was then "looking left" all the time,
/// and either drifted the highlight by themselves or had to strain much
/// further one way than the other.
///
/// Fully hands-free: it starts when the camera sees a face, retries by itself
/// if the reading was unsteady, and returns to Gaze Control when it is done.
/// [profileId] names the learner when a teacher or parent runs it from their
/// own profile; null means the signed-in learner.
class GazeCalibrationScreen extends ConsumerStatefulWidget {
  const GazeCalibrationScreen({
    super.key,
    this.profileId,
    this.camerasLoader,
    this.detectorFactory,
  });

  final String? profileId;
  final Future<List<CameraDescription>> Function()? camerasLoader;
  final GazeDetector Function()? detectorFactory;

  @override
  ConsumerState<GazeCalibrationScreen> createState() =>
      _GazeCalibrationScreenState();
}

enum _Phase { waiting, countdown, holding, saved, failed }

class _GazeCalibrationScreenState extends ConsumerState<GazeCalibrationScreen> {
  GazeController? _controller;
  _Phase _phase = _Phase.waiting;
  int _count = 3;
  int _attempts = 0;
  Timer? _timer;

  /// After this many unsteady readings in a row, stop and let the learner
  /// (or their grown-up) choose to try again.
  static const int _maxAutoAttempts = 3;

  GazeSettingsEditing get _editor {
    final id = widget.profileId;
    return id == null
        ? ref.read(gazeSettingsProvider.notifier)
        : ref.read(gazeSettingsForProfileProvider(id).notifier);
  }

  GazeSettings _settingsNow() {
    final id = widget.profileId;
    return id == null
        ? ref.read(gazeSettingsProvider)
        : ref.read(gazeSettingsForProfileProvider(id));
  }

  late final GazeSettings _runSettings = _settingsNow().copyWith(
    enabled: true,
    // The capture reads the raw head angle; nothing should be counting a
    // keep-still or stepping a scanner while the learner holds still.
    dwellSelect: false,
    scanMode: false,
  );

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.removeListener(_onUpdate);
    super.dispose();
  }

  void _onController(GazeController controller) {
    _controller = controller;
    controller.addListener(_onUpdate);
  }

  void _onUpdate() {
    final c = _controller;
    if (!mounted || c == null) return;
    if (_phase == _Phase.waiting &&
        c.status == GazeStatus.ready &&
        c.faceVisible) {
      _startCountdown();
    } else {
      setState(() {});
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() {
      _phase = _Phase.countdown;
      _count = 3;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_count > 1) {
        setState(() => _count--);
        return;
      }
      t.cancel();
      _capture();
    });
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null) return;
    setState(() => _phase = _Phase.holding);
    final rest = await c.captureRestPosition();
    if (!mounted) return;
    _attempts++;
    if (rest == null) {
      setState(() => _phase = _Phase.failed);
      if (_attempts < _maxAutoAttempts) {
        _timer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted && _phase == _Phase.failed) {
            setState(() => _phase = _Phase.waiting);
            _onUpdate();
          }
        });
      }
      return;
    }
    _editor.setRestPosition(rest.yaw, rest.pitch);
    final id = widget.profileId ?? _profileIdOrNull();
    if (id != null) GazeMetrics.instance.calibrated(id);
    ref.read(hapticServiceProvider).success();
    setState(() => _phase = _Phase.saved);
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  String? _profileIdOrNull() {
    try {
      return gazeProfileIdAtTablet(ref.read);
    } catch (_) {
      return null;
    }
  }

  void _retry() {
    _attempts = 0;
    setState(() => _phase = _Phase.waiting);
    _onUpdate();
  }

  String _message(AppLocalizations t) {
    final c = _controller;
    if (c != null && c.status != GazeStatus.ready &&
        c.status != GazeStatus.initializing) {
      return c.status == GazeStatus.permissionDenied
          ? t.gzPermission
          : c.status == GazeStatus.noCamera
          ? t.gzNoCamera
          : t.gzCameraFailed;
    }
    return switch (_phase) {
      _Phase.waiting => t.gzcGetReady,
      _Phase.countdown => '${t.gzcGetReady}\n$_count',
      _Phase.holding => t.gzcHold,
      _Phase.saved => t.gzcSaved,
      _Phase.failed => t.gzcFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final c = _controller;
    final camera = c?.cameraController;
    final saved = _phase == _Phase.saved;
    return Scaffold(
      appBar: AppBar(title: Text(t.gzcTitle)),
      body: GazeTraversalScope(
        settingsOverride: _runSettings,
        onController: _onController,
        camerasLoader: widget.camerasLoader,
        detectorFactory: widget.detectorFactory,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            // The camera takes two thirds; the message the rest, scrolling at
            // the largest text sizes rather than pushing off the screen.
            child: Column(
              children: [
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Colors.black),
                        if (camera != null && c!.status == GazeStatus.ready)
                          GazeCameraView(controller: camera),
                        // Where to look: the middle of the screen.
                        Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: _phase == _Phase.holding ? 64 : 48,
                            height: _phase == _Phase.holding ? 64 : 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: saved
                                  ? AppColors.success
                                  : AppColors.accent.withValues(alpha: 0.85),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: saved
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 32)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _message(t),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_phase == _Phase.failed &&
                            _attempts >= _maxAutoAttempts) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(t.gzTryAgain),
                          ),
                        ],
                      ],
                    ),
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
