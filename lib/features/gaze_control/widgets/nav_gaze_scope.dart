import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kDebugMode, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../controllers/gaze_controller.dart';
import '../logic/gaze_grid_cursor.dart';
import '../logic/grid_scanner.dart';
import '../logic/voice_commands.dart';
import '../models/gaze_models.dart';
import '../models/gaze_settings.dart';
import '../providers/gaze_camera_owners.dart';
import '../providers/gaze_home_grid.dart';
import '../providers/gaze_settings_provider.dart';
import '../services/gaze_detector.dart';
import '../services/gaze_metrics.dart';
import 'gaze_hints.dart';
import 'gaze_route_guard.dart';
import 'gaze_session.dart';
import 'gaze_traversal.dart';
import 'shell_modal_observer.dart';
import 'voice_control_mixin.dart';

/// Snapshot of the gaze-navigation state handed to [NavGazeScope.builder] so the
/// bottom navigation bar can draw the moving highlight and a hint.
class NavGazeState {
  /// Gaze navigation is enabled and this shell currently owns the camera
  /// (nothing camera-using is layered on top).
  final bool active;

  /// The face camera is initialised and streaming.
  final bool ready;

  /// Why the camera isn't [ready] yet — still starting, or permanently
  /// unavailable (permission denied / no front lens / failed).
  ///
  /// Without this the nav bar could only say "Starting gaze…", which it then
  /// said *forever* when the learner had denied the camera: a hands-free user
  /// staring at a spinner with nothing telling them a permission is missing.
  final GazeStatus status;

  /// A face is currently visible to the camera.
  final bool faceVisible;

  /// The tab the highlight is resting on, or null when [active] is false or the
  /// cursor is currently up in the feature tiles (the bottom-nav ring hides
  /// while a feature tile is highlighted instead).
  final int? targetIndex;

  /// Scanning mode's row phase is lighting the **whole** tab bar (the learner
  /// blinks to step into it, then picks a tab).
  final bool wholeNavRow;

  /// The D-pad is currently extended over the foreground hub's feature tiles
  /// (the "Bottom nav + feature tiles" reach, on any of Home / Cards / Games /
  /// Stories / Progress). Drives the richer hint chip.
  final bool featureTilesActive;

  /// Scanning mode is on: the highlight moves by itself and a blink picks.
  final bool scanning;

  /// The learner's settings, so the hint can say what steers and what picks.
  final GazeSettings settings;

  const NavGazeState({
    required this.active,
    required this.ready,
    required this.faceVisible,
    required this.targetIndex,
    this.featureTilesActive = false,
    this.status = GazeStatus.initializing,
    this.wholeNavRow = false,
    this.scanning = false,
    this.settings = const GazeSettings(),
  });

  static const NavGazeState inactive = NavGazeState(
    active: false,
    ready: false,
    faceVisible: false,
    targetIndex: null,
  );
}

/// Wraps the navigation shell so a learner can drive the bottom tab bar
/// hands-free, like a game-controller D-pad: **look left / right** moves a
/// highlight across the tabs and a **blink** (or **look up**) opens the
/// highlighted tab. It reuses the same head-zone + blink pipeline as Big
/// Targets ([GazeController]) — discrete moves, never a jittery cursor.
///
/// With the **"Bottom nav + feature tiles"** reach enabled (see [GazeNavScope]),
/// the same D-pad also reaches the foreground hub's feature tiles — on any tab
/// (Home / Cards / Games / Stories / Progress): the visible hub screen publishes
/// its tile grid to [gazeHomeGrid], the shell stacks those rows on top of the
/// bottom-nav row in one [GazeGridCursor], and **look ▲ ▼** moves between rows
/// while **◀ ▶** moves within a row. A blink opens the focused tile (or, when
/// blink is off, look-up commits so head-only learners still have an open
/// gesture).
///
/// In **scanning mode** the head is not used at all: the same grid lights up
/// by itself — a row at a time, then the controls of a chosen row (see
/// [GridScanner]) — and a blink picks.
///
/// When something covers the hubs — a dialog, a sheet, a pushed page, an
/// in-screen celebration — every input hands over to focus traversal on what
/// is showing (see [GazeTraversal]).
///
/// It is **inert unless Gaze Control is enabled**, in which case it simply runs
/// [builder] with [NavGazeState.inactive] and opens no camera. Touch always
/// works; gaze is purely additive.
///
/// **One camera, ever.** The shell is long-lived, so this is a *background*
/// camera owner: it runs only while no foreground camera surface is active
/// (`gazeCameraOwnersProvider == 0`). When a screen with its own camera — a
/// `GazeScope` activity, the gaze preview, Word Hunt — is pushed on top, that
/// screen acquires the owner count and this scope tears its camera down,
/// re-acquiring it when the screen is dismissed. Moving between tabs keeps the
/// same camera alive (the shell never unmounts), so navigation stays smooth.
class NavGazeScope extends ConsumerStatefulWidget {
  /// The currently-selected tab (drives where the highlight starts / re-syncs).
  final int currentIndex;

  /// How many tabs the bar shows (varies by role). **0 is allowed** — the
  /// nav-less Guest Player shell passes 0, dropping the nav row entirely so
  /// the D-pad + voice drive only the grid the visible screen publishes.
  final int itemCount;

  /// The tabs' visible labels (same order as the bar). Lets spoken commands
  /// open a tab by name ("games", "stories"); may be empty (tests / callers
  /// without voice), which only disables addressing tabs by voice.
  final List<String> navLabels;

  /// Route-level gate: the bottom nav bar is currently shown (i.e. not an
  /// immersive activity). When false the camera stands down. Combined with the
  /// global "Enable Gaze Control" setting and the single-camera owner count.
  final bool enabled;

  /// The visible page is a hub that publishes its own gaze grid (Home,
  /// Cards, Games, Stories, Progress). Any other page shown inside the shell —
  /// Settings above all — publishes nothing, so the grid D-pad could reach
  /// only the tab bar there: a hands-free learner who opened Settings could
  /// not reach a single setting, including Gaze Control itself. With the full
  /// reach on, such a page is driven by focus traversal instead, like a pushed
  /// screen; the nav-only reach keeps the tab-bar D-pad the learner chose.
  final bool hubPage;

  /// Invoked when the learner commits (blink / look-up) on a tab.
  final void Function(int index) onCommit;

  /// Builds the shell content, threading [NavGazeState] into the nav bar.
  final Widget Function(BuildContext context, NavGazeState gaze) builder;

  /// Injection seams for tests; production uses the real camera + ML Kit.
  final Future<List<CameraDescription>> Function()? camerasLoader;
  final GazeDetector Function()? detectorFactory;

  const NavGazeScope({
    super.key,
    required this.currentIndex,
    required this.itemCount,
    required this.onCommit,
    required this.builder,
    this.navLabels = const [],
    this.enabled = true,
    this.hubPage = true,
    this.camerasLoader,
    this.detectorFactory,
  });

  @override
  ConsumerState<NavGazeScope> createState() => _NavGazeScopeState();
}

class _NavGazeScopeState extends ConsumerState<NavGazeScope>
    with VoiceControlMixin, GazeRouteGuard, GazeSessionMixin {
  GazeController? _gaze;
  late GazeGridCursor _cursor;

  /// The settings the running camera was armed with, kept current by a
  /// listener in [build] — the shell never remounts, so it has to follow
  /// changes live rather than snapshot them.
  GazeSettings _settings = const GazeSettings();

  /// The row shape currently applied to [_cursor], so we only rebuild it (and
  /// reset the highlight) when the grid actually changes shape.
  List<int> _appliedRows = const [];

  /// Debounces re-evaluation so provider changes (which can fire during another
  /// widget's build) never call `setState`/teardown mid-build.
  bool _evalScheduled = false;
  bool _syncScheduled = false;

  /// Scanning mode: the row–column scanner over the same grid the D-pad
  /// walks, and the timer that steps it.
  GridScanner? _scanner;
  Timer? _scanTimer;

  /// Head moves, blinks, scan steps and voice while a route or an in-screen
  /// modal covers the hubs — plus the ring that shows where that is.
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
    _appliedRows = [if (_hasNavRow) widget.itemCount];
    _cursor = GazeGridCursor(
      rowLengths: _appliedRows,
      col: widget.currentIndex,
    );
    // Stand the camera up/down as foreground camera surfaces come and go, and
    // re-shape the cursor as the Home tile grid appears / disappears.
    gazeCameraOwners.addListener(_scheduleEvaluate);
    gazeHomeGrid.addListener(_scheduleSyncCursor);
    _scheduleEvaluate();
    _scheduleSyncCursor();
  }

  @override
  void didUpdateWidget(covariant NavGazeScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A role switch (itemCount) or a tab change (currentIndex) re-shapes /
    // re-syncs the cursor. Deferred so the registry notify never runs mid-build.
    if (widget.itemCount != oldWidget.itemCount ||
        widget.currentIndex != oldWidget.currentIndex) {
      _scheduleSyncCursor();
    }
    // Entering / leaving an immersive activity switches this scope between the
    // grid D-pad and focus traversal. The coverage ticker won't notice — the
    // shell's route is still "current" — so swap the affordances here.
    if (widget.enabled != oldWidget.enabled ||
        widget.hubPage != oldWidget.hubPage) {
      _scheduleEvaluate();
      scheduleMicrotask(() {
        if (!mounted) return;
        _publishFocus();
        _syncFocusRing();
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    gazeCameraOwners.removeListener(_scheduleEvaluate);
    gazeHomeGrid.removeListener(_scheduleSyncCursor);
    _teardown();
    super.dispose();
  }

  /// Whether this scope's camera should be running at all.
  ///
  /// Deliberately **not** gated on [NavGazeScope.enabled]: an immersive route
  /// (nav bar hidden) has no tab row to drive, but it still has controls — and
  /// standing the camera down there is what made screens like Drag & Drop,
  /// Tracing and Create-a-Card hard dead ends, with no gaze *and* no way back.
  /// The camera stays up and drives focus traversal instead; the single-camera
  /// rule is still enforced by [gazeCameraOwners], which any screen opening its
  /// own camera acquires.
  bool get _shouldRun =>
      ref.read(gazeSettingsProvider).enabled && !gazeCameraOwners.isBusy;

  /// True when another route is layered over the navigation shell (a pushed
  /// screen or a dialog). Read live at event time via [GazeRouteGuard], so a
  /// head move can never fire a tab change while the learner is looking at
  /// something on top.
  bool get _shellCovered => gazeCovered;

  /// A sheet or dialog opened from the visible hub pushes onto the shell's own
  /// navigator, which this scope's [ModalRoute] cannot see — so consult the
  /// observer installed on it. Without this the D-pad kept driving the hub grid
  /// underneath an open sheet.
  @override
  bool get extraCovered => shellModalObserver.isCovering;

  /// Drive **focus traversal** rather than the tab / tile grid: either
  /// something is layered over the shell, or the shell's own nav bar is hidden
  /// (an immersive activity). Either way the grid's targets are not on screen,
  /// so the same head gesture should steer whatever is.
  ///
  /// Read live at event time, like [_shellCovered].
  bool get _useTraversal =>
      !widget.enabled || _shellCovered || _pageWithoutGrid;

  /// Cached counterpart of [_useTraversal] for `build` — see [GazeRouteGuard].
  bool get _useTraversalForUi =>
      !widget.enabled || gazeCoveredForUi || _pageWithoutGrid;

  /// A page inside the shell that is not a hub, under the full reach — see
  /// [NavGazeScope.hubPage].
  bool get _pageWithoutGrid => !widget.hubPage && _settings.navHomeTiles;

  /// Whether the D-pad should currently extend over the foreground hub's feature
  /// tiles: the visible hub screen has published a grid (it only does so under
  /// the combined scope). Any tab qualifies — only the foreground tab publishes,
  /// and it clears on dispose, so a live grid always belongs to the shown tab.
  bool get _useFeatureGrid => gazeHomeGrid.hasGrid;

  /// Whether a bottom-nav row exists at all (the Guest Player shell has none).
  bool get _hasNavRow => widget.itemCount > 0;

  /// The combined row shape: feature-tile rows (when active) stacked on top of
  /// the single bottom-nav row, which — when present — is always the last row.
  List<int> _rowLengths() => [
    if (_useFeatureGrid) ...gazeHomeGrid.rowLengths,
    if (_hasNavRow) widget.itemCount,
  ];

  /// How many of the combined rows are feature-tile rows.
  int get _tileRowCount => _useFeatureGrid ? gazeHomeGrid.rows.length : 0;

  /// Index of the bottom-nav row within the cursor (always the last row).
  /// Without a nav row this is one past the end, so no cursor row matches it.
  int get _navRow => _hasNavRow ? _cursor.rowCount - 1 : _cursor.rowCount;

  /// Whether the cursor is resting up in the feature tiles (not on the nav row).
  bool get _onTileRow => _cursor.rowCount > 0 && _cursor.row < _navRow;

  /// Coalesces evaluation to a microtask so it can safely run while a
  /// freshly-pushed camera screen is still building (it bumps the owner count
  /// in its `initState`) — the microtask runs once the current build completes,
  /// avoiding "setState during build".
  void _scheduleEvaluate() {
    if (_evalScheduled) return;
    _evalScheduled = true;
    scheduleMicrotask(() {
      _evalScheduled = false;
      _evaluate();
    });
  }

  /// Coalesces cursor re-shaping to a microtask, so the registry `setFocus`
  /// notify it performs can never fire while the tree is still building (which
  /// would mark the Home tiles' highlight widgets dirty mid-build).
  void _scheduleSyncCursor() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    scheduleMicrotask(() {
      _syncScheduled = false;
      if (!mounted) return;
      _syncCursor();
      setState(() {});
    });
  }

  void _evaluate() {
    if (!mounted) return;
    final run = _shouldRun;
    if (run && _gaze == null) {
      _start();
    } else if (!run && _gaze != null) {
      _teardown();
      setState(() {});
    }
  }

  void _start() {
    final settings = ref.read(gazeSettingsProvider);
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
    beginGazeSession(settings, onSwitch: _onSwitch);
    if (settings.scanMode) _startScanning();
    // Begin where the learner actually is (on the live tab).
    _syncCursor();
    controller.start();
    // Voice runs exactly while the shell owns the camera, so it can never fight
    // a foreground scope's own voice controller over the single microphone.
    if (settings.voiceCommands) startVoiceControl();
    // A pushed screen or dialog switches this scope from the grid D-pad to the
    // focus-traversal fallback; watch for it so the right highlight is live.
    startGazeCoverageWatch();
    _syncFocusRing();
    setState(() {});
  }

  /// A press on the learner's switch or controller.
  void _onSwitch() => _commit(by: GazeSelectBy.switchButton);

  void _teardown() {
    endGazeSession();
    _stopScanning();
    stopGazeCoverageWatch();
    _traversal.hideRing();
    disposeVoiceControl();
    final controller = _gaze;
    _gaze = null;
    if (controller != null) {
      controller.removeListener(_onControllerUpdate);
      controller.dispose();
    }
    // Drop any Home-tile highlight when the camera stands down.
    gazeHomeGrid.setFocus(null, null);
  }

  /// A setting changed while the camera is running — a teacher adjusting the
  /// learner's tuning, or a profile switch that kept the shell. Applied in
  /// place: the controller re-tunes itself and scanning starts or stops,
  /// without a camera restart.
  void _onSettingsChanged(GazeSettings next) {
    final previous = _settings;
    _settings = next;
    final controller = _gaze;
    if (controller == null) return;
    if (previous.usesCamera != next.usesCamera) {
      // Camera on ↔ off (switch scanning) is the one change that cannot be
      // made in place.
      _teardown();
      if (_shouldRun) _start();
      setState(() {});
      return;
    }
    controller.applySettings(next);
    reconfigureGazeSession(next, onSwitch: _onSwitch);
    if (previous.scanMode != next.scanMode ||
        previous.scanStepMs != next.scanStepMs) {
      _stopScanning();
      if (next.scanMode) _startScanning();
      _publishFocus();
    }
    _syncFocusRing();
    setState(() {});
  }

  // ── Scanning ──────────────────────────────────────────────────────────

  void _startScanning() {
    _scanner = GridScanner(_rowLengths());
    _restartScanTimer();
  }

  void _stopScanning() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _scanner = null;
  }

  /// (Re)starts the step timer, so a highlight that has just moved — or a row
  /// just stepped into — always gets a full step before moving on.
  void _restartScanTimer() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(_settings.scanStepDuration, (_) => _scanTick());
  }

  void _scanTick() {
    final scanner = _scanner;
    if (!mounted || _gaze == null || scanner == null) return;
    if (_useTraversal) {
      // Something covers the hubs: light up its controls in turn instead.
      _traversal.scanStep();
      return;
    }
    scanner.setRows(_rowLengths());
    if (scanner.isEmpty) return;
    ref.read(hapticServiceProvider).selectionClick();
    scanner.step();
    GazeMetrics.instance.scanned();
    _sayScanned();
    _publishFocus();
    setState(() {});
  }

  /// The name of what scanning has just lit: a whole row's names, a control,
  /// a tab.
  void _sayScanned() {
    final scanner = _scanner;
    if (scanner == null || scanner.isEmpty) return;
    final labels = _rowLabels(scanner.row);
    final col = scanner.col;
    if (col == null) {
      sayHighlight(labels.join(', '));
    } else if (col < labels.length) {
      sayHighlight(labels[col]);
    }
  }

  /// The names of the controls in combined-grid row [row].
  List<String> _rowLabels(int row) {
    if (row < _tileRowCount) {
      return [for (final c in gazeHomeGrid.rows[row]) c.label];
    }
    return widget.navLabels;
  }

  /// The name of the control the D-pad cursor rests on.
  void _sayCursor() {
    final labels = _rowLabels(_onTileRow ? _cursor.row : _tileRowCount);
    if (_cursor.col < labels.length) sayHighlight(labels[_cursor.col]);
  }

  /// A blink while scanning the hubs: step into the lit row, or open the lit
  /// control.
  void _scanSelect(GazeSelectBy by) {
    final scanner = _scanner;
    if (scanner == null) return;
    scanner.setRows(_rowLengths());
    final pick = scanner.select();
    if (pick == null) {
      if (scanner.isEmpty) return;
      ref.read(hapticServiceProvider).selectionClick();
      _sayScanned();
      _restartScanTimer();
      _publishFocus();
      setState(() {});
      return;
    }
    _restartScanTimer();
    _activate(pick.row, pick.col, by: by);
  }

  /// Opens the cell at a combined-grid position: a feature tile on the hub, or
  /// a bottom-nav tab.
  void _activate(int row, int col, {required GazeSelectBy by}) {
    if (row < _tileRowCount) {
      final cell = gazeHomeGrid.cellAt(row, col);
      if (cell == null) return;
      ref.read(hapticServiceProvider).success();
      gazePicked(_gaze, by);
      cell.onActivate();
    } else {
      if (!_hasNavRow || col < 0 || col >= widget.itemCount) return;
      ref.read(hapticServiceProvider).success();
      gazePicked(_gaze, by);
      widget.onCommit(col);
    }
  }

  // ── Voice ─────────────────────────────────────────────────────────────

  /// A spoken phrase → a feature tile or nav tab by its label, a D-pad cursor
  /// move ("left" / "up" / "kanan"…) identical to the matching head gesture, a
  /// "select" that commits the focused cell like a blink, or a global scroll /
  /// leave-screen action. Reads the live grid + labels at event time, mirroring
  /// [_commit]. While another route covers the shell, the same phrases drive
  /// focus traversal on whatever is showing.
  @override
  void onVoiceCommand(String text) {
    if (!mounted || _gaze == null) return;
    // Grid not on screen: spoken movement / select drive the same focus
    // traversal the head gestures do, keeping voice at D-pad parity in this
    // mode too. "go back" still pops, which is often the whole point.
    if (_useTraversal) {
      final intent = _traversal.voice(text);
      if (kDebugMode) debugPrint('VoiceCmd nav(covered) "$text" → $intent');
      // Traversal already closed the surface on "go back"; only the scroll
      // gesture is left to this scope.
      if (intent != DpadVoiceIntent.goBack) _globalVoice(intent);
      return;
    }
    final tileRows = gazeHomeGrid.rows;
    final rows = <List<VoiceTarget>>[
      ...tileRows,
      [for (final label in widget.navLabels) _NavTabTarget(label)],
    ];
    final result = resolveDpadVoiceCommand(text, rows);
    if (kDebugMode) {
      debugPrint(
        'VoiceCmd nav “$text” → ${result.intent} (${result.row},${result.col})',
      );
    }
    switch (result.intent) {
      case DpadVoiceIntent.activate:
        if (result.row < tileRows.length) {
          final cell = gazeHomeGrid.cellAt(result.row, result.col);
          if (cell == null) return;
          ref.read(hapticServiceProvider).success();
          gazePicked(_gaze, GazeSelectBy.voice);
          cell.onActivate();
        } else {
          if (result.col < 0 || result.col >= widget.itemCount) return;
          ref.read(hapticServiceProvider).success();
          gazePicked(_gaze, GazeSelectBy.voice);
          widget.onCommit(result.col);
        }
      // Scanning moves the highlight by itself; a spoken direction has no
      // cursor to move there, so only naming a control or "select" act.
      case DpadVoiceIntent.moveLeft:
        if (!_scanning) _moveHoriz(-1);
      case DpadVoiceIntent.moveRight:
        if (!_scanning) _moveHoriz(1);
      case DpadVoiceIntent.moveUp:
        if (!_scanning) _moveVert(-1);
      case DpadVoiceIntent.moveDown:
        if (!_scanning) _moveVert(1);
      case DpadVoiceIntent.select:
        _commit(by: GazeSelectBy.voice);
      case DpadVoiceIntent.scrollUp:
      case DpadVoiceIntent.scrollDown:
      case DpadVoiceIntent.goBack:
      case DpadVoiceIntent.none:
        _globalVoice(result.intent);
    }
  }

  /// The intents that mean the same thing on every screen.
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

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  /// Re-shapes the cursor to match the current grid and keeps the highlight in a
  /// sensible spot: on a shape change (grid appeared/disappeared, role switch)
  /// it lands on the live tab; while resting on the nav row it follows the live
  /// selection (gaze commit or a plain touch). A highlight up in the tiles is
  /// left where it is. Always runs outside build (via [_scheduleSyncCursor] or a
  /// post-build start), so its [_publishFocus] notify is safe.
  void _syncCursor() {
    final want = _rowLengths();
    final shapeChanged = !listEquals(want, _appliedRows);
    if (shapeChanged) {
      _cursor.setRows(want);
      _appliedRows = want;
      // Land on the live tab — or, in the nav-less Guest shell, on the first
      // published row (its top action button).
      _cursor.moveTo(_hasNavRow ? _navRow : 0, widget.currentIndex);
    } else if (_hasNavRow && _cursor.row == _navRow) {
      _cursor.moveTo(_navRow, widget.currentIndex);
    }
    // A new hub's grid starts the scan over from its top; the same shape
    // re-published leaves it where it is.
    final scanner = _scanner;
    if (scanner != null) {
      final before = scanner.rowLengths;
      scanner.setRows(want);
      if (!listEquals(before, scanner.rowLengths)) _restartScanTimer();
    }
    _publishFocus();
  }

  /// Head-zone → D-pad. Left/right scrub within the current row. Up/down move
  /// between rows when the Home grid is active; otherwise up commits and down is
  /// ignored (nav-only behaviour). When blink is disabled, up always commits so
  /// a head-only learner keeps an open gesture (rows are still reachable by
  /// looking down, which wraps).
  void _onZone(GazeZone zone) {
    // Scanning is for learners who cannot move their head, so a head move —
    // likely involuntary — must not steer anything.
    if (_scanning) return;
    // The grid isn't on screen — either something is layered over the shell (a
    // dialog, a pushed screen) or this is an immersive activity with the nav
    // bar hidden. Hand the same head gesture to Flutter's focus traversal and
    // drive whatever *is* on screen instead of doing nothing.
    if (_useTraversal) {
      _traversal.zone(zone, lookUpSelects: _settings.lookUpSelects);
      return;
    }
    final multiRow = _cursor.rowCount > 1;
    switch (zone) {
      case GazeZone.left:
        _moveHoriz(-1);
      case GazeZone.right:
        _moveHoriz(1);
      case GazeZone.up:
        if (multiRow && !_settings.lookUpSelects) {
          _moveVert(-1);
        } else {
          _commit(by: GazeSelectBy.headHold);
        }
      case GazeZone.down:
        if (multiRow) _moveVert(1);
      case GazeZone.none:
        break;
    }
  }

  void _moveHoriz(int delta) {
    if (!mounted || _cursor.currentRowLength <= 0) return;
    ref.read(hapticServiceProvider).selectionClick();
    setState(() => _cursor.moveHoriz(delta));
    _afterMove();
  }

  void _moveVert(int delta) {
    if (!mounted || _cursor.rowCount <= 1) return;
    ref.read(hapticServiceProvider).selectionClick();
    setState(() => _cursor.moveVert(delta));
    _afterMove();
  }

  /// Everything a D-pad move sets off: the highlight, the measurement, the
  /// spoken name, and the look-and-hold timer for the new highlight.
  void _afterMove() {
    _publishFocus();
    GazeMetrics.instance.moved();
    _gaze?.armRestSelect();
    _sayCursor();
  }

  void _commit({GazeSelectBy by = GazeSelectBy.blink}) {
    if (!mounted) return;
    // Traversal first: it works even when this shell has no grid of its own
    // (the nav-less guest Player shell).
    if (_useTraversal) {
      _traversal.commit(by: by);
      return;
    }
    if (_scanning) {
      _scanSelect(by);
      return;
    }
    if (_cursor.rowCount == 0) return;
    _activate(_onTileRow ? _cursor.row : _tileRowCount, _cursor.col, by: by);
  }

  /// Publishes the focused cell to [gazeHomeGrid]: a (row, col) while up in the
  /// tiles (so the hub screen highlights it), or null while on the nav row (so
  /// the bottom-nav ring shows instead). Nothing is published while the shell
  /// is covered — the hub is still visible behind a dialog's scrim, and a ring
  /// sitting on a tile the learner cannot open is a false promise.
  void _publishFocus() {
    // Publish nothing while this scope's camera is down. [gazeHomeGrid] is a
    // *shared* highlight registry — the Bluetooth-gamepad host drives the same
    // rings — and this method runs on every cursor re-sync whether or not gaze
    // is switched on. Without this guard an inert gaze scope kept writing
    // `setFocus(null, null)` as hubs published their grids, wiping the ring a
    // gamepad learner was steering by. Teardown clears the focus itself, so
    // stopping gaze still drops its own highlight.
    if (_gaze == null) return;
    if (_useTraversalForUi) {
      gazeHomeGrid.setFocus(null, null);
      return;
    }
    final scanner = _scanner;
    if (scanner != null) {
      if (!scanner.isEmpty && scanner.row < _tileRowCount) {
        // A null column lights the whole row (the scanner's row phase).
        gazeHomeGrid.setFocus(scanner.row, scanner.col);
      } else {
        gazeHomeGrid.setFocus(null, null);
      }
      return;
    }
    if (_onTileRow) {
      gazeHomeGrid.setFocus(_cursor.row, _cursor.col);
    } else {
      gazeHomeGrid.setFocus(null, null);
    }
  }

  /// As a route covers or uncovers the shell, swap which highlight is live:
  /// the hub's tile ring belongs to the grid D-pad, the overlay ring belongs to
  /// the focus-traversal fallback, and exactly one of them applies at a time.
  @override
  void onGazeCoverageChanged(bool covered) {
    _publishFocus();
    _syncFocusRing();
  }

  /// The traversal ring is shown only while gaze is actually running *and* a
  /// route is covering the shell — otherwise the grid D-pad is in charge and
  /// draws its own highlight.
  void _syncFocusRing() {
    if (!mounted) return;
    _traversal.syncRing(
      context,
      wanted: _gaze != null && _useTraversalForUi,
      hint: GazeHints.forSettings(context, _settings, rowsReachable: true),
    );
  }

  /// Where the bottom-nav ring sits: the scanner's tab while scanning the tab
  /// bar, the cursor's tab while the D-pad rests on it, nowhere otherwise.
  int? _navTarget() {
    final scanner = _scanner;
    if (scanner != null) {
      if (scanner.isEmpty || scanner.row != _tileRowCount || !_hasNavRow) {
        return null;
      }
      return scanner.col;
    }
    return _onTileRow ? null : _cursor.col;
  }

  bool get _wholeNavRowLit {
    final scanner = _scanner;
    return scanner != null &&
        _hasNavRow &&
        !scanner.isEmpty &&
        scanner.row == _tileRowCount &&
        scanner.onWholeRow;
  }

  /// Debug bridge: what this scope is doing right now.
  @override
  Map<String, Object?> debugDescribe() => {
    'scope': 'nav',
    'running': _gaze != null,
    'traversal': _gaze != null && _useTraversal,
    'scanning': _scanning,
    'cursor': [_cursor.row, _cursor.col],
    if (_scanner != null) 'scan': [_scanner!.row, _scanner!.col],
    'navTarget': _navTarget(),
    'wholeNavRow': _wholeNavRowLit,
    'rows': _rowLengths(),
  };

  @override
  Widget build(BuildContext context) {
    // The gaze-enabled setting is the other camera gate (the owner count is
    // watched via a listener added in initState). Re-evaluate post-frame.
    ref.listen<bool>(
      gazeSettingsProvider.select((s) => s.enabled),
      (_, _) => _scheduleEvaluate(),
    );
    // Everything else applies live: the shell never remounts, so a teacher
    // tuning sensitivity or switching scanning on must not have to wait for
    // the camera to bounce. Deferred because provider listeners can fire
    // mid-build.
    ref.listen<GazeSettings>(
      gazeSettingsProvider,
      (_, next) => scheduleMicrotask(() {
        if (mounted) _onSettingsChanged(next);
      }),
    );
    // Unlike the per-screen scopes (which re-snapshot on every mount), the
    // shell lives forever — so the voice toggle must take effect live, without
    // waiting for the camera to bounce. Deferred to a microtask because
    // provider listeners can fire mid-build.
    ref.listen<bool>(
      gazeSettingsProvider.select((s) => s.voiceCommands),
      (_, on) => scheduleMicrotask(() {
        if (!mounted || _gaze == null) return;
        on ? startVoiceControl() : disposeVoiceControl();
        setState(() {});
      }),
    );
    // In traversal mode the tab / tile grid is not what the head is driving,
    // so present the shell as inactive for the duration: no tab ring, no hint
    // chip. Leaving them lit is the one thing worse than no affordance — it
    // tells a hands-free learner to aim at a control that will not answer.
    // (The traversal ring above the router is the live affordance instead.)
    final gaze = _useTraversalForUi ? null : _gaze;
    final ready = gaze != null && gaze.status == GazeStatus.ready;
    final state = NavGazeState(
      active: gaze != null,
      ready: ready,
      faceVisible: ready && gaze.faceVisible,
      // The nav ring shows only while the cursor is on the nav row; up in the
      // tiles the hub screen draws the highlight instead.
      targetIndex: gaze != null ? _navTarget() : null,
      wholeNavRow: gaze != null && _wholeNavRowLit,
      featureTilesActive: gaze != null && _useFeatureGrid,
      status: gaze?.status ?? GazeStatus.initializing,
      scanning: _scanning,
      settings: _settings,
    );
    final content = widget.builder(context, state);

    // While voice is listening, float the small mic status chip near the top
    // (the bottom belongs to the nav bar). Informational only. Shown even while
    // covered — spoken commands still work there, via focus traversal.
    //
    // Always the same Stack, chip or not: returning the bare content when the
    // chip went away (voice stops whenever a foreground screen takes the
    // camera) re-created the whole shell beneath it on every such change.
    final chip = voiceChip();
    return hostGazeModals(
      Stack(
        fit: StackFit.expand,
        children: [
          content,
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

/// Lets a bottom-nav tab be addressed by voice through the same [VoiceTarget]
/// matching the feature tiles use (a tab is always openable).
class _NavTabTarget implements VoiceTarget {
  @override
  final String label;
  const _NavTabTarget(this.label);

  @override
  bool get enabled => true;
}
