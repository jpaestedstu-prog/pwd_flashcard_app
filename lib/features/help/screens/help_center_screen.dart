import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_back_button.dart';
import '../models/guides.dart';

/// **Help & Guides** (`/help`): every guide this profile needs, most useful
/// first — a learner's own guide and the ways to use the app; a teacher's or
/// parent's guides first for them (see [guidesFor]).
///
/// Opened from Settings → About, and from the accessibility sheet on the
/// child and guest homes (which have no Settings).
class HelpCenterScreen extends ConsumerWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final filipino = ref.watch(settingsProvider).locale == 'fil';
    final role = ref.watch(profileProvider)?.role;
    final educator = role == UserRole.teacher || role == UserRole.parent;
    final guides = guidesFor(educator: educator);
    final hc = HCColor.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: AppBarTitle(t.helpTitle),
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
              Text(
                t.helpIntro,
                style: AppTypography.bodyLarge.copyWith(
                  color: hc.textSecondary,
                ),
              ),
              AppSpacing.gapLg,
              for (final g in guides) ...[
                _GuideTile(guide: g, filipino: filipino),
                AppSpacing.gapSm,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({required this.guide, required this.filipino});

  final Guide guide;
  final bool filipino;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final title = guide.title.of(filipino: filipino);
    final summary = guide.summary.of(filipino: filipino);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: guide.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(guide.icon, color: guide.color, size: 26),
        ),
        title: Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: hc.textPrimary,
          ),
        ),
        subtitle: Text(summary, style: TextStyle(color: hc.textSecondary)),
        trailing: Icon(Icons.chevron_right_rounded, color: hc.textSecondary),
        onTap: () => context.push('/help/${guide.id}'),
      ),
    );
  }
}
