import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../providers/app_providers.dart';

/// Modal pause overlay shown over a paused game.
///
/// Renders a `ModalBarrier` + a centred card sized by the responsive tier
/// from [ResponsiveExtension]. Pure Material — no external packages.
///
/// Wire-up: parent shows this conditionally inside a `Stack` when the
/// host's `isPaused` flag is true. Parent provides the callbacks; the
/// sound toggle reads / writes [settingsProvider.soundEffects] directly.
class PauseOverlay extends ConsumerWidget {
  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
    this.title = 'Paused',
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final Future<void> Function() onQuit;
  final String title;

  double _cardWidth(BuildContext context) {
    final w = context.responsiveTier<double>(
      phone: 320,
      tablet: 480,
      large: 560,
      xl: 640,
      ultra: 640,
    );
    // Never exceed 60% of viewport width on tablets+, never overflow on phone.
    final cap = context.screenWidth * (context.isTablet ? 0.6 : 0.92);
    return w > cap ? cap : w;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final soundOn = ref.watch(settingsProvider.select((s) => s.soundEffects));
    final width = _cardWidth(context);

    return Stack(
      children: [
        // Dim and block input below.
        const Positioned.fill(
          child: ModalBarrier(
            color: Color(0x99000000),
            dismissible: false,
          ),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: Card(
                elevation: 12,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.pause_circle_filled_rounded,
                            size: 32,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.gapLg,
                      _OverlayButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Resume',
                        primary: true,
                        onTap: onResume,
                      ),
                      AppSpacing.gapMd,
                      _OverlayButton(
                        icon: Icons.refresh_rounded,
                        label: 'Restart',
                        onTap: () {
                          // Confirm before discarding the in-progress run.
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Restart this game?'),
                              content: const Text(
                                'Your current progress in this round will be lost.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    onRestart();
                                  },
                                  child: const Text('Restart'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      AppSpacing.gapMd,
                      _OverlayButton(
                        icon: Icons.exit_to_app_rounded,
                        label: 'Quit to Games',
                        onTap: () async {
                          await onQuit();
                        },
                      ),
                      AppSpacing.gapLg,
                      const Divider(height: 1),
                      AppSpacing.gapMd,
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                          soundOn
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                        ),
                        title: const Text('Sound effects'),
                        value: soundOn,
                        onChanged: (_) =>
                            ref.read(settingsProvider.notifier).toggleSoundEffects(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    // FittedBox keeps the icon+label as one unit that scales down to fit the
    // button rather than overflowing when the Font Size setting (up to 2.0×)
    // would otherwise push the label past a narrow card's width.
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Text(label, maxLines: 1),
        ],
      ),
    );
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(vertical: AppSpacing.md),
      ),
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
    return Semantics(
      button: true,
      label: label,
      child: primary
          ? FilledButton(onPressed: onTap, style: style, child: child)
          : OutlinedButton(onPressed: onTap, style: style, child: child),
    );
  }
}
