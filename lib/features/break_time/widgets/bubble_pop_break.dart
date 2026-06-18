import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A gentle, **no-fail** bubble-popping field for the "I Need a Break" screen.
///
/// Soft bubbles drift slowly upward; tapping one pops it (the parent provides a
/// light haptic via [onPop]). There is no score and nothing to lose — bubbles
/// you miss simply float off the top and new ones keep coming. The whole thing
/// is a calm fidget, not a challenge.
///
/// Compatibility: a single [Ticker] drives the motion (no per-bubble
/// controllers), bubble count is capped, and the field is wrapped in a
/// [RepaintBoundary], so it stays smooth on low-end phones and scales to large
/// tablets. Everything is laid out from the parent box via [LayoutBuilder], so
/// it adapts to any size or orientation.
class BubblePopBreak extends StatefulWidget {
  const BubblePopBreak({
    super.key,
    required this.colors,
    this.reducedMotion = false,
    this.onPop,
  });

  /// Palette the bubbles are tinted from.
  final List<Color> colors;

  /// When true, fewer bubbles, slower rise, and no sideways wobble — calmer for
  /// motion-sensitive learners (the field still works, just gentler).
  final bool reducedMotion;

  /// Called once each time a bubble is popped (e.g. a light haptic).
  final VoidCallback? onPop;

  @override
  State<BubblePopBreak> createState() => _BubblePopBreakState();
}

class _Bubble {
  _Bubble({
    required this.id,
    required this.xFraction,
    required this.radius,
    required this.color,
    required this.riseSpeed,
    required this.bornAt,
    required this.wobbleAmp,
    required this.wobblePhase,
    required this.wobbleSpeed,
  });

  final int id;
  final double xFraction; // horizontal anchor, 0..1 of width
  final double radius; // px
  final Color color;
  final double riseSpeed; // px per second
  final double bornAt; // elapsed seconds when spawned
  final double wobbleAmp; // px sideways sway
  final double wobblePhase;
  final double wobbleSpeed;

  bool popped = false;
  double poppedAt = 0; // elapsed seconds at pop
}

class _BubblePopBreakState extends State<BubblePopBreak>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final math.Random _rand = math.Random();
  final List<_Bubble> _bubbles = [];

  double _elapsed = 0; // seconds since the field started
  double _lastSpawn = -999;
  int _nextId = 0;
  Size _size = Size.zero;

  // How long the little "burst" lasts after a pop before the bubble is removed.
  static const double _popDuration = 0.18;

  double get _spawnInterval => widget.reducedMotion ? 1.4 : 0.8;
  int get _maxBubbles => widget.reducedMotion ? 7 : 12;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed.inMicroseconds / 1e6;
    // Wait until the first layout pass has measured the field.
    if (_size == Size.zero) return;

    // Spawn on a gentle cadence, up to the cap.
    if (_elapsed - _lastSpawn >= _spawnInterval &&
        _bubbles.length < _maxBubbles) {
      _lastSpawn = _elapsed;
      _bubbles.add(_spawn());
    }

    // Remove bubbles that floated off the top or finished their pop burst.
    _bubbles.removeWhere((b) {
      if (b.popped) return (_elapsed - b.poppedAt) >= _popDuration;
      final cy = _centerY(b, _elapsed);
      return cy + b.radius < -8;
    });

    if (mounted) setState(() {});
  }

  _Bubble _spawn() {
    final minSide = math.min(_size.width, _size.height);
    final radius = (minSide * (0.05 + _rand.nextDouble() * 0.05)).clamp(
      20.0,
      56.0,
    );
    final baseSpeed = widget.reducedMotion ? 26.0 : 44.0;
    return _Bubble(
      id: _nextId++,
      xFraction: 0.08 + _rand.nextDouble() * 0.84,
      radius: radius,
      color: widget.colors[_rand.nextInt(widget.colors.length)],
      riseSpeed: baseSpeed + _rand.nextDouble() * 26.0,
      bornAt: _elapsed,
      wobbleAmp: widget.reducedMotion ? 0.0 : 6.0 + _rand.nextDouble() * 14.0,
      wobblePhase: _rand.nextDouble() * math.pi * 2,
      wobbleSpeed: 0.6 + _rand.nextDouble() * 0.8,
    );
  }

  // Vertical CENTRE of a bubble (px from the top of the field) at time [t].
  // Bubbles start just below the bottom edge and rise.
  double _centerY(_Bubble b, double t) {
    final age = t - b.bornAt;
    return _size.height + b.radius - b.riseSpeed * age;
  }

  void _pop(_Bubble b) {
    if (b.popped) return;
    setState(() {
      b.popped = true;
      b.poppedAt = _elapsed;
    });
    widget.onPop?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        final t = _elapsed;
        return Semantics(
          label: 'Pop the bubbles. This is just for fun — there is no score.',
          child: RepaintBoundary(
            child: ClipRect(
              child: SizedBox.expand(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final b in _bubbles) _positioned(b, t),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _positioned(_Bubble b, double t) {
    final cy = _centerY(b, t);
    final wobble = b.wobbleAmp == 0
        ? 0.0
        : math.sin(b.wobblePhase + t * b.wobbleSpeed) * b.wobbleAmp;
    final left = b.xFraction * _size.width - b.radius + wobble;
    final top = cy - b.radius;
    final d = b.radius * 2;

    final popP = b.popped
        ? ((t - b.poppedAt) / _popDuration).clamp(0.0, 1.0)
        : 0.0;
    final scale = 1.0 + 0.35 * popP;
    final opacity = b.popped ? (1.0 - popP) : 1.0;

    return Positioned(
      left: left,
      top: top,
      width: d,
      height: d,
      child: IgnorePointer(
        ignoring: b.popped,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _pop(b),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: _BubbleVisual(color: b.color),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single soft "soap bubble": a radial highlight fading to the tinted edge,
/// a thin rim, and a faint glow. Purely decorative.
class _BubbleVisual extends StatelessWidget {
  const _BubbleVisual({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: [
            Colors.white.withValues(alpha: 0.9),
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.28),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 12),
        ],
      ),
    );
  }
}
