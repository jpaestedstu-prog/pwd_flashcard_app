import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pwdpwdpwd/data/models/seasonal_events.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/seasonal_event_provider.dart';

/// Seasonal banner + falling emoji decorations overlay.
///
/// Place this in a Stack on key screens. If no event is active, renders nothing.
class SeasonalDecorations extends ConsumerStatefulWidget {
  /// If true, show the banner at the top.
  final bool showBanner;

  /// If true, show falling emoji particles.
  final bool showParticles;

  const SeasonalDecorations({
    super.key,
    this.showBanner = true,
    this.showParticles = true,
  });

  @override
  ConsumerState<SeasonalDecorations> createState() =>
      _SeasonalDecorationsState();
}

class _SeasonalDecorationsState extends ConsumerState<SeasonalDecorations>
    with TickerProviderStateMixin {
  late final AnimationController _bannerController;
  late final AnimationController _particleController;
  late final Animation<double> _bannerSlide;
  late final Animation<double> _bannerOpacity;

  final List<FallingEmoji> _emojis = [];
  final _random = Random();
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();

    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bannerSlide = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _bannerController, curve: Curves.easeOutBack),
    );
    _bannerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _bannerController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _particleController.addListener(() {
      if (mounted) setState(() {});
    });

    _bannerController.forward();
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _initEmojis(Size size, SeasonalEvent event) {
    if (_emojis.isNotEmpty) return;
    for (int i = 0; i < 12; i++) {
      _emojis.add(FallingEmoji(
        emoji: event.decorationEmojis[i % event.decorationEmojis.length],
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height,
        speed: 0.3 + _random.nextDouble() * 0.5,
        wobbleSpeed: 0.5 + _random.nextDouble() * 1.5,
        wobbleAmount: 10.0 + _random.nextDouble() * 20.0,
        size: 16.0 + _random.nextDouble() * 12.0,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.02,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(seasonalEventProvider);
    if (event == null) return const SizedBox.shrink();

    final reducedMotion =
        ref.watch(settingsProvider.select((s) => s.reducedMotion));

    if (reducedMotion && !widget.showBanner) return const SizedBox.shrink();

    return Stack(
      children: [
        // ─── Falling Emoji Particles ─────────────
        if (widget.showParticles && !reducedMotion)
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  _initEmojis(size, event);
                  _updateEmojis(size);

                  return CustomPaint(
                    painter: EmojiParticlePainter(
                      emojis: _emojis,
                      opacity: EmojiParticlePainter.defaultOpacity,
                    ),
                    size: size,
                  );
                },
              ),
            ),
          ),

        // ─── Seasonal Banner ─────────────────────
        if (widget.showBanner && !_dismissed)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _bannerController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _bannerSlide.value * 60),
                  child: Opacity(
                    opacity: _bannerOpacity.value,
                    child: child,
                  ),
                );
              },
              child: _SeasonalBanner(
                event: event,
                onDismiss: () => setState(() => _dismissed = true),
              ),
            ),
          ),
      ],
    );
  }

  void _updateEmojis(Size size) {
    for (final e in _emojis) {
      e.y -= e.speed;
      e.x += sin(e.y * 0.01 * e.wobbleSpeed) * e.wobbleAmount * 0.02;
      e.rotation += e.rotationSpeed;

      if (e.y < -30) {
        e.y = size.height + 30;
        e.x = _random.nextDouble() * size.width;
      }
    }
  }
}

/// The seasonal banner on its own, laid out **in flow** rather than as an
/// overlay.
///
/// [SeasonalDecorations] positions its copy at `top: 0` over whatever screen it
/// decorates, which meant the banner sat on top of the first row of home tiles
/// and stayed there while the page scrolled underneath — "Assessments",
/// "Learning", "My Portfolio" and "My Goals" were unreadable until it was
/// dismissed. A banner that announces an event should cost the page its own
/// height, not a row of its content.
///
/// Place this in the scroll content and pass `showBanner: false` to
/// [SeasonalDecorations] so the particles still float above everything.
/// Renders nothing when no event is active or the learner has dismissed it.
class SeasonalBannerStrip extends ConsumerStatefulWidget {
  const SeasonalBannerStrip({super.key});

  @override
  ConsumerState<SeasonalBannerStrip> createState() =>
      _SeasonalBannerStripState();
}

class _SeasonalBannerStripState extends ConsumerState<SeasonalBannerStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slide;
  late final Animation<double> _fade;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slide = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(seasonalEventProvider);
    if (event == null || _dismissed) return const SizedBox.shrink();

    final reducedMotion = ref.watch(
      settingsProvider.select((s) => s.reducedMotion),
    );
    final banner = _SeasonalBanner(
      event: event,
      onDismiss: () => setState(() => _dismissed = true),
    );

    // The entrance is decoration; a learner who asked for less motion gets the
    // banner already in place.
    if (reducedMotion) return banner;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _slide.value * 60),
        child: Opacity(opacity: _fade.value, child: child),
      ),
      child: banner,
    );
  }
}

// ─── Seasonal Banner Widget ────────────────────────────────────
class _SeasonalBanner extends StatelessWidget {
  final SeasonalEvent event;
  final VoidCallback onDismiss;

  const _SeasonalBanner({required this.event, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  event.primaryColor,
                  event.secondaryColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  event.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (event.daysRemaining > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${event.daysRemaining}d left',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Falling Emoji Model ───────────────────────────────────────
class FallingEmoji {
  final String emoji;
  double x;
  double y;
  final double speed;
  final double wobbleSpeed;
  final double wobbleAmount;
  final double size;
  double rotation;
  final double rotationSpeed;

  FallingEmoji({
    required this.emoji,
    required this.x,
    required this.y,
    required this.speed,
    required this.wobbleSpeed,
    required this.wobbleAmount,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
  });
}

// ─── Emoji Particle Custom Painter ─────────────────────────────
///
/// Public only so a test can assert the layer never returns to full opacity;
/// nothing outside this file constructs it.
@visibleForTesting
class EmojiParticlePainter extends CustomPainter {
  final List<FallingEmoji> emojis;

  /// Alpha applied to the whole particle layer.
  ///
  /// These particles are painted *over* every screen they decorate, so at full
  /// strength a flag or a flower lands on top of a label and eats a letter —
  /// the home tile read "Playe🎊Profile", and a flag sat on the XP counter.
  /// Legibility is the one thing this app cannot trade away, so the confetti
  /// stays as texture behind the words.
  ///
  /// Applied with a single `saveLayer` rather than a colour on the [TextStyle]:
  /// these are colour-emoji glyphs, which ignore a text colour entirely, and a
  /// per-glyph `Opacity` widget would cost a layer each.
  final double opacity;

  /// Faint enough that a particle crossing a word never costs a letter, strong
  /// enough to still read as a celebration.
  static const double defaultOpacity = 0.3;

  EmojiParticlePainter({required this.emojis, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    for (final e in emojis) {
      canvas.save();
      canvas.translate(e.x, e.y);
      canvas.rotate(e.rotation);

      final textPainter = TextPainter(
        text: TextSpan(
          text: e.emoji,
          style: TextStyle(fontSize: e.size),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );

      canvas.restore();
    }
    canvas.restore();
  }

  // The particles move every frame, so this always repaints.
  @override
  bool shouldRepaint(covariant EmojiParticlePainter oldDelegate) => true;
}
