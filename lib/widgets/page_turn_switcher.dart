import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A storybook **page-turn** transition.
///
/// Wrap the content of a paginated surface (e.g. the Stories reader card) and
/// give the [child] a key that changes when the page changes (a
/// `ValueKey(pageIndex)`). Each time the key changes the widget plays a single
/// 3D turn around the page's vertical centre axis: the page being left rotates
/// to edge-on, then — past the perpendicular midpoint — the page being entered
/// takes over, counter-rotated so it is never mirrored, and swings up to flat.
///
/// [forward] sets which way the page turns, so *Next* and *Previous/Back* read
/// as opposite motions, just like turning forward or back in a real book.
///
/// Implementation notes:
///  - Pure paint-time [Transform]s (a perspective matrix + a Y rotation). There
///    are no platform views or shaders, so it renders identically on every
///    Android version and adds no new platform calls.
///  - Only one face is ever on screen at a time (a strict hand-off at the
///    midpoint), so the turn never shows two overlapping cards.
///  - Honours the accessibility **reduced-motion** setting: when [reducedMotion]
///    is true the page swaps instantly (no spin). The caller's page-dot
///    indicator still animates, so the learner keeps the change feedback.
class PageTurnSwitcher extends StatefulWidget {
  const PageTurnSwitcher({
    super.key,
    required this.child,
    required this.forward,
    this.reducedMotion = false,
    this.duration = const Duration(milliseconds: 460),
  });

  /// The current page's content. Must carry a key that changes per page (e.g.
  /// `KeyedSubtree(key: ValueKey(pageIndex), child: …)`); the turn is triggered
  /// by that key changing.
  final Widget child;

  /// `true` when moving to a later page (*Next*), `false` for *Previous/Back*.
  /// Sets the turn direction.
  final bool forward;

  /// Skip the spin and swap instantly — the a11y reduced-motion setting.
  final bool reducedMotion;

  /// Length of a full turn.
  final Duration duration;

  @override
  State<PageTurnSwitcher> createState() => _PageTurnSwitcherState();
}

class _PageTurnSwitcherState extends State<PageTurnSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;

  /// The live page (the one being turned *into* view).
  late Widget _current;

  /// The page being turned *away from*; shown only for the first half of a
  /// turn, then released. Null while at rest.
  Widget? _outgoing;

  /// Direction captured at the start of the current turn.
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _current = widget.child;
    _controller =
        AnimationController(
          vsync: this,
          duration: widget.duration,
          value: 1, // start settled — no turn on first build
        )..addStatusListener((status) {
          // Release the page we turned away from once the turn finishes, so its
          // subtree can be disposed.
          if (status == AnimationStatus.completed && _outgoing != null) {
            setState(() => _outgoing = null);
          }
        });
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  }

  @override
  void didUpdateWidget(covariant PageTurnSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changedPage = widget.child.key != oldWidget.child.key;
    if (!changedPage) {
      // Same page rebuilt (e.g. a setting toggled) — keep the freshest content
      // without re-running the turn.
      _current = widget.child;
      return;
    }

    _forward = widget.forward;

    if (widget.reducedMotion) {
      // Motion-free: swap instantly. The caller's page-dot indicator still
      // animates, so the learner gets feedback without a spin.
      setState(() {
        _outgoing = null;
        _current = widget.child;
      });
      _controller.value = 1;
      return;
    }

    setState(() {
      _outgoing = _current; // the page we are turning away from
      _current = widget.child; // the page turning into view
    });
    _controller
      ..duration = widget.duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          final t = _t.value;
          final outgoing = _outgoing;
          // At rest (or with nothing to turn from) just show the page.
          if (outgoing == null || t >= 1.0) return _current;

          // A single sheet rotates around its vertical centre axis from flat
          // (0) to a half-turn (±π). The first half shows the page being left;
          // past the perpendicular midpoint the entering page takes over,
          // counter-rotated by the same half-turn so it never reads mirrored.
          // Forward (Next) and back (Previous) turn opposite ways.
          final dir = _forward ? -1.0 : 1.0;
          final angle = t * math.pi * dir;
          final Widget face = t <= 0.5
              ? outgoing
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi * dir),
                  child: _current,
                );
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective depth
              ..rotateY(angle),
            child: face,
          );
        },
      ),
    );
  }
}
