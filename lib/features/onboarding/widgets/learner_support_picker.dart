import 'package:flutter/material.dart';

import '../../../core/accessibility/learner_support.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Picks the supports a Student / Child profile carries for its accessibility
/// category — the sign system a Deaf learner uses, how a learner with low
/// vision reads the screen, how a learner with a motor impairment drives the
/// app, plus the optional extras.
///
/// Shared by profile creation, the accessibility wizard and Edit Profile so
/// the three never drift. The host owns the [selected] set and persists it;
/// this widget only presents the catalogue and enforces its one rule — a
/// single-choice group always keeps exactly one selection, so a learner can
/// swap their primary mode but never end up without one.
class LearnerSupportPicker extends StatelessWidget {
  const LearnerSupportPicker({
    super.key,
    required this.disabilityType,
    required this.selected,
    required this.onChanged,
    this.showHeader = true,
    this.dense = false,
  });

  final DisabilityType disabilityType;
  final Set<LearnerSupportOption> selected;
  final ValueChanged<Set<LearnerSupportOption>> onChanged;

  /// Whether to draw the "Learner Support" title and blurb above the groups.
  final bool showHeader;

  /// Tightens the spacing for the profile-creation form, where this sits under
  /// several other fields.
  final bool dense;

  void _toggle(LearnerSupportGroup group, LearnerSupportOption option) {
    final next = {...selected};
    if (group.singleChoice) {
      next.removeAll(group.options);
      next.add(option);
    } else if (!next.remove(option)) {
      next.add(option);
    }
    onChanged(LearnerSupportCatalog.normalize(disabilityType, next));
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l10n = AppLocalizations.of(context);
    final groups = LearnerSupportCatalog.groupsFor(disabilityType);
    if (groups.isEmpty) return const SizedBox.shrink();

    final gap = dense ? 12.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Text(
            l10n?.supportSectionTitle ?? 'Learner Support',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (l10n ?? AppLocalizationsEn()).supportSectionBlurb(
              disabilityType.labelOf(l10n),
            ),
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          SizedBox(height: gap),
        ],
        for (final group in groups) ...[
          Text(
            group.titleOf(l10n),
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            group.descriptionOf(l10n),
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 8),
          for (final option in group.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _SupportTile(
                option: option,
                isSelected: selected.contains(option),
                singleChoice: group.singleChoice,
                onTap: () => _toggle(group, option),
              ),
            ),
          SizedBox(height: gap),
        ],
      ],
    );
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.option,
    required this.isSelected,
    required this.singleChoice,
    required this.onTap,
  });

  final LearnerSupportOption option;
  final bool isSelected;
  final bool singleChoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = LearnerSupportCatalog.colorFor(option);

    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: singleChoice,
      checked: singleChoice ? null : isSelected,
      selected: singleChoice ? isSelected : null,
      label: '${option.labelOf(l10n)}. ${option.descriptionOf(l10n)}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? accent.withValues(alpha: 0.12) : hc.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? accent : hc.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(option.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.labelOf(l10n),
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.descriptionOf(l10n),
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                singleChoice
                    ? (isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded)
                    : (isSelected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded),
                color: isSelected ? accent : hc.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only summary of a learner's supports, for the screens that show a
/// profile rather than edit it (the educator's learner detail, the roster).
class LearnerSupportChips extends StatelessWidget {
  const LearnerSupportChips({
    super.key,
    required this.options,
    this.alignment = WrapAlignment.start,
  });

  final Set<LearnerSupportOption> options;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    final ordered = options.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: alignment,
      children: [
        for (final option in ordered)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: LearnerSupportCatalog.colorFor(
                option,
              ).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: LearnerSupportCatalog.colorFor(
                  option,
                ).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              '${option.emoji} ${option.shortLabelOf(AppLocalizations.of(context))}',
              style: AppTypography.labelSmall.copyWith(
                color: LearnerSupportCatalog.colorFor(option),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}
