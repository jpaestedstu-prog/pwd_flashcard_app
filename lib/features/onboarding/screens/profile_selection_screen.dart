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
/// - `playerGuest`: casual guest mode. Local-only, never syncs to Firestore.
///   Progress stays on this device and isn't backed up.
/// - `playerProgress`: a saved Player profile that keeps XP / streaks / badges
///   and can be backed up + restored (set a PIN during setup).
/// - `joinClass`: school-linked Student. Routes to the join-class screen.
/// - `joinHomeGroup`: family-linked Child. Routes to the join-home-group screen.
/// - `teacher` / `parent`: educator roles, set a PIN, manage learners.
enum _EntryChoice {
  playerGuest,
  playerProgress,
  joinClass,
  joinHomeGroup,
  teacher,
  parent,
}

extension on _EntryChoice {
  /// The [UserRole] this entry maps to — used to look up the [RoleTheme].
  /// Both Player variants share the Player role/theme.
  UserRole get role => switch (this) {
        _EntryChoice.playerGuest => UserRole.player,
        _EntryChoice.playerProgress => UserRole.player,
        _EntryChoice.joinClass => UserRole.student,
        _EntryChoice.joinHomeGroup => UserRole.child,
        _EntryChoice.teacher => UserRole.teacher,
        _EntryChoice.parent => UserRole.parent,
      };

  String label(AppLocalizations l10n) => switch (this) {
        _EntryChoice.playerGuest => l10n.rolePlayerGuest,
        _EntryChoice.playerProgress => l10n.rolePlayerProgress,
        _EntryChoice.joinClass => l10n.roleStudent,
        _EntryChoice.joinHomeGroup => l10n.roleChild,
        _EntryChoice.teacher => l10n.roleTeacher,
        _EntryChoice.parent => l10n.roleParent,
      };

  String tagline(AppLocalizations l10n) => switch (this) {
        _EntryChoice.playerGuest => l10n.rolePlayerGuestTagline,
        _EntryChoice.playerProgress => l10n.rolePlayerProgressTagline,
        _EntryChoice.joinClass => l10n.roleStudentTagline,
        _EntryChoice.joinHomeGroup => l10n.roleChildTagline,
        _EntryChoice.teacher => l10n.roleTeacherTagline,
        _EntryChoice.parent => l10n.roleParentTagline,
      };

  /// Per-choice glyph. The two Player variants share the Player theme colour
  /// but use distinct icons so they're easy to tell apart at a glance.
  IconData get icon => switch (this) {
        _EntryChoice.playerGuest => Icons.sports_esports_rounded,
        _EntryChoice.playerProgress => Icons.workspace_premium_rounded,
        _ => RoleTheme.of(role).icon,
      };

  /// Destination route for this entry. Student / Child go through a code
  /// screen first; the rest land on the role-setup form. The two Player
  /// variants share the form but pass a `mode` so it knows whether to create
  /// a guest (local-only) or a progress-keeping profile.
  String get route => switch (this) {
        _EntryChoice.joinClass => '/join-class',
        _EntryChoice.joinHomeGroup => '/join-home-group',
        _EntryChoice.playerGuest => '/role-setup/player?mode=guest',
        _EntryChoice.playerProgress => '/role-setup/player?mode=progress',
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

                    // ─── Grouped role choices ────────────────
                    ..._buildGroups(context, l10n),

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

                    // "Learn about PWD awareness" — open the awareness primer.
                    // Surfaced here so anyone (including guests) can read it
                    // before choosing a profile.
                    AppButton.text(
                      label: l10n.pwdAwarenessEntry,
                      icon: Icons.diversity_3_rounded,
                      onPressed: () => context.push('/pwd-awareness'),
                    ).animate().fadeIn(duration: 500.ms, delay: 900.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the three labelled groups of role cards in order, with a staggered
  /// entrance. The functional routes are unchanged — this only reorganises the
  /// flat list into Player Profiles / Classroom / Family Group sections.
  List<Widget> _buildGroups(BuildContext context, AppLocalizations l10n) {
    final groups = <({
      String title,
      String description,
      List<_EntryChoice> choices,
    })>[
      (
        title: l10n.groupPlayerProfiles,
        description: l10n.groupPlayerProfilesDesc,
        choices: const [_EntryChoice.playerGuest, _EntryChoice.playerProgress],
      ),
      (
        title: l10n.groupClassroom,
        description: l10n.groupClassroomDesc,
        choices: const [_EntryChoice.joinClass, _EntryChoice.teacher],
      ),
      (
        title: l10n.groupFamily,
        description: l10n.groupFamilyDesc,
        choices: const [_EntryChoice.joinHomeGroup, _EntryChoice.parent],
      ),
    ];

    final widgets = <Widget>[];
    var delay = 300;
    for (var g = 0; g < groups.length; g++) {
      final group = groups[g];
      if (g > 0) widgets.add(AppSpacing.gapLg);
      widgets.add(
        _GroupHeader(title: group.title, description: group.description)
            .animate()
            .fadeIn(duration: 500.ms, delay: delay.ms)
            .slideX(begin: -0.1, end: 0),
      );
      widgets.add(AppSpacing.gapMd);
      delay += 80;
      for (final choice in group.choices) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _ChoiceCard(
              choice: choice,
              onTap: () => context.go(choice.route),
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: delay.ms)
              .slideX(begin: 0.12, end: 0),
        );
        delay += 80;
      }
    }
    return widgets;
  }
}

/// Section header for a role group: a bold title plus a one-line description
/// of what that group is for. Left-aligned under the centred screen title.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Semantics(
      header: true,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(
                      color: hc.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                description,
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ),
          ],
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
              child: Icon(choice.icon, color: Colors.white, size: 32),
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
