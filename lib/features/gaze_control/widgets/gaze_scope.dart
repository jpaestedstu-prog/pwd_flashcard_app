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
    with VoiceControlMixin {
  GazeController? _gaze;
  GazeSettings? _settings;
  ScanCycler? _scanner;
  Timer? _scanTimer;
  int _scanIndex = 0;

  /// True once this scope has claimed the shared camera owner count, so the
  /// shell's nav-gaze stands its camera down. Released exactly once on dispose.
  bool _ownsCamera = false;

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
    _ownsCamera = true;
    gazeCameraOwners.acquire();
    controller.start();
    if (settings.scanMode) _startScanning(settings);
    // Voice is additive — it layers on top of the targets.
    if (settings.voiceCommands) startVoiceControl();
  }

  /// A spoken phrase → the target on a matching edge / label, a "select" that
  /// fires the screen's blink action (mirroring the camera), or a global
  /// scroll / leave-screen action.
  @override
  void onVoiceCommand(String text) {
    if (!mounted) return;
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
      _scanner!.count = widget.actions.length;
      setState(() => _scanIndex = _scanner!.advance());
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _gaze?.dispose();
    disposeVoiceControl();
    if (_ownsCamera) gazeCameraOwners.release();
    super.dispose();
  }

  /// Head-dwell selection. Ignored in scanning mode (head movement isn't used
  /// there).
  void _onSelect(GazeZone zone) {
    if (!mounted || _scanning) return;
    final action =
        widget.actions.where((a) => a.zone == zone && a.enabled).firstOrNull;
    if (action != null) {
      ref.read(hapticServiceProvider).success();
      action.onSelect();
    }
  }

  void _onBlink() {
    if (!mounted) return;
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
  Widget build(BuildContext context) {
    final hasGaze = _gaze != null;
    final chip = voiceChip();
    // Nothing active → totally transparent (no wrapper, no behaviour change).
    if (!hasGaze && chip == null) return widget.child;

    // Expand to fill the screen so overlays always have room, regardless of how
    // large the wrapped child reports itself to be.
    final children = <Widget>[widget.child];

    if (hasGaze) {
      children.add(
        Positioned.fill(
          child: GazeOverlay(
            controller: _gaze!,
            actions: widget.actions,
            scanIndex: _scanning ? _scanIndex : null,
          ),
        ),
      );
    }

    if (chip != null) {
      children.add(
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: IgnorePointer(child: Center(child: chip)),
        ),
      );
    }

    return Stack(fit: StackFit.expand, children: children);
  }
}
