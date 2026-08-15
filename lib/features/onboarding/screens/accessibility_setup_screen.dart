import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/accessibility/accessibility_presets.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';

/// A 3-step accessibility setup wizard shown after profile creation.
///
/// Step 1: Choose disability type (or "No Accessibility Needs")
/// Step 2: Preview recommended settings
/// Step 3: Confirmation
class AccessibilitySetupScreen extends ConsumerStatefulWidget {
  /// When non-null, the screen configures this student profile instead of
  /// the active (logged-in) profile. Used when an educator creates a
  /// student profile and wants to set up accessibility for that student.
  final UserProfile? studentProfile;

  const AccessibilitySetupScreen({super.key, this.studentProfile});

  @override
  ConsumerState<AccessibilitySetupScreen> createState() =>
      _AccessibilitySetupScreenState();
}

class _AccessibilitySetupScreenState
    extends ConsumerState<AccessibilitySetupScreen> {
  int _currentStep = 0;
  DisabilityType? _selectedType;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// True when an educator is setting up accessibility for a new student.
  bool get _isEducatorSetup => widget.studentProfile != null;

  Future<void> _applyAndContinue() async {
    final type = _selectedType ?? DisabilityType.none;

    if (_isEducatorSetup) {
      // Educator created a student — update the student profile in Hive
      // without touching the active logged-in educator profile.
      final updated = widget.studentProfile!.copyWith(disabilityType: type);
      await HiveService.saveProfile(updated);
      if (!mounted) return;
      ref.invalidate(allProfilesWithProgressProvider);
      // Switch to the new student so the app shows their home screen,
      // just like after a normal profile creation.
      await ref.read(profileProvider.notifier).setProfile(updated);
      if (!mounted) return;
      // Show onboarding tutorial for first-time students
      final seen = HiveService.hasSeenTutorial(updated.id);
      context.go(seen ? '/home' : '/onboarding-tutorial');
      return;
    }

    final profile = ref.read(profileProvider);

    // Apply accessibility preset to settings
    if (type != DisabilityType.none) {
      final currentSettings = ref.read(settingsProvider);
      final preset = AccessibilityPresets.presetFor(
        type,
        current: currentSettings,
      );
      ref.read(settingsProvider.notifier).update(preset);
      // Gaze Control lives in its own provider, so the preset can't carry it.
      // For the categories whose barrier is reaching the screen at all, turn
      // hands-free control on here — the learner has just confirmed it in the
      // preview list, and it is saved against their profile alone.
      if (AccessibilityPresets.enablesGazeControl(type)) {
        ref.read(gazeSettingsProvider.notifier).setEnabled(true);
      }
    }

    // Update profile with disability type
    if (profile != null) {
      final updatedProfile = profile.copyWith(disabilityType: type);
      await ref.read(profileProvider.notifier).setProfile(updatedProfile);
    }

    if (mounted) {
      final pid = ref.read(profileProvider)?.id ?? '';
      final seen = HiveService.hasSeenTutorial(pid);
      context.go(seen ? '/home' : '/onboarding-tutorial');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF0F4FF),
              Color(0xFFF5F0FF),
              AppColors.background,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ─── Top bar with skip ─────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      IconButton(
                        onPressed: _prevStep,
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Go back',
                      )
                    else
                      const SizedBox(width: 48),
                    // Step indicator dots
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        final isActive = i == _currentStep;
                        final isDone = i < _currentStep;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 28 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppColors.primary
                                : isActive
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (_isEducatorSetup) {
                          ref.invalidate(allProfilesWithProgressProvider);
                          await ref
                              .read(profileProvider.notifier)
                              .setProfile(widget.studentProfile!);
                          if (!context.mounted) return;
                        }
                        final pid = ref.read(profileProvider)?.id ?? '';
                        final seen = HiveService.hasSeenTutorial(pid);
                        context.go(seen ? '/home' : '/onboarding-tutorial');
                      },
                      child: Text(
                        AppLocalizations.of(context)!.skip,
                        style: AppTypography.labelLarge.copyWith(
                          color: HCColor.of(context).textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Page content ──────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [_buildStep1(), _buildStep2(), _buildStep3()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  //  Step 1: Choose Disability Type
  // ════════════════════════════════════════
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),

          Text(
            AppLocalizations.of(context)!.accessibilitySetup,
            style: AppTypography.displaySmall.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, end: 0),

          const SizedBox(height: 8),

          Text(
            'We\'ll optimize the app for your needs.\nSelect the option that best describes you:',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: HCColor.of(context).textSecondary,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 150.ms),

          const SizedBox(height: 28),

          ...DisabilityType.values.asMap().entries.map((entry) {
            final index = entry.key;
            final type = entry.value;
            final isSelected = _selectedType == type;

            return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DisabilityCard(
                    type: type,
                    isSelected: isSelected,
                    onTap: () => setState(() => _selectedType = type),
                  ),
                )
                .animate()
                .fadeIn(duration: 400.ms, delay: (200 + index * 80).ms)
                .slideX(begin: index.isEven ? -0.1 : 0.1, end: 0);
          }),

          const SizedBox(height: 20),

          // Continue button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _selectedType != null ? _nextStep : null,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(AppLocalizations.of(context)!.continueButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.3,
                ),
                textStyle: AppTypography.buttonText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 700.ms),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  //  Step 2: Preview Recommended Settings
  // ════════════════════════════════════════
  Widget _buildStep2() {
    final type = _selectedType ?? DisabilityType.none;
    final changes = AccessibilityPresets.changeSummary(type);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),

          Text(
            AppLocalizations.of(context)!.recommendedSettings,
            style: AppTypography.displaySmall.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, end: 0),

          const SizedBox(height: 8),

          Text(
            type == DisabilityType.none
                ? 'No special settings needed!\nYou\'re all set with the defaults.'
                : 'We\'ll apply these settings for ${type.label}:',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: HCColor.of(context).textSecondary,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 150.ms),

          const SizedBox(height: 24),

          // Selected type badge
          Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: type.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(type.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Text(
                      type.label,
                      style: AppTypography.titleMedium.copyWith(
                        color: type.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 300.ms)
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.0, 1.0),
              ),

          const SizedBox(height: 24),

          // For learners with no flagged needs we still surface the two
          // optional comfort tweaks — dyslexia-friendly palette and
          // reduced motion — since they're useful well beyond the
          // disability presets and otherwise easy to miss.
          if (type == DisabilityType.none) ...[
            const _OptionalComfortTipsCard(
                  tips: [
                    _ComfortTip(
                      emoji: '📝',
                      title: 'Dyslexia-friendly',
                      subtitle:
                          'Cream background, Lexend font, wider letter spacing — easier reading for everyone.',
                    ),
                    _ComfortTip(
                      emoji: '🎬',
                      title: 'Reduced Motion',
                      subtitle:
                          'Less animation, instant page transitions — good for motion sensitivity or older devices.',
                    ),
                  ],
                )
                .animate()
                .fadeIn(duration: 400.ms, delay: 350.ms)
                .slideY(begin: 0.05, end: 0),
            const SizedBox(height: 8),
          ],

          // Settings changes list
          if (changes.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: HCColor.of(context).surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                children: changes.asMap().entries.map((entry) {
                  final i = entry.key;
                  final change = entry.value;
                  final isLast = i == changes.length - 1;

                  return Column(
                    children: [
                      Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  change.emoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        change.name,
                                        style: AppTypography.labelLarge
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        change.value,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: HCColor.of(
                                            context,
                                          ).textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 22,
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 350.ms, delay: (400 + i * 80).ms)
                          .slideX(begin: 0.05, end: 0),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          indent: 56,
                          color: AppColors.border,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 16),

          Text(
            'You can change these anytime in Settings ⚙️',
            style: AppTypography.bodySmall.copyWith(
              color: HCColor.of(context).textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 800.ms),

          const SizedBox(height: 28),

          // Continue button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _nextStep,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(AppLocalizations.of(context)!.applyAndContinue),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                textStyle: AppTypography.buttonText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 900.ms),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  //  Step 3: Confirmation
  // ════════════════════════════════════════
  Widget _buildStep3() {
    final type = _selectedType ?? DisabilityType.none;
    final profile = _isEducatorSetup
        ? widget.studentProfile
        : ref.watch(profileProvider);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success animation
            Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 72,
                    color: AppColors.success,
                  ),
                )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1.0, 1.0),
                  curve: Curves.elasticOut,
                  duration: 800.ms,
                ),

            const SizedBox(height: 28),

            Text(
              'You\'re All Set! 🎉',
              style: AppTypography.displaySmall.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 300.ms),

            const SizedBox(height: 12),

            Text(
              profile != null ? 'Welcome, ${profile.name}!' : 'Welcome!',
              style: AppTypography.titleLarge.copyWith(
                color: HCColor.of(context).textSecondary,
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 450.ms),

            const SizedBox(height: 8),

            if (type != DisabilityType.none) ...[
              Text(
                'Your app has been optimized for\n${type.label.toLowerCase()}.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: HCColor.of(context).textSecondary,
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
            ] else ...[
              Text(
                'Standard settings are ready to go.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: HCColor.of(context).textSecondary,
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
            ],

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HCColor.of(context).surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.softShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.settings_rounded,
                    color: HCColor.of(context).textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'You can adjust all settings anytime\nfrom the Settings page.',
                      style: AppTypography.bodySmall.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 750.ms),

            const SizedBox(height: 36),

            // Let's Go button
            SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _applyAndContinue,
                    icon: Icon(
                      _isEducatorSetup
                          ? Icons.check_rounded
                          : Icons.rocket_launch_rounded,
                    ),
                    label: Text(
                      _isEducatorSetup
                          ? 'Save & Finish'
                          : AppLocalizations.of(context)!.letsStartLearning,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      textStyle: AppTypography.buttonText.copyWith(
                        fontSize: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                )
                .animate()
                .fadeIn(duration: 500.ms, delay: 900.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  Disability Type Selection Card
// ════════════════════════════════════════════
class _DisabilityCard extends StatelessWidget {
  final DisabilityType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _DisabilityCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${type.label}: ${type.description}${isSelected ? ", selected" : ""}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [type.color, type.color.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : HCColor.of(context).surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? type.color
                  : AppColors.primary.withValues(alpha: 0.12),
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: type.color.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : AppColors.softShadow,
          ),
          child: Row(
            children: [
              // Emoji circle
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : type.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(type.emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: AppTypography.titleSmall.copyWith(
                        color: isSelected
                            ? Colors.white
                            : HCColor.of(context).textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      type.description,
                      style: AppTypography.bodySmall.copyWith(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.85)
                            : HCColor.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : type.color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected
                      ? Icons.check_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isSelected
                      ? type.color
                      : HCColor.of(context).textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plain data record for an entry in [_OptionalComfortTipsCard]. Lives
/// alongside the widget rather than in the model layer because nothing
/// else consumes it.
class _ComfortTip {
  final String emoji;
  final String title;
  final String subtitle;

  const _ComfortTip({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
}

/// "Did you know?" card shown on the onboarding accessibility wizard
/// when the learner picks "No Accessibility Needs". Surfaces optional
/// comfort features (dyslexia-friendly, reduced motion) that aren't
/// part of any preset but useful regardless.
class _OptionalComfortTipsCard extends StatelessWidget {
  final List<_ComfortTip> tips;

  const _OptionalComfortTipsCard({required this.tips});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 20,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 8),
              Text(
                'Comfort tweaks you can try later',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < tips.length; i++) ...[
            _ComfortTipRow(tip: tips[i]),
            if (i != tips.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ComfortTipRow extends StatelessWidget {
  final _ComfortTip tip;

  const _ComfortTipRow({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tip.emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tip.title,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tip.subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: HCColor.of(context).textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
