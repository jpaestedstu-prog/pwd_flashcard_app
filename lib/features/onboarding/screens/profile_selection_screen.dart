import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/role_theme.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';

/// Top-level entry choices on the role-picker screen.
///
/// - `player`: casual guest mode. Local-only, never syncs to Firestore.
/// - `joinClass`: school-linked Student. Routes to the join-class screen.
/// - `joinHomeGroup`: family-linked Child. Routes to the join-home-group screen.
/// - `teacher` / `parent`: educator roles, set a PIN, manage learners.
enum _EntryChoice { player, joinClass, joinHomeGroup, teacher, parent }

extension on _EntryChoice {
  /// The [UserRole] this entry maps to — used to look up the [RoleTheme].
  UserRole get role => switch (this) {
        _EntryChoice.player => UserRole.player,
        _EntryChoice.joinClass => UserRole.student,
        _EntryChoice.joinHomeGroup => UserRole.child,
        _EntryChoice.teacher => UserRole.teacher,
        _EntryChoice.parent => UserRole.parent,
      };

  String label(AppLocalizations l10n) => switch (this) {
        _EntryChoice.player => l10n.rolePlayer,
        _EntryChoice.joinClass => l10n.roleStudent,
        _EntryChoice.joinHomeGroup => l10n.roleChild,
        _EntryChoice.teacher => l10n.roleTeacher,
        _EntryChoice.parent => l10n.roleParent,
      };

  String tagline(AppLocalizations l10n) => switch (this) {
        _EntryChoice.player => l10n.rolePlayerTagline,
        _EntryChoice.joinClass => l10n.roleStudentTagline,
        _EntryChoice.joinHomeGroup => l10n.roleChildTagline,
        _EntryChoice.teacher => l10n.roleTeacherTagline,
        _EntryChoice.parent => l10n.roleParentTagline,
      };

  /// Destination route for this entry. Student / Child go through a code
  /// screen first; the rest land on the role-setup form.
  String get route => switch (this) {
        _EntryChoice.joinClass => '/join-class',
        _EntryChoice.joinHomeGroup => '/join-home-group',
        _EntryChoice.player => '/role-setup/player',
        _EntryChoice.teacher => '/role-setup/teacher',
        _EntryChoice.parent => '/role-setup/parent',
      };
}

/// First real screen of onboarding: pick who you are. Each card routes
/// straight to the relevant flow (no inline form lives here anymore).
class ProfileSelectionScreen extends StatelessWidget {
  const ProfileSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

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
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: context.pagePadding,
              vertical: AppSpacing.xl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.maxContentWidth),
                child: Column(
                  children: [
                    AppSpacing.gapLg,

                    // ─── Title ──────────────────────────────
                    Text(
                      l10n.welcome,
                      style: AppTypography.displayMedium.copyWith(
                        color:
                            isDark ? colorScheme.primary : AppColors.primaryDark,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .slideY(begin: -0.2, end: 0),

                    AppSpacing.gapSm,

                    Text(
                      l10n.whoAreYou,
                      style: AppTypography.titleLarge.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

                    AppSpacing.gapXxl,

                    // ─── Entry Choice Cards ──────────────────
                    ..._EntryChoice.values.asMap().entries.map((entry) {
                      final index = entry.key;
                      final choice = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _ChoiceCard(
                          choice: choice,
                          onTap: () => context.go(choice.route),
                        ),
                      )
                          .animate()
                          .fadeIn(
                              duration: 500.ms, delay: (300 + index * 100).ms)
                          .slideX(begin: index.isEven ? -0.15 : 0.15, end: 0);
                    }),

                    // "Recover with code" — for users restoring a profile
                    // on a fresh device.
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: AppButton.text(
                        label: l10n.iHaveRecoveryCode,
                        icon: Icons.restore_rounded,
                        onPressed: () => context.push('/recovery/redeem'),
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 800.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable role card. Uses [AppCard] for the surface and [RoleTheme] for
/// the per-role accent + Material glyph (no emoji, so it renders on every
/// supported Android version).
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.choice, required this.onTap});

  final _EntryChoice choice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roleTheme = RoleTheme.of(choice.role);
    final label = choice.label(l10n);

    return Semantics(
      button: true,
      label: label,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        borderColor: roleTheme.primary.withValues(alpha: 0.15),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: roleTheme.gradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: roleTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(roleTheme.icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.titleLarge.copyWith(
                      color: HCColor.of(context).textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    choice.tagline(l10n),
                    style: AppTypography.bodySmall.copyWith(
                      color: HCColor.of(context).textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: HCColor.of(context).textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
