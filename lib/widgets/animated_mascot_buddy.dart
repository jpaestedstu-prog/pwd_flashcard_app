import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/app_providers.dart';

/// The mascot's current emotional expression / action.
enum MascotMood {
  idle,       // Default gentle floating
  happy,      // After correct answer or star earned
  excited,    // After level-up or game complete
  thinking,   // During quiz/assessment
  cheering,   // Perfect score or achievement
  sleeping,   // Idle for too long
  waving,     // First visit / greeting
}

/// Riverpod provider to control the mascot mood from anywhere.
final mascotMoodProvider = StateProvider<MascotMood>((ref) => MascotMood.idle);

/// A small animated mascot companion that floats on screen.
///
/// Place this in a `Stack` on any screen. It respects reduced motion
/// and can be dragged around. Double-tap to trigger a reaction.
///
/// The mascot is a simple owl character built with custom paint,
/// no asset dependencies required.
class AnimatedMascotBuddy extends ConsumerStatefulWidget {
  /// Initial position from bottom-right corner.
  final Offset initialOffset;

  /// Size of the mascot widget.
  final double size;

  const AnimatedMascotBuddy({
    super.key,
    this.initialOffset = const Offset(16, 100),
    this.size = 64,
  });

  @override
  ConsumerState<AnimatedMascotBuddy> createState() =>
      _AnimatedMascotBuddyState();
}

class _AnimatedMascotBuddyState extends ConsumerState<AnimatedMascotBuddy>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _reactionController;
  late final AnimationController _blinkController;

  late Offset _position;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();

    _position = Offset.zero; // Will be set in layout

    // Gentle floating bob
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    // Reaction bounce (triggered per mood change)
    _reactionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Periodic blinking
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _startBlinkLoop();
  }

  void _startBlinkLoop() async {
    while (mounted) {
      await Future.delayed(
        Duration(milliseconds: 2500 + math.Random().nextInt(3000)),
      );
      if (!mounted) return;
      await _blinkController.forward();
      if (!mounted) return;
      await _blinkController.reverse();
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _reactionController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  void _triggerReaction() {
    _reactionController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    if (settings.reducedMotion) return const SizedBox.shrink();

    final mood = ref.watch(mascotMoodProvider);

    // Trigger bounce on mood changes
    ref.listen<MascotMood>(mascotMoodProvider, (prev, next) {
      if (prev != next) _triggerReaction();
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        // Initialize position to bottom-right
        if (_position == Offset.zero) {
          _position = Offset(
            constraints.maxWidth - widget.size - widget.initialOffset.dx,
            constraints.maxHeight - widget.size - widget.initialOffset.dy,
          );
        }

        return Stack(
          children: [
            AnimatedPositioned(
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              left: _position.dx,
              top: _position.dy,
              child: GestureDetector(
                onPanStart: (_) => setState(() => _isDragging = true),
                onPanUpdate: (details) {
                  setState(() {
                    _position = Offset(
                      (_position.dx + details.delta.dx)
                          .clamp(0, constraints.maxWidth - widget.size),
                      (_position.dy + details.delta.dy)
                          .clamp(0, constraints.maxHeight - widget.size),
                    );
                  });
                },
                onPanEnd: (_) => setState(() => _isDragging = false),
                onDoubleTap: () {
                  // Cycle through fun reactions
                  final current = ref.read(mascotMoodProvider);
                  final next = current == MascotMood.happy
                      ? MascotMood.excited
                      : MascotMood.happy;
                  ref.read(mascotMoodProvider.notifier).state = next;
                  // Reset after a moment
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) {
                      ref.read(mascotMoodProvider.notifier).state =
                          MascotMood.idle;
                    }
                  });
                },
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _floatController,
                    _reactionController,
                    _blinkController,
                  ]),
                  builder: (context, _) {
                    // Float offset
                    final floatY = math.sin(_floatController.value * math.pi) * 4;

                    // Reaction bounce
                    final reactionT = _reactionController.value;
                    final bounce =
                        math.sin(reactionT * math.pi * 2) * 6 * (1 - reactionT);

                    // Mood-based rotation
                    final tilt = mood == MascotMood.excited
                        ? math.sin(reactionT * math.pi * 4) * 0.1
                        : mood == MascotMood.thinking
                            ? 0.05
                            : 0.0;

                    return Transform.translate(
                      offset: Offset(0, -floatY + bounce),
                      child: Transform.rotate(
                        angle: tilt,
                        child: _MascotBody(
                          size: widget.size,
                          mood: mood,
                          blinkProgress: _blinkController.value,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The mascot owl character, drawn with CustomPaint.
class _MascotBody extends StatelessWidget {
  final double size;
  final MascotMood mood;
  final double blinkProgress;

  const _MascotBody({
    required this.size,
    required this.mood,
    required this.blinkProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mascot buddy',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _MascotPainter(
            mood: mood,
            blinkProgress: blinkProgress,
          ),
          child: _speechBubble,
        ),
      ),
    );
  }

  Widget? get _speechBubble {
    final text = switch (mood) {
      MascotMood.happy => '😊',
      MascotMood.excited => '🎉',
      MascotMood.thinking => '🤔',
      MascotMood.cheering => '⭐',
      MascotMood.waving => '👋',
      MascotMood.sleeping => '💤',
      MascotMood.idle => null,
    };
    if (text == null) return null;

    return Align(
      alignment: Alignment.topRight,
      child: Transform.translate(
        offset: const Offset(8, -8),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
              ),
            ],
          ),
          child: Text(text, style: const TextStyle(fontSize: 14)),
        ),
      ),
    );
  }
}

/// Custom painter that draws a cute owl mascot.
class _MascotPainter extends CustomPainter {
  final MascotMood mood;
  final double blinkProgress;

  _MascotPainter({required this.mood, required this.blinkProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Body — round owl shape
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary,
          AppColors.primaryDark,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + h * 0.05), width: w * 0.85, height: h * 0.8),
      bodyPaint,
    );

    // Belly — lighter oval
    final bellyPaint = Paint()..color = AppColors.primaryLight.withValues(alpha: 0.6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + h * 0.15), width: w * 0.5, height: h * 0.4),
      bellyPaint,
    );

    // Ear tufts
    final earPaint = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.fill;
    // Left ear
    final leftEar = Path()
      ..moveTo(cx - w * 0.2, cy - h * 0.3)
      ..lineTo(cx - w * 0.35, cy - h * 0.48)
      ..lineTo(cx - w * 0.08, cy - h * 0.28)
      ..close();
    canvas.drawPath(leftEar, earPaint);
    // Right ear
    final rightEar = Path()
      ..moveTo(cx + w * 0.2, cy - h * 0.3)
      ..lineTo(cx + w * 0.35, cy - h * 0.48)
      ..lineTo(cx + w * 0.08, cy - h * 0.28)
      ..close();
    canvas.drawPath(rightEar, earPaint);

    // Eyes — white circles
    final eyeWhite = Paint()..color = Colors.white;
    final eyeRadius = w * 0.14;
    final eyeY = cy - h * 0.06;
    final leftEyeX = cx - w * 0.16;
    final rightEyeX = cx + w * 0.16;

    // Blink: squish eye vertically
    final eyeScaleY = 1.0 - blinkProgress * 0.9;

    canvas.save();
    canvas.translate(leftEyeX, eyeY);
    canvas.scale(1.0, eyeScaleY);
    canvas.drawCircle(Offset.zero, eyeRadius, eyeWhite);
    canvas.restore();

    canvas.save();
    canvas.translate(rightEyeX, eyeY);
    canvas.scale(1.0, eyeScaleY);
    canvas.drawCircle(Offset.zero, eyeRadius, eyeWhite);
    canvas.restore();

    // Pupils — mood-dependent
    final pupilPaint = Paint()..color = const Color(0xFF37474F);
    final pupilR = w * 0.06;

    if (blinkProgress < 0.5) {
      // Pupil position based on mood
      final pupilOffsetX = mood == MascotMood.thinking ? -2.0 : 0.0;
      final pupilOffsetY = mood == MascotMood.happy || mood == MascotMood.excited
          ? -1.0
          : mood == MascotMood.sleeping
              ? 2.0
              : 0.0;

      canvas.drawCircle(
        Offset(leftEyeX + pupilOffsetX, eyeY + pupilOffsetY),
        pupilR,
        pupilPaint,
      );
      canvas.drawCircle(
        Offset(rightEyeX + pupilOffsetX, eyeY + pupilOffsetY),
        pupilR,
        pupilPaint,
      );

      // Eye sparkle
      final sparklePaint = Paint()..color = Colors.white;
      canvas.drawCircle(
        Offset(leftEyeX + pupilOffsetX + 2, eyeY + pupilOffsetY - 2),
        pupilR * 0.35,
        sparklePaint,
      );
      canvas.drawCircle(
        Offset(rightEyeX + pupilOffsetX + 2, eyeY + pupilOffsetY - 2),
        pupilR * 0.35,
        sparklePaint,
      );
    }

    // Beak
    final beakPaint = Paint()..color = AppColors.warning;
    final beakPath = Path()
      ..moveTo(cx - w * 0.06, cy + h * 0.06)
      ..lineTo(cx, cy + h * 0.14)
      ..lineTo(cx + w * 0.06, cy + h * 0.06)
      ..close();
    canvas.drawPath(beakPath, beakPaint);

    // Mouth / expression
    final mouthPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    if (mood == MascotMood.happy || mood == MascotMood.excited || mood == MascotMood.cheering) {
      // Smile
      final smilePath = Path();
      smilePath.moveTo(cx - w * 0.08, cy + h * 0.16);
      smilePath.quadraticBezierTo(cx, cy + h * 0.22, cx + w * 0.08, cy + h * 0.16);
      canvas.drawPath(smilePath, mouthPaint);
    } else if (mood == MascotMood.thinking) {
      // Small 'o' mouth
      canvas.drawCircle(
        Offset(cx, cy + h * 0.17),
        w * 0.03,
        mouthPaint,
      );
    } else if (mood == MascotMood.sleeping) {
      // Flat line
      canvas.drawLine(
        Offset(cx - w * 0.06, cy + h * 0.17),
        Offset(cx + w * 0.06, cy + h * 0.17),
        mouthPaint,
      );
    }

    // Feet
    final feetPaint = Paint()..color = AppColors.warning;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - w * 0.12, cy + h * 0.4), width: w * 0.18, height: h * 0.08),
      feetPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + w * 0.12, cy + h * 0.4), width: w * 0.18, height: h * 0.08),
      feetPaint,
    );

    // Cheek blush (when happy/excited)
    if (mood == MascotMood.happy || mood == MascotMood.excited || mood == MascotMood.cheering) {
      final blushPaint = Paint()..color = AppColors.accent.withValues(alpha: 0.3);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - w * 0.25, cy + h * 0.06), width: w * 0.12, height: h * 0.06),
        blushPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + w * 0.25, cy + h * 0.06), width: w * 0.12, height: h * 0.06),
        blushPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MascotPainter oldDelegate) =>
      mood != oldDelegate.mood || blinkProgress != oldDelegate.blinkProgress;
}
