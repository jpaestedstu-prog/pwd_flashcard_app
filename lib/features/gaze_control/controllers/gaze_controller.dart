import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../logic/blink_detector.dart';
import '../logic/dwell_tracker.dart';
import '../logic/gaze_zone_resolver.dart';
import '../logic/one_euro_filter.dart';
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
       _usesCamera = settings.usesCamera,
       _restYaw = settings.restYaw,
       _restPitch = settings.restPitch,
       _restSelectEnabled = settings.restSelects,
       _restSelectDuration = settings.dwellSelectDuration,
       _smoothing = settings.smoothing,
       _dwell = DwellTracker(dwellDuration: settings.dwellDuration),
       _detectorFactory = detectorFactory {
    _detector = _newDetector();
  }
  final Future<List<CameraDescription>> Function() camerasLoader;
  final GazeDetector Function()? _detectorFactory;

  /// Replaced when it stops answering (see [detectTimeout]).
  late GazeDetector _detector;

  GazeDetector _newDetector() =>
      _detectorFactory?.call() ??
      MlKitGazeDetector(
        mirrorHorizontal: _mirrorHorizontal,
        invertVertical: _invertVertical,
      );

  /// How long one frame's face detection may take before the detector is
  /// written off. A frame normally takes a few tens of milliseconds.
  ///
  /// On the tablet, with a real learner, face tracking froze after a few
  /// minutes: one detection never completed, and since each frame waits for
  /// the one before it, every later frame was skipped for good. The camera
  /// kept streaming, the highlight kept showing, and the learner's head and
  /// blinks did nothing at all until the screen was left.
  static const Duration detectTimeout = Duration(seconds: 2);

  /// How long the camera may go without delivering a frame before the stream
  /// is restarted.
  static const Duration streamStallLimit = Duration(seconds: 5);
  DwellTracker _dwell;
  final BlinkDetector _blink = BlinkDetector();
  final Stopwatch _clock = Stopwatch();
  double _turnThreshold;
  double _tiltThreshold;
  bool _blinkEnabled;
  bool _mirrorHorizontal;
  bool _invertVertical;

  /// False for switch scanning: no camera at all, the highlight moves by
  /// itself and a switch press picks.
  final bool _usesCamera;

  /// The learner's resting head position (raw camera angles); readings are
  /// measured from here instead of from straight ahead.
  double _restYaw;
  double _restPitch;

  /// Look and hold to select.
  bool _restSelectEnabled;
  Duration _restSelectDuration;

  GazeSmoothing _smoothing;
  OneEuroFilter? _turnFilter;
  OneEuroFilter? _tiltFilter;

  /// Whether this controller opens the camera (see [GazeSettings.usesCamera]).
  bool get usesCamera => _usesCamera;

  /// Re-tunes a running controller in place: sensitivity, hold time, blink
  /// and the left/right · up/down calibration all take effect on the next
  /// frame, with no camera restart.
  ///
  /// The navigation shell's controller lives for the whole session, so
  /// without this a teacher who changed a learner's sensitivity saw nothing
  /// happen — the shell kept the values it was started with until something
  /// happened to bounce its camera.
  ///
  /// Switching the camera on or off ([GazeSettings.usesCamera]) is the one
  /// change this cannot make in place — the owner restarts the controller.
  void applySettings(GazeSettings settings) {
    _turnThreshold = settings.turnThresholdDeg;
    _tiltThreshold = settings.tiltThresholdDeg;
    _blinkEnabled = settings.blinkSelects;
    _mirrorHorizontal = settings.mirrorHorizontal;
    _invertVertical = settings.invertVertical;
    _restYaw = settings.restYaw;
    _restPitch = settings.restPitch;
    _restSelectDuration = settings.dwellSelectDuration;
    if (_restSelectEnabled != settings.restSelects) {
      _restSelectEnabled = settings.restSelects;
      disarmRestSelect();
    }
    if (_smoothing != settings.smoothing) {
      _smoothing = settings.smoothing;
      _turnFilter = null;
      _tiltFilter = null;
    }
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

  /// The last head angles, as the camera read them and as the zone was
  /// decided on (rest offset + smoothing) — for measuring smoothing on a real
  /// face from the debug bridge.
  double _debugRawTurn = 0, _debugRawTilt = 0, _debugTurn = 0, _debugTilt = 0;

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
    'usesCamera': _usesCamera,
    'rest': [_restYaw, _restPitch],
    'smoothing': _smoothing.name,
    'restSelect': _restSelectEnabled,
    'restArmed': _restArmed,
    'restProgress': double.parse(_restProgress.toStringAsFixed(2)),
    'framesProcessed': _debugFrames,
    'detectorRestarts': debugDetectorRestarts,
    'streamRestarts': debugStreamRestarts,
    'angles': [
      for (final v in [_debugRawTurn, _debugRawTilt, _debugTurn, _debugTilt])
        double.parse(v.toStringAsFixed(1)),
    ],
  };

  /// Fires a completed hold on [zone], as if the learner had held it.
  void debugSelect(GazeZone zone) {
    if (kReleaseMode || _disposed) return;
    onSelect?.call(zone);
  }

  /// Feeds one camera reading through the whole pipeline (resting position,
  /// smoothing, dwell, blink, keep-still) as if it had come from a frame.
  @visibleForTesting
  void debugFeed(FaceSignal signal, Duration now) {
    if (kReleaseMode || _disposed) return;
    _applySignal(signal, now);
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
    if (!_usesCamera) {
      // Switch scanning: nothing to start. Report ready (and a "face", so no
      // affordance asks the learner to look at a camera that is not on).
      _status = GazeStatus.ready;
      _faceVisible = true;
      _notify();
      return Future.value();
    }
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
  ///
  /// Switch scanning has no camera, but is suspended all the same: the scopes
  /// read [suspended] to stand their scanner and switch down while covered,
  /// and to take them back when uncovered. Without it a covered switch screen
  /// kept scanning underneath, and never took its switch back afterwards — the
  /// learner's presses went nowhere once they returned.
  void suspendCamera() {
    if (_suspended || _disposed) return;
    _suspended = true;
    // A keep-still pending on this screen must not fire when it comes back.
    disarmRestSelect();
    if (!_usesCamera) {
      _notify();
      return;
    }
    _restartAfterInit = false;
    _teardownController();
    _status = GazeStatus.initializing;
    _notify();
  }

  /// Re-acquires the camera after [suspendCamera].
  void resumeCamera() {
    if (!_suspended || _disposed) return;
    _suspended = false;
    if (!_usesCamera) {
      _notify();
      return;
    }
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_usesCamera) return;
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
    _stopWatchdog();
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
      _startWatchdog();
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
    _lastFrameAt = _clock.elapsed;
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
      await _detectFrame(input, now);
    } catch (_) {
      // A single bad frame must never kill the stream.
    } finally {
      _isDetecting = false;
    }
  }

  /// One frame's face detection — written off, and the detector replaced,
  /// when it takes longer than [detectTimeout].
  Future<void> _detectFrame(InputImage input, Duration now) async {
    final FaceSignal signal;
    try {
      signal = await _detector.detect(input).timeout(detectTimeout);
    } on TimeoutException {
      _replaceDetector();
      return;
    }
    if (_disposed || !_streaming) return;
    _applySignal(signal, now);
  }

  /// Runs [_detectFrame] on [input], as a camera frame would (tests).
  @visibleForTesting
  Future<void> debugDetectFrame(InputImage input, Duration now) =>
      _detectFrame(input, now);

  /// The detector stopped answering: start a fresh one, and say the face is
  /// not seen until it answers — a hung reading must not leave the last head
  /// position (and a "face found") standing as if the learner were frozen.
  void _replaceDetector() {
    if (_disposed) return;
    debugDetectorRestarts++;
    final old = _detector;
    _detector = _newDetector();
    old.close().catchError((Object _) {});
    _faceVisible = false;
    _dwell.reset();
    _blink.reset();
    _turnFilter?.reset();
    _tiltFilter?.reset();
    _zone = GazeZone.none;
    _progress = 0;
    _notify();
  }

  // ── Watchdog ───────────────────────────────────────────────────────────

  Timer? _watchdog;
  Duration _lastFrameAt = Duration.zero;

  /// Times the detector or the camera stream was restarted (debug bridge).
  int debugDetectorRestarts = 0;
  int debugStreamRestarts = 0;

  void _startWatchdog() {
    _watchdog?.cancel();
    _lastFrameAt = _clock.elapsed;
    _watchdog = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      checkStream();
    });
  }

  void _stopWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  /// Restarts the camera when it has stopped delivering frames altogether
  /// (the stream can die without an error). Called by the watchdog; public
  /// for tests.
  @visibleForTesting
  void checkStream() {
    if (_disposed || _suspended || !_streaming || _initInFlight) return;
    if (_clock.elapsed - _lastFrameAt < streamStallLimit) return;
    debugStreamRestarts++;
    _teardownController();
    _status = GazeStatus.initializing;
    _notify();
    _initCamera();
  }

  void _applySignal(FaceSignal raw, Duration now) {
    _faceVisible = raw.hasFace;
    final samples = _restSamples;
    if (samples != null && raw.hasFace) {
      samples.add((raw.headTurn, raw.headTilt));
    }

    final signal = _steadied(raw, now);
    if (raw.hasFace) {
      _debugRawTurn = raw.headTurn;
      _debugRawTilt = raw.headTilt;
      _debugTurn = signal.headTurn;
      _debugTilt = signal.headTilt;
    }
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
    final rested = _updateRest(reading.zone, signal.hasFace, now);

    _zone = reading.zone;
    _progress = reading.progress;
    _notify();

    if (reading.justSelected) {
      onSelect?.call(reading.zone);
    } else if (blinked) {
      onBlink?.call();
    } else if (rested) {
      onRest?.call();
    }
  }

  /// The head angle measured from the learner's resting position and
  /// steadied by the One Euro filter — what the zone is decided on.
  FaceSignal _steadied(FaceSignal raw, Duration now) {
    if (!raw.hasFace) {
      // A lost face must not leave the filter remembering the old angle.
      _turnFilter?.reset();
      _tiltFilter?.reset();
      return raw;
    }
    var turn = raw.headTurn - _restYaw * (_mirrorHorizontal ? -1 : 1);
    var tilt = raw.headTilt - _restPitch * (_invertVertical ? -1 : 1);
    final params = switch (_smoothing) {
      GazeSmoothing.off => null,
      GazeSmoothing.light => (minCutoff: 1.2, beta: 0.04),
      GazeSmoothing.strong => (minCutoff: 0.5, beta: 0.02),
    };
    if (params != null) {
      _turnFilter ??= OneEuroFilter(
        minCutoff: params.minCutoff,
        beta: params.beta,
      );
      _tiltFilter ??= OneEuroFilter(
        minCutoff: params.minCutoff,
        beta: params.beta,
      );
      turn = _turnFilter!.filter(turn, now);
      tilt = _tiltFilter!.filter(tilt, now);
    }
    return FaceSignal(
      hasFace: true,
      headTurn: turn,
      headTilt: tilt,
      leftEyeOpen: raw.leftEyeOpen,
      rightEyeOpen: raw.rightEyeOpen,
    );
  }

  // ── Look and hold to select ────────────────────────────────────────────

  /// Fired once when the learner has kept still on an armed highlight for the
  /// keep-still time (see [armRestSelect]).
  VoidCallback? onRest;

  bool _restArmed = false;
  Duration? _restSince;
  double _restProgress = 0;

  /// How far the keep-still timer has filled, 0 … 1 — for a progress ring.
  double get restProgress => _restProgress;

  /// Whether a keep-still is currently counting toward a selection.
  bool get restArmed => _restArmed;

  /// Arms look-and-hold for the control that has just been highlighted: once
  /// the head comes back to rest and stays there for the keep-still time, it
  /// opens. Armed again by every move, so resting where you already are does
  /// nothing — only a highlight you moved to can be picked this way.
  void armRestSelect() {
    if (!_restSelectEnabled) return;
    _restArmed = true;
    _restSince = null;
    _restProgress = 0;
  }

  /// Stops a pending keep-still (the screen changed, something covers it).
  void disarmRestSelect() {
    _restArmed = false;
    _restSince = null;
    _restProgress = 0;
  }

  /// Advances the keep-still timer; true on the frame it completes.
  bool _updateRest(GazeZone zone, bool face, Duration now) {
    if (!_restArmed) return false;
    if (!face || zone != GazeZone.none) {
      _restSince = null;
      _restProgress = 0;
      return false;
    }
    final since = _restSince ??= now;
    final total = _restSelectDuration.inMicroseconds;
    final elapsed = (now - since).inMicroseconds;
    _restProgress = total <= 0 ? 1 : (elapsed / total).clamp(0.0, 1.0);
    if (_restProgress < 1) return false;
    disarmRestSelect();
    return true;
  }

  // ── Resting position ───────────────────────────────────────────────────

  List<(double, double)>? _restSamples;

  /// Watches the learner hold still for [window] and returns their resting
  /// head position as raw camera angles (for [GazeSettings.restYaw] /
  /// [GazeSettings.restPitch]), or null when it could not tell — the face was
  /// not seen in enough frames, or the head was moving.
  Future<({double yaw, double pitch})?> captureRestPosition({
    Duration window = const Duration(seconds: 2),
  }) async {
    final samples = <(double, double)>[];
    _restSamples = samples;
    await Future<void>.delayed(window);
    if (identical(_restSamples, samples)) _restSamples = null;
    return restFromSamples(
      samples,
      mirrorHorizontal: _mirrorHorizontal,
      invertVertical: _invertVertical,
    );
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

/// The resting head position from the readings taken while a learner held
/// still, as raw camera angles — or null when there is not enough to go on.
///
/// [samples] are head angles in the learner's frame (after left/right and
/// up/down calibration); the result is converted back to the raw camera frame
/// so a later change to those calibration switches still measures from the
/// same physical position. Rejects fewer than eight readings (the face was not
/// seen), a spread wider than 6° (the head was moving), and anything further
/// than [GazeSettings.maxRestDeg] from straight ahead (looking away, not
/// resting). Pure, so the arithmetic is unit-tested without a camera.
({double yaw, double pitch})? restFromSamples(
  List<(double, double)> samples, {
  required bool mirrorHorizontal,
  required bool invertVertical,
}) {
  if (samples.length < 8) return null;
  double mean(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;
  final turns = samples.map((s) => s.$1);
  final tilts = samples.map((s) => s.$2);
  final turn = mean(turns);
  final tilt = mean(tilts);
  double spread(Iterable<double> v, double m) {
    final variance = mean(v.map((x) => (x - m) * (x - m)));
    return variance <= 0 ? 0 : math.sqrt(variance);
  }

  if (spread(turns, turn) > 6 || spread(tilts, tilt) > 6) return null;
  if (turn.abs() > GazeSettings.maxRestDeg ||
      tilt.abs() > GazeSettings.maxRestDeg) {
    return null;
  }
  return (
    yaw: turn * (mirrorHorizontal ? -1 : 1),
    pitch: tilt * (invertVertical ? -1 : 1),
  );
}
