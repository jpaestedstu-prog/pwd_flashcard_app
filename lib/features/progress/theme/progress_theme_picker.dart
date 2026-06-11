import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'progress_layout.dart';
import 'progress_layout_registry.dart';
import 'progress_theme.dart';
import 'progress_theme_registry.dart';

/// Opens the combined "Customize Progress" bottom sheet: pick a color **skin**
/// and a layout **template** in one place. Selections apply live (the sheet
/// stays open) so a learner can preview both together.
///
/// Overflow-safe by construction: `isScrollControlled` + a
/// `SingleChildScrollView` body and `Wrap`s of swatches, so it adapts to any
/// tablet width / font scale without RenderFlex overflow.
Future<void> showProgressCustomizeSheet(
  BuildContext context, {
  required String selectedThemeId,
  required String selectedLayoutId,
  required ValueChanged<String> onThemeSelected,
  required ValueChanged<String> onLayoutSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HCColor.of(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final hc = HCColor.of(context);
      var themeId = selectedThemeId;
      var layoutId = selectedLayoutId;
      return StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.8,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: hc.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text('Customize Progress',
                        style: AppTypography.titleLarge
                            .copyWith(color: hc.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Pick a look and a layout for the Progress page',
                        style: AppTypography.bodySmall
                            .copyWith(color: hc.textSecondary)),
                    const SizedBox(height: 20),

                    // ─── Theme (skin) ───────────────────────
                    const _SectionLabel(
                        icon: Icons.palette_rounded, text: 'Theme'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final theme in ProgressThemes.all)
                          _ThemeSwatch(
                            theme: theme,
                            selected: theme.id == themeId,
                            onTap: () {
                              onThemeSelected(theme.id);
                              setState(() => themeId = theme.id);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ─── Layout (template) ──────────────────
                    const _SectionLabel(
                        icon: Icons.dashboard_customize_rounded,
                        text: 'Layout'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final lay in ProgressLayouts.all)
                          _LayoutSwatch(
                            layout: lay,
                            accent: ProgressThemes.byId(themeId).accent,
                            selected: lay.id == layoutId,
                            onTap: () {
                              onLayoutSelected(lay.id);
                              setState(() => layoutId = lay.id);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: hc.textSecondary),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppTypography.titleSmall.copyWith(
            color: hc.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final ProgressTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 96,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 64,
              decoration: BoxDecoration(
                gradient: theme.gradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? theme.accent : Colors.transparent,
                  width: 3,
                ),
                boxShadow: AppColors.softShadow,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(theme.emoji,
                        style: const TextStyle(fontSize: 26)),
                  ),
                  if (selected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_circle,
                            color: theme.accent, size: 18),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              theme.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: hc.textPrimary,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayoutSwatch extends StatelessWidget {
  final ProgressLayout layout;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _LayoutSwatch({
    required this.layout,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 150,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.10)
                : hc.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : hc.border.withValues(alpha: 0.5),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(layout.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      layout.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        color: hc.textPrimary,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    Text(
                      layout.blurb,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall
                          .copyWith(color: hc.textSecondary),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
