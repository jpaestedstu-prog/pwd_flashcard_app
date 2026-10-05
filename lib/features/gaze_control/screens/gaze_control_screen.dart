import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/theme/app_colors.dart';
import '../controllers/gaze_controller.dart';
import '../logic/voice_commands.dart';
import '../models/gaze_models.dart';
import '../models/gaze_settings.dart';
import '../providers/gaze_camera_owners.dart';
import '../providers/gaze_settings_provider.dart';
import '../services/gaze_detector.dart';
import '../widgets/gaze_widgets.dart';
import '../widgets/voice_control_mixin.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// **Gaze Control practice** ("Try it now") — the learner tries every gesture
/// once, hands-free, and sees it register: a hold toward each of the four
/// edge targets and, when blinks pick, a long blink. Each lands with a ✓, and
/// once all are done the same gesture that picks things takes them back.
///
/// It follows the learner's settings rather than demonstrating a fixed
/// scheme: in **scanning mode** the targets light up in turn and a blink picks
/// the lit one, exactly as the rest of the app now scans; with blinks off,
/// looking up is the way back.
///
/// It used to be a dead end for the very learner it was for. The only way out
/// was the touch back button, the screen had no voice control, and it ignored
/// scanning mode — a blink-only learner opened it and could neither try
/// anything nor leave.
///
/// All work happens in [GazeController]; this screen is its full-screen
/// visualisation. [camerasLoader] and [detectorFactory] are injectable so
/// widget tests can render the camera-less fallback without platform channels.
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

/// The four practice targets, in the order scanning lights them (clockwise
/// from the top).
const List<GazeZone> _kTargets = [
  GazeZone.up,
  GazeZone.right,
  GazeZone.down,
  GazeZone.left,
];

class _GazeControlScreenState extends ConsumerState<GazeControlScreen>
    with VoiceControlMixin {
  GazeController? _gaze;
  GazeSettings _settings = const GazeSettings();
  Object? _cameraToken;

  /// Practice progress.
  final Set<GazeZone> _done = {};
  bool _blinkDone = false;

  /// Scanning mode: the target currently lit, and the timer that moves it.
  int _scanIndex = 0;
  Timer? _scanTimer;

  // Selection confirmation banner.
  String? _lastAction;
  int _bannerToken = 0;

  bool get _scanning => _settings.scanMode;

  /// Every gesture this learner's settings use has been tried. Scanning picks
  /// with a blink, so its four picks already include it.
  bool get _complete =>
      _done.length == _kTargets.length &&
      (_scanning || !_settings.blinkSelects || _blinkDone);

  @override
  void initState() {
    super.initState();
    final settings = ref.read(gazeSettingsProvider);
    _settings = settings;
    final gaze = GazeController(
      settings: settings,
      camerasLoader: widget.camerasLoader,
      detectorFactory: widget.detectorFactory,
    );
    gaze.onSelect = _onHold;
    gaze.onBlink = _onBlink;
    gaze.addListener(_onGazeUpdate);
    _gaze = gaze;
    // Claim the single camera so the shell's background nav-gaze stands down
    // while this full-screen preview owns it.
    _cameraToken = gazeCameraOwners.acquire();
    gaze.start();
    if (settings.scanMode) {
      _scanTimer = Timer.periodic(settings.scanStepDuration, (_) {
        if (!mounted) return;
        setState(() => _scanIndex = (_scanIndex + 1) % _kTargets.length);
      });
    }
    // The shell's microphone stood down with its camera, so listen here —
    // "go back" has to work on this screen too.
    if (settings.voiceCommands) startVoiceControl();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    disposeVoiceControl();
    _gaze?.removeListener(_onGazeUpdate);
    _gaze?.dispose();
    final token = _cameraToken;
    if (token != null) gazeCameraOwners.release(token);
    super.dispose();
  }

  void _onGazeUpdate() {
    if (mounted) setState(() {});
  }

  void _leave() {
    if (!mounted) return;
    ref.read(hapticServiceProvider).success();
    Navigator.of(context).maybePop();
  }

  /// A completed hold toward an edge.
  void _onHold(GazeZone zone) {
    // Scanning is for learners who cannot move their head.
    if (_scanning || zone == GazeZone.none) return;
    // With blinks off, looking up is the way back once everything is done.
    if (_complete && !_settings.blinkSelects && zone == GazeZone.up) {
      _leave();
      return;
    }
    _done.add(zone);
    _confirm(_actionFor(zone));
  }

  void _onBlink() {
    if (_complete) {
      _leave();
      return;
    }
    if (_scanning) {
      final zone = _kTargets[_scanIndex];
      _done.add(zone);
      _confirm(_actionFor(zone));
      return;
    }
    _blinkDone = true;
    _confirm(_t(context).gzSelect);
  }

  void _confirm(String action) {
    ref.read(hapticServiceProvider).success();
    final token = ++_bannerToken;
    setState(() => _lastAction = action);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _bannerToken == token) {
        setState(() => _lastAction = null);
      }
    });
  }

  @override
  void onVoiceCommand(String text) {
    if (!mounted) return;
    final intent = resolveDpadVoiceCommand(text, const []).intent;
    if (kDebugMode) debugPrint('VoiceCmd preview "$text" → $intent');
    switch (intent) {
      case DpadVoiceIntent.goBack:
        _leave();
      case DpadVoiceIntent.select:
        _onBlink();
      default:
        break;
    }
  }

  @override
  Map<String, Object?> debugDescribe() => {
    'scope': 'preview',
    'scanning': _scanning,
    if (_scanning) 'scanIndex': _scanIndex,
    'done': [for (final z in _done) z.name],
    'blinkDone': _blinkDone,
    'complete': _complete,
  };

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
    final chip = voiceChip();
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
          if (chip != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: SafeArea(
                child: IgnorePointer(child: Center(child: chip)),
              ),
            ),
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

  /// The target's label with a ✓ once it has been tried.
  String _labelFor(GazeZone zone, String label) =>
      _done.contains(zone) ? '✓  $label' : label;

  /// Whether [zone]'s target is lit: the held direction in head mode, the
  /// scanned one in scanning mode.
  bool _isLit(GazeZone zone) => _scanning
      ? !_complete && _kTargets[_scanIndex] == zone
      : _gaze!.zone == zone;

  Widget _target(
    GazeZone zone,
    String label,
    IconData icon,
    Color color,
    Alignment alignment,
  ) {
    final lit = _isLit(zone);
    return Align(
      alignment: alignment,
      child: GazeTarget(
        label: _labelFor(zone, label),
        icon: _done.contains(zone) ? Icons.check_rounded : icon,
        color: color,
        active: lit,
        // Scanning has no hold to fill, so a lit target shows a full ring.
        progress: _scanning
            ? (lit ? 1 : 0)
            : (_gaze!.zone == zone ? _gaze!.progress : 0),
      ),
    );
  }

  Widget _targetsLayer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            _target(
              GazeZone.up,
              _t(context).gzHearWord,
              Icons.volume_up_rounded,
              AppColors.info,
              Alignment.topCenter,
            ),
            _target(
              GazeZone.down,
              _t(context).gzFlipCard,
              Icons.flip_rounded,
              AppColors.accent,
              Alignment.bottomCenter,
            ),
            _target(
              GazeZone.left,
              _t(context).vgPrevious,
              Icons.arrow_back_rounded,
              AppColors.secondary,
              Alignment.centerLeft,
            ),
            _target(
              GazeZone.right,
              _t(context).next,
              Icons.arrow_forward_rounded,
              AppColors.success,
              Alignment.centerRight,
            ),
          ],
        ),
      ),
    );
  }

  /// What the learner should do now, centred: look at the screen, the next
  /// thing to try, or how to leave once everything is done.
  String? _instruction() {
    final t = _t(context);
    if (_complete) {
      final how = _settings.blinkSelects ? t.gzLeaveBlink : t.gzLeaveLookUp;
      return '${t.gzPracticeDone}\n$how';
    }
    if (_scanning) return t.gzFocusHintScan;
    final blinkLeft = _settings.blinkSelects && !_blinkDone;
    if (_done.length == _kTargets.length && blinkLeft) return t.gzBlink;
    return t.gzPracticeIntro;
  }

  Widget _centerHud() {
    final faceVisible = _gaze!.faceVisible;
    final resting = _gaze!.zone == GazeZone.none;
    final text = faceVisible ? _instruction() : _t(context).gzLook;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (faceVisible)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: resting ? 18 : 10,
              height: resting ? 18 : 10,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
            ),
          if (text != null) ...[
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(maxWidth: 320),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: _complete
                    ? AppColors.success.withValues(alpha: 0.85)
                    : Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ],
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
