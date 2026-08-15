import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/accessibility/tts_service.dart' show ttsServiceProvider;
import '../../../core/theme/app_colors.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../../data/models/achievements.dart';
import '../../../data/models/models.dart';
import '../../gaze_control/logic/voice_commands.dart';
import '../../gaze_control/providers/gaze_camera_owners.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';
import '../../gaze_control/widgets/voice_control_mixin.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../models/object_scan_models.dart';
import '../services/label_word_mapper.dart';
import '../services/object_labeler.dart';
import '../services/object_scan_discovery_service.dart';
import '../widgets/discovered_word_sheet.dart';
import '../widgets/hunt_target_strip.dart';
import '../widgets/photo_results_panel.dart';

enum _ScanStatus { initializing, ready, noCamera, permissionDenied, failed }

/// Where the learner is in the photo flow: aiming, waiting for the shutter,
/// or looking at a captured photo with its detected words.
enum _CapturePhase { preview, capturing, reviewing }

/// True when the device exposes both a front and a back lens, so the flip
/// control is worth showing. Pure (no platform channels) so it is unit
/// testable; the actual flip still needs a real camera on-device.
bool hasFrontAndBackCameras(List<CameraDescription> cameras) {
  final hasBack = cameras.any(
    (c) => c.lensDirection == CameraLensDirection.back,
  );
  final hasFront = cameras.any(
    (c) => c.lensDirection == CameraLensDirection.front,
  );
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
    with WidgetsBindingObserver, VoiceControlMixin {
  /// How many hunt targets ("try to find") the aiming panel suggests.
  static const int _targetCount = 3;

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

  /// Words this profile has already collected, so a result can be badged NEW
  /// and an already-found word can be dropped from the hunt targets.
  Set<String> _discovered = const {};

  /// The "try to find" suggestions, drawn once per visit so they don't shuffle
  /// under the learner between shots.
  List<Flashcard> _targets = const [];

  /// Suggestions the current photo actually landed. A hunt you were *asked* to
  /// go on should say so when you succeed — otherwise the target quietly
  /// vanishes from the strip and the win goes unmarked.
  List<Flashcard> _targetsHit = const [];

  @override
  void initState() {
    super.initState();
    _labeler = widget.labelerFactory();
    WidgetsBinding.instance.addObserver(this);
    // Claim the single camera so the shell's background nav-gaze stands its
    // camera down while Word Hunt's scanner is open (one camera at a time).
    gazeCameraOwners.acquire();
    // …so head control cannot run here: the gaze detector needs the front lens
    // and its own image stream. The **microphone** is free, though, so if the
    // learner drives the app hands-free, keep voice listening — it is their
    // only way to take a photo, pick a word, or leave. Same trade as Sign It
    // (`confirmHandsFreePause` warns them at the hub before they arrive).
    final gaze = ref.read(gazeSettingsProvider);
    if (gaze.enabled && gaze.voiceCommands) startVoiceControl();
    _loadDiscoveries();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    disposeVoiceControl();
    _controller?.dispose();
    _controller = null;
    _labeler.close();
    _deletePhoto();
    gazeCameraOwners.release();
    super.dispose();
  }

  /// Reads the profile's collection and tops the hunt targets back up from the
  /// words it is still missing.
  ///
  /// Targets the learner has *not* found yet are kept exactly where they are:
  /// a suggestion that reshuffles every time you take a photo is a suggestion
  /// nobody can act on. Only a target that has just been collected is retired
  /// and replaced.
  void _loadDiscoveries() {
    final discovered = ObjectScanDiscoveryService.discoveredWordIds(
      ref.read(profileProvider)?.id,
    );
    final kept = [
      for (final card in _targets)
        if (!discovered.contains(card.id)) card,
    ];
    final keptIds = {for (final card in kept) card.id};
    final pool = [
      for (final card in LabelWordMapper.huntableCards)
        if (!discovered.contains(card.id) && !keptIds.contains(card.id)) card,
    ]..shuffle(Random());
    _discovered = discovered;
    _targets = [...kept, ...pool.take(_targetCount - kept.length)];
  }

  /// Voice is the whole of hands-free control on this screen — see the note in
  /// [initState]. Commands are ignored while the discovered-word sheet is up:
  /// the controls they name are behind it, the same rule the gaze scopes apply
  /// under a covering route.
  @override
  void onVoiceCommand(String text) {
    if (!mounted || _sheetOpen) return;
    final reviewing = _phase == _CapturePhase.reviewing;
    final result = resolveWordHuntVoiceCommand(text, [
      if (reviewing)
        for (final m in _photoMatches)
          [m.card.wordEnglish, m.card.wordFilipino],
    ]);
    switch (result.intent) {
      case WordHuntVoiceIntent.goBack:
        Navigator.of(context).maybePop();
      case WordHuntVoiceIntent.capture:
        // While reviewing a photo, "take a photo" means the obvious thing:
        // start over and take the next one.
        reviewing ? _retake() : _capturePhoto();
      case WordHuntVoiceIntent.retake:
        if (reviewing) _retake();
      case WordHuntVoiceIntent.openCollection:
        _openCollection();
      case WordHuntVoiceIntent.openWord:
        if (reviewing && result.wordIndex < _photoMatches.length) {
          _openWord(_photoMatches[result.wordIndex]);
        }
      case WordHuntVoiceIntent.none:
        break;
    }
  }

  void _openCollection() {
    ref.read(hapticServiceProvider).lightTap();
    context.push('/word-hunt-collection').then((_) {
      if (mounted) setState(_loadDiscoveries);
    });
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
      setState(
        () => _status = e.code.startsWith('CameraAccess')
            ? _ScanStatus.permissionDenied
            : _ScanStatus.failed,
      );
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
      final matches = LabelWordMapper.matchAll(labels).take(3).toList();
      // Which of the "try to find" suggestions this shot actually landed —
      // captured now, because opening the word retires the target.
      final targetIds = {for (final card in _targets) card.id};
      setState(() {
        _photoMatches = matches;
        _targetsHit = [
          for (final m in matches)
            if (targetIds.contains(m.card.id)) m.card,
        ];
        _searching = false;
      });
      if (_targetsHit.isNotEmpty) {
        ref.read(hapticServiceProvider).celebration();
      }
      _announceResults();
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

  /// Says what the photo turned up. Word Hunt is a *visual* activity on a
  /// screen with no reading order — a learner with low vision had no way to
  /// know whether the shot found anything without inspecting the panel. This
  /// reads the outcome out loud, honouring the app's Text-to-Speech setting.
  void _announceResults() {
    if (!mounted || !ref.read(settingsProvider).ttsEnabled) return;
    final l10n = AppLocalizations.of(context)!;
    final tts = ref.read(ttsServiceProvider);
    if (_photoMatches.isEmpty) {
      tts.speakEnglish(l10n.wordHuntNoneFound);
      return;
    }
    final found = l10n.wordHuntSpokenFound(
      _photoMatches.length,
      _photoMatches.map((m) => m.card.wordEnglish).join(', '),
    );
    // Lead with the target win when there is one: a learner who cannot see the
    // green banner should still hear that they completed the hunt.
    if (_targetsHit.isEmpty) {
      tts.speakEnglish(found);
      return;
    }
    final words = _targetsHit.map((c) => c.wordEnglish).join(', ');
    tts.speakEnglish(
      '${_targetsHit.length == 1 ? l10n.wordHuntFoundTarget(words) : l10n.wordHuntFoundTargets(words)} $found',
    );
  }

  void _retake() {
    ref.read(hapticServiceProvider).lightTap();
    _deletePhoto();
    setState(() {
      _phase = _CapturePhase.preview;
      _searching = false;
      _photoMatches = const [];
      _targetsHit = const [];
    });
  }

  Future<void> _openWord(WordMatch match) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    final profileId = ref.read(profileProvider)?.id;
    final result = ObjectScanDiscoveryService.recordDiscovery(
      profileId,
      match.card.id,
    );
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
    // A camera find can cross a Word Hunt badge (First Find / Word Spotter /
    // Word Collector / Daily Hunter), so run the same achievement check the
    // games run and hand anything new to the sheet to celebrate. Only on a new
    // word: re-opening a collected one can't unlock anything.
    final unlocked = result.isNew
        ? ref.read(progressProvider.notifier).checkAchievements()
        : const <Achievement>[];
    if (!mounted) {
      _sheetOpen = false;
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DiscoveredWordSheet(
        card: match.card,
        isNewDiscovery: result.isNew,
        starAwarded: result.starAwarded,
        unlockedAchievements: unlocked,
      ),
    );
    _sheetOpen = false;
    // The word just joined the collection: drop its NEW badge and retire it
    // as a hunt target.
    if (mounted) setState(_loadDiscoveries);
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
            _FallbackState(status: _status, l10n: l10n, onRetry: _initCamera),
          SafeArea(
            child: Column(
              children: [
                _topBar(context, l10n),
                if (voiceActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: IgnorePointer(child: voiceChip()),
                  ),
                const Spacer(),
                if (showPhoto)
                  SingleChildScrollView(
                    reverse: true,
                    child: PhotoResultsPanel(
                      matches: _photoMatches,
                      searching: _searching,
                      newWordIds: _newIdsIn(_photoMatches),
                      targetsHit: _targetsHit,
                      targets: _photoMatches.isEmpty ? _targets : const [],
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

  /// Ids among [matches] the learner has never collected — badged NEW so the
  /// reward is visible *before* the tap, not only after it.
  Set<String> _newIdsIn(List<WordMatch> matches) => {
    for (final m in matches)
      if (!_discovered.contains(m.card.id)) m.card.id,
  };

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
          const SizedBox(width: 8),
          // The collection lives here rather than on the hub so it is always
          // one tap from the hunt — and stays reachable in the no-camera and
          // permission-denied states, where it is the only thing left to do.
          Semantics(
            button: true,
            label: l10n.wordHuntMyFinds,
            child: Material(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _openCollection,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎒', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        '${_discovered.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
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
          if (_targets.isNotEmpty) ...[
            HuntTargetStrip(targets: _targets),
            const SizedBox(height: 10),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              voiceActive
                  ? '${l10n.wordHuntPointCamera}  ${l10n.wordHuntSayTakePhoto}'
                  : l10n.wordHuntPointCamera,
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
