import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/story_image_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/local/seed_stories.dart' show StoryImagePair;

/// A tap-to-flip story illustration that switches between a **cartoon** picture
/// and the matching **real-life** photograph, with a smooth 3D flip — the same
/// animation the Flashcards → Cards viewer uses for its emoji ⇄ photo toggle.
///
/// The cartoon is shown first. Tapping flips to the real photo (and back). A
/// caption beneath updates with the current face:
///   • cartoon  → "Tap to see the real picture."
///   • real-life → "Tap to see the cartoon picture."
///
/// Both faces are network pictures resolved + cached on-device by
/// [StoryImageService] (the seed data stores friendly share-page links). The
/// cartoon resolves immediately; the real photo resolves lazily on the first
/// flip. While a face loads it shows a spinner; if it can't be fetched (e.g.
/// offline first run) it shows a neutral placeholder, and the flip still works —
/// so the surrounding story / quiz stays fully usable in every scenario.
class StoryImageFlip extends StatefulWidget {
  /// The cartoon + real-life share-page URLs for this picture.
  final StoryImagePair pair;

  /// Stable, unique cache key base (e.g. `s_a01_page0`). Each face caches under
  /// `<cacheKey>_cartoon` / `<cacheKey>_real`.
  final String cacheKey;

  /// Accent colour — usually the story category colour. Used for the frame,
  /// placeholders and the caption pill.
  final Color color;

  /// Spoken subject for screen readers (e.g. the sentence / option text).
  final String semanticLabel;

  /// Honour the accessibility "reduced motion" setting — a near-instant
  /// cross-fade instead of the full 3D rotation.
  final bool reducedMotion;

  /// Smaller picture + caption, for the denser quiz answer-option rows.
  final bool compact;

  /// Largest width the picture is allowed to take (it shrinks to fit narrower
  /// parents). Defaults depend on [compact].
  final double? maxWidth;

  /// Width ÷ height of the picture box.
  final double aspectRatio;

  const StoryImageFlip({
    super.key,
    required this.pair,
    required this.cacheKey,
    required this.color,
    required this.semanticLabel,
    this.reducedMotion = false,
    this.compact = false,
    this.maxWidth,
    this.aspectRatio = 4 / 3,
  });

  /// The caption shown for the current face.
  static String tapHint({required bool showingReal}) => showingReal
      ? 'Tap to see the cartoon picture.'
      : 'Tap to see the real picture.';

  @override
  State<StoryImageFlip> createState() => _StoryImageFlipState();
}

class _StoryImageFlipState extends State<StoryImageFlip> {
  ImageProvider? _cartoon;
  ImageProvider? _real;
  bool _resolvingCartoon = false;
  bool _resolvingReal = false;
  bool _cartoonFailed = false;
  bool _realFailed = false;

  /// false = cartoon (shown first), true = real-life photo.
  bool _showReal = false;

  String get _cartoonKey => '${widget.cacheKey}_cartoon';
  String get _realKey => '${widget.cacheKey}_real';

  @override
  void initState() {
    super.initState();
    _resolveCartoon();
  }

  @override
  void didUpdateWidget(covariant StoryImageFlip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reused for a different page/item → reset to the cartoon and re-resolve.
    if (oldWidget.cacheKey != widget.cacheKey) {
      _cartoon = null;
      _real = null;
      _resolvingCartoon = false;
      _resolvingReal = false;
      _cartoonFailed = false;
      _realFailed = false;
      _showReal = false;
      _resolveCartoon();
    }
  }

  void _resolveCartoon() {
    if (_cartoon != null || _resolvingCartoon) return;
    final cached = StoryImageService.resolvedFile(_cartoonKey);
    if (cached != null) {
      _cartoon = FileImage(cached);
      return;
    }
    _resolvingCartoon = true;
    StoryImageService.imageFile(widget.pair.cartoonUrl, cacheKey: _cartoonKey)
        .then((file) {
      _resolvingCartoon = false;
      if (!mounted) return;
      setState(() {
        if (file != null) {
          _cartoon = FileImage(file);
        } else {
          _cartoonFailed = true;
        }
      });
    });
  }

  void _resolveReal() {
    if (_real != null || _resolvingReal) return;
    final cached = StoryImageService.resolvedFile(_realKey);
    if (cached != null) {
      _real = FileImage(cached);
      return;
    }
    _resolvingReal = true;
    StoryImageService.imageFile(widget.pair.realUrl, cacheKey: _realKey)
        .then((file) {
      _resolvingReal = false;
      if (!mounted) return;
      setState(() {
        if (file != null) {
          _real = FileImage(file);
        } else {
          _realFailed = true;
        }
      });
    });
  }

  void _toggle() {
    setState(() => _showReal = !_showReal);
    if (_showReal) _resolveReal();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MergeSemantics(
          child: Semantics(
            button: true,
            image: true,
            label: _showReal
                ? 'Real-life picture of ${widget.semanticLabel}. '
                      'Tap to see the cartoon picture.'
                : 'Cartoon picture of ${widget.semanticLabel}. '
                      'Tap to see the real picture.',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              // The same smooth 3D flip the flashcard viewer uses
              // (650ms easeOutBack), so cartoon ⇄ real animates instead of
              // snapping. Reduced motion → a quick near-instant turn.
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _showReal ? math.pi : 0),
                duration: widget.reducedMotion
                    ? const Duration(milliseconds: 80)
                    : const Duration(milliseconds: 650),
                curve: widget.reducedMotion
                    ? Curves.linear
                    : Curves.easeOutBack,
                builder: (context, value, child) {
                  final showFront = value < math.pi / 2;
                  final face = showFront
                      ? _face(real: false)
                      : Transform(
                          // Counter-rotate the back face so the photo isn't
                          // mirrored once the card flips past 90°.
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: _face(real: true),
                        );
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(value),
                    child: face,
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(height: widget.compact ? 8 : 12),
        _tapHintPill(),
      ],
    );
  }

  // ─── Faces ────────────────────────────────────────────────────────
  Widget _face({required bool real}) {
    final provider = real ? _real : _cartoon;
    final failed = real ? _realFailed : _cartoonFailed;
    final clip = BorderRadius.circular(widget.compact ? 16 : 20);
    final fallbackWidth = widget.maxWidth ?? (widget.compact ? 240.0 : 360.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : fallbackWidth;
        final w = math.min(avail, fallbackWidth);
        final h = w / widget.aspectRatio;

        Widget content;
        if (provider != null) {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          content = Image(
            image: ResizeImage(
              provider,
              width: (w * dpr).ceil(),
              height: (h * dpr).ceil(),
              policy: ResizeImagePolicy.fit,
            ),
            width: w,
            height: h,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _placeholder(w, h, failed: true),
          );
        } else {
          content = _placeholder(w, h, failed: failed);
        }

        return RepaintBoundary(
          child: Container(
            width: w,
            height: h,
            // Frame painted over the image, like the flashcard photo face.
            foregroundDecoration: BoxDecoration(
              borderRadius: clip,
              border: Border.all(
                color: widget.color.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: clip,
              clipBehavior: Clip.hardEdge,
              child: content,
            ),
          ),
        );
      },
    );
  }

  /// Shown while a face is downloading (spinner) or when it couldn't be
  /// fetched (a neutral broken-image icon). Keeps the layout stable either way.
  Widget _placeholder(double w, double h, {required bool failed}) {
    return Container(
      width: w,
      height: h,
      color: widget.color.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: failed
          ? Icon(
              Icons.image_not_supported_rounded,
              color: widget.color.withValues(alpha: 0.55),
              size: widget.compact ? 28 : 40,
            )
          : SizedBox(
              width: widget.compact ? 22 : 28,
              height: widget.compact ? 22 : 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(widget.color),
              ),
            ),
    );
  }

  Widget _tapHintPill() {
    // Darken the accent a touch so the caption stays legible on its own
    // 12%-tinted pill, regardless of how light the category colour is.
    final textColor = Color.lerp(widget.color, Colors.black, 0.25)!;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 12 : 16,
        vertical: widget.compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _showReal ? Icons.brush_rounded : Icons.photo_camera_rounded,
            size: widget.compact ? 16 : 20,
            color: textColor,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              StoryImageFlip.tapHint(showingReal: _showReal),
              style:
                  (widget.compact
                          ? AppTypography.labelLarge
                          : AppTypography.titleSmall)
                      .copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
