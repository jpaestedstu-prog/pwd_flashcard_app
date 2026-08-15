import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kDebugMode, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/theme/app_colors.dart' show AppColors;
import '../controllers/gaze_controller.dart';
import '../logic/gaze_grid_cursor.dart';
import '../logic/voice_commands.dart';
import '../models/gaze_models.dart';
import '../models/gaze_settings.dart';
import '../providers/gaze_camera_owners.dart';
import '../providers/gaze_settings_provider.dart';
import '../services/gaze_detector.dart';
import 'gaze_route_guard.dart';
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
///
/// [focusRow] / [focusCol] and [isFocused] are always expressed in the screen's
/// **own** row indices — the exit row [GazeDpadScope.onExit] adds is invisible
/// here, so adopting it never renumbers a screen's cells. When the highlight is
/// resting on that exit row, [focusRow] is null and [exitFocused] is true.
class GazeDpadState {
  /// Gaze is enabled and this scope's camera is running.
  final bool active;

  /// The camera is initialised and streaming.
  final bool ready;

  /// A face is currently visible to the camera.
  final bool faceVisible;

  /// The cell the highlight rests on, or null when [active] is false or the
  /// highlight is on the scope's own exit row.
  final int? focusRow;
  final int? focusCol;

  /// The highlight is resting on the hands-free "Back" control the scope draws.
  final bool exitFocused;

  const GazeDpadState({
    required this.active,
    required this.ready,
    required this.faceVisible,
    this.focusRow,
    this.focusCol,
    this.exitFocused = false,
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

  /// **The way out.** A hands-free learner who cannot reach a touch target also
  /// cannot reach the app bar's back button, so an immersive screen whose cells
  /// are all "do something here" is a room with no door — without this, leaving
  /// the flashcard viewer needed a caregiver (or voice, which head-only and
  /// non-verbal learners do not have).
  ///
  /// When set, the scope prepends a one-cell row *above* the screen's own rows
  /// and draws a "Back" pill for it, so **look ▲** from the top row reaches the
  /// exit and a blink takes it — the same two gestures as everything else, and
  /// in the direction the button actually sits. The screen's own row indices are
  /// untouched (see [GazeDpadState]).
  final VoidCallback? onExit;

  /// Label on the exit pill (and the word spoken commands match). Defaults to
  /// "Back"; pass e.g. "Exit" where that reads better.
  final String exitLabel;

  /// Which [GazeSettings] to run on, when the ambient [gazeSettingsProvider] is
  /// not the right answer. The profile picker needs this: it runs *before* a
  /// profile is chosen, so it must not follow the previously signed-in
  /// learner's settings (see `gazePickerSettingsProvider`).
  final GazeSettings? settingsOverride;

  /// Injection seams for tests; production uses the real camera + ML Kit.
  final Future<List<CameraDescription>> Function()? camerasLoader;
  final GazeDetector Function()? detectorFactory;

  const GazeDpadScope({
    super.key,
    required this.rows,
    required this.builder,
    this.onExit,
    this.exitLabel = 'Back',
    this.settingsOverride,
    this.camerasLoader,
    this.detectorFactory,
  });

  @override
  ConsumerState<GazeDpadScope> createState() => _GazeDpadScopeState();
}

class _GazeDpadScopeState extends ConsumerState<GazeDpadScope>
    with VoiceControlMixin, GazeRouteGuard {
  GazeController? _gaze;
  late GazeGridCursor _cursor;
  List<int> _appliedLengths = const [];

  /// The settings this scope actually armed with — the ambient provider, or
  /// [GazeDpadScope.settingsOverride] when the caller supplied one. Snapshotted
  /// on mount so every later read (e.g. the blink rule) agrees with the
  /// controller that is running.
  GazeSettings _settings = const GazeSettings();

  /// True once this scope has claimed the shared camera owner count, so the
  /// shell's nav-gaze stands its camera down. Released exactly once on dispose.
  bool _ownsCamera = false;

  @override
  void initState() {
    super.initState();
    _appliedLengths = _lengths();
    // Start on the screen's own first control, never on the exit row: Back is
    // somewhere to go, not where you arrive.
    _cursor = GazeGridCursor(rowLengths: _appliedLengths, row: _rowOffset);

    // Snapshot settings on mount (like GazeScope). Off → pure pass-through.
    final GazeSettings settings =
        widget.settingsOverride ?? ref.read(gazeSettingsProvider);
    if (!settings.enabled) return;
    _settings = settings;
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
    // This screen's own sheets ("Show Me", "Examples") cover the action bar
    // the D-pad drives; watch for that so the ring stops following a hidden
    // control.
    startGazeCoverageWatch();
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
    stopGazeCoverageWatch();
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
  /// enabled flags and callbacks are always current. Ignored while another
  /// route covers this screen, exactly like the head D-pad.
  @override
  void onVoiceCommand(String text) {
    if (!mounted || gazeCovered) return;
    // Resolve against the same grid the cursor walks, so "back" reaches the
    // exit row by name and the returned coordinates need no translation.
    final result = resolveDpadVoiceCommand(text, _grid());
    if (kDebugMode) {
      debugPrint(
        'VoiceCmd dpad "$text" → ${result.intent} (${result.row},${result.col})',
      );
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

  /// Whether the scope contributes its own exit row above the screen's rows.
  bool get _hasExitRow => widget.onExit != null;

  /// How many rows the scope owns before the screen's first row — 1 with an
  /// exit row, 0 without. Every translation between cursor rows and the
  /// screen's own row numbering goes through this.
  int get _rowOffset => _hasExitRow ? 1 : 0;

  /// True while the highlight rests on the exit row.
  bool get _onExitRow => _hasExitRow && _cursor.row == 0;

  /// The screen's rows with the scope's exit row (when present) stacked on top
  /// — the single grid the cursor, the commit and the voice resolver all
  /// address, so a spoken "back" and a look-▲-then-blink hit the same cell.
  List<List<GazeDpadCell>> _grid() => [
    if (_hasExitRow)
      [GazeDpadCell(label: widget.exitLabel, onActivate: widget.onExit!)],
    ...widget.rows,
  ];

  List<int> _lengths() => [for (final r in _grid()) r.length];

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  /// Head-zone → D-pad, identical to the shell: ◀ ▶ scrub within the row, ▲ ▼
  /// move between rows when there's more than one; otherwise up commits and down
  /// is ignored. When blink is disabled, up always commits so a head-only
  /// learner keeps an open gesture (rows stay reachable by looking down).
  void _onZone(GazeZone zone) {
    if (gazeCovered) return;
    final multiRow = _cursor.rowCount > 1;
    // From the armed snapshot, not the ambient provider — otherwise a scope
    // running on a `settingsOverride` (the profile picker) would take its
    // commit rule from a different learner's configuration.
    final blink = _settings.blinkEnabled;
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
    if (!mounted || gazeCovered || _cursor.rowCount == 0) return;
    final cell = _cellAt(_cursor.row, _cursor.col);
    if (cell == null || !cell.enabled) return;
    ref.read(hapticServiceProvider).success();
    cell.onActivate();
  }

  /// Resolves a **cursor** row/col against [_grid] — i.e. exit row included.
  GazeDpadCell? _cellAt(int row, int col) {
    final grid = _grid();
    if (row < 0 || row >= grid.length) return null;
    final r = grid[row];
    if (col < 0 || col >= r.length) return null;
    return r[col];
  }

  @override
  Widget build(BuildContext context) {
    // Settings are snapshotted on mount (like GazeScope): re-enter the screen to
    // apply a Gaze Control toggle. When off, this is a pure pass-through.
    // A dialog / sheet / pushed page over this screen gates the D-pad off, so
    // report `inactive` for the duration: the screen drops its highlight ring
    // rather than leaving one on a control the learner's head can't move.
    final gaze = gazeCoveredForUi ? null : _gaze;
    final Widget content;
    final onExitRow = gaze != null && _onExitRow;
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
          // Reported in the screen's own row numbering — null while the
          // highlight is up on the scope's exit row, which the screen knows
          // nothing about.
          focusRow: onExitRow ? null : _cursor.row - _rowOffset,
          focusCol: onExitRow ? null : _cursor.col,
          exitFocused: onExitRow,
        ),
      );
    }

    // While voice is listening, float a small mic status chip near the top so it
    // never collides with the screen's bottom action bar. Informational only —
    // and hidden while covered, since spoken commands are gated off too.
    final chip = gazeCoveredForUi ? null : voiceChip();
    // The hands-free way out, drawn top-left where a back button belongs so
    // "look up to leave" matches what the learner sees.
    final exitPill = gaze != null && _hasExitRow
        ? _GazeExitPill(label: widget.exitLabel, focused: onExitRow)
        : null;
    if (chip == null && exitPill == null) return content;
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (exitPill != null)
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IgnorePointer(child: exitPill),
              ),
            ),
          ),
        if (chip != null)
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

/// The hands-free "Back" target [GazeDpadScope.onExit] adds. Non-interactive —
/// touch already has the real back button underneath; this only shows the
/// learner where the gaze exit is and when the highlight is on it.
class _GazeExitPill extends StatelessWidget {
  final String label;
  final bool focused;
  const _GazeExitPill({required this.label, required this.focused});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: focused ? AppColors.accent : Colors.black54,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focused ? AppColors.accent : Colors.white24,
          width: focused ? 3 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.5),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
