import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_card.dart';

/// A short, friendly primer on Persons with Disabilities (PWD): what the
/// term means, the common kinds of disability, how to interact respectfully,
/// and how this app supports accessible learning.
///
/// Reached from the profile-selection screen and from Settings → About, so
/// guests and signed-in users alike can read it. Content is intentionally
/// plain-language and pairs an icon with every point to stay readable for the
/// PWD learners the app is built for.
class PwdAwarenessScreen extends StatelessWidget {
  const PwdAwarenessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/profile'),
        title: Text(l10n.pwdAwarenessTitle),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.maxContentWidth),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              AppSpacing.lg,
              context.pagePadding,
              AppSpacing.xxl,
            ),
            children: [
              // ─── Hero ───────────────────────────────
              _HeroCard(
                title: l10n.pwdAwarenessTitle,
                subtitle: l10n.pwdAwarenessSubtitle,
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0),

              AppSpacing.gapXl,

              // ─── What is a PWD? ─────────────────────
              const _Section(
                index: 0,
                icon: Icons.diversity_3_rounded,
                color: AppColors.primary,
                title: 'What does "PWD" mean?',
                body:
                    'PWD stands for Persons with Disabilities — people who have '
                    'a long-term physical, sensory, cognitive, or learning '
                    'condition. Disability is a natural part of human '
                    'diversity. Use person-first language: say "a person with '
                    'a disability," not "a disabled person." Every learner '
                    'deserves the same respect and the same chance to learn.',
              ),

              AppSpacing.gapLg,

              // ─── Types of disability ────────────────
              const _SectionHeader(
                icon: Icons.category_rounded,
                color: AppColors.secondary,
                title: 'Common kinds of disability',
              ),
              AppSpacing.gapSm,
              ...DisabilityType.values
                  .where((t) => t != DisabilityType.none)
                  .toList()
                  .asMap()
                  .entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _TypeRow(type: e.value)
                          .animate()
                          .fadeIn(
                            duration: 350.ms,
                            delay: (120 + e.key * 70).ms,
                          )
                          .slideX(begin: 0.08, end: 0),
                    ),
                  ),

              AppSpacing.gapLg,

              // ─── Respectful interaction ─────────────
              const _Section(
                index: 1,
                icon: Icons.volunteer_activism_rounded,
                color: AppColors.accent,
                title: 'Interacting respectfully',
                bullets: [
                  'Speak directly to the person, not to their companion or '
                      'interpreter.',
                  'Ask before you help — don\'t assume someone needs it.',
                  'Be patient and give people time to respond.',
                  'Keep language simple and clear; avoid labels and pity.',
                  'A wheelchair, cane, or guide is personal space — don\'t '
                      'touch it without permission.',
                ],
              ),

              AppSpacing.gapLg,

              // ─── Accessible communication ───────────
              _Section(
                index: 2,
                icon: Icons.sign_language_rounded,
                color: DisabilityType.hearing.color,
                title: 'Communicating accessibly',
                body:
                    'Many Deaf and hard-of-hearing Filipinos communicate '
                    'through Filipino Sign Language (FSL) — a complete language '
                    'with its own grammar. Captions, plain text, pictures, and '
                    'sign-language video all make information reach more '
                    'people. This app teaches vocabulary alongside FSL clips '
                    'so signing learners are included from the start.',
              ),

              AppSpacing.gapLg,

              // ─── How the app helps ──────────────────
              const _Section(
                index: 3,
                icon: Icons.accessibility_new_rounded,
                color: AppColors.primary,
                title: 'How FlashLearn PWD helps',
                bullets: [
                  'High-contrast and dyslexia-friendly themes for easier '
                      'reading.',
                  'Adjustable font size, reduced motion, and text-to-speech.',
                  'Filipino Sign Language videos in flashcards and stories.',
                  'Hands-free gaze control — move your head or blink to '
                      'select.',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient hero banner at the top of the primer.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      depth: true,
      depthBubbles: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      gradient: const LinearGradient(
        colors: [AppColors.primary, AppColors.secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.diversity_3_rounded,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled content card. Renders [body] paragraph text and/or a [bullets]
/// list — at least one should be provided.
class _Section extends StatelessWidget {
  const _Section({
    required this.index,
    required this.icon,
    required this.color,
    required this.title,
    this.body,
    this.bullets,
  });

  final int index;
  final IconData icon;
  final Color color;
  final String title;
  final String? body;
  final List<String>? bullets;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return AppCard(
      borderColor: color.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(icon: icon, color: color, title: title),
          if (body != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              body!,
              style: AppTypography.bodyMedium.copyWith(
                color: hc.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          if (bullets != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ...bullets!.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(Icons.check_circle_rounded,
                          size: 18, color: color),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        b,
                        style: AppTypography.bodyMedium.copyWith(
                          color: hc.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (100 + index * 90).ms)
        .slideY(begin: 0.06, end: 0);
  }
}

/// Icon + title row shared by [_Section] and the standalone "types" header.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
  });

  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                color: HCColor.of(context).textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One disability-type row inside the "Common kinds of disability" list.
/// Reuses [DisabilityTypeX] for the icon, label, colour, and description so
/// the wording stays consistent with the accessibility setup wizard.
class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.type});

  final DisabilityType type;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return AppCard(
      borderColor: type.color.withValues(alpha: 0.18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: type.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(type.icon, color: type.color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.label,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  type.description,
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
