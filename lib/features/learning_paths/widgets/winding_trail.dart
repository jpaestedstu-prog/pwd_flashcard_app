import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';

/// State of a single node on a [WindingTrail].
///
/// [current] is the single "next up" node and pulses; [available] nodes are
/// also unlocked/tappable but render calmly (no pulse) so only one node draws
/// the eye. The single-path lesson trail only uses done/current/locked.
enum TrailNodeState { done, current, available, locked }

/// Declarative description of one node on a [WindingTrail]. The trail owns all
/// geometry and styling; callers just supply state + content + a tap handler.
@immutable
class TrailNode {
  const TrailNode({
    required this.state,
    required this.label,
    required this.accent,
    this.emoji,
    this.pillText,
    this.onTap,
  });

  final TrailNodeState state;

  /// Short caption shown beneath the node (ellipsized to two lines).
  final String label;

  /// Identity colour for the node when it's the current/active one.
  final Color accent;

  /// Emoji shown inside the node circle when it isn't locked. Locked nodes
  /// always render a lock glyph regardless of this.
  final String? emoji;

  /// Optional pill beneath the label (e.g. "START", "REPLAY", "2/5").
  final String? pillText;

  final VoidCallback? onTap;
}

/// A Duolingo-style winding vertical trail of nodes, climbed bottom-to-top.
///
/// Shared by the single-path lesson trail and the top-level "world of regions"
/// map, so both look and behave identically. The layout is deterministic
/// (fixed-geometry `Stack` inside a scroll view, row height scales with the
/// Font Size setting, labels cap to two ellipsized lines), which keeps it
/// overflow-safe at any tablet size or text scale — see
/// test/lesson_trail_overflow_test.dart and test/world_map_overflow_test.dart.
class WindingTrail extends StatelessWidget {
  const WindingTrail({super.key, required this.nodes});

  final List<TrailNode> nodes;

  // Horizontal placement pattern (fraction of width) that zigzags nodes gently
  // around the centre.
  static const List<double> _xPattern = [0.5, 0.76, 0.5, 0.24];

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    if (nodes.isEmpty) return const SizedBox.shrink();

    final nodeSize = context.scaledHeightCapped(72, max: 1.4);
    final rowH = context.scaledHeightCapped(132);
    const cellWidth = 132.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final centers = <Offset>[
          for (var i = 0; i < nodes.length; i++)
            Offset(_xPattern[i % _xPattern.length] * width, rowH * i + rowH / 2),
        ];
        final completedFlags = [
          for (final n in nodes) n.state == TrailNodeState.done,
        ];

        final positioned = <Widget>[];
        for (var i = 0; i < nodes.length; i++) {
          final center = centers[i];
          final left = (center.dx - cellWidth / 2).clamp(0.0, width - cellWidth);
          positioned.add(Positioned(
            left: left,
            top: center.dy - rowH / 2,
            width: cellWidth,
            height: rowH,
            child: _TrailNodeView(node: nodes[i], nodeSize: nodeSize),
          ));
        }

        return SizedBox(
          width: width,
          height: rowH * nodes.length,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _TrailPathPainter(
                    centers: centers,
                    completedFlags: completedFlags,
                    doneColor: AppColors.success,
                    pendingColor: hc.border,
                  ),
                ),
              ),
              ...positioned,
            ],
          ),
        );
      },
    );
  }
}

/// Renders one node: a circular "stone" with its glyph/state + a capped label.
class _TrailNodeView extends StatelessWidget {
  const _TrailNodeView({required this.node, required this.nodeSize});

  final TrailNode node;
  final double nodeSize;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final isDone = node.state == TrailNodeState.done;
    final isCurrent = node.state == TrailNodeState.current;
    final isAvailable = node.state == TrailNodeState.available;
    final isLocked = node.state == TrailNodeState.locked;

    final circleColor = isDone
        ? AppColors.success
        : isCurrent
            ? node.accent
            : isAvailable
                ? hc.surface
                : hc.surfaceVariant;

    final glyph = isLocked
        ? Icon(Icons.lock_rounded, size: nodeSize * 0.4, color: hc.textHint)
        : Text(node.emoji ?? '•', style: TextStyle(fontSize: nodeSize * 0.42));

    Widget circle = Container(
      width: nodeSize,
      height: nodeSize,
      decoration: BoxDecoration(
        color: circleColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isCurrent || isAvailable
              ? node.accent
              : isDone
                  ? AppColors.success
                  : hc.border,
          width: isCurrent ? 4 : 2,
        ),
        boxShadow: isCurrent || isDone
            ? [
                BoxShadow(
                  color: circleColor.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: glyph,
    );

    if (isDone) {
      circle = Stack(
        clipBehavior: Clip.none,
        children: [
          circle,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: hc.surface, width: 2),
              ),
              child: const Icon(Icons.check_rounded,
                  size: 14, color: AppColors.textOnPrimary),
            ),
          ),
        ],
      );
    }

    if (isCurrent) {
      circle = circle
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            duration: 900.ms,
            begin: const Offset(1, 1),
            end: const Offset(1.08, 1.08),
            curve: Curves.easeInOut,
          );
    }

    final label = Text(
      node.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: AppTypography.labelSmall.copyWith(
        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
        color: isLocked ? hc.textHint : hc.textPrimary,
      ),
    );

    return Semantics(
      button: node.onTap != null,
      label: '${node.label}. ${isDone ? 'Completed' : isCurrent ? 'Current' : isAvailable ? 'Available' : 'Locked'}',
      child: GestureDetector(
        onTap: node.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            circle,
            const SizedBox(height: 8),
            Flexible(child: label),
            if (node.pillText != null) ...[
              const SizedBox(height: 4),
              _Pill(
                text: node.pillText!,
                color: isDone ? AppColors.success : node.accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textOnPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Draws smooth connectors between consecutive nodes. A segment is "done" when
/// the node it leads up from is completed.
class _TrailPathPainter extends CustomPainter {
  _TrailPathPainter({
    required this.centers,
    required this.completedFlags,
    required this.doneColor,
    required this.pendingColor,
  });

  final List<Offset> centers;
  final List<bool> completedFlags;
  final Color doneColor;
  final Color pendingColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < centers.length - 1; i++) {
      final p1 = centers[i];
      final p2 = centers[i + 1];
      paint.color = completedFlags[i] ? doneColor : pendingColor;
      final midY = (p1.dy + p2.dy) / 2;
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(p1.dx, midY, p2.dx, midY, p2.dx, p2.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_TrailPathPainter old) =>
      old.centers != centers ||
      old.completedFlags != completedFlags ||
      old.doneColor != doneColor ||
      old.pendingColor != pendingColor;
}
