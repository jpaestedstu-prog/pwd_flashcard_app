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

  final List<_FallingEmoji> _emojis = [];
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
      _emojis.add(_FallingEmoji(
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
                    painter: _EmojiParticlePainter(emojis: _emojis),
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
class _FallingEmoji {
  final String emoji;
  double x;
  double y;
  final double speed;
  final double wobbleSpeed;
  final double wobbleAmount;
  final double size;
  double rotation;
  final double rotationSpeed;

  _FallingEmoji({
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
class _EmojiParticlePainter extends CustomPainter {
  final List<_FallingEmoji> emojis;

  _EmojiParticlePainter({required this.emojis});

  @override
  void paint(Canvas canvas, Size size) {
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
  }

  @override
  bool shouldRepaint(covariant _EmojiParticlePainter oldDelegate) => true;
}
