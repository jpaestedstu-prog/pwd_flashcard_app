import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/local/hive_service.dart';
import '../../../l10n/app_localizations.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressController;
  late final AnimationController _particleController;
  // Stored so it can be cancelled in dispose(); using a bare
  // `Future.delayed` left a pending timer hanging when the widget
  // tree tore down (e.g. in widget tests that pump the app once).
  Timer? _navigationTimer;
  int _stageIndex = 0;

  /// Number of staged loading messages (their text is localised in [build]).
  static const _stageCount = 3;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..addListener(() {
        final newStage = (_progressController.value * _stageCount)
            .floor()
            .clamp(0, _stageCount - 1);
        if (newStage != _stageIndex && mounted) {
          setState(() => _stageIndex = newStage);
        }
      });

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    _progressController.forward();
    _scheduleNavigation();
  }

  @override
  void dispose() {
    // Cancel BEFORE super.dispose() so the timer can never fire against
    // an unmounted state object (the mounted-check inside _navigate is
    // a defensive backstop, not the primary guard).
    _navigationTimer?.cancel();
    _progressController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _scheduleNavigation() {
    _navigationTimer = Timer(const Duration(milliseconds: 3000), () {
      if (!mounted) return;

      final profiles = HiveService.getProfiles();
      final activeId = HiveService.getActiveProfileId();

      if (profiles.length > 1) {
        context.go('/profile-switcher');
      } else if (profiles.isNotEmpty && activeId != null) {
        context.go('/home');
      } else if (!HiveService.hasSeenWelcome()) {
        // First launch, no profiles yet — show the welcome carousel once.
        context.go('/welcome');
      } else {
        context.go('/profile');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stages = [
      l10n?.splashLoadingResources ?? 'Loading resources...',
      l10n?.splashPreparingCards ?? 'Preparing your cards...',
      l10n?.splashAlmostReady ?? 'Almost ready!',
    ];

    return Scaffold(
      body: Semantics(
        label: l10n?.appTitle ?? 'FlashLearn PWD',
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: isDark ? null : AppColors.splashGradient,
            color: isDark ? Theme.of(context).scaffoldBackgroundColor : null,
          ),
          child: Stack(
            children: [
              // ─── Floating particles ─────────────
              ..._buildParticles(isDark),

              // ─── Main content ───────────────────
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ─── Animated Logo/Icon ───────────────
                    Semantics(
                      label: 'FlashLearn logo',
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: HCColor.of(context).surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.3),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.15),
                              blurRadius: 80,
                              spreadRadius: 15,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '📚',
                            style: TextStyle(fontSize: 72),
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.0, 0.0),
                          end: const Offset(1.0, 1.0),
                          duration: 800.ms,
                          curve: Curves.elasticOut,
                        )
                        .then()
                        .animate(
                          onPlay: (c) => c.repeat(reverse: true),
                        )
                        .scale(
                          begin: const Offset(1.0, 1.0),
                          end: const Offset(1.05, 1.05),
                          duration: 2000.ms,
                          curve: Curves.easeInOut,
                        ),

                    const SizedBox(height: 40),

                    // ─── App Name with letter-by-letter reveal ──
                    _LetterRevealText(
                      text: 'FlashLearn',
                      style: AppTypography.displayLarge.copyWith(
                        color: isDark
                            ? Theme.of(context).colorScheme.primary
                            : AppColors.primaryDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ─── Tagline ──────────────────────────
                    Text(
                      l10n?.learnWordsThrough ?? 'Learn words through play! ✨',
                      style: AppTypography.titleMedium.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 900.ms)
                        .slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 60),

                    // ─── Staged progress bar ────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 60),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 8,
                              child: AnimatedBuilder(
                                animation: _progressController,
                                builder: (context, _) {
                                  return Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.15),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor:
                                            _progressController.value,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.7),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 1200.ms),

                          const SizedBox(height: 14),

                          // ─── Stage text with crossfade ──────
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              stages[_stageIndex],
                              key: ValueKey(_stageIndex),
                              style: AppTypography.bodyMedium.copyWith(
                                color: HCColor.of(context).textSecondary
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 1400.ms),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildParticles(bool isDark) {
    final rng = math.Random(42);
    final size = MediaQuery.of(context).size;
    final baseColor = isDark
        ? Theme.of(context).colorScheme.primary
        : AppColors.primaryDark;

    return List.generate(12, (i) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final dotSize = 3.0 + rng.nextDouble() * 5;
      final delay = (rng.nextDouble() * 2000).round();

      return Positioned(
        left: x,
        top: y,
        child: Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.08 + rng.nextDouble() * 0.12),
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fadeIn(duration: 800.ms, delay: delay.ms)
            .moveY(
              begin: 0,
              end: -15 - rng.nextDouble() * 20,
              duration: (2500 + rng.nextInt(2000)).ms,
              curve: Curves.easeInOut,
            )
            .scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1.2, 1.2),
              duration: (3000 + rng.nextInt(1500)).ms,
            ),
      );
    });
  }
}

/// Reveals text letter by letter with staggered fade-in and slide.
class _LetterRevealText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _LetterRevealText({
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(text.length, (i) {
        return Text(
          text[i],
          style: style,
        )
            .animate()
            .fadeIn(
              duration: 200.ms,
              delay: (400 + i * 50).ms,
            )
            .slideY(
              begin: 0.4,
              end: 0,
              duration: 300.ms,
              delay: (400 + i * 50).ms,
              curve: Curves.easeOutBack,
            );
      }),
    );
  }
}
