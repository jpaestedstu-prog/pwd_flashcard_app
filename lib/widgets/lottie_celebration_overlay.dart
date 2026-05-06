import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../core/constants/app_constants.dart';

/// A celebration overlay that plays a Lottie animation on top of a [child].
///
/// Works alongside the existing [CelebrationOverlay] (confetti) — designed
/// to be composed in a `Stack`:
///
/// ```dart
/// LottieCelebrationOverlay(
///   show: _showCelebration,
///   lottieAsset: celebrationService.lottieAssetFor(CelebrationType.gameComplete),
///   child: CelebrationOverlay(
///     show: _showCelebration,
///     child: Scaffold(/* ... */),
///   ),
/// )
/// ```
///
/// When [show] flips to `true` and [lottieAsset] is non-null, the animation
/// plays once and then fades out. If [lottieAsset] is null (e.g. because
/// `reducedMotion` is enabled), only the [child] is rendered.
class LottieCelebrationOverlay extends StatefulWidget {
  /// Whether the celebration is currently active.
  final bool show;

  /// The Lottie JSON asset path to play, or `null` to skip animation.
  /// Typically obtained from [CelebrationService.lottieAssetFor].
  final String? lottieAsset;

  /// The widget to render underneath the animation.
  final Widget child;

  /// How long the animation remains visible. Defaults to
  /// [AppConstants.celebrationDuration] (3 seconds).
  final Duration duration;

  /// Size of the Lottie animation widget. Defaults to 200×200.
  final double animationSize;

  const LottieCelebrationOverlay({
    super.key,
    required this.show,
    required this.child,
    this.lottieAsset,
    this.duration = AppConstants.celebrationDuration,
    this.animationSize = 200,
  });

  @override
  State<LottieCelebrationOverlay> createState() =>
      _LottieCelebrationOverlayState();
}

class _LottieCelebrationOverlayState extends State<LottieCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _visible = false;
  String? _currentAsset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener(_onAnimationStatus);
  }

  @override
  void didUpdateWidget(LottieCelebrationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger when show flips from false → true
    if (widget.show && !oldWidget.show && widget.lottieAsset != null) {
      _play(widget.lottieAsset!);
    }
    // Also trigger if asset changes while showing
    if (widget.show &&
        widget.lottieAsset != null &&
        widget.lottieAsset != oldWidget.lottieAsset) {
      _play(widget.lottieAsset!);
    }
  }

  void _play(String asset) {
    setState(() {
      _visible = true;
      _currentAsset = asset;
    });
    _controller.reset();
    // Let the Lottie widget drive the controller via onLoaded
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Keep visible briefly after completion, then fade out
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _visible = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_visible && _currentAsset != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Center(
                  child: SizedBox(
                    width: widget.animationSize,
                    height: widget.animationSize,
                    child: Lottie.asset(
                      _currentAsset!,
                      controller: _controller,
                      onLoaded: (composition) {
                        _controller.duration = composition.duration;
                        _controller.forward();
                      },
                      errorBuilder: (context, error, stackTrace) {
                        // Silently degrade — don't break UX for missing animations
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
