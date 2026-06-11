import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/constants/flashcard_emojis.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../models/object_scan_models.dart';
import '../services/label_word_mapper.dart';
import '../services/object_labeler.dart';
import '../services/object_scan_discovery_service.dart';
import '../widgets/discovered_word_sheet.dart';

enum _ScanStatus { initializing, ready, noCamera, permissionDenied, failed }

/// Word Hunt — points the camera at real objects and turns on-device
/// ML Kit labels into tappable vocabulary words.
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
    with WidgetsBindingObserver {
  static const _minInferenceGap = Duration(milliseconds: 400);

  late final ObjectLabeler _labeler;
  CameraController? _controller;
  _ScanStatus _status = _ScanStatus.initializing;
  bool _initInFlight = false;

  bool _inferenceBusy = false;
  bool _sheetOpen = false;
  DateTime? _lastInferenceAt;

  List<WordMatch> _matches = const [];
  String? _hintLabel;

  @override
  void initState() {
    super.initState();
    _labeler = widget.labelerFactory();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _controller = null;
    _labeler.close();
    super.dispose();
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
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      // NV21 is what ML Kit consumes directly on Android.
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    _controller = controller;
    // After every await: if `_controller` no longer points at this
    // controller, dispose()/the lifecycle handler already tore it down —
    // this run is stale and must not dispose it a second time.
    try {
      await controller.initialize();
      if (!mounted || !identical(_controller, controller)) return;
      await controller.startImageStream(_onFrame);
      if (!mounted || !identical(_controller, controller)) return;
      setState(() => _status = _ScanStatus.ready);
    } on CameraException catch (e) {
      if (!identical(_controller, controller)) return;
      _controller = null;
      controller.dispose();
      if (!mounted) return;
      setState(() => _status = e.code.startsWith('CameraAccess')
          ? _ScanStatus.permissionDenied
          : _ScanStatus.failed);
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

  void _onFrame(CameraImage image) {
    if (_inferenceBusy || _sheetOpen || !mounted) return;
    final now = DateTime.now();
    final last = _lastInferenceAt;
    if (last != null && now.difference(last) < _minInferenceGap) return;
    final controller = _controller;
    if (controller == null) return;
    final input = inputImageFromCameraImage(
      image,
      camera: controller.description,
      deviceOrientation: controller.value.deviceOrientation,
    );
    if (input == null) return;
    _inferenceBusy = true;
    _lastInferenceAt = now;
    _labeler.labelImage(input).then((labels) {
      if (!mounted || _sheetOpen) return;
      final matches = LabelWordMapper.matchAll(labels);
      RecognizedLabel? top;
      for (final l in labels) {
        if (top == null || l.confidence > top.confidence) top = l;
      }
      setState(() {
        _matches = matches.take(3).toList();
        _hintLabel = matches.isEmpty ? top?.label : null;
      });
    }).catchError((Object _) {
      // A dropped frame is fine — the next one retries.
    }).whenComplete(() => _inferenceBusy = false);
  }

  Future<void> _openWord(WordMatch match) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    final result = ObjectScanDiscoveryService.recordDiscovery(
      ref.read(profileProvider)?.id,
      match.card.id,
    );
    if (result.starAwarded) {
      ref.read(progressProvider.notifier).addStars(1);
      ref.read(hapticServiceProvider).celebration();
    } else {
      ref.read(hapticServiceProvider).lightTap();
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DiscoveredWordSheet(
        card: match.card,
        isNewDiscovery: result.isNew,
        starAwarded: result.starAwarded,
      ),
    );
    _sheetOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_status == _ScanStatus.ready && _controller != null)
            _CameraCover(controller: _controller!)
          else
            _FallbackState(
              status: _status,
              l10n: l10n,
              onRetry: _initCamera,
            ),
          SafeArea(
            child: Column(
              children: [
                _topBar(context, l10n),
                const Spacer(),
                if (_status == _ScanStatus.ready) _detectionPanel(l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
        ],
      ),
    );
  }

  Widget _detectionPanel(AppLocalizations l10n) {
    final hint = _hintLabel;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _matches.isEmpty
                ? (hint == null
                    ? l10n.wordHuntPointCamera
                    : l10n.wordHuntISee(hint))
                : l10n.wordHuntTapToLearn,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (_matches.isNotEmpty) ...[
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Row(
                key: ValueKey(_matches.map((m) => m.card.id).join(',')),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final match in _matches)
                    Flexible(child: _WordChip(match: match, onTap: _openWord)),
                ],
              ),
            ),
          ],
        ],
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

class _WordChip extends StatelessWidget {
  final WordMatch match;
  final void Function(WordMatch) onTap;
  const _WordChip({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = match.card;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onTap(match),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  FlashcardEmojis.forId(card.id),
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(height: 2),
                Text(
                  card.wordEnglish,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  card.wordFilipino,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
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
