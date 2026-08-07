import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/constants/flashcard_emojis.dart';
import '../core/services/flashcard_photo_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../data/local/seed_data.dart';
import '../data/models/enums.dart';
import '../data/models/models.dart';

/// A reusable widget that renders a visual representation of a flashcard.
///
/// A card has up to two picture faces, both from [FlashcardPhotoService]: an
/// illustrated **cartoon** and a **realistic** photograph. What it shows, in
/// priority order:
/// 1. the cartoon face, else
/// 2. [Flashcard.imageAsset] (a bundled asset) or the realistic photograph, else
/// 3. the mapped emoji in a styled container.
///
/// The emoji is a **last-resort fallback only** — for the words that have no
/// picture yet (the Actions verbs and the later extra words), and for the moment
/// before a picture finishes downloading or when the device is offline. Any card
/// with a picture shows the picture, never the emoji.
///
/// Two modes:
///  * **Static** (default) — shows the cartoon if there is one, else the
///    photograph, else the emoji. Used inside games and lists where a tap means
///    something else.
///  * **[interactive]** — shows the cartoon first and lets the user **tap to
///    flip** to the realistic photograph (and back again), with a clear
///    on-screen instruction. Used in the flashcard viewer. A card with only one
///    face never flips — Colors & Shapes and Numbers are realistic-only by
///    design — so it renders statically instead, with no misleading tap hint.
///
/// Sizing: by default the box is [size] × 1.6 (square). Pass [expand] = true to
/// fill the parent's constraints instead.
class FlashcardImage extends StatefulWidget {
  /// The flashcard to visualise.
  final Flashcard card;

  /// Emoji / icon size. The container is [size] × 1.6. Ignored when [expand].
  final double size;

  /// Background colour override (defaults to category colour at 12% opacity).
  final Color? backgroundColor;

  /// Border radius of the container.
  final double borderRadius;

  /// Whether to show a subtle border around the container.
  final bool showBorder;

  /// Fill the parent's constraints instead of using a fixed [size] box.
  final bool expand;

  /// Cartoon-first, tap to flip to the realistic photograph and back, with an
  /// instruction caption. Only takes effect when the card actually has *both*
  /// faces. The toggle plays the same smooth 3D flip the viewer's big card uses.
  final bool interactive;

  /// Honour the accessibility "reduced motion" setting for the [interactive]
  /// flip (near-instant cross-fade instead of the full 3D rotation).
  final bool reducedMotion;

  /// Draw a black outline effect on the emoji glyph and a black frame around
  /// the pictures (Color: Black · Size: 25 · Intensity: 50). Used only on the
  /// flashcard viewer's interactive card; off everywhere else.
  final bool outlined;

  const FlashcardImage({
    super.key,
    required this.card,
    this.size = 72,
    this.backgroundColor,
    this.borderRadius = 24,
    this.showBorder = false,
    this.expand = false,
    this.interactive = false,
    this.reducedMotion = false,
    this.outlined = false,
  });

  /// The instruction shown in [interactive] mode for the current face. Worded
  /// to match the Stories tap-to-flip pictures so both features read the same.
  static String tapHint({required bool showingPhoto}) => showingPhoto
      ? 'Tap to see the cartoon picture.'
      : 'Tap to see the real picture.';

  @override
  State<FlashcardImage> createState() => _FlashcardImageState();
}

class _FlashcardImageState extends State<FlashcardImage> {
  /// The realistic photograph (bundled asset or downloaded).
  ImageProvider? _photo;
  bool _resolving = false;

  /// The illustrated face. Null for realistic-only cards.
  ImageProvider? _cartoon;
  bool _resolvingCartoon = false;

  /// Interactive toggle — the cartoon face is shown first.
  bool _showPhoto = false;

  // ─── Outline effect (Color: Black · Size: 25 · Intensity: 50) ──────
  // A black frame around the emoji card and the photo. Applied only when
  // [widget.outlined] is true (the viewer's card).
  static const Color _outlineColor = Colors.black;
  static const double _outlineIntensity = 0.50; // "Intensity: 50" → alpha
  static const double _photoFrameWidth = 3.5; // "Size: 25" frame thickness

  bool get _hasAssetPhoto =>
      widget.card.imageAsset != null && widget.card.imageAsset!.isNotEmpty;
  bool get _hasManifestPhoto => FlashcardPhotoService.hasPhoto(widget.card);
  bool get _hasPhotoSource => _hasAssetPhoto || _hasManifestPhoto;
  bool get _hasCartoonSource =>
      FlashcardPhotoService.cartoonUrlFor(widget.card) != null;

  /// Both faces present — only then does tapping flip between them.
  bool get _canFlip => _hasCartoonSource && _hasPhotoSource;

  @override
  void initState() {
    super.initState();
    _resolveCartoon();
    // The photograph is the only face on realistic-only cards, so fetch it up
    // front there; on flippable cards it can wait until the first flip.
    if (!_hasCartoonSource) _resolvePhoto();
  }

  @override
  void didUpdateWidget(covariant FlashcardImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _photo = null;
      _cartoon = null;
      _resolving = false;
      _resolvingCartoon = false;
      _showPhoto = false; // a new card starts on the cartoon again
      _resolveCartoon();
      if (!_hasCartoonSource) _resolvePhoto();
    }
  }

  void _resolvePhoto() {
    if (!_hasPhotoSource || _photo != null) return;

    if (_hasAssetPhoto) {
      _photo = AssetImage(widget.card.imageAsset!);
      return;
    }

    final cached = FlashcardPhotoService.resolvedFile(widget.card);
    if (cached != null) {
      _photo = FileImage(cached);
      return;
    }

    if (_resolving) return;
    _resolving = true;
    FlashcardPhotoService.photoFile(widget.card).then((file) {
      _resolving = false;
      if (!mounted || file == null) return;
      setState(() => _photo = FileImage(file));
    });
  }

  void _resolveCartoon() {
    if (!_hasCartoonSource || _cartoon != null) return;

    final cached = FlashcardPhotoService.resolvedCartoon(widget.card);
    if (cached != null) {
      _cartoon = FileImage(cached);
      return;
    }

    if (_resolvingCartoon) return;
    _resolvingCartoon = true;
    FlashcardPhotoService.cartoonFile(widget.card).then((file) {
      _resolvingCartoon = false;
      if (!mounted || file == null) return;
      setState(() => _cartoon = FileImage(file));
    });
  }

  void _toggle() {
    setState(() => _showPhoto = !_showPhoto);
    if (_showPhoto) _resolvePhoto();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.interactive && _canFlip) return _buildInteractive();

    // Static: the cartoon is the card's identity face, so prefer it; fall back
    // to the photograph (the only face on Colors & Shapes / Numbers) and
    // finally to the emoji for words that have no picture at all.
    final face = _cartoon ?? _photo;
    return face != null ? _photoFrame(face) : _emoji();
  }

  // ─── Interactive (tap to toggle, animated 3D flip) ────────────────
  Widget _buildInteractive() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MergeSemantics(
          child: Semantics(
            button: true,
            label: _showPhoto
                ? 'Real picture of ${widget.card.wordEnglish}. '
                      'Tap to see the cartoon picture.'
                : 'Cartoon picture of ${widget.card.wordEnglish}. '
                      'Tap to see the real picture.',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              // Reuse the same smooth 3D flip the viewer's big card uses
              // (650ms easeOutBack), so the cartoon⇄photo toggle animates
              // instead of snapping instantly.
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _showPhoto ? math.pi : 0),
                duration: widget.reducedMotion
                    ? const Duration(milliseconds: 80)
                    : const Duration(milliseconds: 650),
                curve: widget.reducedMotion
                    ? Curves.linear
                    : Curves.easeOutBack,
                builder: (context, value, child) {
                  final showFront = value < math.pi / 2;
                  final face = showFront
                      ? _cartoonFace()
                      : Transform(
                          // Counter-rotate the back face so the photo isn't
                          // mirrored once the card flips past 90°.
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: _photoFace(),
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
        const SizedBox(height: 12),
        _tapHintPill(),
      ],
    );
  }

  /// Front face of the flip: the cartoon once resolved, otherwise the emoji.
  ///
  /// Deliberately no spinner. This face paints the moment the card appears, so
  /// a slow or offline fetch would leave an indicator spinning indefinitely on
  /// every card the learner scrolls past. The emoji stands in silently instead
  /// and is swapped for the picture when it arrives.
  Widget _cartoonFace() => _cartoon != null ? _photoFrame(_cartoon!) : _emoji();

  /// Back face of the flip: the realistic photo once resolved, otherwise the
  /// cartoon that's already on screen with a spinner over it. The spinner is
  /// warranted here — the learner asked for this face by tapping, so it's
  /// feedback for a wait they initiated.
  Widget _photoFace() {
    if (_photo != null) return _photoFrame(_photo!);
    return Stack(
      alignment: Alignment.center,
      children: [
        _cartoon != null ? _photoFrame(_cartoon!) : _emoji(),
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ],
    );
  }

  Widget _tapHintPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _showPhoto ? Icons.brush_rounded : Icons.photo_camera_rounded,
            size: 20,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 8),
          // No Flexible/Expanded here: the viewer hosts this inside a
          // FittedBox (unbounded width), where a flex child would throw. The
          // FittedBox scales the whole pill to fit instead.
          Text(
            FlashcardImage.tapHint(showingPhoto: _showPhoto),
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Faces ────────────────────────────────────────────────────────
  Widget _photoFrame(ImageProvider provider) {
    final clip = BorderRadius.circular(widget.borderRadius);

    if (widget.expand) {
      return RepaintBoundary(
        child: Semantics(
          image: true,
          label: '${widget.card.wordEnglish}, ${widget.card.wordFilipino}',
          child: _maybeFrame(
            ClipRRect(
              borderRadius: clip,
              clipBehavior: Clip.hardEdge,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dpr = MediaQuery.devicePixelRatioOf(context);
                  final side = constraints.biggest.shortestSide.isFinite
                      ? constraints.biggest.shortestSide
                      : 160.0;
                  final cache = (side * dpr).ceil();
                  return Image(
                    image: ResizeImage(
                      provider,
                      width: cache,
                      height: cache,
                      policy: ResizeImagePolicy.fit,
                    ),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => _emoji(),
                  );
                },
              ),
            ),
            clip,
          ),
        ),
      );
    }

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheExtent = (widget.size * 1.6 * devicePixelRatio).ceil();
    final boxSize = widget.size * 1.6;
    return RepaintBoundary(
      child: Semantics(
        image: true,
        label: '${widget.card.wordEnglish}, ${widget.card.wordFilipino}',
        child: _maybeFrame(
          ClipRRect(
            borderRadius: clip,
            clipBehavior: Clip.hardEdge,
            child: Image(
              image: ResizeImage(
                provider,
                width: cacheExtent,
                height: cacheExtent,
                policy: ResizeImagePolicy.fit,
              ),
              width: boxSize,
              height: boxSize,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _emoji(),
            ),
          ),
          clip,
        ),
      ),
    );
  }

  Widget _emoji() {
    final emoji = FlashcardEmojis.forId(widget.card.id);
    final catColor = widget.card.category.color;
    final bg = widget.backgroundColor ?? catColor.withValues(alpha: 0.12);
    final border = widget.showBorder
        ? Border.all(color: catColor.withValues(alpha: 0.3), width: 2)
        : null;
    final decoration = BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(widget.borderRadius),
      border: border,
    );

    final Widget box = widget.expand
        ? SizedBox.expand(
            child: DecoratedBox(
              decoration: decoration,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: FittedBox(
                    child: Text(emoji, style: const TextStyle(height: 1.15)),
                  ),
                ),
              ),
            ),
          )
        : Container(
            width: widget.size * 1.6,
            height: widget.size * 1.6,
            decoration: decoration,
            alignment: Alignment.center,
            child: Text(
              emoji,
              style: TextStyle(fontSize: widget.size, height: 1.15),
            ),
          );

    return Semantics(
      image: true,
      label: '${widget.card.wordEnglish}, ${widget.card.wordFilipino}',
      // The emoji card gets the same black frame as the photo face.
      child: _maybeFrame(box, BorderRadius.circular(widget.borderRadius)),
    );
  }

  /// Wraps the emoji card or a clipped photo with the black frame
  /// (foreground-painted, so it adds no layout) when [widget.outlined].
  Widget _maybeFrame(Widget child, BorderRadius clip) {
    if (!widget.outlined) return child;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: clip,
        border: Border.all(
          color: _outlineColor.withValues(alpha: _outlineIntensity),
          width: _photoFrameWidth,
        ),
      ),
      child: child,
    );
  }
}

/// A compact variant for use in grids, game tiles, and smaller contexts.
class FlashcardImageSmall extends StatelessWidget {
  final Flashcard card;
  final double size;

  const FlashcardImageSmall({super.key, required this.card, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return FlashcardImage(card: card, size: size, borderRadius: 12);
  }
}

/// A card's picture sized to a fixed square [extent], for the places that used
/// to render a bare emoji glyph (game tiles, word rows, result panels).
///
/// [extent] is the box side at the default text scale and grows with the user's
/// text-size setting, exactly as the emoji glyph it replaces did — so low-vision
/// presets still enlarge the picture and the existing overflow matrices keep
/// measuring the same thing.
class FlashcardPicture extends StatelessWidget {
  final Flashcard card;

  /// Box side at 1.0 text scale.
  final double extent;

  final double borderRadius;

  const FlashcardPicture({
    super.key,
    required this.card,
    required this.extent,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.textScalerOf(context).scale(extent);
    return SizedBox(
      width: side,
      height: side,
      child: FlashcardImage(
        card: card,
        expand: true,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// [FlashcardPicture] for a card known only by its id.
///
/// Used by the multiplayer race players, whose boards arrive over the wire from
/// the other device. Falls back to [fallback] — the emoji the peer sent — when
/// the id matches no seed card, so a peer on an older build (which sends no
/// `card_id` at all) still shows something rather than an empty tile.
class FlashcardPictureById extends StatelessWidget {
  final String? cardId;

  /// Shown when [cardId] is null or unknown.
  final String fallback;

  final double extent;
  final double borderRadius;

  const FlashcardPictureById({
    super.key,
    required this.cardId,
    required this.fallback,
    required this.extent,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final id = cardId;
    if (id != null) {
      for (final c in SeedData.allFlashcards) {
        if (c.id == id) {
          return FlashcardPicture(
            card: c,
            extent: extent,
            borderRadius: borderRadius,
          );
        }
      }
    }
    return Text(
      fallback,
      style: TextStyle(fontSize: extent * 0.85, height: 1.15),
    );
  }
}

/// Just the emoji text, no container. Useful inline.
class FlashcardEmoji extends StatelessWidget {
  final String cardId;
  final double fontSize;

  const FlashcardEmoji({super.key, required this.cardId, this.fontSize = 48});

  @override
  Widget build(BuildContext context) {
    return Text(
      FlashcardEmojis.forId(cardId),
      style: TextStyle(fontSize: fontSize, height: 1.15),
    );
  }
}
