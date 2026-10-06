import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:pwdpwdpwd/features/gaze_control/controllers/gaze_controller.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';

/// The real `GazeController` camera pipeline — controller, image stream,
/// frame pacing, detection, watchdog — on a stand-in camera, in real time.
///
/// On the tablet, face tracking stayed dead after the camera restarted: the
/// frame clock started over but the time of the last frame read did not, so
/// every new frame looked "too soon" for as long as the camera had run
/// before. Status said ready, the last face reading stayed on screen, nothing
/// answered. These tests run that path end to end.

const _front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 270,
);

/// A camera that sends a frame when told to.
class _FakeCamera extends CameraPlatform {
  final Map<int, StreamController<CameraImageData>> _frames = {};
  final Map<int, StreamController<CameraInitializedEvent>> _ready = {};

  /// Open, and never fires: the camera package waits on its first event.
  final StreamController<CameraErrorEvent> _errors =
      StreamController.broadcast();
  int _nextId = 1;
  int opened = 0;
  int closed = 0;

  @override
  Future<List<CameraDescription>> availableCameras() async => const [_front];

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    final id = _nextId++;
    opened++;
    _ready[id] = StreamController.broadcast();
    _frames[id] = StreamController.broadcast();
    return id;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _ready[cameraId]!.stream;

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    scheduleMicrotask(
      () => _ready[cameraId]!.add(
        CameraInitializedEvent(
          cameraId,
          640,
          480,
          ExposureMode.auto,
          false,
          FocusMode.auto,
          false,
        ),
      ),
    );
  }

  @override
  bool supportsImageStreaming() => true;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) => _frames[cameraId]!.stream;

  @override
  Future<void> dispose(int cameraId) async {
    closed++;
    await _frames.remove(cameraId)?.close();
    await _ready.remove(cameraId)?.close();
  }

  /// One frame from every open camera. (The test host is neither Android nor
  /// iOS, so the controller asks for — and accepts — BGRA frames.)
  void frame() {
    for (final stream in _frames.values) {
      stream.add(
        CameraImageData(
          format: const CameraImageFormat(
            ImageFormatGroup.bgra8888,
            raw: 1111970369,
          ),
          planes: [
            CameraImagePlane(bytes: Uint8List(16), bytesPerRow: 8),
          ],
          height: 2,
          width: 2,
        ),
      );
    }
  }
}

/// Reports a face in every frame.
class _FaceDetector implements GazeDetector {
  int reads = 0;
  @override
  Future<FaceSignal> detect(InputImage image) async {
    reads++;
    return const FaceSignal(hasFace: true);
  }

  @override
  Future<void> close() async {}
}

int _framesRead(GazeController c) =>
    c.debugDescribe()['framesProcessed'] as int;

Future<void> _until(bool Function() ok, {int ms = 3000}) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (!ok() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// Frames at a learner-like pace: one every 100 ms, [n] of them.
Future<void> _stream(_FakeCamera camera, int n) async {
  for (var i = 0; i < n; i++) {
    camera.frame();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCamera camera;
  late CameraPlatform real;
  setUp(() {
    real = CameraPlatform.instance;
    camera = _FakeCamera();
    CameraPlatform.instance = camera;
  });
  tearDown(() => CameraPlatform.instance = real);

  GazeController controller() => GazeController(
    settings: const GazeSettings(enabled: true),
    camerasLoader: () async => const [_front],
    detectorFactory: _FaceDetector.new,
  );

  test('frames are read on a running camera', () async {
    final c = controller();
    await c.start();
    expect(c.status, GazeStatus.ready);
    await _stream(camera, 5);
    expect(_framesRead(c), greaterThanOrEqualTo(4));
    expect(c.faceVisible, isTrue);
    c.dispose();
  });

  test('a camera that stands down and comes back reads frames again at once',
      () async {
    final c = controller();
    await c.start();
    // A while of tracking first — the length the old bug then went dead for.
    await _stream(camera, 8);
    final before = _framesRead(c);
    expect(before, greaterThan(4));

    // Covered by another camera screen, then uncovered (the same teardown
    // and restart as the app going to the background and back).
    c.suspendCamera();
    c.resumeCamera();
    await _until(() => c.status == GazeStatus.ready);
    expect(c.status, GazeStatus.ready);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _stream(camera, 4);
    expect(_framesRead(c), greaterThan(before),
        reason: 'frames are read again, not skipped for as long as the '
            'camera had already been running');
    expect(camera.opened, 2);
    c.dispose();
  });

  test('a camera that stops sending frames is restarted, and reads frames '
      'again', () async {
    final c = controller();
    await c.start();
    await _stream(camera, 4);
    final before = _framesRead(c);

    // Silence: no frame for longer than the watchdog allows.
    await Future<void>.delayed(
      GazeController.streamStallLimit + const Duration(milliseconds: 2000),
    );
    expect(c.debugStreamRestarts, 1);
    await _until(() => c.status == GazeStatus.ready);
    expect(camera.opened, 2, reason: 'a fresh camera session');
    expect(camera.closed, greaterThanOrEqualTo(1),
        reason: 'the old one closed first');

    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _stream(camera, 4);
    expect(_framesRead(c), greaterThan(before));
    expect(c.debugStreamRestarts, 1, reason: 'and no restart while it runs');
    c.dispose();
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('a reading that never comes back does not stop the frames after it',
      () async {
    final c = controller();
    await c.start();
    await _stream(camera, 3);
    final before = _framesRead(c);
    c.debugHangDetections(1);
    await _stream(camera, 2);
    await Future<void>.delayed(
      GazeController.detectTimeout + const Duration(milliseconds: 300),
    );
    expect(c.debugDetectorRestarts, 1);
    await _stream(camera, 4);
    expect(_framesRead(c), greaterThan(before + 1));
    expect(c.faceVisible, isTrue, reason: 'the fresh detector sees the face');
    c.dispose();
  }, timeout: const Timeout(Duration(seconds: 30)));
}
