import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kDebugMode, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/theme/app_colors.dart' show AppColors;
import '../controllers/gaze_controller.dart';
import '../logic/gaze_grid_cursor.dart';
import '../logic/grid_scanner.dart';
import '../logic/voice_commands.dart';
import '../models/gaze_models.dart';
import '../models/gaze_settings.dart';
import '../providers/gaze_camera_owners.dart';
import '../providers/gaze_settings_provider.dart';
import '../services/gaze_detector.dart';
import '../services/gaze_metrics.dart';
import 'gaze_hints.dart';
import 'gaze_route_guard.dart';
import 'gaze_session.dart';
import 'gaze_traversal.dart';
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
///
/// In scanning mode's row phase a whole row is lit: [focusRow] is set and
/// [focusCol] is null, and [isFocused] is true for every cell in that row — so
/// a screen that rings `isFocused` cells lights the row with no extra code.
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

  /// Scanning mode is on: the highlight moves by itself and a blink picks.
  final bool scanning;

  const GazeDpadState({
    required this.active,
    required this.ready,
    required this.faceVisible,
    this.focusRow,
    this.focusCol,
    this.exitFocused = false,
    this.scanning = false,
  });

  /// True when [row]/[col] is the currently focused cell (and gaze is active),
  /// or sits in the whole row scanning has lit.
  bool isFocused(int row, int col) =>
      active && focusRow == row && (focusCol == null || focusCol == col);

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
/// In **scanning mode** the controls light up by themselves — a row at a time
/// when there are several, then the controls of the chosen row (see
/// [GridScanner]) — and a blink picks.
///
/// When something covers the screen — one of its own sheets ("Show Me",
/// "Examples", the FSL clip), a dialog, an in-screen modal — head, blink,
/// scanning and voice all hand over to focus traversal on what is showing
/// (see [GazeTraversal]), so the learner can operate it and close it.
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
    with VoiceControlMixin, GazeRouteGuard, GazeSessionMixin {
  GazeController? _gaze;
  late GazeGridCursor _cursor;
  List<int> _appliedLengths = const [];

  /// The settings this scope actually armed with — the ambient provider, or
  /// [GazeDpadScope.settingsOverride] when the caller supplied one. Snapshotted
  /// on mount so every later read (e.g. the blink rule) agrees with the
  /// controller that is running.
  GazeSettings _settings = const GazeSettings();

  /// This scope's place in the camera-owner stack, so the shell's nav-gaze
  /// stands down — and so this scope can tell when another camera surface has
  /// opened on top of it. Released exactly once on dispose.
  Object? _cameraToken;

  /// Scanning mode: the row–column scanner over the same grid the D-pad
  /// walks (exit row included), and the timer that steps it.
  GridScanner? _scanner;
  Timer? _scanTimer;

  /// Head moves, blinks, scan steps and voice while something covers this
  /// screen — plus the ring that shows where that is.
  late final GazeTraversal _traversal = GazeTraversal(
    onMoved: () {
      ref.read(hapticServiceProvider).selectionClick();
      GazeMetrics.instance.moved();
      _gaze?.armRestSelect();
      sayFocusedSoon();
    },
    onScanned: () {
      ref.read(hapticServiceProvider).selectionClick();
      GazeMetrics.instance.scanned();
      sayFocusedSoon();
    },
    onPressed: (by) {
      ref.read(hapticServiceProvider).success();
      gazePicked(_gaze, by);
    },
    onLeft: GazeMetrics.instance.backed,
  );

  bool get _scanning => _scanner != null;

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
    controller.onRest = () => _commit(by: GazeSelectBy.rest);
    controller.addListener(_onControllerUpdate);
    _gaze = controller;
    // Claim the single camera so the shell's background nav-gaze stands down.
    _cameraToken = gazeCameraOwners.acquire();
    gazeCameraOwners.addListener(_onCameraOwnersChanged);
    controller.start();
    beginGazeSession(settings, onSwitch: _onSwitch);
    if (settings.scanMode) {
      // Like the D-pad, the scan begins on the screen's own controls rather
      // than on the Back row above them.
      _scanner = GridScanner(_appliedLengths);
      _skipExitRowOnStart();
      _restartScanTimer();
    }
    // Voice is additive — it addresses the same cells by their label.
    if (settings.voiceCommands) startVoiceControl();
    // This screen's own sheets ("Show Me", "Examples") cover the action bar
    // the D-pad drives; watch for that so the ring stops following a hidden
    // control and traversal takes over.
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
      final scanner = _scanner;
      if (scanner != null) {
        scanner.setRows(want);
        _skipExitRowOnStart();
        _restartScanTimer();
      }
      setState(() {});
    }
  }

  /// A press on the learner's switch or controller.
  void _onSwitch() => _commit(by: GazeSelectBy.switchButton);

  @override
  void dispose() {
    endGazeSession();
    _scanTimer?.cancel();
    stopGazeCoverageWatch();
    _traversal.hideRing();
    disposeVoiceControl();
    final controller = _gaze;
    _gaze = null;
    if (controller != null) {
      controller.removeListener(_onControllerUpdate);
      controller.dispose();
    }
    gazeCameraOwners.removeListener(_onCameraOwnersChanged);
    final token = _cameraToken;
    if (token != null) gazeCameraOwners.release(token);
    super.dispose();
  }

  /// Whether this screen is the newest camera owner — the one the learner is
  /// looking at. Only then may it run its camera and microphone.
  bool get _isTopOwner {
    final token = _cameraToken;
    return token != null && gazeCameraOwners.isTop(token);
  }

  /// Another camera surface opened over this screen (the race the Play
  /// Together lobby starts, the media camera a message thread opens): stand
  /// the camera, the microphone and the traversal ring down until it closes.
  /// Deferred because owners change from `initState` / `dispose`.
  void _onCameraOwnersChanged() {
    scheduleMicrotask(() {
      final gaze = _gaze;
      if (!mounted || gaze == null) return;
      if (!_isTopOwner && !gaze.suspended) {
        gaze.suspendCamera();
        endGazeSession();
        disposeVoiceControl();
        _traversal.hideRing();
        setState(() {});
      } else if (_isTopOwner && gaze.suspended) {
        gaze.resumeCamera();
        beginGazeSession(_settings, onSwitch: _onSwitch);
        if (_settings.voiceCommands) startVoiceControl();
        if (_scanning) _restartScanTimer();
        onGazeCoverageChanged(gazeCovered);
        setState(() {});
      }
    });
  }

  /// A spoken phrase → the same cell its label names (fired like a blink), a
  /// D-pad cursor move ("left" / "up" / "kanan"…) identical to the matching
  /// head gesture, a "select" that commits the focused cell like a blink, or a
  /// global scroll / leave-screen action. Reads the live [widget.rows] so the
  /// enabled flags and callbacks are always current. While something covers
  /// this screen, the same phrases drive focus traversal on what is showing.
  @override
  void onVoiceCommand(String text) {
    if (!mounted) return;
    if (gazeCovered) {
      final intent = _traversal.voice(text);
      if (kDebugMode) debugPrint('VoiceCmd dpad(covered) "$text" → $intent');
      // Traversal already closed the surface on "go back"; only the scroll
      // gesture is left to this scope.
      if (intent != DpadVoiceIntent.goBack) _globalVoice(intent);
      return;
    }
    // Resolve against the same grid the cursor walks, so "back" reaches the
    // exit row by name and the returned coordinates need no translation.
    final result = resolveDpadVoiceCommand(text, _grid());
    if (kDebugMode) {
      debugPrint(
        'VoiceCmd dpad “$text” → ${result.intent} (${result.row},${result.col})',
      );
    }
    switch (result.intent) {
      case DpadVoiceIntent.activate:
        final cell = _cellAt(result.row, result.col);
        if (cell != null && cell.enabled) {
          ref.read(hapticServiceProvider).success();
          _record(result.row, GazeSelectBy.voice);
          cell.onActivate();
        }
      // Scanning moves the highlight by itself; a spoken direction has no
      // cursor to move there, so only naming a control or "select" act.
      case DpadVoiceIntent.moveLeft:
        if (!_scanning) _move(() => _cursor.moveHoriz(-1));
      case DpadVoiceIntent.moveRight:
        if (!_scanning) _move(() => _cursor.moveHoriz(1));
      case DpadVoiceIntent.moveUp:
        if (!_scanning) _move(() => _cursor.moveVert(-1));
      case DpadVoiceIntent.moveDown:
        if (!_scanning) _move(() => _cursor.moveVert(1));
      case DpadVoiceIntent.select:
        _commit(by: GazeSelectBy.voice);
      case DpadVoiceIntent.scrollUp:
      case DpadVoiceIntent.scrollDown:
      case DpadVoiceIntent.goBack:
      case DpadVoiceIntent.none:
        _globalVoice(result.intent);
    }
  }

  void _globalVoice(DpadVoiceIntent intent) {
    switch (intent) {
      case DpadVoiceIntent.scrollUp:
        voiceScroll(-1);
      case DpadVoiceIntent.scrollDown:
        voiceScroll(1);
      case DpadVoiceIntent.goBack:
        GazeMetrics.instance.backed();
        Navigator.of(context).maybePop();
      default:
        break;
    }
  }

  /// Measures a press on cursor row [row]: the Back row is a leave, anything
  /// else a selection.
  void _record(int row, GazeSelectBy by) {
    if (_hasExitRow && row == 0) {
      GazeMetrics.instance.backed();
    } else {
      gazePicked(_gaze, by);
    }
  }

  /// The name of the cell at cursor position [row]/[col], spoken when
  /// highlights are read aloud.
  void _sayCell(int row, int? col) {
    final grid = _grid();
    if (row < 0 || row >= grid.length) return;
    if (col == null) {
      sayHighlight(grid[row].map((c) => c.label).join(', '));
    } else if (col < grid[row].length) {
      sayHighlight(grid[row][col].label);
    }
  }

  /// Whether the scope contributes its own exit row above the screen's rows.
  bool get _hasExitRow => widget.onExit != null;

  /// How many rows the scope owns before the screen's first row — 1 with an
  /// exit row, 0 without. Every translation between cursor rows and the
  /// screen's own row numbering goes through this.
  int get _rowOffset => _hasExitRow ? 1 : 0;

  /// True while the highlight rests on the exit row.
  bool get _onExitRow {
    if (!_hasExitRow) return false;
    final scanner = _scanner;
    if (scanner != null) return !scanner.isEmpty && scanner.row == 0;
    return _cursor.row == 0;
  }

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

  // ── Scanning ──────────────────────────────────────────────────────────

  /// Starts the scan on the screen's first row rather than on Back.
  void _skipExitRowOnStart() {
    final scanner = _scanner;
    if (scanner == null || !_hasExitRow || scanner.isEmpty) return;
    if (scanner.row == 0 && scanner.onWholeRow) scanner.step();
  }

  void _restartScanTimer() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(_settings.scanStepDuration, (_) => _scanTick());
  }

  void _scanTick() {
    final scanner = _scanner;
    if (!mounted || _gaze == null || scanner == null) return;
    // Stood down under another camera surface: that one is scanning now.
    if (_gaze!.suspended) return;
    if (gazeCovered) {
      // A sheet or dialog is up: light up *its* controls in turn instead.
      _traversal.scanStep();
      return;
    }
    if (scanner.isEmpty) return;
    ref.read(hapticServiceProvider).selectionClick();
    setState(scanner.step);
    GazeMetrics.instance.scanned();
    _sayCell(scanner.row, scanner.col);
  }

  void _scanSelect(GazeSelectBy by) {
    final scanner = _scanner;
    if (scanner == null) return;
    final pick = scanner.select();
    _restartScanTimer();
    if (pick == null) {
      if (scanner.isEmpty) return;
      ref.read(hapticServiceProvider).selectionClick();
      _sayCell(scanner.row, scanner.col);
      setState(() {});
      return;
    }
    final cell = _cellAt(pick.row, pick.col);
    if (cell == null || !cell.enabled) return;
    ref.read(hapticServiceProvider).success();
    _record(pick.row, by);
    cell.onActivate();
    setState(() {});
  }

  // ── Head D-pad ────────────────────────────────────────────────────────

  /// Head-zone → D-pad, identical to the shell: ◀ ▶ scrub within the row, ▲ ▼
  /// move between rows when there's more than one; otherwise up commits and down
  /// is ignored. When blink is disabled, up always commits so a head-only
  /// learner keeps an open gesture (rows stay reachable by looking down).
  void _onZone(GazeZone zone) {
    // Scanning is for learners who cannot move their head; a head move —
    // likely involuntary — must not steer anything.
    if (_scanning) return;
    // From the armed snapshot, not the ambient provider — otherwise a scope
    // running on a `settingsOverride` (the profile picker) would take its
    // commit rule from a different learner's configuration.
    final lookUpSelects = _settings.lookUpSelects;
    if (gazeCovered) {
      _traversal.zone(zone, lookUpSelects: lookUpSelects);
      return;
    }
    final multiRow = _cursor.rowCount > 1;
    switch (zone) {
      case GazeZone.left:
        _move(() => _cursor.moveHoriz(-1));
      case GazeZone.right:
        _move(() => _cursor.moveHoriz(1));
      case GazeZone.up:
        if (multiRow && !lookUpSelects) {
          _move(() => _cursor.moveVert(-1));
        } else {
          _commit(by: GazeSelectBy.headHold);
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
    GazeMetrics.instance.moved();
    _gaze?.armRestSelect();
    _sayCell(_cursor.row, _cursor.col);
  }

  void _commit({GazeSelectBy by = GazeSelectBy.blink}) {
    if (!mounted) return;
    if (gazeCovered) {
      _traversal.commit(by: by);
      return;
    }
    if (_scanning) {
      _scanSelect(by);
      return;
    }
    if (_cursor.rowCount == 0) return;
    final cell = _cellAt(_cursor.row, _cursor.col);
    if (cell == null || !cell.enabled) return;
    ref.read(hapticServiceProvider).success();
    _record(_cursor.row, by);
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
  void onGazeCoverageChanged(bool covered) {
    if (!mounted || _gaze == null) return;
    _traversal.syncRing(
      context,
      // Covered by a screen with its own gaze, that screen draws its own
      // highlight; the ring belongs to whoever is driving.
      wanted: covered && _isTopOwner,
      hint: GazeHints.forSettings(context, _settings, rowsReachable: true),
    );
  }

  @override
  Map<String, Object?> debugDescribe() => {
    'scope': 'dpad',
    'running': _gaze != null,
    'topOwner': _isTopOwner,
    'covered': _gaze != null && gazeCovered,
    'scanning': _scanning,
    'cursor': [_cursor.row, _cursor.col],
    if (_scanner != null) 'scan': [_scanner!.row, _scanner!.col],
    'exitRow': _hasExitRow,
    'rows': [
      for (final row in _grid()) [for (final c in row) c.label],
    ],
  };

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
      final scanner = _scanner;
      final int focusRow;
      final int? focusCol;
      if (scanner != null && !scanner.isEmpty) {
        focusRow = scanner.row;
        focusCol = scanner.col;
      } else {
        focusRow = _cursor.row;
        focusCol = _cursor.col;
      }
      content = widget.builder(
        context,
        GazeDpadState(
          active: true,
          ready: ready,
          faceVisible: ready && gaze.faceVisible,
          // Reported in the screen's own row numbering — null while the
          // highlight is up on the scope's exit row, which the screen knows
          // nothing about.
          focusRow: onExitRow ? null : focusRow - _rowOffset,
          focusCol: onExitRow ? null : focusCol,
          exitFocused: onExitRow,
          scanning: _scanning,
        ),
      );
    }

    // While voice is listening, float a small mic status chip near the top so it
    // never collides with the screen's bottom action bar. Informational only —
    // and hidden while covered, since the covering surface has the stage.
    final chip = gazeCoveredForUi ? null : voiceChip();
    // The hands-free way out, drawn top-left where a back button belongs so
    // "look up to leave" matches what the learner sees.
    final exitPill = gaze != null && _hasExitRow
        ? _GazeExitPill(label: widget.exitLabel, focused: onExitRow)
        : null;
    // Always the same Stack, so the screen beneath never remounts as the chip
    // or the pill come and go (a sheet opening over the viewer used to rebuild
    // the whole viewer from scratch).
    return hostGazeModals(
      Stack(
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
      ),
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
    // A transparent Material gives the text the app's own style. This floats
    // beside a screen's Scaffold, not inside it, so without one the text fell
    // back to Flutter's "missing Material" style — red-yellow double
    // underlines in a monospace font — on every gaze learner's screen.
    return Material(
      type: MaterialType.transparency,
      child: AnimatedContainer(
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
      ),
    );
  }
}
