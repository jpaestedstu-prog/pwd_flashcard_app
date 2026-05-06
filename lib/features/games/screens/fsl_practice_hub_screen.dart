import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../widgets/game_widgets.dart';

/// Hub screen for FSL (Filipino Sign Language) Practice.
///
/// Offers two game modes:
/// - **Sign → Word**: Watch a sign language video and pick the correct word.
/// - **Word → Sign**: See a word and pick which video shows the correct sign.
class FslPracticeHubScreen extends StatelessWidget {
  const FslPracticeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => context.go('/games'),
        ),
        title: Text(
          'FSL Practice',
          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
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
                      colors: [
                        Color(0xFFB388FF),
                        Color(0xFF7C4DFF),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB388FF).withValues(alpha: 0.4),
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
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Filipino Sign Language Practice',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 150.ms),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Watch sign language videos and test your knowledge.\nChoose a practice mode below!',
                  style: AppTypography.bodyMedium.copyWith(
                    color: HCColor.of(context).textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 250.ms),
              const SizedBox(height: 40),

              // ─── Mode Cards ───
              Expanded(
                child: Column(
                  children: [
                    // Sign → Word mode
                    _FslModeCard(
                      icon: Icons.videocam_rounded,
                      title: 'Sign → Word',
                      subtitle: 'Watch a sign language video, then pick the correct word from choices.',
                      gradient: const [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                      onTap: () => _launchMode(context, 'sign-to-word'),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 350.ms)
                        .slideY(begin: 0.15, end: 0),
                    const SizedBox(height: 16),
                    // Word → Sign mode
                    _FslModeCard(
                      icon: Icons.abc_rounded,
                      title: 'Word → Sign',
                      subtitle: 'See a word, then pick which video shows the correct sign.',
                      gradient: const [Color(0xFF00BFA5), Color(0xFF64FFDA)],
                      onTap: () => _launchMode(context, 'word-to-sign'),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 450.ms)
                        .slideY(begin: 0.15, end: 0),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _launchMode(BuildContext context, String mode) async {
    // Word → Sign needs at least 3 videos in a category (1 prompt + 2 distractors);
    // Sign → Word can run with 2. Use the stricter floor so the user never
    // lands on an empty-state in either game.
    final availability = await FslAssetsService.load();
    final playable = availability.playableCategories(min: 3);

    if (!context.mounted) return;

    if (playable.isEmpty) {
      AppSnackBar.info(
        context,
        message:
            'FSL videos are still being added. Try the FSL Dictionary in the meantime.',
      );
      return;
    }

    final categories = await showCategoryPicker(
      context,
      availableCategories: playable,
      unavailableLabel: 'Coming soon',
    );
    if (categories == null || !context.mounted) return;

    final catParam = categories.isEmpty
        ? ''
        : '?categories=${categories.map((c) => c.index).join(',')}';
    context.go('/games/fsl-practice/$mode$catParam');
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
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
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
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(widget.icon, size: 36, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: AppTypography.titleLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
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
