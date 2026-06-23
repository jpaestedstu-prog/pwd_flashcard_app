import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// One edge target: a depth-styled circle that brightens and fills a progress
/// ring as the learner dwells on it. Shared by the full-screen preview
/// ([GazeControlScreen]) and the in-context viewer overlay so the dwell
/// affordance looks identical everywhere.
class GazeTarget extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final double progress;

  /// Diameter of the circle. Defaults to the full-screen size; the viewer
  /// overlay uses a smaller value so it doesn't crowd the flashcard.
  final double size;

  const GazeTarget({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.progress,
    this.size = 84,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Gaze target: $label',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: active ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 180),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: active ? 1 : 0.7),
                          color.withValues(alpha: active ? 0.8 : 0.45),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: active ? 0.6 : 0.25),
                          blurRadius: active ? 22 : 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: size * 0.45),
                  ),
                  if (progress > 0)
                    SizedBox(
                      width: size,
                      height: size,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Camera preview scaled to cover/contain its box, mirrored so the learner
/// sees themselves naturally (like a mirror). Used full-screen in the preview
/// and as a small picture-in-picture in the viewer overlay.
class GazeCameraView extends StatelessWidget {
  final CameraController controller;
  final bool mirror;
  final BoxFit fit;

  const GazeCameraView({
    super.key,
    required this.controller,
    this.mirror = true,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return const SizedBox.shrink();
    // previewSize is reported landscape-oriented; swap in portrait so the
    // FittedBox fills correctly on phones and tablets alike.
    final portrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final width = portrait ? previewSize.height : previewSize.width;
    final height = portrait ? previewSize.width : previewSize.height;
    Widget preview = FittedBox(
      fit: fit,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: width,
        height: height,
        child: CameraPreview(controller),
      ),
    );
    if (mirror) {
      preview = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(3.1415926535),
        child: preview,
      );
    }
    return preview;
  }
}
