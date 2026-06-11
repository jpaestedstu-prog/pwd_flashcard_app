import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// 3D motion kit — shared perspective-tilt primitives.
///
/// Two widgets:
///  - [Pressable3D] — wraps any tappable child and tilts it in 3D toward the
///    finger while pressed (like pushing the corner of a physical card), with
///    an optional press-depth scale. Pure paint-time transform: no relayout,
///    no extra layers, works the same on every Android version.
///  - [Float3D] — a gentle, continuous 3D sway for *decorative* elements
///    (mascots, empty-state art). Never put it on a tap target.
///
/// Both honour the reduced-motion accessibility setting: the wrapped child
/// renders completely static, but the widget tree shape stays identical so
/// toggling the setting never discards child state.
///
/// Input is raw [Listener] pointer events, which do not enter the gesture
/// arena — the child's own `InkWell` / `GestureDetector` keeps receiving
/// taps exactly as before.
class Pressable3D extends ConsumerStatefulWidget {
  const Pressable3D({
    super.key,
    required this.child,
    this.maxTilt = 0.06,
    this.pressScale = 0.97,
    this.perspective = 0.0015,
    this.enabled = true,
  });

  /// The tappable content. Its own gesture handling is unaffected.
  final Widget child;

  /// Maximum tilt angle in radians (reached when pressing an edge;
  /// a centre press barely tilts). 0.06 rad ≈ 3.4°.
  final double maxTilt;

  /// Scale while fully pressed — the "push into the screen" depth cue.
  /// Use 1.0 for buttons that already animate their own scale.
  final double pressScale;

  /// Perspective strength (Matrix4 entry 3,2). Larger = more dramatic
  /// foreshortening. Keep small for big surfaces.
  final double perspective;

  /// When false (e.g. a disabled button), presses are ignored.
  final bool enabled;

  @override
  ConsumerState<Pressable3D> createState() => _Pressable3DState();
}

class _Pressable3DState extends ConsumerState<Pressable3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 140),
  );

  /// Tilt direction captured at pointer-down, each axis in -1..1
  /// (relative to the widget's centre).
  Offset _tiltDir = Offset.zero;
  Offset _downPosition = Offset.zero;
  int _activePointers = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _motionAllowed =>
      widget.enabled && !ref.read(settingsProvider).reducedMotion;

  void _onPointerDown(PointerDownEvent event) {
    if (!_motionAllowed) return;
    _activePointers++;
    _downPosition = event.position;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return;
    final local = box.globalToLocal(event.position);
    _tiltDir = Offset(
      (local.dx / box.size.width * 2 - 1).clamp(-1.0, 1.0),
      (local.dy / box.size.height * 2 - 1).clamp(-1.0, 1.0),
    );
    _controller.forward();
  }

  void _onPointerMove(PointerMoveEvent event) {
    // Once the touch drifts past the tap slop it is a scroll/drag, not a
    // press — release the tilt instead of holding it while the list moves.
    if (_activePointers == 0) return;
    if ((event.position - _downPosition).distance > kTouchSlop) {
      _activePointers = 0;
      _controller.reverse();
    }
  }

  void _onPointerEnd(PointerEvent event) {
    if (_activePointers == 0) return;
    _activePointers--;
    if (_activePointers == 0) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_controller.value);
          // The tree shape must be identical at every t. An earlier
          // `if (t == 0) return child!` shortcut swapped the subtree in and
          // out of the Transform wrappers on the first frame of every press,
          // which re-inflated the child and killed its in-flight tap
          // recognizer — every button needed a second tap unless reduced
          // motion had the tilt disabled. At t == 0 the matrices below are
          // identity, so the constant wrappers cost nothing visually.
          // Sign convention (see Matrix4.rotationX/Y): these signs push the
          // touched edge *away* from the viewer, like a key on a keyboard.
          final transform = Matrix4.identity()
            ..setEntry(3, 2, widget.perspective * t)
            ..rotateX(_tiltDir.dy * widget.maxTilt * t)
            ..rotateY(-_tiltDir.dx * widget.maxTilt * t);
          final scale = 1.0 + (widget.pressScale - 1.0) * t;
          return Transform.scale(
            scale: scale,
            child: Transform(
              transform: transform,
              alignment: Alignment.center,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Continuous, subtle 3D sway for decorative (non-interactive) elements.
///
/// The child is wrapped in a [RepaintBoundary] so its raster is reused each
/// frame — only the transform layer changes, which keeps the per-frame cost
/// near zero even on entry-level devices.
class Float3D extends ConsumerStatefulWidget {
  const Float3D({
    super.key,
    required this.child,
    this.period = const Duration(seconds: 5),
    this.tilt = 0.05,
    this.bob = 3.0,
    this.perspective = 0.0015,
  });

  final Widget child;

  /// Duration of one full sway cycle.
  final Duration period;

  /// Maximum sway angle in radians on each axis.
  final double tilt;

  /// Vertical bob amplitude in logical pixels (0 to disable).
  final double bob;

  /// Perspective strength (Matrix4 entry 3,2).
  final double perspective;

  @override
  ConsumerState<Float3D> createState() => _Float3DState();
}

class _Float3DState extends ConsumerState<Float3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ref.watch(
      settingsProvider.select((s) => s.reducedMotion),
    );
    if (reduced) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Same tree-shape rule as Pressable3D: never swap the child in and
        // out of the Transform wrappers (the old `t == 0` shortcut also
        // re-inflated the child once per repeat cycle, resetting its state).
        // When reduced motion is on the controller sits at 0 and the
        // matrices below stay identity.
        final sway = reduced ? 0.0 : 1.0;
        // All components are periodic over t ∈ [0,1] so the repeat wraps
        // without a visible jump.
        final phase = t * 2 * math.pi;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, widget.perspective * sway)
          ..rotateX(math.sin(phase) * widget.tilt * sway)
          ..rotateY(math.cos(phase) * widget.tilt * 0.8 * sway);
        return Transform.translate(
          offset: Offset(0, math.sin(phase * 2) * widget.bob * sway),
          child: Transform(
            transform: transform,
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: RepaintBoundary(child: widget.child),
    );
  }
}
