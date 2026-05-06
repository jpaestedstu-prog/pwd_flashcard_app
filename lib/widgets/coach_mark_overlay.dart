import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// An enhanced tutorial step that can optionally spotlight a real widget.
class CoachStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  /// If provided, the overlay will cut a spotlight hole around this widget.
  final GlobalKey? targetKey;

  /// Where to position the tooltip relative to the target.
  final TooltipPosition position;

  /// Hint for what the user should do (e.g. "Tap here").
  final String? actionHint;

  const CoachStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.targetKey,
    this.position = TooltipPosition.below,
    this.actionHint,
  });
}

enum TooltipPosition { above, below, left, right }

/// A full-screen coach-mark overlay that spotlights real UI elements.
///
/// If a [CoachStep] has a [targetKey], the overlay will draw a spotlight
/// circle around that widget and position the tooltip card near it.
/// If no [targetKey], falls back to a centered card (like the old tutorial).
class CoachMarkOverlay extends StatefulWidget {
  final List<CoachStep> steps;
  final VoidCallback onComplete;

  const CoachMarkOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
  });

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  Rect? _targetRect;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _updateTarget();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updateTarget() {
    final step = widget.steps[_currentStep];
    if (step.targetKey?.currentContext != null) {
      final renderObject = step.targetKey!.currentContext!.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        final box = renderObject;
        final pos = box.localToGlobal(Offset.zero);
        setState(() {
          _targetRect = Rect.fromLTWH(
            pos.dx,
            pos.dy,
            box.size.width,
            box.size.height,
          );
        });
      } else {
        setState(() => _targetRect = null);
      }
    } else {
      setState(() => _targetRect = null);
    }
  }

  void _next() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateTarget());
    } else {
      widget.onComplete();
    }
  }

  void _skip() => widget.onComplete();

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final isLast = _currentStep == widget.steps.length - 1;
    final screenSize = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ─── Dark overlay with spotlight cutout ──────
          if (_targetRect != null)
            _SpotlightOverlay(
              targetRect: _targetRect!,
              pulseAnimation: _pulseController,
              color: step.color,
            )
          else
            Container(color: Colors.black.withValues(alpha: 0.7)),

          // ─── Skip button ────────────────────────────
          Positioned(
            top: MediaQuery.viewPaddingOf(context).top + 8,
            right: 16,
            child: SafeArea(
              child: TextButton(
                onPressed: _skip,
                child: Text(
                  'Skip',
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ),

          // ─── Step counter ───────────────────────────
          Positioned(
            top: MediaQuery.viewPaddingOf(context).top + 16,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Text(
                  '${_currentStep + 1} / ${widget.steps.length}',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          ),

          // ─── Tooltip card ───────────────────────────
          _buildTooltipCard(step, screenSize, isLast),

          // ─── Dot indicators at bottom ───────────────
          Positioned(
            bottom: 90,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.steps.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentStep ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _currentStep
                        ? step.color
                        : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),

          // ─── Next button ────────────────────────────
          Positioned(
            bottom: 28,
            left: 40,
            right: 40,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: step.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 8,
                shadowColor: step.color.withValues(alpha: 0.4),
              ),
              child: Text(
                isLast ? 'Got It! 🎉' : 'Next →',
                style: AppTypography.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltipCard(CoachStep step, Size screenSize, bool isLast) {
    // If we have a target, position near it. Otherwise center on screen.
    if (_targetRect != null) {
      final bool showBelow =
          _targetRect!.center.dy < screenSize.height * 0.5;
      final top = showBelow ? _targetRect!.bottom + 20.0 : null;
      final bottom = showBelow ? null : screenSize.height - _targetRect!.top + 20.0;

      return Positioned(
        top: top,
        bottom: bottom,
        left: 24,
        right: 24,
        child: _TooltipContent(step: step),
      );
    }

    // Centered fallback
    return Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: _TooltipContent(step: step),
    ));
  }
}

// ────────────────────────────────────────
// Spotlight overlay with circular cutout
// ────────────────────────────────────────
class _SpotlightOverlay extends StatelessWidget {
  final Rect targetRect;
  final AnimationController pulseAnimation;
  final Color color;

  const _SpotlightOverlay({
    required this.targetRect,
    required this.pulseAnimation,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        final pulse = 1.0 + pulseAnimation.value * 0.08;
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _SpotlightPainter(
            targetRect: targetRect,
            pulseScale: pulse,
            spotlightColor: color,
          ),
        );
      },
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double pulseScale;
  final Color spotlightColor;

  _SpotlightPainter({
    required this.targetRect,
    required this.pulseScale,
    required this.spotlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Full dark background
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.7);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Cut out spotlight circle (with padding)
    final center = targetRect.center;
    final radius =
        (targetRect.longestSide / 2 + 16) * pulseScale;
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    canvas.drawCircle(center, radius, clearPaint);
    canvas.restore();

    // Glow ring around the spotlight
    final glowPaint = Paint()
      ..color = spotlightColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.pulseScale != pulseScale ||
      oldDelegate.targetRect != targetRect;
}

// ────────────────────────────────────────
// Tooltip content card
// ────────────────────────────────────────
class _TooltipContent extends StatelessWidget {
  final CoachStep step;

  const _TooltipContent({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HCColor.of(context).surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: step.color.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: step.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(step.icon, color: step.color, size: 28),
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            step.title,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: HCColor.of(context).textPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Description
          Text(
            step.description,
            style: AppTypography.bodyMedium.copyWith(
              color: HCColor.of(context).textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),

          // Action hint
          if (step.actionHint != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: step.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, size: 16, color: step.color),
                  const SizedBox(width: 6),
                  Text(
                    step.actionHint!,
                    style: AppTypography.labelSmall.copyWith(
                      color: step.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.1, end: 0, duration: 350.ms);
  }
}

// ────────────────────────────────────────
// Predefined tutorial step sets
// ────────────────────────────────────────

/// Tutorial steps for the Flashcard Viewer screen.
List<CoachStep> flashcardViewerTutorialSteps({
  GlobalKey? flipKey,
  GlobalKey? ttsKey,
  GlobalKey? fslKey,
  GlobalKey? navKey,
}) =>
    [
      CoachStep(
        title: 'Flip the Card 🔄',
        description:
            'Tap the card to flip it and see the translation in English or Filipino.',
        icon: Icons.flip_rounded,
        color: const Color(0xFF5C6BC0),
        targetKey: flipKey,
        actionHint: 'Tap the card to flip',
      ),
      CoachStep(
        title: 'Listen to Pronunciation 🔊',
        description:
            'Tap the speaker icon to hear the word spoken aloud in English or Filipino.',
        icon: Icons.volume_up_rounded,
        color: const Color(0xFF26A69A),
        targetKey: ttsKey,
        actionHint: 'Tap the speaker icon',
      ),
      CoachStep(
        title: 'Watch Sign Language 🤟',
        description:
            'Tap the FSL button to watch a Filipino Sign Language video for this word.',
        icon: Icons.sign_language_rounded,
        color: const Color(0xFFEF5350),
        targetKey: fslKey,
        actionHint: 'Tap to see FSL video',
      ),
      CoachStep(
        title: 'Navigate Cards ← →',
        description:
            'Swipe left or right, or use the arrow buttons to move between flashcards.',
        icon: Icons.swipe_rounded,
        color: const Color(0xFFFFA726),
        targetKey: navKey,
        actionHint: 'Swipe to navigate',
      ),
    ];

/// Tutorial steps for the Game Hub screen.
List<CoachStep> gameHubTutorialSteps({
  GlobalKey? difficultyKey,
  GlobalKey? categoryKey,
  GlobalKey? timedKey,
}) =>
    [
      CoachStep(
        title: 'Choose Difficulty 🎯',
        description:
            'Select Easy, Medium, or Hard. The app can also suggest a difficulty based on your progress!',
        icon: Icons.tune_rounded,
        color: const Color(0xFF4CAF50),
        targetKey: difficultyKey,
        actionHint: 'Tap to change difficulty',
      ),
      CoachStep(
        title: 'Pick Categories 📂',
        description:
            'Filter games to specific vocabulary categories, or play with all categories mixed.',
        icon: Icons.category_rounded,
        color: const Color(0xFFFF9800),
        targetKey: categoryKey,
        actionHint: 'Tap to select categories',
      ),
      CoachStep(
        title: 'Timed Mode ⏱️',
        description:
            'Enable timed mode for an extra challenge! Race against the clock to earn bonus stars.',
        icon: Icons.timer_rounded,
        color: const Color(0xFFF44336),
        targetKey: timedKey,
        actionHint: 'Toggle timed mode',
      ),
    ];

/// Tutorial steps for the Progress screen.
List<CoachStep> progressTutorialSteps({
  GlobalKey? streakKey,
  GlobalKey? categoryKey,
  GlobalKey? achievementKey,
}) =>
    [
      CoachStep(
        title: 'Your Streak 🔥',
        description:
            'See how many consecutive days you\'ve been learning. Keep it going!',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFEF5350),
        targetKey: streakKey,
        actionHint: 'View your daily streak',
      ),
      CoachStep(
        title: 'Category Progress 📊',
        description:
            'Track your mastery in each vocabulary category. Aim for 100% in every category!',
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFF5C6BC0),
        targetKey: categoryKey,
        actionHint: 'Check your progress',
      ),
      CoachStep(
        title: 'Achievements 🏆',
        description:
            'Unlock badges by reaching milestones — learn words, maintain streaks, and play games!',
        icon: Icons.emoji_events_rounded,
        color: const Color(0xFFFFA726),
        targetKey: achievementKey,
        actionHint: 'View your badges',
      ),
    ];
