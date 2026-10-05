import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../logic/blink_detector.dart';
import '../logic/dwell_tracker.dart';
import '../logic/gaze_zone_resolver.dart';
import '../models/gaze_models.dart';
import '../models/gaze_settings.dart';
import '../services/gaze_detector.dart';

/// Lifecycle/acquisition state of the camera behind a [GazeController].
enum GazeStatus { initializing, ready, noCamera, permissionDenied, failed }

/// Maps each [DeviceOrientation] to the clockwise degrees ML Kit needs to
/// rotate an Android frame upright. (iOS reports rotation directly.)
const Map<DeviceOrientation, int> _kOrientationDegrees = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// The reusable engine behind gaze control: it owns the front camera + image
/// stream, runs the ML Kit detector, and feeds the pure gaze pipeline
/// (resolver → dwell → blink), exposing the result as [ChangeNotifier] state.
///
/// Any screen can drive its UI from [status]/[faceVisible]/[zone]/[progress]
/// and react to selections via [onSelect] / [onBlink]. The full-screen preview
/// and the in-context flashcard overlay both use this single implementation, so
/// the hard-won camera-lifecycle handling lives in exactly one place.
///
/// Not a widget: guards use a [_disposed] flag instead of `mounted`, and an
/// `identical(_controller, …)` check after each await (mirrors `ObjectScanScreen`).
class GazeController extends ChangeNotifier with WidgetsBindingObserver {
  GazeController({
    required GazeSettings settings,
    this.camerasLoader = availableCameras,
    GazeDetector Function()? detectorFactory,
  }) : _turnThreshold = settings.turnThresholdDeg,
       _tiltThreshold = settings.tiltThresholdDeg,
       _blinkEnabled = settings.blinkSelects,
       _mirrorHorizontal = settings.mirrorHorizontal,
       _invertVertical = settings.invertVertical,
       _dwell = DwellTracker(dwellDuration: settings.dwellDuration),
       _detector =
           detectorFactory?.call() ??
           MlKitGazeDetector(
             mirrorHorizontal: settings.mirrorHorizontal,
             invertVertical: settings.invertVertical,
           );
  final Future<List<CameraDescription>> Function() camerasLoader;
  final GazeDetector _detector;
  DwellTracker _dwell;
  final BlinkDetector _blink = BlinkDetector();
  final Stopwatch _clock = Stopwatch();
  double _turnThreshold;
  double _tiltThreshold;
  bool _blinkEnabled;
  bool _mirrorHorizontal;
  bool _invertVertical;

  /// Re-tunes a running controller in place: sensitivity, hold time, blink
  /// and the left/right · up/down calibration all take effect on the next
  /// frame, with no camera restart.
  ///
  /// The navigation shell's controller lives for the whole session, so
  /// without this a teacher who changed a learner's sensitivity saw nothing
  /// happen — the shell kept the values it was started with until something
  /// happened to bounce its camera.
  void applySettings(GazeSettings settings) {
    _turnThreshold = settings.turnThresholdDeg;
    _tiltThreshold = settings.tiltThresholdDeg;
    _blinkEnabled = settings.blinkSelects;
    _mirrorHorizontal = settings.mirrorHorizontal;
    _invertVertical = settings.invertVertical;
    final detector = _detector;
    if (detector is MlKitGazeDetector) {
      detector.calibrate(
        mirrorHorizontal: settings.mirrorHorizontal,
        invertVertical: settings.invertVertical,
      );
    }
    if (_dwell.dwellDuration != settings.dwellDuration) {
      // A half-filled hold measured against the old duration would fire at
      // the wrong moment, so start the hold over on the new one.
      _dwell = DwellTracker(dwellDuration: settings.dwellDuration);
    }
    _blink.reset();
  }

  // ── Debug-only remote input ────────────────────────────────────────────
  //
  // A real device cannot be tested end-to-end without a person moving their
  // head in front of it. In debug and profile builds the gaze debug bridge
  // (`gaze_debug_bridge.dart`) can stand in for that person: it lists the live
  // controllers here and can replace the camera's head pose for a while, so
  // the dwell, sensitivity, blink and calibration logic all run exactly as
  // they would for a learner. Compiled out of release builds (`kReleaseMode`).

  /// Live controllers, oldest first. Debug and profile builds only.
  static final List<GazeController> debugLive = [];

  /// When non-null and returning a pose, that pose replaces what the camera
  /// saw — raw head angles in ML Kit's frame, before calibration.
  static ({double yaw, double pitch, double leftEye, double rightEye})?
  Function()?
  debugPoseSource;

  int _debugFrames = 0;

  /// A snapshot for the debug bridge.
  Map<String, Object?> debugDescribe() => {
    'status': _status.name,
    'suspended': _suspended,
    'faceVisible': _faceVisible,
    'zone': _zone.name,
    'progress': double.parse(_progress.toStringAsFixed(2)),
    'blinkSelects': _blinkEnabled,
    'turnThresholdDeg': _turnThreshold,
    'tiltThresholdDeg': _tiltThreshold,
    'dwellMs': _dwell.dwellDuration.inMilliseconds,
    'mirrorHorizontal': _mirrorHorizontal,
    'invertVertical': _invertVertical,
    'framesProcessed': _debugFrames,
  };

  /// Fires a completed hold on [zone], as if the learner had held it.
  void debugSelect(GazeZone zone) {
    if (kReleaseMode || _disposed) return;
    onSelect?.call(zone);
  }

  /// Fires a deliberate blink — ignored when blink isn't a selector here,
  /// exactly as a real blink would be.
  bool debugBlink() {
    if (kReleaseMode || _disposed || !_blinkEnabled) return false;
    onBlink?.call();
    return true;
  }

  /// Fired once when a dwell completes on a (non-none) zone.
  void Function(GazeZone zone)? onSelect;

  /// Fired once per deliberate long blink (when blink is enabled).
  VoidCallback? onBlink;

  CameraController? _controller;
  CameraDescription? _frontCamera;
  GazeStatus _status = GazeStatus.initializing;
  bool _initInFlight = false;
  bool _isDetecting = false;
  bool _streaming = false;
  bool _disposed = false;

  // ~15 fps: enough samples for the One Euro filter to smooth well and keep
  // latency low, without pegging the CPU on a mid-range tablet.
  static const Duration _minFrameGap = Duration(milliseconds: 66);
  Duration _lastProcessed = Duration.zero;

  bool _faceVisible = false;
  GazeZone _zone = GazeZone.none;
  double _progress = 0;

  GazeStatus get status => _status;
  bool get faceVisible => _faceVisible;
  GazeZone get zone => _zone;
  double get progress => _progress;

  CameraController? get cameraController => _controller;
  bool get isReady => _status == GazeStatus.ready && _controller != null;

  /// Begins observing the app lifecycle and acquires the front camera.
  Future<void> start() {
    WidgetsBinding.instance.addObserver(this);
    if (!kReleaseMode && !debugLive.contains(this)) debugLive.add(this);
    return _initCamera();
  }

  @override
  void dispose() {
    _disposed = true;
    if (!kReleaseMode) debugLive.remove(this);
    WidgetsBinding.instance.removeObserver(this);
    _teardownController();
    _detector.close();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Another camera surface is on top of this one's screen (see
  /// `GazeCameraOwners.isTop`).
  bool _suspended = false;

  /// A resume arrived while a start was still in flight; start again once it
  /// settles, so the camera can never be left down.
  bool _restartAfterInit = false;

  /// Whether the camera is stood down for another camera surface.
  bool get suspended => _suspended;

  /// Stands the camera down because another camera surface is now on top —
  /// the hardware runs one session at a time. The controller stays alive and
  /// keeps its tuning; [resumeCamera] brings the camera back.
  void suspendCamera() {
    if (_suspended || _disposed) return;
    _suspended = true;
    _restartAfterInit = false;
    _teardownController();
    _status = GazeStatus.initializing;
    _notify();
  }

  /// Re-acquires the camera after [suspendCamera].
  void resumeCamera() {
    if (!_suspended || _disposed) return;
    _suspended = false;
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Never tear down a controller still initializing: the permission dialog
      // itself sends `inactive`, and disposing mid-initialize crashes the
      // plugin. (Same guard as ObjectScanScreen.)
      if (controller != null && controller.value.isInitialized) {
        _teardownController();
        _status = GazeStatus.initializing;
        _notify();
      }
    } else if (state == AppLifecycleState.resumed &&
        controller == null &&
        !_initInFlight &&
        !_suspended &&
        _status != GazeStatus.noCamera) {
      _initCamera();
    }
  }

  void _teardownController() {
    final controller = _controller;
    // Null it first so any in-flight `_initCameraInner` sees itself as stale and
    // disposes the controller *after* initialize() finishes.
    _controller = null;
    _streaming = false;
    _isDetecting = false;
    _dwell.reset();
    _blink.reset();
    _clock
      ..stop()
      ..reset();
    if (controller == null) return;
    if (controller.value.isInitialized) {
      _disposeController(controller);
    }
    // If it isn't initialized yet, do NOT dispose here: CameraX throws
    // `releaseFlutterSurfaceTexture() ... not yet been initialized` when the
    // preview surface doesn't exist. The init path disposes it once ready.
  }

  /// Disposes a camera controller defensively — stops the image stream first
  /// and swallows the platform errors that can surface during teardown.
  void _disposeController(CameraController controller) {
    () async {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
      try {
        await controller.dispose();
      } catch (_) {}
    }();
  }

  Future<void> _initCamera() async {
    if (_disposed || _suspended) return;
    if (_initInFlight) {
      _restartAfterInit = true;
      return;
    }
    _initInFlight = true;
    try {
      await _initCameraInner();
    } finally {
      _initInFlight = false;
      final again = _restartAfterInit;
      _restartAfterInit = false;
      if (again && !_disposed && !_suspended && _controller == null) {
        _initCamera();
      }
    }
  }

  Future<void> _initCameraInner() async {
    if (_status != GazeStatus.initializing) {
      _status = GazeStatus.initializing;
      _notify();
    }
    List<CameraDescription> cameras;
    try {
      cameras = await camerasLoader();
    } catch (_) {
      // Any failure enumerating cameras — a CameraException, or a platform
      // channel that isn't there at all — means the same thing to a learner:
      // gaze can't run here. Degrade to the friendly no-camera fallback rather
      // than letting it escape as an unhandled async error, which is what the
      // initialize() path below already does.
      cameras = const [];
    }
    if (_disposed) return;

    final front = cameras
        .where((c) => c.lensDirection == CameraLensDirection.front)
        .firstOrNull;
    if (front == null) {
      _status = GazeStatus.noCamera;
      _notify();
      return;
    }
    _frontCamera = front;

    final controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _controller = controller;

    try {
      await controller.initialize();
      // Torn down during initialize(): now that the surface exists, dispose
      // safely here (doing it earlier would hit the CameraX surface crash).
      if (_disposed || !identical(_controller, controller)) {
        _disposeController(controller);
        return;
      }
      _clock
        ..reset()
        ..start();
      await controller.startImageStream(_onFrame);
      if (_disposed || !identical(_controller, controller)) {
        _disposeController(controller);
        return;
      }
      _streaming = true;
      _status = GazeStatus.ready;
      _notify();
    } on CameraException catch (e) {
      if (!identical(_controller, controller)) return;
      _controller = null;
      _disposeController(controller);
      if (_disposed) return;
      _status = e.code.startsWith('CameraAccess')
          ? GazeStatus.permissionDenied
          : GazeStatus.failed;
      _notify();
    } catch (_) {
      if (!identical(_controller, controller)) return;
      _controller = null;
      _disposeController(controller);
      if (_disposed) return;
      _status = GazeStatus.failed;
      _notify();
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_isDetecting || !_streaming || _disposed) return;
    final now = _clock.elapsed;
    if (now - _lastProcessed < _minFrameGap) return;
    _isDetecting = true;
    _lastProcessed = now;
    try {
      final controller = _controller;
      final camera = _frontCamera;
      if (controller == null || camera == null) return;
      if (!kReleaseMode) {
        _debugFrames++;
        final pose = debugPoseSource?.call();
        if (pose != null) {
          _applySignal(
            faceSignalFromAngles(
              rawEulerY: pose.yaw,
              rawEulerX: pose.pitch,
              leftEyeOpen: pose.leftEye,
              rightEyeOpen: pose.rightEye,
              mirrorHorizontal: _mirrorHorizontal,
              invertVertical: _invertVertical,
            ),
            now,
          );
          return;
        }
      }
      final input = _inputImageFromCameraImage(image, controller, camera);
      if (input == null) return;
      final signal = await _detector.detect(input);
      if (_disposed || !_streaming) return;
      _applySignal(signal, now);
    } catch (_) {
      // A single bad frame must never kill the stream.
    } finally {
      _isDetecting = false;
    }
  }

  void _applySignal(FaceSignal signal, Duration now) {
    _faceVisible = signal.hasFace;

    final zone = resolveGazeZone(
      signal,
      turnThresholdDeg: _turnThreshold,
      tiltThresholdDeg: _tiltThreshold,
    );
    final reading = _dwell.update(zone, now);
    final blinked =
        _blinkEnabled &&
        signal.hasFace &&
        _blink.update(signal.leftEyeOpen, signal.rightEyeOpen, now);

    _zone = reading.zone;
    _progress = reading.progress;
    _notify();

    if (reading.justSelected) {
      onSelect?.call(reading.zone);
    } else if (blinked) {
      onBlink?.call();
    }
  }

  /// Builds an ML Kit [InputImage] from a [CameraImage], handling rotation and
  /// the single-plane NV21 (Android) / BGRA (iOS) formats. Returns null for an
  /// unexpected format/orientation so the frame is simply skipped. Follows the
  /// official `google_mlkit_face_detection` example; the most device-dependent
  /// part of the feature and not unit-testable off-device.
  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraController controller,
    CameraDescription camera,
  ) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      final compensation =
          _kOrientationDegrees[controller.value.deviceOrientation];
      if (compensation == null) return null;
      final rotationDeg = camera.lensDirection == CameraLensDirection.front
          ? (sensorOrientation + compensation) % 360
          : (sensorOrientation - compensation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(rotationDeg);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    final formatOk = Platform.isAndroid
        ? format == InputImageFormat.nv21
        : format == InputImageFormat.bgra8888;
    if (!formatOk || image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}
