import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/fsl_fullscreen_player.dart';
import '../../../widgets/fsl_loading_overlay.dart';
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

  /// True while a video is being resolved/downloaded. Only one video resolves
  /// at a time: taps on other cards are ignored while this is set, so several
  /// videos can't open or download simultaneously. Drives the full-screen
  /// loading overlay.
  bool _isResolving = false;

  Future<void> _openVideo(Flashcard card) async {
    if (_isResolving) return;
    setState(() => _isResolving = true);
    final source = await FslAssetsService.videoSourceFor(card);
    if (!mounted) return;
    setState(() => _isResolving = false);
    if (source == null) {
      AppSnackBar.info(
        context,
        message: 'No FSL video available yet for "${card.wordEnglish}"',
      );
      return;
    }
    final profileId = ref.read(profileProvider)?.id;
    if (profileId != null) {
      HiveService.recordFslVideoView(
        profileId,
        card.category.label,
        card.wordEnglish,
      );
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DictionaryVideoSheet(
        videoSource: source,
        wordEnglish: card.wordEnglish,
        wordFilipino: card.wordFilipino,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final allCards = SeedData.allFlashcards;
    final profileId = ref.watch(profileProvider)?.id;

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
      (a, b) =>
          a.wordEnglish.toLowerCase().compareTo(b.wordEnglish.toLowerCase()),
    );

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              AppLocalizations.of(context)!.fslDictionary,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
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

                // Category filter chips — height grows with text scale so the
                // chip labels never get clipped at Extra Large font size.
                SizedBox(
                  height: 42 * MediaQuery.textScalerOf(context).scale(1.0),
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
                      ...FlashcardCategory.values.map(
                        (cat) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text(cat.label),
                            avatar: Icon(cat.icon, size: context.scaleIcon(16)),
                            selected: _selectedCategory == cat,
                            onSelected: (_) =>
                                setState(() => _selectedCategory = cat),
                            selectedColor: cat.color.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
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

                // Word grid — uses max-extent so columns reflow naturally on
                // phones (2), 10-inch tablets (3-4), and ultra-wide tablets
                // in landscape (5+). No need for breakpoint branching.
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
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                childAspectRatio: 1.4,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final card = filtered[index];
                            return _FslWordCard(
                                  card: card,
                                  onOpen: () => _openVideo(card),
                                )
                                .animate()
                                .fadeIn(
                                  duration: 300.ms,
                                  delay: Duration(
                                    milliseconds: 40 * (index % 10),
                                  ),
                                )
                                .slideY(begin: 0.05, end: 0);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        if (_isResolving) const FslLoadingOverlay(),
      ],
    );
  }
}

class _FslWordCard extends StatefulWidget {
  final Flashcard card;

  /// Invoked when the user taps a card that has a video. The parent owns the
  /// resolve (and the loading overlay) so only one video opens at a time.
  final VoidCallback onOpen;

  const _FslWordCard({required this.card, required this.onOpen});

  @override
  State<_FslWordCard> createState() => _FslWordCardState();
}

class _FslWordCardState extends State<_FslWordCard> {
  bool? _hasVideo;

  @override
  void initState() {
    super.initState();
    _checkVideo();
  }

  Future<void> _checkVideo() async {
    await FslAssetsService.load();
    if (!mounted) return;
    setState(() => _hasVideo = FslAssetsService.hasAnyVideoSource(widget.card));
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final hasVid = _hasVideo == true;

    return GestureDetector(
      onTap: () {
        if (hasVid) {
          widget.onOpen();
        } else {
          AppSnackBar.info(
            context,
            message: 'No FSL video available yet for "${card.wordEnglish}"',
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HCColor.of(context).surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasVid
                ? card.category.color.withValues(alpha: 0.4)
                : HCColor.of(context).border,
            width: 1.5,
          ),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  card.category.icon,
                  color: card.category.color,
                  size: context.scaleIcon(18),
                ),
                const Spacer(),
                Icon(
                  hasVid
                      ? Icons.play_circle_rounded
                      : Icons.videocam_off_rounded,
                  color: hasVid
                      ? AppColors.secondary
                      : HCColor.of(context).textHint,
                  size: context.scaleIcon(22),
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
  final VideoSource videoSource;
  final String wordEnglish;
  final String wordFilipino;

  const _DictionaryVideoSheet({
    required this.videoSource,
    required this.wordEnglish,
    required this.wordFilipino,
  });

  @override
  State<_DictionaryVideoSheet> createState() => _DictionaryVideoSheetState();
}

class _DictionaryVideoSheetState extends State<_DictionaryVideoSheet> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  double _playbackSpeed = 1.0;

  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5];

  @override
  void initState() {
    super.initState();
    _controller = widget.videoSource.createController()
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() => _initialized = true);
              _controller.setLooping(true);
              _controller.play();
            }
          })
          .catchError((_) {
            if (mounted) setState(() => _hasError = true);
          });
  }

  @override
  void dispose() {
    _controller.dispose();
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
            width: 48,
            height: 4,
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
              Icon(
                Icons.sign_language_rounded,
                color: AppColors.secondaryDark,
                size: context.scaleIcon(24),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(widget.wordEnglish, style: AppTypography.titleLarge),
                  Text(
                    widget.wordFilipino,
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
              aspectRatio: _initialized
                  ? _controller.value.aspectRatio
                  : 16 / 9,
              child: _hasError
                  ? Container(
                      color: hc.surfaceVariant,
                      child: Center(
                        child: Text(
                          'Unable to load video',
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : _initialized
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        });
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(_controller),
                          if (!_controller.value.isPlaying)
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: context.scaleIcon(36),
                              ),
                            ),
                          // Fullscreen button
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: GestureDetector(
                              onTap: () async {
                                final wasPlaying = _controller.value.isPlaying;
                                final pos = _controller.value.position;
                                _controller.pause();
                                final returnPos = await openFslFullscreenPlayer(
                                  context,
                                  videoSource: widget.videoSource,
                                  wordEnglish: widget.wordEnglish,
                                  wordFilipino: widget.wordFilipino,
                                  startPosition: pos,
                                );
                                if (returnPos != null && mounted) {
                                  _controller.seekTo(returnPos);
                                }
                                if (wasPlaying && mounted) {
                                  _controller.play();
                                }
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.fullscreen_rounded,
                                  color: Colors.white,
                                  size: context.scaleIcon(22),
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
                                size: context.scaleIcon(48),
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.3),
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
              Icon(
                Icons.speed_rounded,
                size: context.scaleIcon(18),
                color: hc.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.speed,
                style: AppTypography.labelSmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              ..._speeds.map((speed) {
                final isActive = _playbackSpeed == speed;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _playbackSpeed = speed);
                      _controller.setPlaybackSpeed(speed);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive ? Colors.white : hc.textSecondary,
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
                    _controller.seekTo(Duration.zero);
                    _controller.play();
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
