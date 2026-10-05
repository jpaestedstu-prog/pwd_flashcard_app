import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../controllers/gaze_controller.dart';
import '../logic/voice_commands.dart';
import '../models/gaze_settings.dart';
import '../providers/gaze_camera_owners.dart';
import '../providers/gaze_settings_provider.dart';
import '../services/gaze_detector.dart';
import '../services/gaze_metrics.dart';
import 'gaze_hints.dart';
import 'gaze_route_guard.dart';
import 'gaze_session.dart';
import 'gaze_traversal.dart';
import 'voice_control_mixin.dart';

/// Gaze for a screen that lives **outside the navigation shell** and has no
/// scope of its own — the first-run tutorial, the "join your home group"
/// gate. Head moves, blinks, scanning and voice drive focus traversal over
/// the screen's own controls (see [GazeTraversal]), with the ring and the
/// Back pill, exactly as on any covered surface.
///
/// The shell's scope only exists while a shell page is in the route stack.
/// These screens are reached with `go()`, which takes the shell away, so they
/// had no gaze at all — and the tutorial is the very first screen a learner
/// sees after the setup step that switched gaze on for them.
///
/// Inert unless Gaze Control is enabled for the signed-in profile. A
/// foreground camera owner, so it can never run beside another gaze camera.
class GazeTraversalScope extends ConsumerStatefulWidget {
  const GazeTraversalScope({
    super.key,
    required this.child,
    this.settingsOverride,
    this.onController,
    this.camerasLoader,
    this.detectorFactory,
  });

  final Widget child;

  /// Run on these settings instead of the signed-in profile's — a grown-up
  /// calibrating a learner's resting position from their own profile. They
  /// are used even when the learner's Gaze Control is switched off, because
  /// the screen that passes them needs the camera regardless.
  final GazeSettings? settingsOverride;

  /// Hands the running controller to the screen (the calibration screen reads
  /// the resting position through it).
  final void Function(GazeController controller)? onController;

  /// Injection seams for tests; production uses the real camera + ML Kit.
  final Future<List<CameraDescription>> Function()? camerasLoader;
  final GazeDetector Function()? detectorFactory;

  @override
  ConsumerState<GazeTraversalScope> createState() => _GazeTraversalScopeState();
}

class _GazeTraversalScopeState extends ConsumerState<GazeTraversalScope>
    with VoiceControlMixin, GazeRouteGuard, GazeSessionMixin {
  GazeController? _gaze;
  GazeSettings _settings = const GazeSettings();
  Object? _cameraToken;
  Timer? _scanTimer;

  late final GazeTraversal _traversal = GazeTraversal(
    onMoved: () {
      ref.read(hapticServiceProvider).selectionClick();
      GazeMetrics.instance.moved();
      _gaze?.armRestSelect();
      sayFocusedSoon();
    },
    onScanned: () {
      ref.read(hapticServiceProvider).selectionClick();
      GazeMetrics.instance.scanned();
      sayFocusedSoon();
    },
    onPressed: (by) {
      ref.read(hapticServiceProvider).success();
      gazePicked(_gaze, by);
    },
    onLeft: GazeMetrics.instance.backed,
  );

  bool get _isTopOwner {
    final token = _cameraToken;
    return token != null && gazeCameraOwners.isTop(token);
  }

  @override
  void initState() {
    super.initState();
    final override = widget.settingsOverride;
    final GazeSettings settings = override ?? ref.read(gazeSettingsProvider);
    if (override == null && !settings.enabled) return;
    _settings = settings;
    final controller = GazeController(
      settings: settings,
      camerasLoader: widget.camerasLoader ?? availableCameras,
      detectorFactory: widget.detectorFactory,
    );
    controller.onSelect = (zone) {
      if (!mounted || _settings.scanMode) return;
      _traversal.zone(zone, lookUpSelects: _settings.lookUpSelects);
    };
    controller.onBlink = () {
      if (mounted) _traversal.commit();
    };
    controller.onRest = () {
      if (mounted) _traversal.commit(by: GazeSelectBy.rest);
    };
    _gaze = controller;
    widget.onController?.call(controller);
    _cameraToken = gazeCameraOwners.acquire();
    gazeCameraOwners.addListener(_onCameraOwnersChanged);
    controller.start();
    beginGazeSession(settings, onSwitch: _onSwitch);
    if (settings.scanMode) {
      _scanTimer = Timer.periodic(settings.scanStepDuration, (_) {
        if (!mounted || (_gaze?.suspended ?? true)) return;
        _traversal.scanStep();
      });
    }
    if (settings.voiceCommands) startVoiceControl();
    // The ring goes up once this frame has laid the screen out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncRing());
  }

  void _onSwitch() {
    if (mounted) _traversal.commit(by: GazeSelectBy.switchButton);
  }

  @override
  void dispose() {
    endGazeSession();
    _scanTimer?.cancel();
    _traversal.hideRing();
    disposeVoiceControl();
    _gaze?.dispose();
    gazeCameraOwners.removeListener(_onCameraOwnersChanged);
    final token = _cameraToken;
    if (token != null) gazeCameraOwners.release(token);
    super.dispose();
  }

  void _syncRing() {
    if (!mounted || _gaze == null) return;
    _traversal.syncRing(
      context,
      wanted: _isTopOwner,
      hint: GazeHints.forSettings(context, _settings, rowsReachable: true),
    );
  }

  /// Another camera surface opened over this screen: stand down until it
  /// closes. Deferred because owners change from `initState` / `dispose`.
  void _onCameraOwnersChanged() {
    scheduleMicrotask(() {
      final gaze = _gaze;
      if (!mounted || gaze == null) return;
      if (!_isTopOwner && !gaze.suspended) {
        gaze.suspendCamera();
        endGazeSession();
        disposeVoiceControl();
      } else if (_isTopOwner && gaze.suspended) {
        gaze.resumeCamera();
        beginGazeSession(_settings, onSwitch: _onSwitch);
        if (_settings.voiceCommands) startVoiceControl();
      }
      _syncRing();
      setState(() {});
    });
  }

  @override
  void onVoiceCommand(String text) {
    if (!mounted) return;
    final intent = _traversal.voice(text);
    if (kDebugMode) debugPrint('VoiceCmd standalone "$text" → $intent');
    switch (intent) {
      case DpadVoiceIntent.scrollUp:
        voiceScroll(-1);
      case DpadVoiceIntent.scrollDown:
        voiceScroll(1);
      default:
        break;
    }
  }

  @override
  Map<String, Object?> debugDescribe() => {
    'scope': 'standalone',
    'running': _gaze != null,
    'topOwner': _isTopOwner,
    'scanning': _settings.scanMode,
    'onExit': _traversal.onExit,
  };

  @override
  Widget build(BuildContext context) {
    if (_gaze == null) return widget.child;
    final chip = voiceChip();
    return hostGazeModals(
      Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (chip != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: IgnorePointer(child: Center(child: chip)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
