import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kDebugMode, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../controllers/gaze_controller.dart';
import '../logic/gaze_focus_driver.dart';
import '../logic/gaze_grid_cursor.dart';
import '../logic/voice_commands.dart';
import '../models/gaze_models.dart';
import '../providers/gaze_camera_owners.dart';
import '../providers/gaze_home_grid.dart';
import '../providers/gaze_settings_provider.dart';
import '../services/gaze_detector.dart';
import 'gaze_focus_overlay.dart';
import 'gaze_route_guard.dart';
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
    this.status = GazeStatus.initializing,
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
    this.camerasLoader,
    this.detectorFactory,
  });

  @override
  ConsumerState<NavGazeScope> createState() => _NavGazeScopeState();
}

class _NavGazeScopeState extends ConsumerState<NavGazeScope>
    with VoiceControlMixin, GazeRouteGuard {
  GazeController? _gaze;
  late GazeGridCursor _cursor;

  /// The row shape currently applied to [_cursor], so we only rebuild it (and
  /// reset the highlight) when the grid actually changes shape.
  List<int> _appliedRows = const [];

  /// Debounces re-evaluation so provider changes (which can fire during another
  /// widget's build) never call `setState`/teardown mid-build.
  bool _evalScheduled = false;
  bool _syncScheduled = false;

  /// The bright ring drawn over whatever the focus-traversal fallback is
  /// pointing at, while a route covers the shell.
  final GazeFocusOverlay _focusRing = GazeFocusOverlay();

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
    if (widget.enabled != oldWidget.enabled) {
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

  /// Drive **focus traversal** rather than the tab / tile grid: either
  /// something is layered over the shell, or the shell's own nav bar is hidden
  /// (an immersive activity). Either way the grid's targets are not on screen,
  /// so the same head gesture should steer whatever is.
  ///
  /// Read live at event time, like [_shellCovered].
  bool get _useTraversal => !widget.enabled || _shellCovered;

  /// Cached counterpart of [_useTraversal] for `build` — see [GazeRouteGuard].
  bool get _useTraversalForUi => !widget.enabled || gazeCoveredForUi;

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
    // Voice runs exactly while the shell owns the camera, so it can never fight
    // a foreground scope's own voice controller over the single microphone.
    if (settings.voiceCommands) startVoiceControl();
    // A pushed screen or dialog switches this scope from the grid D-pad to the
    // focus-traversal fallback; watch for it so the right highlight is live.
    startGazeCoverageWatch();
    _syncFocusRing();
    setState(() {});
  }

  void _teardown() {
    stopGazeCoverageWatch();
    _focusRing.hide();
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

  /// A spoken phrase → a feature tile or nav tab by its label, a D-pad cursor
  /// move ("left" / "up" / "kanan"…) identical to the matching head gesture, a
  /// "select" that commits the focused cell like a blink, or a global scroll /
  /// leave-screen action. Reads the live grid + labels at event time, mirroring
  /// [_commit]. Ignored while another route covers the shell (a dialog / pushed
  /// screen), exactly like the head D-pad.
  @override
  void onVoiceCommand(String text) {
    if (!mounted || _gaze == null) return;
    // Grid not on screen: spoken movement / select drive the same focus
    // traversal the head gestures do, keeping voice at D-pad parity in this
    // mode too. "go back" still pops, which is often the whole point.
    if (_useTraversal) {
      _voiceTraverse(text);
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
        'VoiceCmd nav "$text" → ${result.intent} (${result.row},${result.col})',
      );
    }
    switch (result.intent) {
      case DpadVoiceIntent.activate:
        if (result.row < tileRows.length) {
          final cell = gazeHomeGrid.cellAt(result.row, result.col);
          if (cell == null) return;
          ref.read(hapticServiceProvider).success();
          cell.onActivate();
        } else {
          if (result.col < 0 || result.col >= widget.itemCount) return;
          ref.read(hapticServiceProvider).success();
          widget.onCommit(result.col);
        }
      case DpadVoiceIntent.moveLeft:
        _moveHoriz(-1);
      case DpadVoiceIntent.moveRight:
        _moveHoriz(1);
      case DpadVoiceIntent.moveUp:
        _moveVert(-1);
      case DpadVoiceIntent.moveDown:
        _moveVert(1);
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
    _publishFocus();
  }

  /// Head-zone → D-pad. Left/right scrub within the current row. Up/down move
  /// between rows when the Home grid is active; otherwise up commits and down is
  /// ignored (nav-only behaviour). When blink is disabled, up always commits so
  /// a head-only learner keeps an open gesture (rows are still reachable by
  /// looking down, which wraps).
  void _onZone(GazeZone zone) {
    // The grid isn't on screen — either something is layered over the shell (a
    // dialog, a pushed screen) or this is an immersive activity with the nav
    // bar hidden. Hand the same head gesture to Flutter's focus traversal and
    // drive whatever *is* on screen instead of doing nothing.
    if (_useTraversal) {
      _traverse(zone);
      return;
    }
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

  /// A spoken phrase while a route covers the shell. Movement and select map
  /// onto focus traversal; scroll and go-back keep working as they always did.
  /// Resolved against an empty grid so only the global intents can match — a
  /// dialog publishes no cells to address by name.
  void _voiceTraverse(String text) {
    final result = resolveDpadVoiceCommand(text, const []);
    if (kDebugMode) {
      debugPrint('VoiceCmd nav(covered) "$text" → ${result.intent}');
    }
    switch (result.intent) {
      case DpadVoiceIntent.moveLeft:
        _traverseMove(TraversalDirection.left);
      case DpadVoiceIntent.moveRight:
        _traverseMove(TraversalDirection.right);
      case DpadVoiceIntent.moveUp:
        _traverseMove(TraversalDirection.up);
      case DpadVoiceIntent.moveDown:
        _traverseMove(TraversalDirection.down);
      case DpadVoiceIntent.select:
      case DpadVoiceIntent.activate:
        _traverseCommit();
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

  /// Head zone → directional focus traversal on the covering route. Look-up
  /// doubles as "open it" when blink is off, mirroring the grid D-pad's rule so
  /// a head-only learner always has a commit gesture.
  void _traverse(GazeZone zone) {
    if (!mounted) return;
    final blink = ref.read(gazeSettingsProvider).blinkEnabled;
    switch (zone) {
      case GazeZone.left:
        _traverseMove(TraversalDirection.left);
      case GazeZone.right:
        _traverseMove(TraversalDirection.right);
      case GazeZone.up:
        // With blink off, look-up is the only commit gesture a head-only
        // learner has; ▼ still reaches everything, so nothing is stranded.
        blink ? _traverseMove(TraversalDirection.up) : _traverseCommit();
      case GazeZone.down:
        _traverseMove(TraversalDirection.down);
      case GazeZone.none:
        break;
    }
  }

  /// One traversal step. When the route has nothing focusable that way, the
  /// focus is probably still on its bare scope node — pull it onto the first
  /// control so the next gesture has somewhere to go.
  void _traverseMove(TraversalDirection direction) {
    if (!mounted) return;
    final moved =
        GazeFocusDriver.move(direction) || GazeFocusDriver.moveFirst();
    if (moved) ref.read(hapticServiceProvider).selectionClick();
  }

  /// Blink (or look-up with blink off) while covered: press whatever the
  /// traversal ring is on. A freshly-opened dialog often has focus still
  /// resting on its bare scope node with nothing to press — pull focus onto its
  /// first control instead, so the learner's first blink is never swallowed.
  void _traverseCommit() {
    if (!mounted) return;
    if (GazeFocusDriver.activate()) {
      ref.read(hapticServiceProvider).success();
    } else if (GazeFocusDriver.moveFirst()) {
      ref.read(hapticServiceProvider).selectionClick();
    }
  }

  void _commit() {
    if (!mounted) return;
    // Traversal first: it works even when this shell has no grid of its own
    // (the nav-less guest Player shell).
    if (_useTraversal) {
      _traverseCommit();
      return;
    }
    if (_cursor.rowCount == 0) return;
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
  /// the bottom-nav ring shows instead). Nothing is published while the shell
  /// is covered — the hub is still visible behind a dialog's scrim, and a ring
  /// sitting on a tile the learner cannot open is a false promise.
  void _publishFocus() {
    if (_onTileRow && !_useTraversalForUi) {
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
    final wanted = _gaze != null && _useTraversalForUi;
    if (wanted == _focusRing.isShowing) return;
    wanted ? _focusRing.show(context) : _focusRing.hide();
  }

  @override
  Widget build(BuildContext context) {
    // The gaze-enabled setting is the other camera gate (the owner count is
    // watched via a listener added in initState). Re-evaluate post-frame.
    ref.listen<bool>(
      gazeSettingsProvider.select((s) => s.enabled),
      (_, _) => _scheduleEvaluate(),
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
    // (The traversal ring in the root overlay is the live affordance instead.)
    final gaze = _useTraversalForUi ? null : _gaze;
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
      status: gaze?.status ?? GazeStatus.initializing,
    );
    final content = widget.builder(context, state);

    // While voice is listening, float the small mic status chip near the top
    // (the bottom belongs to the nav bar). Informational only. Shown even while
    // covered — spoken commands still work there, via focus traversal.
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

/// Lets a bottom-nav tab be addressed by voice through the same [VoiceTarget]
/// matching the feature tiles use (a tab is always openable).
class _NavTabTarget implements VoiceTarget {
  @override
  final String label;
  const _NavTabTarget(this.label);

  @override
  bool get enabled => true;
}
