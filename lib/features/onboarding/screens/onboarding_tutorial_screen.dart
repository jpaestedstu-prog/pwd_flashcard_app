import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/avatar_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// A multi-page onboarding walkthrough shown after profile creation.
///
/// Personalised with the student's name and avatar. Highlights key features
/// and marks the tutorial as seen on completion so it only shows once.
class OnboardingTutorialScreen extends ConsumerStatefulWidget {
  const OnboardingTutorialScreen({super.key});

  @override
  ConsumerState<OnboardingTutorialScreen> createState() =>
      _OnboardingTutorialScreenState();
}

class _OnboardingTutorialScreenState
    extends ConsumerState<OnboardingTutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_OnboardingPage> _buildPages(UserProfile profile) {
    final t = _t(context);
    final avatar = AvatarData.getAvatar(profile.avatarIndex);
    // Student, Child, and Player all use the app as learners, so they get the
    // second-person ("you") walkthrough copy. Only Teacher / Parent get the
    // observer copy ("your students" / "your child's learning").
    final isLearner = profile.role == UserRole.student ||
        profile.role == UserRole.child ||
        profile.role == UserRole.player;

    return [
      // ─── Page 1: Welcome ──────────────────
      _OnboardingPage(
        title: t.obWelcome(profile.name),
        description: isLearner
            ? t.obWelcomeLearner
            : profile.role == UserRole.teacher
            ? t.obWelcomeTeacher
            : t.obWelcomeParent,
        emoji: avatar.emoji,
        emojiSize: 64,
        color: avatar.color,
      ),

      // ─── Page 2: Flashcards ───────────────
      _OnboardingPage(
        title: t.obFlashTitle,
        description: isLearner ? t.obFlashLearner : t.obFlashAdult,
        color: const Color(0xFFFF9800),
        icon: Icons.style_rounded,
      ),

      // ─── Page 3: Games ────────────────────
      _OnboardingPage(
        title: t.obGamesTitle,
        description: isLearner ? t.obGamesLearner : t.obGamesAdult,
        color: const Color(0xFF4CAF50),
        icon: Icons.sports_esports_rounded,
      ),

      // ─── Page 4: Progress & Stars ─────────
      _OnboardingPage(
        title: t.obProgressTitle,
        description: isLearner ? t.obProgressLearner : t.obProgressAdult,
        color: const Color(0xFFF44336),
        icon: Icons.emoji_events_rounded,
      ),

      // ─── Page 5: Accessibility ────────────
      _OnboardingPage(
        title: t.obAccessTitle,
        description: t.obAccessBody,
        color: const Color(0xFF9C27B0),
        icon: Icons.accessibility_new_rounded,
      ),

      // ─── Page 6: Let's Go! ────────────────
      _OnboardingPage(
        title: t.obReadyTitle,
        description: isLearner
            ? t.obReadyLearner
            : profile.role == UserRole.teacher
            ? t.obReadyTeacher
            : t.obReadyParent,
        emoji: '🌟',
        emojiSize: 56,
        color: AppColors.accent,
      ),
    ];
  }

  void _next() {
    final pages = _buildPages(ref.read(profileProvider)!);
    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
      setState(() => _currentPage++);
    } else {
      _complete();
    }
  }

  void _complete() {
    final profile = ref.read(profileProvider);
    if (profile != null) {
      HiveService.markTutorialSeen(profile.id);
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    if (profile == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
      return const SizedBox.shrink();
    }

    final pages = _buildPages(profile);
    final page = pages[_currentPage];
    final isLast = _currentPage == pages.length - 1;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              page.color.withValues(alpha: 0.15),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ─── Skip ────────────────────
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: _complete,
                    child: Text(
                      _t(context).skip,
                      style: AppTypography.labelLarge.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    ),
                  ),
                ),
              ),

              // ─── Page Content ────────────
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, index) {
                    return _OnboardingPageWidget(
                      page: pages[index],
                      index: index,
                    );
                  },
                ),
              ),

              // ─── Progress Bar ────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: List.generate(pages.length, (i) {
                    final isActive = i <= _currentPage;
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: isActive ? 6 : 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? LinearGradient(
                                  colors: [
                                    page.color,
                                    page.color.withValues(alpha: 0.7),
                                  ],
                                )
                              : null,
                          color: isActive ? null : page.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: page.color.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 24),

              // ─── Step Counter ─────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: page.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: page.color.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '${_currentPage + 1} of ${pages.length}',
                  style: AppTypography.bodySmall.copyWith(
                    color: HCColor.of(context).readableOver(
                      page.color,
                      page.color.withValues(alpha: 0.1),
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ─── Action Button ────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: page.color.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HCColor.of(
                          context,
                        ).fillFor(page.color),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isLast ? '${_t(context).letsGo} 🎉' : _t(context).next,
                        style: AppTypography.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Data Model ──────────────────────────────────────────

class _OnboardingPage {
  final String title;
  final String description;
  final String? emoji;
  final double emojiSize;
  final Color color;
  final IconData? icon;

  const _OnboardingPage({
    required this.title,
    required this.description,
    this.emoji,
    this.emojiSize = 48,
    required this.color,
    this.icon,
  });
}

// ─── Page Widget ─────────────────────────────────────────

class _OnboardingPageWidget extends StatelessWidget {
  final _OnboardingPage page;
  final int index;

  const _OnboardingPageWidget({required this.page, required this.index});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon / Emoji in decorated circle
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  page.color.withValues(alpha: 0.15),
                  page.color.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: page.color.withValues(alpha: 0.3),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: page.color.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: page.emoji != null
                  ? Text(
                      page.emoji!,
                      style: TextStyle(fontSize: page.emojiSize),
                    )
                  : Icon(
                      page.icon,
                      size: 60,
                      color: page.color,
                    ),
            ),
          )
              .animate(key: ValueKey('icon_$index'))
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: Curves.elasticOut,
              ),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          )
              .animate(key: ValueKey('title_$index'))
              .fadeIn(duration: 400.ms, delay: 150.ms)
              .slideY(begin: 0.15, end: 0),

          const SizedBox(height: 16),

          // Description
          Text(
            page.description,
            style: AppTypography.bodyLarge.copyWith(
              color: HCColor.of(context).textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          )
              .animate(key: ValueKey('desc_$index'))
              .fadeIn(duration: 400.ms, delay: 300.ms)
              .slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
