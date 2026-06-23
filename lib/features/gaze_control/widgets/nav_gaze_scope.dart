import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../controllers/gaze_controller.dart';
import '../logic/gaze_grid_cursor.dart';
import '../models/gaze_models.dart';
import '../providers/gaze_camera_owners.dart';
import '../providers/gaze_home_grid.dart';
import '../providers/gaze_settings_provider.dart';
import '../services/gaze_detector.dart';

/// Snapshot of the gaze-navigation state handed to [NavGazeScope.builder] so the
/// bottom navigation bar can draw the moving highlight and a hint.
class NavGazeState {
  /// Gaze navigation is enabled and this shell currently owns the camera
  /// (nothing camera-using is layered on top).
  final bool active;

  /// The face camera is initialised and streaming.
  final bool ready;

  /// A face is currently visible to the camera.
  final bool faceVisible;

  /// The tab the highlight is resting on, or null when [active] is false or the
  /// cursor is currently up in the feature tiles (the bottom-nav ring hides
  /// while a feature tile is highlighted instead).
  final int? targetIndex;

  /// The D-pad is currently extended over the foreground hub's feature tiles
  /// (the "Bottom nav + feature tiles" reach, on any of Home / Cards / Games /
  /// Stories / Progress). Drives the richer hint chip.
  final bool featureTilesActive;

  const NavGazeState({
    required this.active,
    required this.ready,
    required this.faceVisible,
    required this.targetIndex,
    this.featureTilesActive = false,
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

  /// How many tabs the bar shows (varies by role).
  final int itemCount;

  /// Route-level gate: the bottom nav bar is currently shown (i.e. not an
  /// immersive activity). When false the camera stands down. Combined with the
  /// global "Enable Gaze Control" setting and the single-camera owner count.
  final bool enabled;

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
    this.enabled = true,
    this.camerasLoader,
    this.detectorFactory,
  });

  @override
  ConsumerState<NavGazeScope> createState() => _NavGazeScopeState();
}

class _NavGazeScopeState extends ConsumerState<NavGazeScope> {
  GazeController? _gaze;
  late GazeGridCursor _cursor;

  /// The row shape currently applied to [_cursor], so we only rebuild it (and
  /// reset the highlight) when the grid actually changes shape.
  List<int> _appliedRows = const [];

  /// Debounces re-evaluation so provider changes (which can fire during another
  /// widget's build) never call `setState`/teardown mid-build.
  bool _evalScheduled = false;
  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    _appliedRows = [widget.itemCount];
    _cursor = GazeGridCursor(rowLengths: _appliedRows, col: widget.currentIndex);
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
    if (widget.enabled != oldWidget.enabled) _scheduleEvaluate();
  }

  @override
  void dispose() {
    gazeCameraOwners.removeListener(_scheduleEvaluate);
    gazeHomeGrid.removeListener(_scheduleSyncCursor);
    _teardown();
    super.dispose();
  }

  bool get _shouldRun =>
      widget.enabled &&
      ref.read(gazeSettingsProvider).enabled &&
      !gazeCameraOwners.isBusy;

  /// True when another route is layered over the navigation shell (a pushed
  /// screen or a dialog). Read live at event time, so a head move can never
  /// fire a tab change while the learner is looking at something on top.
  bool get _shellCovered => ModalRoute.of(context)?.isCurrent == false;

  /// Whether the D-pad should currently extend over the foreground hub's feature
  /// tiles: the visible hub screen has published a grid (it only does so under
  /// the combined scope). Any tab qualifies — only the foreground tab publishes,
  /// and it clears on dispose, so a live grid always belongs to the shown tab.
  bool get _useFeatureGrid => gazeHomeGrid.hasGrid;

  /// The combined row shape: feature-tile rows (when active) stacked on top of
  /// the single bottom-nav row, which is always the last row.
  List<int> _rowLengths() =>
      _useFeatureGrid ? [...gazeHomeGrid.rowLengths, widget.itemCount]
                      : [widget.itemCount];

  /// Index of the bottom-nav row within the cursor (always the last row).
  int get _navRow => _cursor.rowCount - 1;

  /// Whether the cursor is resting up in the feature tiles (not on the nav row).
  bool get _onTileRow => _cursor.rowCount > 1 && _cursor.row < _navRow;

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
    final controller = GazeController(
      settings: settings,
      camerasLoader: widget.camerasLoader ?? availableCameras,
      detectorFactory: widget.detectorFactory,
    );
    controller.onSelect = _onZone;
    controller.onBlink = _commit;
    controller.addListener(_onControllerUpdate);
    _gaze = controller;
    // Begin where the learner actually is (on the live tab).
    _syncCursor();
    controller.start();
    setState(() {});
  }

  void _teardown() {
    final controller = _gaze;
    _gaze = null;
    if (controller != null) {
      controller.removeListener(_onControllerUpdate);
      controller.dispose();
    }
    // Drop any Home-tile highlight when the camera stands down.
    gazeHomeGrid.setFocus(null, null);
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
      _cursor.moveTo(_navRow, widget.currentIndex);
    } else if (_cursor.row == _navRow) {
      _cursor.moveTo(_navRow, widget.currentIndex);
    }
    _publishFocus();
  }

  /// Head-zone → D-pad. Left/right scrub within the current row. Up/down move
  /// between rows when the Home grid is active; otherwise up commits and down is
  /// ignored (nav-only behaviour). When blink is disabled, up always commits so
  /// a head-only learner keeps an open gesture (rows are still reachable by
  /// looking down, which wraps).
  void _onZone(GazeZone zone) {
    if (_shellCovered) return;
    final multiRow = _cursor.rowCount > 1;
    final blink = ref.read(gazeSettingsProvider).blinkEnabled;
    switch (zone) {
      case GazeZone.left:
        _moveHoriz(-1);
      case GazeZone.right:
        _moveHoriz(1);
      case GazeZone.up:
        if (multiRow && blink) {
          _moveVert(-1);
        } else {
          _commit();
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
    _publishFocus();
  }

  void _moveVert(int delta) {
    if (!mounted || _cursor.rowCount <= 1) return;
    ref.read(hapticServiceProvider).selectionClick();
    setState(() => _cursor.moveVert(delta));
    _publishFocus();
  }

  void _commit() {
    if (!mounted || _shellCovered || _cursor.rowCount == 0) return;
    if (_onTileRow) {
      // Opening a feature tile on the foreground hub.
      final cell = gazeHomeGrid.cellAt(_cursor.row, _cursor.col);
      if (cell == null) return;
      ref.read(hapticServiceProvider).success();
      cell.onActivate();
    } else {
      // Opening a bottom-nav tab.
      if (widget.itemCount <= 0) return;
      ref.read(hapticServiceProvider).success();
      widget.onCommit(_cursor.col);
    }
  }

  /// Publishes the focused cell to [gazeHomeGrid]: a (row, col) while up in the
  /// tiles (so the hub screen highlights it), or null while on the nav row (so
  /// the bottom-nav ring shows instead).
  void _publishFocus() {
    if (_onTileRow) {
      gazeHomeGrid.setFocus(_cursor.row, _cursor.col);
    } else {
      gazeHomeGrid.setFocus(null, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The gaze-enabled setting is the other camera gate (the owner count is
    // watched via a listener added in initState). Re-evaluate post-frame.
    ref.listen<bool>(
      gazeSettingsProvider.select((s) => s.enabled),
      (_, _) => _scheduleEvaluate(),
    );

    final gaze = _gaze;
    final ready = gaze != null && gaze.status == GazeStatus.ready;
    final onTileRow = gaze != null && _onTileRow;
    final state = NavGazeState(
      active: gaze != null,
      ready: ready,
      faceVisible: ready && gaze.faceVisible,
      // The nav ring shows only while the cursor is on the nav row; up in the
      // tiles the hub screen draws the highlight instead.
      targetIndex: gaze != null && !onTileRow ? _cursor.col : null,
      featureTilesActive: gaze != null && _useFeatureGrid,
    );
    return widget.builder(context, state);
  }
}
