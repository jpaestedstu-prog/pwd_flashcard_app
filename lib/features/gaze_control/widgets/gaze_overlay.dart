import 'package:flutter/material.dart';

import '../controllers/gaze_controller.dart';
import '../models/gaze_action.dart';
import '../models/gaze_models.dart';
import 'gaze_widgets.dart';

/// Additive, **non-interactive** gaze overlay shared by every `GazeScope`.
///
/// It draws one dwell target per [GazeAction] at the edge matching its
/// [GazeZone], a small mirrored camera picture-in-picture, and a "look at the
/// screen" hint. Selection is handled by the owning `GazeScope` (via the
/// controller's `onSelect`/`onBlink`), so this widget is purely visual and
/// wrapped in [IgnorePointer] — touches fall straight through to the real UI.
///
/// In **scanning mode** [scanIndex] is non-null: the highlighted action lights
/// up (no dwell ring) and a "blink to choose" hint is shown.
class GazeOverlay extends StatelessWidget {
  final GazeController controller;
  final List<GazeAction> actions;

  /// Non-null only in scanning mode — the index of the action being highlighted.
  final int? scanIndex;

  const GazeOverlay({
    super.key,
    required this.controller,
    required this.actions,
    this.scanIndex,
  });

  bool get _scanning => scanIndex != null;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.status != GazeStatus.ready) {
            return SafeArea(child: _statusChip(controller.status));
          }
          return SafeArea(child: _content(faceVisible: controller.faceVisible));
        },
      ),
    );
  }

  Widget _content({required bool faceVisible}) {
    return Stack(
      children: [
        for (var i = 0; i < actions.length; i++)
          _positioned(actions[i], _targetFor(actions[i], i)),
        if (controller.cameraController != null)
          Positioned(top: 6, right: 8, child: _cameraPip()),
        ?_hint(faceVisible),
      ],
    );
  }

  /// The contextual hint, or null when there's nothing to say.
  Widget? _hint(bool faceVisible) {
    final String text;
    if (!faceVisible) {
      text = '😊  Look at the screen';
    } else if (_scanning) {
      text = '😉  Blink to choose';
    } else {
      return null;
    }
    return Align(alignment: const Alignment(0, -0.55), child: _chip(text));
  }

  Widget _targetFor(GazeAction action, int index) {
    final bool active = _scanning
        ? (index == scanIndex && action.enabled)
        : (controller.zone == action.zone && action.enabled);
    final double progress = (!_scanning && active) ? controller.progress : 0;
    final target = GazeTarget(
      label: action.label,
      icon: action.icon,
      color: action.color,
      active: active,
      progress: progress,
      size: 60,
    );
    return action.enabled ? target : Opacity(opacity: 0.4, child: target);
  }

  /// Places a target at the edge matching its zone. "Down" sits above the
  /// bottom action bar so it never covers the real controls.
  Widget _positioned(GazeAction action, Widget child) {
    switch (action.zone) {
      case GazeZone.up:
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(padding: const EdgeInsets.only(top: 4), child: child),
        );
      case GazeZone.left:
        return Align(alignment: Alignment.centerLeft, child: child);
      case GazeZone.right:
        return Align(alignment: Alignment.centerRight, child: child);
      case GazeZone.down:
        return Positioned(
          left: 0,
          right: 0,
          bottom: 150,
          child: Center(child: child),
        );
      case GazeZone.none:
        return const SizedBox.shrink();
    }
  }

  Widget _cameraPip() {
    final cam = controller.cameraController;
    if (cam == null) return const SizedBox.shrink();
    return Container(
      width: 72,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white70, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GazeCameraView(controller: cam),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
    );
  }

  Widget _statusChip(GazeStatus status) {
    final (icon, text) = switch (status) {
      GazeStatus.initializing => (Icons.hourglass_top_rounded, 'Starting gaze…'),
      GazeStatus.noCamera => (Icons.videocam_off_rounded, 'Gaze: no front camera'),
      GazeStatus.permissionDenied =>
        (Icons.lock_rounded, 'Gaze: camera permission needed'),
      _ => (Icons.error_outline_rounded, 'Gaze unavailable'),
    };
    return Align(
      alignment: const Alignment(0, -0.7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
