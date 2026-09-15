import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/routine_timeline.dart';

/// A picture of time running out: a coloured disc that shrinks, clockwise,
/// towards twelve o'clock as a step's time is used up.
///
/// The "time timer" shape special-education classrooms use because it needs
/// no numbers — how much colour is left *is* how much time is left. Drawn from
/// the shared ten-second clock, so it moves on its own with no animation loop
/// running (nothing to switch off for reduced motion), and frozen grey while
/// an adult has paused the step.
///
/// Carries no semantics of its own: every host already says the time left in
/// words, and a second node reading the same thing is one more to swipe past.
class RoutineTimeTimer extends StatelessWidget {
  const RoutineTimeTimer({
    super.key,
    required this.start,
    required this.end,
    required this.now,
    this.size = 96,
    this.emoji = '',
    this.paused = false,
  });

  final DateTime start;
  final DateTime end;
  final DateTime now;
  final double size;
  final String emoji;
  final bool paused;

  /// Share of the step's time still to go, 0–1.
  static double remainingFraction({
    required DateTime start,
    required DateTime end,
    required DateTime now,
  }) {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    final left = end.difference(now).inSeconds;
    return (left / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final fill = paused
        ? hc.textSecondary
        : (hc.hc ? hc.primary : AppColors.warning);
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _TimerPainter(
            remaining: remainingFraction(start: start, end: end, now: now),
            fill: fill,
            track: hc.textHint.withValues(alpha: hc.hc ? 0.35 : 0.18),
            rim: hc.hc ? hc.textPrimary : hc.border,
            rimWidth: hc.hc ? 3 : 2,
          ),
          child: Center(
            child: paused
                ? Icon(
                    Icons.pause_rounded,
                    size: size * 0.4,
                    color: hc.textPrimary,
                  )
                : (emoji.isEmpty
                    ? null
                    : Container(
                        width: size * 0.46,
                        height: size * 0.46,
                        decoration: BoxDecoration(
                          color: hc.surface,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          emoji,
                          style: TextStyle(
                            fontSize: size * 0.24,
                            height: 1.0,
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
                          textScaler: const TextScaler.linear(1.0),
                        ),
                      )),
          ),
        ),
      ),
    );
  }
}

class _TimerPainter extends CustomPainter {
  _TimerPainter({
    required this.remaining,
    required this.fill,
    required this.track,
    required this.rim,
    required this.rimWidth,
  });

  final double remaining;
  final Color fill;
  final Color track;
  final Color rim;
  final double rimWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - rimWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius, Paint()..color = track);
    if (remaining > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        remaining * 2 * math.pi,
        true,
        Paint()..color = fill,
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimWidth,
    );
  }

  @override
  bool shouldRepaint(_TimerPainter old) =>
      old.remaining != remaining ||
      old.fill != fill ||
      old.track != track ||
      old.rim != rim;
}

/// The timer with its words beside it: "12 min left · until 7:10 AM", or
/// "Paused". What the learner's Home card shows for the step that is on now.
class RoutineNowCountdown extends StatelessWidget {
  const RoutineNowCountdown({
    super.key,
    required this.start,
    required this.end,
    required this.now,
    required this.filipino,
    this.emoji = '',
    this.paused = false,
    this.timerSize = 72,
  });

  final DateTime start;
  final DateTime end;
  final DateTime now;
  final bool filipino;
  final String emoji;
  final bool paused;
  final double timerSize;

  /// "12 min left", "Almost done", "Paused" — also what hosts put in their
  /// own semantics label.
  static String leftLabel({
    required DateTime end,
    required DateTime now,
    required bool filipino,
    bool paused = false,
  }) {
    if (paused) return filipino ? 'Nakahinto' : 'Paused';
    final left = minutesUntilEnd(end, now);
    if (left <= 1) return filipino ? 'Malapit nang tapos' : 'Almost done';
    return filipino ? '$left minuto natitira' : '$left min left';
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = filipino;
    final headline = leftLabel(end: end, now: now, filipino: l, paused: paused);
    final detail = paused
        ? (l
            ? 'Ang iyong guro o magulang ay magpapatuloy dito.'
            : 'Your teacher or parent will start it again.')
        : (l ? 'hanggang ${formatClockOf(end)}' : 'until ${formatClockOf(end)}');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RoutineTimeTimer(
          start: start,
          end: end,
          now: now,
          size: timerSize,
          emoji: emoji,
          paused: paused,
        ),
        const SizedBox(width: 14),
        Flexible(
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    color: hc.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  detail,
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
