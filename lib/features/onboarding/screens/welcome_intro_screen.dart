import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/local/hive_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_button.dart';

/// One-time welcome / intro carousel shown on the very first launch, before
/// the role picker. Explains what the app is, who it's for, and that it's
/// accessibility-first. Gated by [HiveService.hasSeenWelcome]; returning or
/// multi-profile users never see it (the splash routes them straight past).
class WelcomeIntroScreen extends StatefulWidget {
  const WelcomeIntroScreen({super.key});

  @override
  State<WelcomeIntroScreen> createState() => _WelcomeIntroScreenState();
}

class _WelcomeIntroScreenState extends State<WelcomeIntroScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Slide> _slides(AppLocalizations l10n) => [
        _Slide(
          icon: Icons.sign_language_rounded,
          color: AppColors.primary,
          title: l10n.welcomeSlide1Title,
          body: l10n.welcomeSlide1Body,
        ),
        _Slide(
          icon: Icons.groups_rounded,
          color: AppColors.secondary,
          title: l10n.welcomeSlide2Title,
          body: l10n.welcomeSlide2Body,
        ),
        _Slide(
          icon: Icons.accessibility_new_rounded,
          color: AppColors.accent,
          title: l10n.welcomeSlide3Title,
          body: l10n.welcomeSlide3Body,
        ),
      ];

  Future<void> _finish() async {
    await HiveService.markWelcomeSeen();
    if (!mounted) return;
    context.go('/profile');
  }

  void _next(int slideCount) {
    if (_page >= slideCount - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slides = _slides(l10n);
    final isLast = _page >= slides.length - 1;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : const LinearGradient(
                  colors: [AppColors.surfaceVariant, AppColors.background],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
          color: isDark ? Theme.of(context).scaffoldBackgroundColor : null,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.maxContentWidth),
              child: Column(
                children: [
                  // ─── Skip ──────────────────────────────────
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: AppButton.text(
                        label: l10n.skip,
                        onPressed: _finish,
                      ),
                    ),
                  ),

                  // ─── Slides ────────────────────────────────
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: slides.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, i) => _SlideView(slide: slides[i]),
                    ),
                  ),

                  // ─── Page indicator dots ───────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(slides.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  AppSpacing.gapXl,

                  // ─── Next / Get Started ────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.pagePadding,
                    ),
                    child: AppButton.primary(
                      label: isLast ? l10n.getStarted : l10n.next,
                      icon: Icons.arrow_forward_rounded,
                      fullWidth: true,
                      onPressed: () => _next(slides.length),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final iconSize = context.responsiveSize(140);
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppSpacing.gapXxl,
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [slide.color, slide.color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: slide.color.withValues(alpha: 0.35),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(slide.icon, color: Colors.white, size: iconSize * 0.45),
          )
              .animate()
              .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 300.ms),
          AppSpacing.gapXxl,
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTypography.displaySmall.copyWith(
              color: HCColor.of(context).textPrimary,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
          AppSpacing.gapMd,
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: HCColor.of(context).textSecondary,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
        ],
      ),
    );
  }
}
