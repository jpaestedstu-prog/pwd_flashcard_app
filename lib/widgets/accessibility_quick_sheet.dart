import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// A small, child-safe accessibility panel surfaced from the home surfaces that
/// have no Settings gear — the Child home and the Guest Player home.
///
/// Those learners are themselves the PWD users, but neither screen exposed a
/// way to adjust accessibility (text size, contrast, easy-read font, read-aloud,
/// reduced motion) without an educator switching profiles. This sheet gives the
/// essentials inline while leaving the full Settings screen (profiles, PINs,
/// notifications, sync) parent-managed.
///
/// It writes through the same [settingsProvider] used everywhere else, so a
/// change here applies app-wide and persists to Hive immediately.
Future<void> showAccessibilityQuickSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _AccessibilityQuickSheet(),
  );
}

/// A round icon button that opens [showAccessibilityQuickSheet]. Drop it into a
/// home surface that lacks a Settings entry point.
class AccessibilityQuickButton extends StatelessWidget {
  const AccessibilityQuickButton({super.key, this.color, this.iconSize = 26});

  /// Icon tint; defaults to the theme's [ColorScheme.onSurfaceVariant].
  final Color? color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Accessibility options',
      child: IconButton(
        onPressed: () => showAccessibilityQuickSheet(context),
        icon: const Icon(Icons.accessibility_new_rounded),
        iconSize: iconSize,
        tooltip: 'Accessibility',
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _AccessibilityQuickSheet extends ConsumerWidget {
  const _AccessibilityQuickSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Icon(Icons.accessibility_new_rounded, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Accessibility',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Make the app easier to see, hear, and use.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            // ── Text size ──
            Text(
              'Text Size',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _SizePreset(
                  label: 'S',
                  isActive: settings.fontScale <= 0.85,
                  onTap: () => notifier.updateFontScale(0.8),
                ),
                const SizedBox(width: 8),
                _SizePreset(
                  label: 'M',
                  isActive:
                      settings.fontScale > 0.85 && settings.fontScale <= 1.05,
                  onTap: () => notifier.updateFontScale(1.0),
                ),
                const SizedBox(width: 8),
                _SizePreset(
                  label: 'L',
                  isActive:
                      settings.fontScale > 1.05 && settings.fontScale <= 1.25,
                  onTap: () => notifier.updateFontScale(1.2),
                ),
                const SizedBox(width: 8),
                _SizePreset(
                  label: 'XL',
                  isActive: settings.fontScale > 1.25,
                  onTap: () => notifier.updateFontScale(1.5),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Toggles ──
            _ToggleTile(
              icon: Icons.contrast_rounded,
              title: 'High Contrast',
              subtitle: 'Bolder colors and outlines',
              value: settings.highContrastMode,
              onChanged: (_) => notifier.toggleHighContrast(),
            ),
            _ToggleTile(
              icon: Icons.font_download_rounded,
              title: 'Easy-Read Font',
              subtitle: 'Friendlier spacing for reading',
              value: settings.dyslexiaMode,
              onChanged: (v) =>
                  notifier.update(settings.copyWith(dyslexiaMode: v)),
            ),
            _ToggleTile(
              icon: Icons.volume_up_rounded,
              title: 'Read Aloud',
              subtitle: 'Speak words and buttons',
              value: settings.ttsEnabled,
              onChanged: (_) => notifier.toggleTts(),
            ),
            _ToggleTile(
              icon: Icons.motion_photos_off_rounded,
              title: 'Reduce Motion',
              subtitle: 'Calmer, simpler animations',
              value: settings.reducedMotion,
              onChanged: (_) => notifier.toggleReducedMotion(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A square text-size preset button (S / M / L / XL) that highlights when its
/// scale is the active one.
class _SizePreset extends StatelessWidget {
  const _SizePreset({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: 'Text size $label',
        child: Material(
          color: isActive ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isActive ? colors.onPrimary : colors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled switch row for a single accessibility toggle.
class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: colors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
