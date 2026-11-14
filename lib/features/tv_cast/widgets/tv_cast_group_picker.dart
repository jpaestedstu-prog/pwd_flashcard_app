import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/fit_text.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../providers/app_providers.dart';
import '../../live_session/models/live_session_models.dart';
import '../models/cast_group_selection.dart';
import '../providers/cast_group_provider.dart';

/// "Class / group" on the TV Cast screen: which of the educator's classes
/// (Teacher) or home groups (Parent) the cast is for.
///
/// A summary row says who the cast is for right now; tapping it opens the
/// list. "All classes" is one combined choice at the top. Tapping a class
/// narrows the cast to it, tapping more adds them, and picking every class one
/// by one folds back into "All" — see [CastGroupSelection]. Each class shows
/// the accessibility audience it was created for ("Hearing Impairment",
/// "Multiple Disabilities", …) and how many learners belong to it.
///
/// The choice is saved per educator on this device and applies at once: the
/// progress board shows only these learners, a live activity is sent to these
/// classes only, and the TV names them. It can be changed at any time, mid-cast
/// included.
class TvCastGroupPicker extends ConsumerStatefulWidget {
  const TvCastGroupPicker({super.key});

  @override
  ConsumerState<TvCastGroupPicker> createState() => _TvCastGroupPickerState();
}

class _TvCastGroupPickerState extends ConsumerState<TvCastGroupPicker> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    if (profile == null) return const SizedBox.shrink();
    final t = _t(context);
    final hc = HCColor.of(context);
    final options = ref.watch(castGroupOptionsProvider(profile.id));

    if (options.isEmpty) {
      return ProPanel(
        padding: AppSpacing.paddingMd,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.groups_rounded, size: 20, color: hc.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                profile.role == UserRole.parent ? t.tcgNoGroup : t.tcgNoClass,
                style: AppTypography.bodyMedium.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final selection = ref.watch(castGroupSelectionProvider(profile.id));
    final notifier = ref.read(castGroupSelectionProvider(profile.id).notifier);
    final forAll = selection.coversAll(options);
    final allLabel = castAllGroupsLabel(t, options);
    final summary = forAll
        ? (options.length == 1 ? options.first.name : allLabel)
        : selection.resolve(options).map((o) => o.name).join(' · ');

    return ProPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryRow(
            summary: summary,
            open: _open,
            // One class has nothing to choose between: the row just says so.
            onTap: options.length < 2
                ? null
                : () => setState(() => _open = !_open),
          ),
          if (_open && options.length > 1) ...[
            Divider(height: 1, color: hc.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text(
                t.tcgHint(allLabel),
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ),
            _GroupRow(
              icon: Icons.select_all_rounded,
              title: allLabel,
              subtitle: t.tcgAllNote,
              selected: forAll,
              accent: AppColors.success,
              onTap: () => notifier.selectAll(),
            ),
            for (final option in options)
              _GroupRow(
                icon: option.kind == LiveSessionOwnerKind.homeGroup
                    ? Icons.home_rounded
                    : option.accessibility.icon,
                title: option.name,
                subtitleBuilder: (count) => [
                  option.accessibility.labelOf(t),
                  if (count != null) t.tcgMembers(count),
                ].join(' · '),
                option: option,
                selected: !forAll && selection.includes(option.id),
                onTap: () => notifier.toggle(option.id, options),
              ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

/// "Casting for: Hearing Class · Cognitive Class   Change ▾".
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.summary,
    required this.open,
    required this.onTap,
  });

  final String summary;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final t = _t(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hc.primary.withValues(alpha: 0.12),
              borderRadius: ProSurface.borderRadius,
            ),
            child: Icon(Icons.groups_rounded, size: 22, color: hc.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.tcgCastingFor,
                  style: AppTypography.labelSmall.copyWith(
                    color: hc.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: fittedStyle(
                    context,
                    summary,
                    AppTypography.titleSmall.copyWith(
                      color: hc.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              open ? t.tcgDone : t.tcgChange,
              style: AppTypography.labelLarge.copyWith(
                color: hc.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Icon(
              open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: hc.primary,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return Semantics(
        container: true,
        label: '${t.tcgCastingFor}: $summary',
        child: ExcludeSemantics(child: row),
      );
    }
    return Semantics(
      container: true,
      button: true,
      expanded: open,
      label: '${t.tcgCastingFor}: $summary. ${open ? t.tcgDone : t.tcgChange}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: ExcludeSemantics(child: row),
        ),
      ),
    );
  }
}

/// One choice in the open list: a check box, the class name and what it is.
class _GroupRow extends ConsumerWidget {
  const _GroupRow({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.subtitleBuilder,
    this.option,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Builds the subtitle once the learner count is known (null while not).
  final String Function(int? count)? subtitleBuilder;

  /// The group this row stands for; null for the "All" row.
  final CastGroupOption? option;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final group = option;
    final count = group == null
        ? null
        : ref.watch(castGroupMemberCountProvider(group));
    final caption = subtitleBuilder?.call(count) ?? subtitle ?? '';
    final tint = accent ?? hc.primary;

    final visual = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            color: selected ? tint : hc.textSecondary,
            size: 26,
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(icon, size: 20, color: selected ? tint : hc.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: fittedStyle(
                    context,
                    title,
                    AppTypography.titleSmall.copyWith(
                      color: hc.textPrimary,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (caption.isNotEmpty)
                  Text(
                    caption,
                    style: fittedStyle(
                      context,
                      caption,
                      AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                      ),
                      factor: 0.82,
                      longWord: 9,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      button: true,
      checked: selected,
      label: caption.isEmpty ? title : '$title, $caption',
      child: Material(
        color: selected
            ? Color.alphaBlend(tint.withValues(alpha: 0.08), hc.cardBackground)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ExcludeSemantics(child: visual),
        ),
      ),
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
