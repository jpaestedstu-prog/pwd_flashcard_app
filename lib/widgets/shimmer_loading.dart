import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

/// A pastel shimmer effect widget that replaces loading spinners.
///
/// Wraps any child in a sweeping shine animation. Commonly used with
/// skeleton placeholder shapes to show content layout while loading.
///
/// Respects reduced-motion — falls back to a gentle pulse.
///
/// Usage:
/// ```dart
/// ShimmerLoading(
///   child: ShimmerBox(width: 200, height: 20),
/// )
/// ```
class ShimmerLoading extends ConsumerStatefulWidget {
  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  final Widget child;

  /// Base skeleton color. Defaults to theme surface variant.
  final Color? baseColor;

  /// Shimmer highlight sweep color. Defaults to lighter theme surface.
  final Color? highlightColor;

  /// Duration for one full shimmer sweep.
  final Duration duration;

  @override
  ConsumerState<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends ConsumerState<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;

    final base = widget.baseColor ??
        scheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final highlight = widget.highlightColor ??
        scheme.surface.withValues(alpha: 0.8);

    // Reduced motion: gentle pulsing opacity instead of sweep
    if (settings.reducedMotion) {
      return _PulseShimmer(
        baseColor: base,
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + 2.0 * _controller.value, -0.3),
              end: Alignment(1.0 + 2.0 * _controller.value, 0.3),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Gentle pulse animation fallback for reduced-motion.
class _PulseShimmer extends StatefulWidget {
  const _PulseShimmer({
    required this.baseColor,
    required this.child,
  });

  final Color baseColor;
  final Widget child;

  @override
  State<_PulseShimmer> createState() => _PulseShimmerState();
}

class _PulseShimmerState extends State<_PulseShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.4 + 0.4 * _controller.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ─── Skeleton Primitives ──────────────────────────────

/// A rounded rectangle placeholder box for shimmer skeletons.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A circular placeholder for avatar/icon shimmer.
class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─── Pre-built Skeleton Templates ─────────────────────

/// Skeleton for a card with icon, title, and subtitle.
/// Mimics the common AppCard / FeatureBanner layout.
class ShimmerCardSkeleton extends StatelessWidget {
  const ShimmerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            children: [
              ShimmerCircle(),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 140, height: 18),
                    SizedBox(height: 10),
                    ShimmerBox(height: 14),
                    SizedBox(height: 8),
                    ShimmerBox(width: 100, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for the home screen stats banner.
class ShimmerStatsBannerSkeleton extends StatelessWidget {
  const ShimmerStatsBannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
            3,
            (_) => const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShimmerCircle(size: 28),
                SizedBox(height: 8),
                ShimmerBox(width: 40, height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for a grid of game/category cards.
class ShimmerGridSkeleton extends StatelessWidget {
  const ShimmerGridSkeleton({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.2,
  });

  final int itemCount;
  final int crossAxisCount;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(16),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShimmerCircle(size: 40),
                SizedBox(height: 12),
                ShimmerBox(width: 80, height: 14),
                SizedBox(height: 8),
                ShimmerBox(width: 50, height: 10),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton for a list of items (flashcards, stories, etc.).
class ShimmerListSkeleton extends StatelessWidget {
  const ShimmerListSkeleton({
    super.key,
    this.itemCount = 5,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        children: List.generate(
          itemCount,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  ShimmerBox(width: 56, height: 56, borderRadius: 16),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 120),
                        SizedBox(height: 8),
                        ShimmerBox(height: 12),
                      ],
                    ),
                  ),
                  ShimmerBox(width: 24, height: 24, borderRadius: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-page loading skeleton — replaces `Center(child: CircularProgressIndicator())`.
/// Shows a shimmer layout with a stats banner placeholder + list items.
class ShimmerPageSkeleton extends StatelessWidget {
  const ShimmerPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title area
            ShimmerLoading(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 180, height: 24),
                  SizedBox(height: 10),
                  ShimmerBox(width: 240, height: 14),
                ],
              ),
            ),
            SizedBox(height: 24),
            // Banner placeholder
            ShimmerStatsBannerSkeleton(),
            SizedBox(height: 24),
            // List items
            Expanded(child: ShimmerListSkeleton(itemCount: 4)),
          ],
        ),
      ),
    );
  }
}
