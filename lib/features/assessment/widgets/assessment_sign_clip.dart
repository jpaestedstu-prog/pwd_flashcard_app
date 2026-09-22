import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Builds the widget that shows one sign clip inside an assessment.
///
/// Injectable so a widget test can render a marker instead of reaching for the
/// video plugin, which no test binding provides. Production passes nothing and
/// gets [AssessmentSignClip].
typedef SignClipBuilder = Widget Function(BuildContext context, String cardId);

/// The prompt half of a "watch the sign, pick the word" item.
///
/// Loops quietly and offers a replay, because one viewing is not a fair look
/// at a sign — and unlike the FSL Dictionary sheet it deliberately shows no
/// word anywhere on screen. The clip *is* the question; a caption would be the
/// answer.
class AssessmentSignClip extends StatefulWidget {
  const AssessmentSignClip({super.key, required this.cardId});

  final String cardId;

  @override
  State<AssessmentSignClip> createState() => _AssessmentSignClipState();
}

class _AssessmentSignClipState extends State<AssessmentSignClip> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AssessmentSignClip old) {
    super.didUpdateWidget(old);
    if (old.cardId != widget.cardId) {
      _controller?.dispose();
      _controller = null;
      _ready = false;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final card = _cardFor(widget.cardId);
    if (card == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    try {
      final source = await FslAssetsService.videoSourceFor(card);
      if (source == null) {
        if (mounted) setState(() => _failed = true);
        return;
      }
      final controller = source.createController();
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.play();
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  static Flashcard? _cardFor(String id) {
    for (final card in SeedData.allFlashcards) {
      if (card.id == id) return card;
    }
    return null;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final controller = _controller;

    return Semantics(
      label: _failed ? _tr(context).clipFailedSemantics : _tr(context).clipSemantics,
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: hc.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: hc.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 16 / 12,
            child: _failed
                ? _unavailable(hc)
                : !_ready || controller == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      FittedBox(
                        child: SizedBox(
                          width: controller.value.size.width,
                          height: controller.value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: _tr(context).clipReplay,
                            icon: const Icon(
                              Icons.replay_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              await controller.seekTo(Duration.zero);
                              await controller.play();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _unavailable(HCColor hc) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_rounded, size: 34, color: hc.textHint),
          const SizedBox(height: 10),
          Text(
            _tr(context).clipFailedTitle,
            textAlign: TextAlign.center,
            style: AppTypography.labelLarge.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            _tr(context).clipFailedBody,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: hc.textHint),
          ),
        ],
      ),
    );
  }
}

AppLocalizations _tr(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
