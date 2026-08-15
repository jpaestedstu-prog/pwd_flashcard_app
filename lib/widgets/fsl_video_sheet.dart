import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/services/fsl_assets_service.dart';
import '../data/models/enums.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/responsive_utils.dart';
import '../l10n/app_localizations.dart';
import 'app_action_bar.dart';
import 'fsl_fullscreen_player.dart';
import 'shimmer_loading.dart';

/// Presents the FSL sign-language clip for [wordEnglish] in a modal bottom
/// sheet with an inline, looping video player (speed selector, replay, close,
/// and a fullscreen button).
///
/// This is the single shared entry point for "watch this in Filipino Sign
/// Language" across the app — Flashcards → Cards and Stories both call it so
/// the two surfaces behave identically. The sheet owns the player lifecycle;
/// callers only resolve a [VideoSource] (e.g. via
/// [FslAssetsService.videoSourceFor] or [FslAssetsService.videoSourceForUrl])
/// and hand it over.
///
/// [wordFilipino] is optional; when supplied it is forwarded to the fullscreen
/// player so its subtitle shows both languages (Flashcards pass English only,
/// Stories pass both — neither changes this sheet's own layout).
Future<void> showFslVideoSheet(
  BuildContext context, {
  required VideoSource videoSource,
  required String wordEnglish,
  String wordFilipino = '',
  SignMastery mastery = SignMastery.notSet,
  SignVerification verification = SignVerification.unreviewed,
  ValueChanged<SignMastery>? onMasteryChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => FslVideoSheet(
      videoSource: videoSource,
      wordEnglish: wordEnglish,
      wordFilipino: wordFilipino,
      mastery: mastery,
      verification: verification,
      onMasteryChanged: onMasteryChanged,
    ),
  );
}

/// Shows the friendly "no FSL video available yet" bottom sheet for
/// [wordEnglish]. Shared by every surface that can fail to resolve a clip so
/// the unavailable path looks the same everywhere (a SnackBar would be easy to
/// miss for Deaf / hard-of-hearing learners relying on the visual signing path).
/// Set [unreachable] when a clip IS registered for the word but could not be
/// resolved — the learner is offline rather than the sign being missing. Left
/// false by callers that cannot tell the two apart, preserving the original
/// wording.
Future<void> showFslUnavailableSheet(
  BuildContext context, {
  required String wordEnglish,
  bool unreachable = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    // Scroll-controlled so the sheet isn't clamped to ~9/16 of the screen,
    // which would clip its content on short phones and at large font scales.
    isScrollControlled: true,
    builder: (context) => _FslUnavailableSheet(
      wordEnglish: wordEnglish,
      unreachable: unreachable,
    ),
  );
}

// ─── FSL Video Bottom Sheet ───────────────────────────
class FslVideoSheet extends StatefulWidget {
  final VideoSource videoSource;
  final String wordEnglish;
  final String wordFilipino;

  /// The learner's current claim about producing this sign.
  final SignMastery mastery;

  /// An educator's judgement of that claim, shown read-only when it exists.
  final SignVerification verification;

  /// Supply to show the "Can you sign this?" self-assessment footer.
  ///
  /// Opt-in per caller rather than always-on, because this sheet is shared:
  /// Stories plays whole-sentence clips and the AI Tutor plays a sign mid
  /// conversation, and "can you sign this?" is meaningless in both. Only the
  /// FSL Dictionary — where the unit really is one word — passes it.
  final ValueChanged<SignMastery>? onMasteryChanged;

  const FslVideoSheet({
    super.key,
    required this.videoSource,
    required this.wordEnglish,
    this.wordFilipino = '',
    this.mastery = SignMastery.notSet,
    this.verification = SignVerification.unreviewed,
    this.onMasteryChanged,
  });

  @override
  State<FslVideoSheet> createState() => _FslVideoSheetState();
}

class _FslVideoSheetState extends State<FslVideoSheet> {
  late SignMastery _mastery = widget.mastery;
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
    // SafeArea + scroll wrapper, matching [_FslUnavailableSheet] below: the
    // sheet sizes to its content and only scrolls when the content would be
    // taller than the screen (XL fonts on a short phone, or landscape), so the
    // Replay / Close buttons are never pushed under the gesture bar.
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Container(
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
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FSL — ${widget.wordEnglish}',
                          style: AppTypography.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Callers that know the Filipino gloss (the Dictionary,
                        // Stories) show it under the English so a learner sees the
                        // sign paired with both words. Cards passes English only.
                        if (widget.wordFilipino.isNotEmpty)
                          Text(
                            widget.wordFilipino,
                            style: AppTypography.bodySmall.copyWith(
                              color: hc.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
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
                          color: AppColors.surfaceVariant,
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context)!.unableToLoadVideo,
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
                                    final wasPlaying =
                                        _controller.value.isPlaying;
                                    final pos = _controller.value.position;
                                    _controller.pause();
                                    final returnPos =
                                        await openFslFullscreenPlayer(
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
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
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
                          color: AppColors.surfaceVariant,
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
              // Playback speed selector. A `Wrap`, not a `Row`: six chips plus the
              // "Speed" label are wider than a phone at 1.0× already, and every
              // step of the Font Size setting makes it worse. Wrapping moves the
              // spill onto a second line instead of clipping the fastest speeds —
              // the slow speeds matter most to a learner copying a sign, but the
              // chips must all stay reachable.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
                    ],
                  ),
                  ..._speeds.map((speed) {
                    final isActive = _playbackSpeed == speed;
                    return GestureDetector(
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
                    );
                  }),
                ],
              ),
              if (widget.onMasteryChanged != null) ...[
                const SizedBox(height: 16),
                _SelfAssessment(
                  mastery: _mastery,
                  verification: widget.verification,
                  onChanged: (next) {
                    setState(() => _mastery = next);
                    widget.onMasteryChanged!(next);
                  },
                ),
              ],
              const SizedBox(height: 16),
              // Replay & Close — equal-width cells that stack on a narrow width
              // (or XL font scale) instead of overflowing horizontally.
              AppActionBar(
                equalWidth: true,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      _controller.seekTo(Duration.zero);
                      _controller.play();
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: Text(AppLocalizations.of(context)!.replay),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)!.close),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── "No FSL video yet" Bottom Sheet ──────────────────
class _FslUnavailableSheet extends StatelessWidget {
  final String wordEnglish;

  /// The clip is registered but could not be fetched — almost always because
  /// the learner is offline. Nothing is bundled with the app, so this is the
  /// *usual* reason a sign fails to open, and telling a Deaf learner the sign
  /// "doesn't exist yet" when it does would be plainly wrong.
  final bool unreachable;

  const _FslUnavailableSheet({
    required this.wordEnglish,
    this.unreachable = false,
  });

  @override
  Widget build(BuildContext context) {
    // SafeArea + scroll wrapper keeps the sheet usable at any font scale /
    // device height: it sizes to its content and only scrolls if the content
    // would otherwise be taller than the screen (e.g. XL accessibility fonts
    // on a small phone), so nothing is ever clipped.
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: HCColor.of(context).surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: HCColor.of(
                    context,
                  ).textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.secondaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sign_language_rounded,
                  size: context.scaleIcon(40),
                  color: AppColors.secondaryDark,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.filipinoSignLanguage,
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                unreachable
                    ? 'The sign for "$wordEnglish" needs the internet to load '
                          'the first time. Connect and try again — after that it '
                          'works offline.'
                    : 'No FSL video available yet for "$wordEnglish".',
                style: AppTypography.bodyMedium.copyWith(
                  color: HCColor.of(context).textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.gotIt),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── "Can you sign this?" self-assessment ─────────────

/// The learner's own claim about producing the sign they just watched.
///
/// Three deliberate properties:
///
///  * **Revocable.** Tapping the active choice clears it back to
///    [SignMastery.notSet]. Capability can be withdrawn — that is exactly what
///    separates this from "signs watched", which only ever grows.
///  * **Unscored on its own.** No XP here; see [XpService]. The claim is
///    unverified self-report, and paying for it would both invite tapping
///    through the dictionary and corrupt the claim-vs-verified comparison.
///  * **"Not yet" is a real answer**, not an absence of one. A learner who has
///    tried and is working on it is in a different state from one who has never
///    attempted the sign, and an educator reviewing the list needs to see which.
class _SelfAssessment extends StatelessWidget {
  final SignMastery mastery;
  final SignVerification verification;
  final ValueChanged<SignMastery> onChanged;

  const _SelfAssessment({
    required this.mastery,
    required this.verification,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Can you sign this?',
          textAlign: TextAlign.center,
          style: AppTypography.labelMedium.copyWith(
            color: hc.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        AppActionBar(
          equalWidth: true,
          children: [
            _choice(
              context,
              label: 'Not yet',
              icon: Icons.hourglass_bottom_rounded,
              selected: mastery == SignMastery.learning,
              tint: hc.textSecondary,
              onTap: () => onChanged(
                mastery == SignMastery.learning
                    ? SignMastery.notSet
                    : SignMastery.learning,
              ),
            ),
            _choice(
              context,
              label: 'I can sign this',
              icon: Icons.back_hand_rounded,
              selected: mastery == SignMastery.canSign,
              tint: AppColors.secondaryDark,
              onTap: () => onChanged(
                mastery == SignMastery.canSign
                    ? SignMastery.notSet
                    : SignMastery.canSign,
              ),
            ),
          ],
        ),
        if (verification != SignVerification.unreviewed) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                verification == SignVerification.confirmed
                    ? Icons.verified_rounded
                    : Icons.school_rounded,
                size: context.scaleIcon(16),
                color: verification == SignVerification.confirmed
                    ? hc.success
                    : hc.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  verification == SignVerification.confirmed
                      ? 'Your teacher confirmed this sign'
                      : 'Your teacher says keep practising this one',
                  style: AppTypography.labelSmall.copyWith(
                    color: verification == SignVerification.confirmed
                        ? hc.success
                        : hc.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _choice(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required Color tint,
    required VoidCallback onTap,
  }) {
    // Filled when chosen, outlined when not — a contrast difference, not just a
    // colour one, so the state survives high-contrast mode and colour blindness.
    return selected
        ? FilledButton.icon(
            onPressed: onTap,
            style: FilledButton.styleFrom(backgroundColor: tint),
            icon: Icon(icon, size: context.scaleIcon(18)),
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: context.scaleIcon(18)),
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
  }
}
