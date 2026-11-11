import 'dart:async';

import 'package:flutter/material.dart';

import '../providers/gamepad_screen.dart';

/// Wraps a screen so a Bluetooth controller can read it.
///
/// Supply [narration] (the prose) and [items] (the controls, by name), and X
/// reads the screen — the question first, then what can be chosen — and Start
/// names it. The controls themselves are the screen's own buttons, which the
/// D-pad reaches by focus exactly as a keyboard's arrows do; [items] only
/// says what they are, so the list a learner hears matches what they can
/// reach.
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
  /// The controls, in reading order — each one a button on the screen.
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
