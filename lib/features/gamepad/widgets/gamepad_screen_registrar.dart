import 'dart:async';

import 'package:flutter/material.dart';

import '../providers/gamepad_screen.dart';

/// Wraps a screen so a Bluetooth controller can drive and read it.
///
/// Adding it is the whole adoption cost for a screen: supply [items] (the
/// controls) and [narration] (the prose), and the controller can walk, open and
/// read the screen — with the same announcements and the same buttons as
/// everywhere else in the app.
///
/// ```dart
/// GamepadScreenRegistrar(
///   title: 'Word Match',
///   narration: ['Which picture is "dog"?'],
///   items: [for (final c in choices) GamepadItem(label: c.word, onActivate: ...)],
///   child: Scaffold(...),
/// )
/// ```
///
/// ## Why it watches its route
/// A pushed screen stays mounted while a dialog, sheet or pause overlay sits on
/// top of it. Left alone it would keep offering its buttons to the controller,
/// so a learner answering a pause menu would instead be answering the quiz
/// underneath — the exact bug `shellModalObserver` was written to fix for gaze.
/// So the registrar withdraws its publication whenever its own [ModalRoute]
/// stops being current, and republishes when the cover goes away.
///
/// Publishing is deferred to a post-frame callback because
/// [GamepadScreenContent] is a [ChangeNotifier]: notifying while the tree is
/// still building would mark the host dirty mid-build.
class GamepadScreenRegistrar extends StatefulWidget {
  /// The controls, in reading order.
  final List<GamepadItem> items;

  /// The readable prose, in reading order.
  final List<String> narration;

  /// The screen's name, for "where am I?".
  final String? title;

  /// Set false to publish nothing — for a screen that only wants the
  /// controller during part of its life (a game that has finished, say).
  final bool active;

  final Widget child;

  const GamepadScreenRegistrar({
    super.key,
    required this.child,
    this.items = const [],
    this.narration = const [],
    this.title,
    this.active = true,
  });

  @override
  State<GamepadScreenRegistrar> createState() => _GamepadScreenRegistrarState();
}

class _GamepadScreenRegistrarState extends State<GamepadScreenRegistrar> {
  /// Stable identity for this screen's tenure as publisher, so a stale clear
  /// from a screen that already handed off is ignored.
  final Object _token = Object();

  Timer? _coverageTimer;
  bool _covered = false;

  /// Matches `GazeRouteGuard`'s poll: nothing rebuilds this widget when a route
  /// is pushed over it, so the cover has to be noticed on a ticker. Slow enough
  /// to be free, fast enough that the controller never spends a visible moment
  /// driving a screen the learner can no longer see.
  static const Duration _pollInterval = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _schedulePublish();
    _coverageTimer = Timer.periodic(_pollInterval, (_) => _checkCoverage());
  }

  @override
  void didUpdateWidget(covariant GamepadScreenRegistrar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedulePublish();
  }

  @override
  void dispose() {
    _coverageTimer?.cancel();
    gamepadScreen.clear(owner: _token);
    super.dispose();
  }

  void _checkCoverage() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    final covered = route != null && !route.isCurrent;
    if (covered == _covered) return;
    _covered = covered;
    // Withdraw immediately when covered; republish as soon as the cover lifts.
    covered ? gamepadScreen.clear(owner: _token) : _publish();
  }

  void _schedulePublish() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _publish();
    });
  }

  void _publish() {
    if (!mounted || _covered) return;
    if (!widget.active || (widget.items.isEmpty && widget.narration.isEmpty)) {
      gamepadScreen.clear(owner: _token);
      return;
    }
    gamepadScreen.publish(
      items: widget.items,
      narration: widget.narration,
      title: widget.title,
      owner: _token,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Draws the controller's focus ring around one published item.
///
/// The hub tiles get this from `GazeFocusable`; screens that publish through
/// [GamepadScreenRegistrar] use this instead. Laid out as an [IgnorePointer]
/// overlay in a [Stack] so it never changes the child's size or intercepts a
/// touch — the screen behaves exactly as before, just with a ring when focused.
class GamepadFocusable extends StatefulWidget {
  final int index;
  final Widget child;

  /// False makes the ring size to the child rather than fill its parent — for
  /// a child in an unbounded list, where [StackFit.expand] would throw.
  final bool expand;

  /// Ring colour. Defaults to a high-contrast amber that reads against both the
  /// game palettes and the hub backgrounds.
  final Color? color;

  const GamepadFocusable({
    super.key,
    required this.index,
    required this.child,
    this.expand = true,
    this.color,
  });

  @override
  State<GamepadFocusable> createState() => _GamepadFocusableState();
}

class _GamepadFocusableState extends State<GamepadFocusable> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focused = gamepadScreen.isFocused(widget.index);
    gamepadScreen.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant GamepadFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _focused = gamepadScreen.isFocused(widget.index);
    }
  }

  @override
  void dispose() {
    gamepadScreen.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final focused = gamepadScreen.isFocused(widget.index);
    if (focused == _focused || !mounted) return;
    setState(() => _focused = focused);
    if (focused) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
    }
  }

  void _ensureVisible() {
    if (!mounted) return;
    if (Scrollable.maybeOf(context) == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xFFFFB300);
    return Stack(
      fit: widget.expand ? StackFit.expand : StackFit.loose,
      children: [
        widget.child,
        if (_focused)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.55),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
