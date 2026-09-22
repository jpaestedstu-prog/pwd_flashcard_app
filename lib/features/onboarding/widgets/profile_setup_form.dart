import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/accessibility/learner_support.dart';
import '../../../core/constants/avatar_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/role_theme.dart';
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import 'learner_support_picker.dart';

/// Shared profile-setup form used by both [RoleSetupScreen] (player / teacher /
/// parent) and [PostJoinSetupScreen] (student / child after a join code).
///
/// It used to be ~250 lines duplicated almost verbatim across the two screens.
/// This widget owns the *presentation* of the Name / Avatar / Birth-date /
/// PIN fields; the host screen still owns the controllers and submit logic so
/// the differing post-submit flows (recovery code vs. educator override,
/// in-place player upgrade vs. fresh profile) stay where they belong.
///
/// Tints itself with [RoleTheme] so each role gets a consistent accent.
class ProfileSetupForm extends StatelessWidget {
  const ProfileSetupForm({
    super.key,
    required this.role,
    required this.nameController,
    required this.selectedAvatarIndex,
    required this.onAvatarSelected,
    required this.enablePin,
    required this.onTogglePin,
    required this.pinController,
    required this.pinConfirmController,
    this.showBirthDate = false,
    this.birthDate,
    this.computedAge,
    this.suggestedLevel,
    this.onPickBirthDate,
    this.supportDisabilityType,
    this.selectedSupports = const {},
    this.onSupportsChanged,
  });

  final UserRole role;

  final TextEditingController nameController;

  final int selectedAvatarIndex;
  final ValueChanged<int> onAvatarSelected;

  /// The accessibility category this learner's supports are being chosen for.
  ///
  /// Non-null only on the Student / Child join flow, where the category is
  /// already settled by the class or home group being joined. Null hides the
  /// block entirely — a Teacher, Parent or Player has no learner supports.
  final DisabilityType? supportDisabilityType;
  final Set<LearnerSupportOption> selectedSupports;
  final ValueChanged<Set<LearnerSupportOption>>? onSupportsChanged;

  /// When true, the Age / Birth Date field (and live level suggestion) shows.
  /// Only learners who supply an age (student / child) set this.
  final bool showBirthDate;
  final DateTime? birthDate;
  final int? computedAge;
  final LearningLevel? suggestedLevel;
  final VoidCallback? onPickBirthDate;

  final bool enablePin;
  final ValueChanged<bool> onTogglePin;
  final TextEditingController pinController;
  final TextEditingController pinConfirmController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roleTheme = RoleTheme.of(role);
    final accent = roleTheme.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Name ──────────────────────────────────────────
        _SectionLabel(l10n.nameLabel),
        AppSpacing.gapMd,
        TextFormField(
          controller: nameController,
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: l10n.enterYourName,
            prefixIcon: const Icon(Icons.person_rounded),
            suffixIcon: IconButton(
              tooltip: l10n.clear,
              icon: const Icon(Icons.clear_rounded),
              onPressed: nameController.clear,
            ),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.pleaseEnterName;
            }
            if (value.trim().length < 2) {
              return l10n.nameMinLength;
            }
            return null;
          },
        ),

        // ─── Age / Birth Date (learners only) ──────────────
        if (showBirthDate) ...[
          AppSpacing.gapXl,
          _SectionLabel(l10n.ageOrBirthDate),
          AppSpacing.gapMd,
          GestureDetector(
            onTap: onPickBirthDate,
            child: AbsorbPointer(
              child: TextFormField(
                key: ValueKey(birthDate),
                style: AppTypography.bodyLarge,
                decoration: InputDecoration(
                  hintText: l10n.tapToSelectBirthDate,
                  prefixIcon: const Icon(Icons.cake_rounded),
                  suffixIcon: birthDate != null
                      ? Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Chip(
                            label: Text(
                              l10n.yearsOld(computedAge ?? 0),
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                            backgroundColor: accent.withValues(alpha: 0.1),
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                      : null,
                ),
                initialValue: birthDate != null
                    ? '${birthDate!.month}/${birthDate!.day}/${birthDate!.year}'
                    : '',
                validator: (_) =>
                    birthDate == null ? l10n.pleaseSelectBirthDate : null,
              ),
            ),
          ),
          if (birthDate != null && suggestedLevel != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                l10n.suggestedLevel(suggestedLevel!.label),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.success,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],

        // ─── Avatar ────────────────────────────────────────
        AppSpacing.gapXl,
        _SectionLabel(l10n.chooseYourAvatar),
        AppSpacing.gapMd,
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: AvatarData.avatarsForRole(role).map((entry) {
            final i = entry.$1;
            final avatar = entry.$2;
            final isSelected = selectedAvatarIndex == i;
            return Semantics(
              button: true,
              selected: isSelected,
              label: AppLocalizations.of(context)?.epAvatarSemantics(avatar.labelOf(filipino: AppLocalizations.of(context)!.localeName.startsWith('fil'))) ?? '${avatar.label} avatar',
              child: GestureDetector(
                onTap: () => onAvatarSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? avatar.color
                        : avatar.color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? accent : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: avatar.color.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      avatar.emoji,
                      style: TextStyle(fontSize: isSelected ? 30 : 26),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

        // ─── Learner Support (Student / Child only) ────────
        // The category came from the class or home group; this is the part
        // that is about this learner rather than the group.
        if (supportDisabilityType != null && onSupportsChanged != null) ...[
          AppSpacing.gapXl,
          LearnerSupportPicker(
            disabilityType: supportDisabilityType!,
            selected: selectedSupports,
            onChanged: onSupportsChanged!,
            dense: true,
          ),
        ],

        // ─── PIN Protection (optional) ─────────────────────
        AppSpacing.gapXl,
        _SectionLabel(l10n.pinProtection),
        AppSpacing.gapXs,
        Text(
          l10n.pinProtectionDescription,
          style: AppTypography.bodySmall.copyWith(
            color: HCColor.of(context).textSecondary,
          ),
        ),
        AppSpacing.gapMd,
        // Its own Material, per Flutter's own advice for this case. A ListTile
        // paints its background and ink splash onto the nearest Material
        // ancestor, and here a decorated container sits in between — so the
        // splash landed underneath it and the row gave no tap feedback at all.
        // The framework only flags this once the container actually has a
        // background colour, which is why the high-contrast theme surfaced it.
        // Transparent, so nothing about the row's appearance changes.
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            value: enablePin,
            onChanged: onTogglePin,
            title: Text(l10n.enablePinLock, style: AppTypography.bodyLarge),
            secondary: Icon(
              enablePin ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: enablePin ? accent : AppColors.textHint,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (enablePin) ...[
          AppSpacing.gapMd,
          TextFormField(
            controller: pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            style: AppTypography.bodyLarge,
            decoration: InputDecoration(
              hintText: l10n.enterFourDigitPin,
              prefixIcon: const Icon(Icons.pin_rounded),
              counterText: '',
            ),
            validator: (value) {
              if (!enablePin) return null;
              if (value == null || value.length != 4) {
                return l10n.pinMustBe4Digits;
              }
              if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                return l10n.pinDigitsOnly;
              }
              return null;
            },
          ),
          AppSpacing.gapMd,
          TextFormField(
            controller: pinConfirmController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            style: AppTypography.bodyLarge,
            decoration: InputDecoration(
              hintText: l10n.confirmPinLabel,
              prefixIcon: const Icon(Icons.pin_rounded),
              counterText: '',
            ),
            validator: (value) {
              if (!enablePin) return null;
              if (value != pinController.text) {
                return l10n.pinsDoNotMatch;
              }
              return null;
            },
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTypography.titleMedium);
  }
}
