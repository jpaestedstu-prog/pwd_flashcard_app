import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/services/game_session_service.dart';
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';
import '../../gaze_control/widgets/hands_free_pause_notice.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../widgets/game_widgets.dart';
import '../../../navigation/nav_extensions.dart';
import '../../../widgets/fullscreen_host.dart';

/// Hub screen for FSL (Filipino Sign Language) Practice.
///
/// Offers three modes:
/// - **Sign → Word**: Watch a sign language video and pick the correct word.
/// - **Word → Sign**: See a word and pick which video shows the correct sign.
/// - **Sign It!**: Watch a reference sign, copy it in a live camera mirror,
///   then self-assess (production practice — no automatic recognition).
class FslPracticeHubScreen extends ConsumerWidget {
  const FslPracticeHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Sign It records the learner, so it takes the camera away from Gaze
    // Control. Say so on the card rather than letting a hands-free learner
    // discover it by getting stuck.
    final gazeOn = ref.watch(gazeSettingsProvider.select((s) => s.enabled));
    return Scaffold(
      appBar: fullscreenBar(
        ref,
        AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: l10n.close,
            // Retrace the stack: this hub is reachable from the Games grid, a
            // home feature tile, and a learning-path step, so a hard-coded
            // '/games' would strand the last two.
            onPressed: () => context.popOrGo('/games'),
          ),
          title: Text(
            l10n.fslPractice,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      body: SafeArea(
        // Always scrollable, not `OverflowSafeBody`: that only engages its
        // scroll wrapper at text scale ≥ 1.25, and this hub's content (header
        // block + three tall mode cards) is already taller than a small phone
        // portrait viewport at the *default* font — so it overflowed with no
        // way to reach the third card. A hub that is a list of cards should
        // simply scroll.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ───
              Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB388FF), Color(0xFF7C4DFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFB388FF,
                            ).withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sign_language_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                  ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  l10n.fslPracticeHeading,
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  l10n.fslPracticeIntro,
                  style: AppTypography.bodyMedium.copyWith(
                    color: HCColor.of(context).textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
              const SizedBox(height: 40),

              // ─── Mode Cards ───
              // Plain Column (no Expanded) so OverflowSafeBody can scroll
              // at large font scales without an unbounded-flex assertion.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sign → Word mode
                  _FslModeCard(
                        icon: Icons.videocam_rounded,
                        title: l10n.fslSignToWord,
                        subtitle: l10n.fslSignToWordSubtitle,
                        gradient: const [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                        onTap: () => _launchMode(context, ref, 'sign-to-word'),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 350.ms)
                      .slideY(begin: 0.15, end: 0),
                  const SizedBox(height: 16),
                  // Word → Sign mode
                  _FslModeCard(
                        icon: Icons.abc_rounded,
                        title: l10n.fslWordToSign,
                        subtitle: l10n.fslWordToSignSubtitle,
                        gradient: const [Color(0xFF00BFA5), Color(0xFF64FFDA)],
                        onTap: () => _launchMode(context, ref, 'word-to-sign'),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 450.ms)
                      .slideY(begin: 0.15, end: 0),
                  const SizedBox(height: 16),
                  // Sign It! — production practice (watch, copy, self-check)
                  _FslModeCard(
                        icon: Icons.front_hand_rounded,
                        title: l10n.fslSignIt,
                        subtitle: gazeOn
                            ? l10n.fslSignItSubtitleGaze
                            : l10n.fslSignItSubtitle,
                        gradient: const [Color(0xFFFF8A65), Color(0xFFFFB74D)],
                        onTap: () =>
                            _launchMode(context, ref, 'sign-it', minVideos: 1),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 550.ms)
                      .slideY(begin: 0.15, end: 0),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _launchMode(
    BuildContext context,
    WidgetRef ref,
    String mode, {
    int minVideos = 3,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    // Sign It records the learner, so it holds the front camera exclusively —
    // video recording and the gaze detector's image stream cannot share one
    // controller. Head control therefore genuinely stops for the duration, and
    // a learner who walked in hands-free would have no way back out. Warn and
    // let them choose; this dialog is on the hub, where the focus-traversal
    // fallback is live, so the choice itself is reachable hands-free.
    if (mode == 'sign-it') {
      final gaze = ref.read(gazeSettingsProvider);
      if (gaze.enabled) {
        final proceed = await confirmHandsFreePause(
          context,
          activityName: l10n.fslSignIt,
          voiceAvailable: gaze.voiceCommands,
        );
        if (!proceed || !context.mounted) return;
      }
    }
    // Word → Sign needs at least 3 videos in a category (1 prompt + 2
    // distractors); Sign → Word can run with 2; "Sign It!" needs only 1 (no
    // distractors). Callers pass the right floor via [minVideos] so the user
    // never lands on an empty-state.
    final availability = await FslAssetsService.load();
    final playable = availability.playableCategories(min: minVideos);

    if (!context.mounted) return;

    if (playable.isEmpty) {
      AppSnackBar.info(context, message: l10n.fslVideosComingSoon);
      return;
    }

    // "Sign It!" is production practice with self-assessment — there are no
    // distractors to add or take away, so it has no difficulty to choose. The
    // two quiz modes do, and now feed the adaptive engine like every other
    // game.
    const gameType = GameType.fslPractice;
    final profileId = ref.read(profileProvider)?.id;
    final isQuizMode = mode != 'sign-it';
    GameDifficulty? difficulty;
    if (isQuizMode) {
      final picked = await showDifficultyPicker(
        context,
        gameType,
        profileId: profileId,
        showTimedToggle: false,
      );
      if (picked == null || !context.mounted) return;
      difficulty = picked.difficulty;
    }

    final last = GameSessionService.lastSetup(
      profileId: profileId,
      gameType: gameType,
    );
    final categories = await showCategoryPicker(
      context,
      availableCategories: playable,
      initialSelection: last?.categories,
    );
    if (categories == null || !context.mounted) return;

    if (difficulty != null) {
      GameSessionService.saveSetup(
        profileId: profileId,
        gameType: gameType,
        difficulty: difficulty,
        categories: categories,
        timedMode: false,
      );
    }

    final params = <String>[
      if (categories.isNotEmpty)
        'categories=${categories.map((c) => c.index).join(',')}',
      if (difficulty != null) 'difficulty=${difficulty.name}',
    ];
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    context.push('/games/fsl-practice/$mode$query');
  }
}

class _FslModeCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _FslModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_FslModeCard> createState() => _FslModeCardState();
}

class _FslModeCardState extends State<_FslModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.subtitle}',
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: widget.gradient.first.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            // No IntrinsicHeight here. It measures children at *unbounded*
            // width, so the subtitle reports a one-line height, the Row is
            // then forced to that, and the text wraps to three lines at the
            // real width — overflowing by ~112 px at large accessibility
            // fonts. The leading icon and trailing play button are both fixed
            // size, so nothing needed the intrinsic pass anyway.
            child: Row(
              children: [
                Container(
                  width: context.scaledHeightCapped(64),
                  height: context.scaledHeightCapped(64),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Icon(widget.icon, size: 36, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: AppTypography.titleLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: context.scaledHeightCapped(44),
                  height: context.scaledHeightCapped(44),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: context.scaleIcon(28),
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
