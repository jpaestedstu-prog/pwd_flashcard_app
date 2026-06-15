import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/services/flashcard_photo_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';
import 'media_sheet_layout.dart';

/// Opens a swipeable gallery of several real-world example photos for a card.
///
/// Used to enrich "simple" vocabulary (colors, numbers) — e.g. *Red* shown as a
/// red apple, a red car, and a red ball — which is far clearer than a single
/// swatch. Photos come from [FlashcardPhotoService] (main photo + the extra
/// `galleries` entries) and are downloaded + cached on demand.
Future<void> showExamplesGallery(BuildContext context, Flashcard card) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ExamplesGallerySheet(card: card),
  );
}

/// A compact pill that opens the "Examples" gallery. Renders nothing unless the
/// card actually has extra example photos configured, so it's safe to drop in.
class ExamplesButton extends StatelessWidget {
  final Flashcard card;

  const ExamplesButton({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    if (!FlashcardPhotoService.hasGallery(card)) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: 'See example photos of ${card.wordEnglish}',
      child: Material(
        color: AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => showExamplesGallery(context, card),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_library_rounded,
                  size: 20,
                  color: AppColors.accentDark,
                ),
                const SizedBox(width: 6),
                Text(
                  'Examples',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.accentDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExamplesGallerySheet extends StatefulWidget {
  final Flashcard card;
  const _ExamplesGallerySheet({required this.card});

  @override
  State<_ExamplesGallerySheet> createState() => _ExamplesGallerySheetState();
}

class _ExamplesGallerySheetState extends State<_ExamplesGallerySheet> {
  final PageController _pageController = PageController();
  List<File> _images = [];
  bool _loading = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await FlashcardPhotoService.load();

    // Main photo first (if any), then each extra example, in order.
    final files = <File>[];
    final main = await FlashcardPhotoService.photoFile(widget.card);
    if (main != null) files.add(main);

    final count = FlashcardPhotoService.galleryUrls(widget.card).length;
    for (var i = 0; i < count; i++) {
      final f = await FlashcardPhotoService.galleryFile(widget.card, i);
      if (f != null) files.add(f);
    }

    if (!mounted) return;
    setState(() {
      _images = files;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MediaSheetLayout(
      icon: Icons.photo_library_rounded,
      iconColor: AppColors.accentDark,
      title: 'Examples — ${widget.card.wordEnglish}',
      caption: widget.card.wordFilipino,
      mediaBuilder: (_) => _buildMedia(context),
      belowMedia: _buildDots(),
    );
  }

  Widget _buildMedia(BuildContext context) {
    final hc = HCColor.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_images.isEmpty) {
      return Center(
        child: Text(
          "These examples aren't available right now.",
          style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }
    return PageView.builder(
      controller: _pageController,
      itemCount: _images.length,
      onPageChanged: (i) => setState(() => _page = i),
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            _images[i],
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget? _buildDots() {
    if (_loading || _images.length < 2) return null;
    final hc = HCColor.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_images.length, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? AppColors.accentDark
                : hc.textSecondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
