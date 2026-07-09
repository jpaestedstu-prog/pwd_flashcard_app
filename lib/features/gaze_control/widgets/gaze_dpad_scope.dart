import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kDebugMode, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../controllers/gaze_controller.dart';
import '../logic/gaze_grid_cursor.dart';
import '../logic/voice_commands.dart';
import '../models/gaze_models.dart';
import '../providers/gaze_camera_owners.dart';
import '../providers/gaze_settings_provider.dart';
import '../services/gaze_detector.dart';
import 'voice_control_mixin.dart';

/// One gaze-navigable control in a [GazeDpadScope] row: a [label] (for the hint
/// / accessibility) and what to run when the learner opens it ([onActivate]).
/// A disabled cell can still be highlighted but won't activate (so a Previous
/// button on the first card behaves like its greyed touch state).
///
/// Implements [VoiceTarget] so the same cells the head D-pad drives are also the
/// ones spoken commands address by [label] (e.g. "next", "flip").
@immutable
class GazeDpadCell implements VoiceTarget {
  @override
  final String label;
  @override
  final bool enabled;
  final VoidCallback onActivate;
  const GazeDpadCell({
    required this.label,
    required this.onActivate,
    this.enabled = true,
  });
}

/// Snapshot of the D-pad state handed to [GazeDpadScope.builder] so a screen can
/// draw a highlight ring on the focused control and a status hint.
class GazeDpadState {
  /// Gaze is enabled and this scope's camera is running.
  final bool active;

  /// The camera is initialised and streaming.
  final bool ready;

  /// A face is currently visible to the camera.
  final bool faceVisible;

  /// The cell the highlight rests on, or null when [active] is false.
  final int? focusRow;
  final int? focusCol;

  const GazeDpadState({
    required this.active,
    required this.ready,
    required this.faceVisible,
    this.focusRow,
    this.focusCol,
  });

  /// True when [row]/[col] is the currently focused cell (and gaze is active).
  bool isFocused(int row, int col) =>
      active && focusRow == row && focusCol == col;

  static const GazeDpadState inactive = GazeDpadState(
    active: false,
    ready: false,
    faceVisible: false,
  );
}

/// Drives a screen's on-screen controls with the **same discrete highlight-ring
/// + blink-to-commit D-pad** as the navigation shell ([NavGazeScope]) — but for
/// a *foreground, immersive* screen that owns its own camera (the shell stands
/// its background camera down on immersive routes).
///
/// Pass the controls as [rows] of [GazeDpadCell] (one row for a single action
/// bar; more rows enable ▲ ▼ between them). **Look ◀ ▶** moves the highlight
/// within a row, **▲ ▼** between rows, and a **blink** opens the focused control
/// (when blink is off, **look-up** opens it, mirroring the shell). The [builder]
/// receives the live [GazeDpadState] so the screen can ring the focused control.
///
/// It is **inert unless Gaze Control is enabled** — then it simply runs
/// [builder] with [GazeDpadState.inactive] and opens no camera. Touch always
/// works; gaze is purely additive. Settings are snapshotted on mount (re-enter
/// the screen to apply a change), exactly like `GazeScope`.
///
/// **One camera, ever.** This is a *foreground* camera owner: it acquires the
/// app-wide `gazeCameraOwners` gate on mount and releases it on dispose, so the
/// shell's background nav-gaze stands down while this screen is on top.
class GazeDpadScope extends ConsumerStatefulWidget {
  /// The navigable controls, as rows of cells (row-major, matching the visual
  /// layout). Rebuilt freely by the parent — the scope reads the live list at
  /// move / commit time, so per-frame `enabled` flags stay fresh, and only
  /// re-shapes the cursor when the row lengths change.
  final List<List<GazeDpadCell>> rows;

  /// Builds the screen, threading the live [GazeDpadState] through so it can
  /// highlight the focused control.
  final Widget Function(BuildContext context, GazeDpadState gaze) builder;

  /// Injection seams for tests; production uses the real camera + ML Kit.
  final Future<List<CameraDescription>> Function()? camerasLoader;
  final GazeDetector Function()? detectorFactory;

  const GazeDpadScope({
    super.key,
    required this.rows,
    required this.builder,
    this.camerasLoader,
    this.detectorFactory,
  });

  @override
  ConsumerState<GazeDpadScope> createState() => _GazeDpadScopeState();
}

class _GazeDpadScopeState extends ConsumerState<GazeDpadScope>
    with VoiceControlMixin {
  GazeController? _gaze;
  late GazeGridCursor _cursor;
  List<int> _appliedLengths = const [];

  /// True once this scope has claimed the shared camera owner count, so the
  /// shell's nav-gaze stands its camera down. Released exactly once on dispose.
  bool _ownsCamera = false;

  @override
  void initState() {
    super.initState();
    _appliedLengths = _lengths();
    _cursor = GazeGridCursor(rowLengths: _appliedLengths);

    // Snapshot settings on mount (like GazeScope). Off → pure pass-through.
    final settings = ref.read(gazeSettingsProvider);
    if (!settings.enabled) return;
    final controller = GazeController(
      settings: settings,
      camerasLoader: widget.camerasLoader ?? availableCameras,
      detectorFactory: widget.detectorFactory,
    );
    controller.onSelect = _onZone;
    controller.onBlink = _commit;
    controller.addListener(_onControllerUpdate);
    _gaze = controller;
    // Claim the single camera so the shell's background nav-gaze stands down.
    _ownsCamera = true;
    gazeCameraOwners.acquire();
    controller.start();
    // Voice is additive — it addresses the same cells by their label.
    if (settings.voiceCommands) startVoiceControl();
  }

  @override
  void didUpdateWidget(covariant GazeDpadScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_gaze == null) return;
    // Re-shape only when the row lengths actually change (a control appears /
    // disappears), keeping the highlight in range; the parent rebuilds `rows`
    // every frame to refresh callbacks, which must not reset the cursor.
    final want = _lengths();
    if (!listEquals(want, _appliedLengths)) {
      _cursor.setRows(want);
      _appliedLengths = want;
      setState(() {});
    }
  }

  @override
  void dispose() {
    disposeVoiceControl();
    final controller = _gaze;
    _gaze = null;
    if (controller != null) {
      controller.removeListener(_onControllerUpdate);
      controller.dispose();
    }
    if (_ownsCamera) gazeCameraOwners.release();
    super.dispose();
  }

  /// A spoken phrase → the same cell its label names (fired like a blink), a
  /// D-pad cursor move ("left" / "up" / "kanan"…) identical to the matching
  /// head gesture, a "select" that commits the focused cell like a blink, or a
  /// global scroll / leave-screen action. Reads the live [widget.rows] so the
  /// enabled flags and callbacks are always current.
  @override
  void onVoiceCommand(String text) {
    if (!mounted) return;
    final result = resolveDpadVoiceCommand(text, widget.rows);
    if (kDebugMode) {
      debugPrint(
          'VoiceCmd dpad "$text" → ${result.intent} (${result.row},${result.col})');
    }
    switch (result.intent) {
      case DpadVoiceIntent.activate:
        final cell = _cellAt(result.row, result.col);
        if (cell != null && cell.enabled) {
          ref.read(hapticServiceProvider).success();
          cell.onActivate();
        }
      case DpadVoiceIntent.moveLeft:
        _move(() => _cursor.moveHoriz(-1));
      case DpadVoiceIntent.moveRight:
        _move(() => _cursor.moveHoriz(1));
      case DpadVoiceIntent.moveUp:
        _move(() => _cursor.moveVert(-1));
      case DpadVoiceIntent.moveDown:
        _move(() => _cursor.moveVert(1));
      case DpadVoiceIntent.select:
        _commit();
      case DpadVoiceIntent.scrollUp:
        voiceScroll(-1);
      case DpadVoiceIntent.scrollDown:
        voiceScroll(1);
      case DpadVoiceIntent.goBack:
        Navigator.of(context).maybePop();
      case DpadVoiceIntent.none:
        break;
    }
  }

  List<int> _lengths() => [for (final r in widget.rows) r.length];

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  /// Head-zone → D-pad, identical to the shell: ◀ ▶ scrub within the row, ▲ ▼
  /// move between rows when there's more than one; otherwise up commits and down
  /// is ignored. When blink is disabled, up always commits so a head-only
  /// learner keeps an open gesture (rows stay reachable by looking down).
  void _onZone(GazeZone zone) {
    final multiRow = _cursor.rowCount > 1;
    final blink = ref.read(gazeSettingsProvider).blinkEnabled;
    switch (zone) {
      case GazeZone.left:
        _move(() => _cursor.moveHoriz(-1));
      case GazeZone.right:
        _move(() => _cursor.moveHoriz(1));
      case GazeZone.up:
        if (multiRow && blink) {
          _move(() => _cursor.moveVert(-1));
        } else {
          _commit();
        }
      case GazeZone.down:
        if (multiRow) _move(() => _cursor.moveVert(1));
      case GazeZone.none:
        break;
    }
  }

  void _move(VoidCallback apply) {
    if (!mounted || _cursor.currentRowLength <= 0) return;
    ref.read(hapticServiceProvider).selectionClick();
    setState(apply);
  }

  void _commit() {
    if (!mounted || _cursor.rowCount == 0) return;
    final cell = _cellAt(_cursor.row, _cursor.col);
    if (cell == null || !cell.enabled) return;
    ref.read(hapticServiceProvider).success();
    cell.onActivate();
  }

  GazeDpadCell? _cellAt(int row, int col) {
    if (row < 0 || row >= widget.rows.length) return null;
    final r = widget.rows[row];
    if (col < 0 || col >= r.length) return null;
    return r[col];
  }

  @override
  Widget build(BuildContext context) {
    // Settings are snapshotted on mount (like GazeScope): re-enter the screen to
    // apply a Gaze Control toggle. When off, this is a pure pass-through.
    final gaze = _gaze;
    final Widget content;
    if (gaze == null) {
      content = widget.builder(context, GazeDpadState.inactive);
    } else {
      final ready = gaze.status == GazeStatus.ready;
      content = widget.builder(
        context,
        GazeDpadState(
          active: true,
          ready: ready,
          faceVisible: ready && gaze.faceVisible,
          focusRow: _cursor.row,
          focusCol: _cursor.col,
        ),
      );
    }

    // While voice is listening, float a small mic status chip near the top so it
    // never collides with the screen's bottom action bar. Informational only.
    final chip = voiceChip();
    if (chip == null) return content;
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
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
    );
  }
}
