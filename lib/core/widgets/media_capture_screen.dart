import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:video_player/video_player.dart';

import '../../features/gaze_control/providers/gaze_camera_owners.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// What the capture screen makes.
enum CaptureMode { video, photo }

/// Opens the in-app camera and returns the path of what was captured, or null
/// if the person closed it.
///
/// The file is the camera plugin's own temporary file: the caller copies it
/// somewhere lasting (an assessment's media store, say) and may then delete
/// it.
Future<String?> captureMedia(
  BuildContext context, {
  required CaptureMode mode,
  Duration maxDuration = MediaCaptureScreen.defaultMaxDuration,
  bool enableAudio = true,
  String? title,
  String? prompt,
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => MediaCaptureScreen(
        mode: mode,
        maxDuration: maxDuration,
        enableAudio: enableAudio,
        title: title,
        prompt: prompt,
      ),
    ),
  );
}

/// Records a short video — a teacher signing a question in FSL, a learner
/// signing or saying their answer — or takes a photo, with the tablet's own
/// camera, so nobody has to record elsewhere and then hunt for the file.
///
/// Built for the people using it:
///
///  * **Front camera first.** Signing is recorded facing the signer, who
///    watches themselves in the preview as they sign.
///  * **A 3-2-1 before recording starts**, shown as big numbers, so a signer
///    has their hands up when the first frame is taken. Nothing moves — the
///    numbers simply change — so it is calm under Reduced Motion too.
///  * **Review before use.** The take plays back on a loop with "Use this
///    video" and "Record again", both large.
///  * **Screen-reader and deaf-friendly both ways**: starting and stopping
///    are announced to a screen reader and felt as a vibration, and the red
///    recording marker and time left are always on screen.
///  * **Small files.** 480p at 1 Mbit/s — about 7.5 MB a minute — so a take
///    fits the free plan's 15 MB sharing cap with room to spare.
///
/// It claims the device camera through [gazeCameraOwners], like every other
/// full-screen camera surface, so the background gaze camera stands down
/// while it is open.
class MediaCaptureScreen extends StatefulWidget {
  static const Duration defaultMaxDuration = Duration(seconds: 60);

  /// Video encoding settings; see the class notes.
  static const int videoBitrate = 1000000;
  static const int audioBitrate = 64000;

  final CaptureMode mode;
  final Duration maxDuration;
  final bool enableAudio;
  final String? title;

  /// Shown above the camera — the question being answered, say.
  final String? prompt;

  /// The device cameras. A seam: no test binding has the camera plugin.
  final Future<List<CameraDescription>> Function() camerasLoader;

  /// Seconds counted down before recording starts; 0 in tests.
  final int countdownSeconds;

  const MediaCaptureScreen({
    super.key,
    required this.mode,
    this.maxDuration = defaultMaxDuration,
    this.enableAudio = true,
    this.title,
    this.prompt,
    this.camerasLoader = availableCameras,
    this.countdownSeconds = 3,
  });

  @override
  State<MediaCaptureScreen> createState() => _MediaCaptureScreenState();
}

enum _Phase { starting, ready, countdown, recording, review, noCamera, denied, failed }

class _MediaCaptureScreenState extends State<MediaCaptureScreen>
    with WidgetsBindingObserver {
  /// This screen's place in the gaze camera-owner stack.
  Object? _cameraToken;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  CameraController? _camera;
  bool _initInFlight = false;
  _Phase _phase = _Phase.starting;

  int _countdown = 0;
  Timer? _ticker;
  DateTime? _recordingStarted;
  Duration _elapsed = Duration.zero;

  /// The take under review, and its player for a video.
  String? _capturedPath;
  VideoPlayerController? _review;

  /// Set when the take is handed back, so dispose does not delete it.
  bool _handedBack = false;

  bool get _isVideo => widget.mode == CaptureMode.video;

  AppLocalizations get _t =>
      AppLocalizations.of(context) ?? AppLocalizationsEn();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // On top of the camera-owner stack: a gaze screen beneath (a message
    // thread) stands its own camera and microphone down while this records.
    _cameraToken = gazeCameraOwners.acquire();
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    gazeCameraOwners.release(_cameraToken);
    _ticker?.cancel();
    _camera?.dispose();
    _review?.dispose();
    if (!_handedBack) _deleteCapture();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _camera;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _review?.pause();
      // A recording in flight goes with the controller; the partial take is
      // not kept. Only a fully initialised controller is disposed — tearing
      // one down mid-initialise (the permission dialog itself sends
      // `inactive`) crashes the plugin.
      if (cam != null && cam.value.isInitialized) {
        _ticker?.cancel();
        cam.dispose();
        _camera = null;
        if (_phase == _Phase.recording || _phase == _Phase.countdown) {
          _phase = _Phase.ready;
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_phase == _Phase.review) {
        _review?.play();
      } else if (_camera == null && _cameras.isNotEmpty) {
        _openCamera();
      }
    }
  }

  Future<void> _start() async {
    List<CameraDescription> cameras;
    try {
      cameras = await widget.camerasLoader();
    } on Object {
      cameras = const [];
    }
    if (!mounted) return;
    if (cameras.isEmpty) {
      setState(() => _phase = _Phase.noCamera);
      return;
    }
    _cameras = cameras;
    final front = cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    _cameraIndex = front == -1 ? 0 : front;
    await _openCamera();
  }

  Future<void> _openCamera() async {
    if (_initInFlight || _cameras.isEmpty) return;
    _initInFlight = true;
    if (mounted) setState(() => _phase = _Phase.starting);
    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.medium,
      enableAudio: _isVideo && widget.enableAudio,
      fps: 30,
      videoBitrate: MediaCaptureScreen.videoBitrate,
      audioBitrate: MediaCaptureScreen.audioBitrate,
    );
    _camera = controller;
    try {
      await controller.initialize();
      if (!mounted || !identical(_camera, controller)) return;
      setState(() => _phase = _Phase.ready);
    } on CameraException catch (e) {
      if (!identical(_camera, controller)) return;
      _camera = null;
      controller.dispose();
      if (mounted) {
        setState(
          () => _phase = e.code.startsWith('CameraAccess') ||
                  e.code.startsWith('AudioAccess')
              ? _Phase.denied
              : _Phase.failed,
        );
      }
    } on Object {
      if (!identical(_camera, controller)) return;
      _camera = null;
      controller.dispose();
      if (mounted) setState(() => _phase = _Phase.failed);
    } finally {
      _initInFlight = false;
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _phase != _Phase.ready) return;
    final old = _camera;
    _camera = null;
    await old?.dispose();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _openCamera();
  }

  void _announce(String message) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  // ─── Video ─────────────────────────────────────────────

  Future<void> _beginCountdown() async {
    if (_phase != _Phase.ready) return;
    if (widget.countdownSeconds <= 0) {
      await _startRecording();
      return;
    }
    setState(() {
      _phase = _Phase.countdown;
      _countdown = widget.countdownSeconds;
    });
    _announce(_t.captureGetReady);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _phase != _Phase.countdown) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        _startRecording();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _startRecording() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    try {
      await cam.startVideoRecording();
    } on Object {
      if (mounted) setState(() => _phase = _Phase.failed);
      return;
    }
    if (!mounted) return;
    _recordingStarted = DateTime.now();
    setState(() {
      _phase = _Phase.recording;
      _elapsed = Duration.zero;
    });
    _announce(_t.captureStarted);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final started = _recordingStarted;
      if (!mounted || started == null) return;
      final elapsed = DateTime.now().difference(started);
      if (elapsed >= widget.maxDuration) {
        _stopRecording();
      } else {
        setState(() => _elapsed = elapsed);
      }
    });
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    final cam = _camera;
    if (cam == null || !cam.value.isRecordingVideo) return;
    XFile file;
    try {
      file = await cam.stopVideoRecording();
    } on Object {
      if (mounted) setState(() => _phase = _Phase.failed);
      return;
    }
    _recordingStarted = null;
    if (!mounted) {
      _capturedPath = file.path;
      return;
    }
    _announce(_t.captureStopped);
    _capturedPath = file.path;
    final player = VideoPlayerController.file(File(file.path));
    try {
      await player.initialize();
      await player.setLooping(true);
      await player.play();
    } on Object {
      // The take exists even if it will not preview; it can still be used.
    }
    if (!mounted) {
      await player.dispose();
      return;
    }
    setState(() {
      _review = player;
      _phase = _Phase.review;
    });
  }

  // ─── Photo ─────────────────────────────────────────────

  Future<void> _takePhoto() async {
    final cam = _camera;
    if (cam == null || _phase != _Phase.ready) return;
    try {
      final file = await cam.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedPath = file.path;
        _phase = _Phase.review;
      });
    } on Object {
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  // ─── Review ────────────────────────────────────────────

  void _use() {
    final path = _capturedPath;
    if (path == null) return;
    _handedBack = true;
    Navigator.of(context).pop(path);
  }

  Future<void> _retake() async {
    await _review?.dispose();
    _review = null;
    _deleteCapture();
    if (!mounted) return;
    setState(() {
      _phase = _camera?.value.isInitialized ?? false
          ? _Phase.ready
          : _Phase.starting;
      _elapsed = Duration.zero;
    });
    if (_camera == null) await _openCamera();
  }

  void _deleteCapture() {
    final path = _capturedPath;
    _capturedPath = null;
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } on Object {
      // The camera's own temp folder; the OS reclaims it anyway.
    }
  }

  // ─── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final title =
        widget.title ?? (_isVideo ? t.captureRecordTitle : t.capturePhotoTitle);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        // Spelled out: the app theme's title colour is dark, and it wins over
        // [foregroundColor] — dark grey on black was barely there.
        titleTextStyle: AppTypography.titleLarge.copyWith(color: Colors.white),
        leading: IconButton(
          tooltip: t.captureClose,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.prompt != null && widget.prompt!.trim().isNotEmpty)
              Container(
                width: double.infinity,
                color: Colors.white10,
                padding: const EdgeInsets.all(14),
                child: Text(
                  widget.prompt!,
                  style: AppTypography.titleMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            Expanded(child: Center(child: _stage(t))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: _controls(t),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stage(AppLocalizations t) {
    switch (_phase) {
      case _Phase.noCamera:
        return _Message(icon: Icons.no_photography_rounded, text: t.captureNoCamera);
      case _Phase.denied:
        return _Message(icon: Icons.lock_rounded, text: t.captureDenied);
      case _Phase.failed:
        return _Message(icon: Icons.error_outline_rounded, text: t.captureFailed);
      case _Phase.starting:
        return const CircularProgressIndicator(color: Colors.white);
      case _Phase.review:
        final review = _review;
        final path = _capturedPath;
        if (!_isVideo && path != null) {
          return Image.file(File(path), fit: BoxFit.contain);
        }
        if (review != null && review.value.isInitialized) {
          return AspectRatio(
            aspectRatio: review.value.aspectRatio,
            child: VideoPlayer(review),
          );
        }
        return _Message(icon: Icons.check_circle_rounded, text: t.captureRecordedHint);
      case _Phase.ready:
      case _Phase.countdown:
      case _Phase.recording:
        final cam = _camera;
        if (cam == null || !cam.value.isInitialized) {
          return const CircularProgressIndicator(color: Colors.white);
        }
        return Stack(
          alignment: Alignment.center,
          children: [
            CameraPreview(cam),
            if (_phase == _Phase.countdown)
              Semantics(
                liveRegion: true,
                label: '$_countdown',
                child: Container(
                  width: 140,
                  height: 140,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$_countdown',
                    style: AppTypography.displayLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            if (_phase == _Phase.recording)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _RecordingBar(
                  elapsed: _elapsed,
                  max: widget.maxDuration,
                  label: t.captureRecordingNow,
                  timeLeft: t.captureTimeLeft(
                    (widget.maxDuration - _elapsed).inSeconds.clamp(0, 9999),
                  ),
                ),
              ),
          ],
        );
    }
  }

  Widget _controls(AppLocalizations t) {
    final big = FilledButton.styleFrom(minimumSize: const Size.fromHeight(64));
    switch (_phase) {
      case _Phase.noCamera:
      case _Phase.denied:
      case _Phase.failed:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                ),
                child: Text(t.captureClose),
              ),
            ),
            if (_phase != _Phase.noCamera) ...[
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _start,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: Text(t.captureTryAgain),
                ),
              ),
            ],
          ],
        );
      case _Phase.review:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _use,
              style: big,
              icon: const Icon(Icons.check_rounded),
              label: Text(_isVideo ? t.captureUse : t.captureUsePhoto),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _retake,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
              ),
              icon: const Icon(Icons.replay_rounded),
              label: Text(_isVideo ? t.captureRetake : t.captureRetakePhoto),
            ),
          ],
        );
      case _Phase.starting:
      case _Phase.ready:
      case _Phase.countdown:
      case _Phase.recording:
        final recording = _phase == _Phase.recording;
        final canSwitch =
            _cameras.length > 1 && _phase == _Phase.ready;
        return Column(
          children: [
            if (_isVideo && !recording)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  t.captureMaxLength(widget.maxDuration.inSeconds),
                  style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Keeps the shutter centred whether or not switching exists.
                SizedBox(
                  width: 56,
                  child: canSwitch
                      ? IconButton(
                          tooltip: t.captureSwitchCamera,
                          iconSize: 32,
                          color: Colors.white,
                          icon: const Icon(Icons.cameraswitch_rounded),
                          onPressed: _switchCamera,
                        )
                      : null,
                ),
                _Shutter(
                  recording: recording,
                  isVideo: _isVideo,
                  enabled: _phase == _Phase.ready || recording,
                  label: !_isVideo
                      ? t.captureTakePhoto
                      : recording
                      ? t.captureStop
                      : t.captureStart,
                  onPressed: !_isVideo
                      ? _takePhoto
                      : recording
                      ? _stopRecording
                      : _beginCountdown,
                ),
                const SizedBox(width: 56),
              ],
            ),
          ],
        );
    }
  }
}

/// The big round button: record, stop, or take the photo. Its label is always
/// spoken and always shown underneath, never an icon alone.
class _Shutter extends StatelessWidget {
  final bool recording;
  final bool isVideo;
  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  const _Shutter({
    required this.recording,
    required this.isVideo,
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          label: label,
          onTap: enabled ? onPressed : null,
          child: ExcludeSemantics(
            child: GestureDetector(
              onTap: enabled ? onPressed : null,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: recording ? 34 : 64,
                  height: recording ? 34 : 64,
                  decoration: BoxDecoration(
                    color: enabled
                        ? (isVideo ? AppColors.error : Colors.white)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(recording ? 8 : 32),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        ExcludeSemantics(
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _RecordingBar extends StatelessWidget {
  final Duration elapsed;
  final Duration max;
  final String label;
  final String timeLeft;

  const _RecordingBar({
    required this.elapsed,
    required this.max,
    required this.label,
    required this.timeLeft,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = max.inMilliseconds == 0
        ? 0.0
        : (elapsed.inMilliseconds / max.inMilliseconds).clamp(0.0, 1.0);
    return Semantics(
      label: '$label. $timeLeft',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.fiber_manual_record_rounded, color: HCColor.of(context).graphic(AppColors.error)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.labelLarge.copyWith(color: Colors.white),
                    ),
                  ),
                  Text(
                    timeLeft,
                    style: AppTypography.labelLarge.copyWith(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: fraction,
                color: AppColors.error,
                backgroundColor: Colors.white24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.white70),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
