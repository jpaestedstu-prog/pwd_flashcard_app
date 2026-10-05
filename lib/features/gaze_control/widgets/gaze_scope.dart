import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../controllers/gaze_controller.dart';
import '../services/gaze_detector.dart';
import '../logic/scan_cycler.dart';
import '../logic/voice_commands.dart';
import '../models/gaze_action.dart';
import '../models/gaze_models.dart';
import '../models/gaze_settings.dart';
import '../providers/gaze_camera_owners.dart';
import '../providers/gaze_settings_provider.dart';
import 'gaze_overlay.dart';
import 'gaze_route_guard.dart';
import 'gaze_traversal.dart';
import 'voice_control_mixin.dart';

/// Wrap any screen in a [GazeScope] to make it controllable by gaze in a few
/// lines: pass the up-to-four [GazeAction]s (one per edge) plus an optional
/// [onBlink], and the scope handles the camera, the overlay, head-dwell
/// selection, and the scanning fallback.
///
/// It is **inert unless the learner has enabled Gaze Control** in Settings — if
/// off, it simply returns [child], so adding it has zero effect by default and
/// never opens a camera. Selection always also works by touch on the screen's
/// own buttons; gaze is purely additive.
///
/// When something covers the screen — a dialog, a sheet, a pushed page, or an
/// in-screen modal such as a game's pause card (see `GazeModalRegion`) — the
/// edge actions stand down and head, blink, scanning and voice drive focus
/// traversal on what is showing instead (see [GazeTraversal]). A game paused
/// by voice used to leave a hands-free learner facing a pause card nothing
/// could press.
///
/// Settings are snapshotted when the scope mounts (re-enter the screen to apply
/// a change). Actions may be rebuilt freely by the parent — the scope always
/// reads the current list at selection time, so per-frame `enabled` flags and
/// captured state stay fresh.
class GazeScope extends ConsumerStatefulWidget {
  final List<GazeAction> actions;

  /// Invoked on a deliberate blink in **head** mode. In **scanning** mode a
  /// blink instead selects the currently highlighted action.
  final VoidCallback? onBlink;

  final Widget child;

  /// Injection seams for tests; production uses the real camera + ML Kit.
  final Future<List<CameraDescription>> Function()? camerasLoader;
  final GazeDetector Function()? detectorFactory;

  const GazeScope({
    super.key,
    required this.actions,
    required this.child,
    this.onBlink,
    this.camerasLoader,
    this.detectorFactory,
  });

  @override
  ConsumerState<GazeScope> createState() => _GazeScopeState();
}

class _GazeScopeState extends ConsumerState<GazeScope>
    with VoiceControlMixin, GazeRouteGuard {
  GazeController? _gaze;
  GazeSettings? _settings;
  ScanCycler? _scanner;
  Timer? _scanTimer;
  int _scanIndex = 0;

  /// This scope's place in the camera-owner stack, so the shell's nav-gaze
  /// stands down — and so this scope can tell when another camera surface has
  /// opened on top of it. Released exactly once on dispose.
  Object? _cameraToken;

  /// Head moves, blinks, scan steps and voice while something covers this
  /// screen — plus the ring that shows where that is.
  late final GazeTraversal _traversal = GazeTraversal(
    onMoved: () => ref.read(hapticServiceProvider).selectionClick(),
    onPressed: () => ref.read(hapticServiceProvider).success(),
  );

  /// True while items auto-highlight (camera blink-scan).
  bool get _scanning => _settings?.scanMode ?? false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(gazeSettingsProvider);
    if (!settings.enabled) return;
    _settings = settings;
    final controller = GazeController(
      settings: settings,
      camerasLoader: widget.camerasLoader ?? availableCameras,
      detectorFactory: widget.detectorFactory,
    );
    controller.onSelect = _onSelect;
    controller.onBlink = _onBlink;
    _gaze = controller;
    // Claim the single camera so the shell's background nav-gaze stands down.
    _cameraToken = gazeCameraOwners.acquire();
    gazeCameraOwners.addListener(_onCameraOwnersChanged);
    controller.start();
    if (settings.scanMode) _startScanning(settings);
    // Voice is additive — it layers on top of the targets.
    if (settings.voiceCommands) startVoiceControl();
    // Watch for a dialog / sheet / pushed page covering this screen, so the
    // overlay and chip stop claiming the edge targets are live, and the
    // traversal ring takes over.
    startGazeCoverageWatch();
  }

  /// A spoken phrase → the target on a matching edge / label, a "select" that
  /// fires the screen's blink action (mirroring the camera), or a global
  /// scroll / leave-screen action. While something covers this screen the same
  /// phrases drive focus traversal on what is showing.
  @override
  void onVoiceCommand(String text) {
    if (!mounted) return;
    if (gazeCovered) {
      final intent = _traversal.voice(text);
      if (kDebugMode) debugPrint('VoiceCmd scope(covered) "$text" → $intent');
      // Traversal already closed the surface on "go back"; only the scroll
      // gesture is left to this scope.
      switch (intent) {
        case DpadVoiceIntent.scrollUp:
          voiceScroll(-1);
        case DpadVoiceIntent.scrollDown:
          voiceScroll(1);
        default:
          break;
      }
      return;
    }
    final result = resolveVoiceCommand(text, widget.actions);
    if (kDebugMode) {
      debugPrint('VoiceCmd scope "$text" → ${result.intent}');
    }
    switch (result.intent) {
      case VoiceIntent.action:
        _fireActionAt(result.actionIndex);
      case VoiceIntent.select:
        _onBlink();
      case VoiceIntent.scrollUp:
        voiceScroll(-1);
      case VoiceIntent.scrollDown:
        voiceScroll(1);
      case VoiceIntent.goBack:
        Navigator.of(context).maybePop();
      case VoiceIntent.none:
        break;
    }
  }

  void _fireActionAt(int index) {
    if (index < 0 || index >= widget.actions.length) return;
    final action = widget.actions[index];
    if (action.enabled) {
      ref.read(hapticServiceProvider).success();
      action.onSelect();
    }
  }

  void _startScanning(GazeSettings settings) {
    _scanner = ScanCycler(count: widget.actions.length);
    _scanTimer = Timer.periodic(settings.scanStepDuration, (_) {
      if (!mounted) return;
      // Stood down under another camera surface: that one is scanning now.
      if (_gaze?.suspended ?? true) return;
      if (gazeCovered) {
        // The edge targets are hidden: light up the covering surface's
        // controls in turn instead.
        _traversal.scanStep();
        return;
      }
      _scanner!.count = widget.actions.length;
      setState(() => _scanIndex = _scanner!.advance());
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    stopGazeCoverageWatch();
    _traversal.hideRing();
    _gaze?.dispose();
    disposeVoiceControl();
    gazeCameraOwners.removeListener(_onCameraOwnersChanged);
    final token = _cameraToken;
    if (token != null) gazeCameraOwners.release(token);
    super.dispose();
  }

  /// Whether this screen is the newest camera owner — the one the learner is
  /// looking at. Only then may it run its camera and microphone.
  bool get _isTopOwner {
    final token = _cameraToken;
    return token != null && gazeCameraOwners.isTop(token);
  }

  /// Another camera surface opened over this screen (the race the Play
  /// Together lobby starts, the media camera a message thread opens): stand
  /// the camera, the microphone and the traversal ring down until it closes.
  /// Deferred because owners change from `initState` / `dispose`.
  void _onCameraOwnersChanged() {
    scheduleMicrotask(() {
      final gaze = _gaze;
      if (!mounted || gaze == null) return;
      if (!_isTopOwner && !gaze.suspended) {
        gaze.suspendCamera();
        disposeVoiceControl();
        _traversal.hideRing();
        setState(() {});
      } else if (_isTopOwner && gaze.suspended) {
        gaze.resumeCamera();
        if (_settings?.voiceCommands ?? false) startVoiceControl();
        onGazeCoverageChanged(gazeCovered);
        setState(() {});
      }
    });
  }

  /// Head-dwell selection. Ignored in scanning mode (head movement isn't used
  /// there). While another route or an in-screen modal covers this screen, a
  /// head hold steers focus traversal on what is showing — it must never fire
  /// an edge action hidden underneath.
  void _onSelect(GazeZone zone) {
    if (!mounted || _scanning) return;
    if (gazeCovered) {
      _traversal.zone(zone, blinkSelects: _settings?.blinkSelects ?? true);
      return;
    }
    final action = widget.actions
        .where((a) => a.zone == zone && a.enabled)
        .firstOrNull;
    if (action != null) {
      ref.read(hapticServiceProvider).success();
      action.onSelect();
    }
  }

  void _onBlink() {
    if (!mounted) return;
    if (gazeCovered) {
      _traversal.commit();
      return;
    }
    if (_scanning) {
      _selectScanned();
    } else {
      ref.read(hapticServiceProvider).success();
      widget.onBlink?.call();
    }
  }

  /// Activates whichever action is currently highlighted by the scanner — fired
  /// by a blink (camera scan) or a tap / switch press (switch scan).
  void _selectScanned() {
    if (!mounted) return;
    if (_scanIndex < 0 || _scanIndex >= widget.actions.length) return;
    final action = widget.actions[_scanIndex];
    if (action.enabled) {
      ref.read(hapticServiceProvider).success();
      action.onSelect();
    }
  }

  @override
  void onGazeCoverageChanged(bool covered) {
    if (!mounted || _gaze == null) return;
    _traversal.syncRing(
      context,
      // Covered by a screen with its own gaze, that screen draws its own
      // highlight; the ring belongs to whoever is driving.
      wanted: covered && _isTopOwner,
      hint: GazeTraversal.hintFor(
        scanning: _scanning,
        blinkSelects: _settings?.blinkSelects ?? true,
      ),
    );
  }

  @override
  Map<String, Object?> debugDescribe() => {
    'scope': 'edge',
    'running': _gaze != null,
    'topOwner': _isTopOwner,
    'covered': _gaze != null && gazeCovered,
    'scanning': _scanning,
    if (_scanning) 'scanIndex': _scanIndex,
    'actions': [
      for (final a in widget.actions)
        '${a.zone.name}:${a.label}${a.enabled ? '' : ' (off)'}',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final gaze = _gaze;
    // Nothing armed → totally transparent (no wrapper, no behaviour change).
    // The settings are snapshotted on mount, so this answer never changes for
    // the lifetime of the scope and the child never remounts over it.
    if (gaze == null) return widget.child;

    // While a dialog / sheet / pushed page covers this screen the edge targets
    // are gated off, so they must not keep drawing their dwell rings or mic
    // chip on top of whatever is now in front — that would advertise a control
    // the learner's head cannot actually move. The structure stays the same
    // either way: switching between a bare child and a Stack used to re-create
    // the whole game beneath every time a dialog opened or closed.
    final covered = gazeCoveredForUi;
    final chip = covered ? null : voiceChip();
    return hostGazeModals(
      Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (!covered)
            Positioned.fill(
              child: GazeOverlay(
                controller: gaze,
                actions: widget.actions,
                scanIndex: _scanning ? _scanIndex : null,
              ),
            ),
          if (chip != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: IgnorePointer(child: Center(child: chip)),
            ),
        ],
      ),
    );
  }
}
