import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A calm guided-breathing animation for the "I Need a Break" screen.
///
/// A soft disc slowly expands on the inhale, holds, then contracts on the
/// exhale, with a matching text cue ("Breathe in" / "Hold" / "Breathe out")
/// shown below it. The pace is deliberately gentle (a ~10-second cycle). There
/// is no score and nothing to fail.
///
/// Accessibility & compatibility:
///  * [reducedMotion] freezes the disc at a steady size (no pulsing) but keeps
///    the text cues changing, so motion-sensitive learners still get the
///    breathing rhythm without vestibular motion.
///  * [highContrast] swaps the soft gradient + glow for a solid fill and a bold
///    white ring.
///  * Everything is sized from the available box via [LayoutBuilder], so it
///    fits any phone or tablet, portrait or landscape, without overflow.
class BreathingBreak extends StatefulWidget {
  const BreathingBreak({
    super.key,
    required this.color,
    required this.textColor,
    this.reducedMotion = false,
    this.highContrast = false,
  });

  /// Accent colour for the breathing disc.
  final Color color;

  /// Colour for the cue text below the disc (theme text colour).
  final Color textColor;

  final bool reducedMotion;
  final bool highContrast;

  @override
  State<BreathingBreak> createState() => _BreathingBreakState();
}

class _BreathingBreakState extends State<BreathingBreak>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Cycle phases as fractions of the controller's 0..1 sweep:
  //   0.00–0.40  inhale   (disc grows)
  //   0.40–0.55  hold     (disc steady, full)
  //   0.55–1.00  exhale   (disc shrinks)
  static const double _inhaleEnd = 0.40;
  static const double _holdEnd = 0.55;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ({double scale, String cue}) _phase(double t) {
    if (t < _inhaleEnd) {
      final p = Curves.easeInOut.transform(t / _inhaleEnd);
      return (scale: 0.55 + 0.45 * p, cue: 'Breathe in…');
    } else if (t < _holdEnd) {
      return (scale: 1.0, cue: 'Hold…');
    } else {
      final p = Curves.easeInOut.transform((t - _holdEnd) / (1 - _holdEnd));
      return (scale: 1.0 - 0.45 * p, cue: 'Breathe out…');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve room for the cue text under the disc; bound the ring so it
        // stays comfortable on small phones and doesn't get huge on tablets.
        final maxD = math.min(constraints.maxWidth, constraints.maxHeight - 64);
        final ring = maxD.clamp(140.0, 360.0);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final ph = _phase(_controller.value);
                  final scale = widget.reducedMotion ? 0.86 : ph.scale;
                  return SizedBox(
                    width: ring,
                    height: ring,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Static guide ring the disc breathes within.
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.highContrast
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : widget.color.withValues(alpha: 0.30),
                              width: 2,
                            ),
                          ),
                        ),
                        // The breathing disc.
                        Transform.scale(
                          scale: scale,
                          child: Container(
                            width: ring * 0.78,
                            height: ring * 0.78,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: widget.highContrast
                                  ? null
                                  : RadialGradient(
                                      center: const Alignment(-0.3, -0.3),
                                      colors: [
                                        Colors.white.withValues(alpha: 0.85),
                                        widget.color.withValues(alpha: 0.85),
                                        widget.color.withValues(alpha: 0.45),
                                      ],
                                      stops: const [0.0, 0.55, 1.0],
                                    ),
                              color: widget.highContrast ? widget.color : null,
                              border: widget.highContrast
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: widget.highContrast
                                  ? null
                                  : [
                                      BoxShadow(
                                        color:
                                            widget.color.withValues(alpha: 0.45),
                                        blurRadius: 36,
                                        spreadRadius: 4,
                                      ),
                                    ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              // Cue text sits below the disc (not on it) so contrast is always
              // good, in any theme. Rebuilt with the disc via AnimatedBuilder.
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Text(
                    _phase(_controller.value).cue,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
