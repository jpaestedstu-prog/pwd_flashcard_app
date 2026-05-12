import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/fsl_fullscreen_player.dart';
import '../../../widgets/shimmer_loading.dart';

/// Browse all flashcard words grouped by category and watch their
/// Filipino Sign Language (FSL) videos. Acts as a stand-alone
/// FSL dictionary independent of the flashcard viewer.
class FslDictionaryScreen extends ConsumerStatefulWidget {
  const FslDictionaryScreen({super.key});

  @override
  ConsumerState<FslDictionaryScreen> createState() =>
      _FslDictionaryScreenState();
}

class _FslDictionaryScreenState extends ConsumerState<FslDictionaryScreen> {
  FlashcardCategory? _selectedCategory;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final allCards = SeedData.allFlashcards;
    final profileId = ref.watch(profileProvider)?.id;
    // Catalog is hydrated by the FutureProvider; null while the first
    // Firestore read is in-flight (rare — usually cached). Treat that as
    // "no videos yet" for the badge, but the sheet still resolves on tap.
    final availability =
        ref.watch(fslAvailabilityProvider).asData?.value;

    // Filter by category and search
    var filtered = allCards.where((c) {
      if (_selectedCategory != null && c.category != _selectedCategory) {
        return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return c.wordEnglish.toLowerCase().contains(q) ||
            c.wordFilipino.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // Sort alphabetically
    filtered.sort(
        (a, b) => a.wordEnglish.toLowerCase().compareTo(b.wordEnglish.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.fslDictionary,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchWords,
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: hc.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Category filter chips
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(AppLocalizations.of(context)!.all),
                    selected: _selectedCategory == null,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = null),
                    selectedColor: AppColors.primaryLight,
                  ),
                ),
                ...FlashcardCategory.values.map((cat) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(cat.label),
                        avatar: Icon(cat.icon, size: 16),
                        selected: _selectedCategory == cat,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                        selectedColor: cat.color.withValues(alpha: 0.3),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${filtered.length} words',
                  style: AppTypography.labelMedium.copyWith(
                    color: hc.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (profileId != null)
                  Text(
                    '${HiveService.fslUniqueWordsViewed(profileId)} videos watched',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Word grid
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context)!.noWordsFound,
                      style: AppTypography.bodyMedium.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final card = filtered[index];
                      return _FslWordCard(
                        card: card,
                        profileId: profileId,
                        hasVideo: availability?.hasVideo(card) ?? false,
                      )
                          .animate()
                          .fadeIn(
                            duration: 300.ms,
                            delay: Duration(milliseconds: 40 * (index % 10)),
                          )
                          .slideY(begin: 0.05, end: 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FslWordCard extends StatelessWidget {
  final Flashcard card;
  final String? profileId;
  final bool hasVideo;

  const _FslWordCard({
    required this.card,
    required this.hasVideo,
    this.profileId,
  });

  @override
  Widget build(BuildContext context) {
    final hasVid = hasVideo;

    return GestureDetector(
      onTap: () {
        if (hasVid) {
          // Record view
          if (profileId != null) {
            HiveService.recordFslVideoView(
              profileId!,
              card.category.label,
              card.wordEnglish,
            );
          }
          // Show video
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => _DictionaryVideoSheet(card: card),
          );
        } else {
          AppSnackBar.info(context, message: 'No FSL video available yet for "${card.wordEnglish}"');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HCColor.of(context).surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasVid ? card.category.color.withValues(alpha: 0.4) : HCColor.of(context).border,
            width: 1.5,
          ),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(card.category.icon, color: card.category.color, size: 18),
                const Spacer(),
                Icon(
                  hasVid
                      ? Icons.play_circle_rounded
                      : Icons.videocam_off_rounded,
                  color: hasVid ? AppColors.secondary : HCColor.of(context).textHint,
                  size: 22,
                ),
              ],
            ),
            const Spacer(),
            Text(
              card.wordEnglish,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              card.wordFilipino,
              style: AppTypography.bodySmall.copyWith(
                color: HCColor.of(context).textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Video Sheet (self-contained, with speed controls) ──────

class _DictionaryVideoSheet extends StatefulWidget {
  final Flashcard card;

  const _DictionaryVideoSheet({required this.card});

  @override
  State<_DictionaryVideoSheet> createState() => _DictionaryVideoSheetState();
}

class _DictionaryVideoSheetState extends State<_DictionaryVideoSheet> {
  VideoPlayerController? _controller;
  File? _videoFile;
  bool _initialized = false;
  bool _hasError = false;
  double _playbackSpeed = 1.0;

  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5];

  @override
  void initState() {
    super.initState();
    _loadAndInit();
  }

  Future<void> _loadAndInit() async {
    try {
      final file = await FslAssetsService.cachedFileFor(widget.card);
      if (!mounted) return;
      _videoFile = file;
      final controller = VideoPlayerController.file(file);
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.setLooping(true);
      controller.play();
      setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 48, height: 4,
            decoration: BoxDecoration(
              color: hc.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sign_language_rounded,
                  color: AppColors.secondaryDark, size: 24),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(
                    widget.card.wordEnglish,
                    style: AppTypography.titleLarge,
                  ),
                  Text(
                    widget.card.wordFilipino,
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Video player
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio:
                  _initialized ? _controller!.value.aspectRatio : 16 / 9,
              child: _hasError
                  ? Container(
                      color: hc.surfaceVariant,
                      child: Center(
                        child: Text('Unable to load video',
                            style: AppTypography.bodyMedium
                                .copyWith(color: hc.textSecondary)),
                      ),
                    )
                  : _initialized
                      ? GestureDetector(
                          onTap: () {
                            setState(() {
                              _controller!.value.isPlaying
                                  ? _controller!.pause()
                                  : _controller!.play();
                            });
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(_controller!),
                              if (!_controller!.value.isPlaying)
                                Container(
                                  width: 56, height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded,
                                      color: Colors.white, size: 36),
                                ),
                              // Fullscreen button
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: GestureDetector(
                                  onTap: () async {
                                    final controller = _controller;
                                    final file = _videoFile;
                                    if (controller == null || file == null) return;
                                    final wasPlaying = controller.value.isPlaying;
                                    final pos = controller.value.position;
                                    controller.pause();
                                    final returnPos = await openFslFullscreenPlayer(
                                      context,
                                      videoFile: file,
                                      wordEnglish: widget.card.wordEnglish,
                                      wordFilipino: widget.card.wordFilipino,
                                      startPosition: pos,
                                    );
                                    if (returnPos != null && mounted) {
                                      controller.seekTo(returnPos);
                                    }
                                    if (wasPlaying && mounted) {
                                      controller.play();
                                    }
                                  },
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.fullscreen_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          color: hc.surfaceVariant,
                          child: ShimmerLoading(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_circle_outline_rounded,
                                    size: 48,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 8),
                                  const ShimmerBox(width: 100, height: 12),
                                ],
                              ),
                            ),
                          ),
                        ),
            ),
          ),
          const SizedBox(height: 12),
          // Speed selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.speed_rounded,
                  size: 18, color: hc.textSecondary),
              const SizedBox(width: 6),
              Text(AppLocalizations.of(context)!.speed,
                  style: AppTypography.labelSmall
                      .copyWith(color: hc.textSecondary)),
              const SizedBox(width: 4),
              ..._speeds.map((speed) {
                final isActive = _playbackSpeed == speed;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _playbackSpeed = speed);
                      _controller!.setPlaybackSpeed(speed);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.secondary
                            : hc.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${speed}x',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 10,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? Colors.white
                              : hc.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          // Replay & Close
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _controller!.seekTo(Duration.zero);
                    _controller!.play();
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(AppLocalizations.of(context)!.replay),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.close),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
