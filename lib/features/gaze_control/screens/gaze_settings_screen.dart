import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../models/gaze_settings.dart';
import '../providers/gaze_settings_provider.dart';

/// Configuration + launch screen for the Gaze (head + blink) accessibility
/// control. Persists to [GazeSettings] and offers a "Try it now" button into
/// the live preview ([/gaze-control]).
class GazeSettingsScreen extends ConsumerWidget {
  const GazeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(gazeSettingsProvider);
    final notifier = ref.read(gazeSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('👁️  Gaze Control'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const _IntroCard(),
          const SizedBox(height: 16),

          SwitchListTile.adaptive(
            value: settings.enabled,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable Gaze Control',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(settings.enabled
                ? 'Head movements & blinks can drive the app'
                : 'Off — touch only'),
            onChanged: notifier.setEnabled,
          ),

          const SizedBox(height: 8),
          Semantics(
            button: true,
            label: 'Try gaze control now',
            child: FilledButton.icon(
              onPressed: () => context.push('/gaze-control'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Try it now'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 24),
          const _SectionHeader('Hands-free navigation'),
          const _NavScopeHint(),
          _NavScopeOption(
            icon: Icons.space_dashboard_outlined,
            title: 'Bottom nav only',
            subtitle: 'The head D-pad moves the highlight across the bottom '
                'tabs. Blink (or look up) to open.',
            selected: settings.navScope == GazeNavScope.bottomNav,
            onTap: () => notifier.setNavScope(GazeNavScope.bottomNav),
          ),
          _NavScopeOption(
            icon: Icons.grid_view_rounded,
            title: 'Bottom nav + feature tiles',
            subtitle: 'Also reach the feature tiles on Home, Cards, Games, '
                'Stories & Progress: look ◀ ▶ across a row, ▲ ▼ between rows, '
                'and blink to open.',
            selected: settings.navHomeTiles,
            onTap: () =>
                notifier.setNavScope(GazeNavScope.bottomNavAndHomeTiles),
          ),

          const SizedBox(height: 24),
          const _SectionHeader('Voice'),
          SwitchListTile.adaptive(
            value: settings.voiceCommands,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.mic_rounded),
            title: const Text('Voice commands'),
            subtitle: const Text(
                'Say "next", "back", "flip", "scroll down"… alongside gaze.'),
            onChanged: notifier.setVoiceCommands,
          ),

          const SizedBox(height: 24),
          const _SectionHeader('Tuning'),

          _SliderTile(
            icon: Icons.speed_rounded,
            title: 'Sensitivity',
            valueLabel: _sensitivityLabel(settings.sensitivity),
            value: settings.sensitivity.toDouble(),
            min: GazeSettings.minSensitivity.toDouble(),
            max: GazeSettings.maxSensitivity.toDouble(),
            divisions: GazeSettings.maxSensitivity - GazeSettings.minSensitivity,
            onChanged: (v) => notifier.setSensitivity(v.round()),
            help: 'Higher = a smaller head movement selects.',
          ),

          _SliderTile(
            icon: Icons.timer_rounded,
            title: 'Hold time',
            valueLabel: '${(settings.dwellMs / 1000).toStringAsFixed(1)}s',
            value: settings.dwellMs.toDouble(),
            min: GazeSettings.minDwellMs.toDouble(),
            max: GazeSettings.maxDwellMs.toDouble(),
            divisions: (GazeSettings.maxDwellMs - GazeSettings.minDwellMs) ~/ 100,
            onChanged: (v) => notifier.setDwellMs((v / 100).round() * 100),
            help: 'How long to look at a button before it activates.',
          ),

          SwitchListTile.adaptive(
            value: settings.blinkEnabled,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.visibility_off_rounded),
            title: const Text('Blink to confirm'),
            subtitle: const Text('A long, deliberate blink acts as "select"'),
            onChanged: notifier.setBlinkEnabled,
          ),

          const SizedBox(height: 24),
          const _SectionHeader('Scanning (no head movement)'),

          SwitchListTile.adaptive(
            value: settings.scanMode,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.repeat_rounded),
            title: const Text('Scanning mode'),
            subtitle: const Text(
                'Buttons highlight one by one — blink to pick. For learners '
                'who can\'t move their head.'),
            onChanged: notifier.setScanMode,
          ),
          if (settings.scanMode)
            _SliderTile(
              icon: Icons.timelapse_rounded,
              title: 'Scan speed',
              valueLabel: '${(settings.scanStepMs / 1000).toStringAsFixed(1)}s',
              value: settings.scanStepMs.toDouble(),
              min: GazeSettings.minScanStepMs.toDouble(),
              max: GazeSettings.maxScanStepMs.toDouble(),
              divisions:
                  (GazeSettings.maxScanStepMs - GazeSettings.minScanStepMs) ~/ 250,
              onChanged: (v) => notifier.setScanStepMs((v / 250).round() * 250),
              help: 'How long each button stays highlighted before moving on.',
            ),

          const SizedBox(height: 24),
          const _SectionHeader('Device calibration'),
          const _CalibrationHint(),

          SwitchListTile.adaptive(
            value: settings.mirrorHorizontal,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.swap_horiz_rounded),
            title: const Text('Mirror left / right'),
            subtitle: const Text('Turn off if Left and Right feel swapped'),
            onChanged: notifier.setMirrorHorizontal,
          ),

          SwitchListTile.adaptive(
            value: settings.invertVertical,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.swap_vert_rounded),
            title: const Text('Invert up / down'),
            subtitle: const Text('Turn on if Up and Down feel swapped'),
            onChanged: notifier.setInvertVertical,
          ),
        ],
      ),
    );
  }

  static String _sensitivityLabel(int s) {
    switch (s) {
      case 1:
        return 'Lowest';
      case 2:
        return 'Low';
      case 3:
        return 'Balanced';
      case 4:
        return 'High';
      default:
        return 'Highest';
    }
  }

}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Text(
        'Control the app hands-free. Move your head toward a button and hold '
        'briefly to choose it, or blink to confirm. Everything runs on this '
        'device — no internet needed.',
        style: TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
      ),
    );
  }
}

class _NavScopeHint extends StatelessWidget {
  const _NavScopeHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        'Choose how far the hands-free D-pad reaches. Either way it stays off '
        'until "Enable Gaze Control" is on, and touch always works.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }
}

/// A single, full-width, text-wrapping choice for the D-pad reach. Vertical
/// (not a SegmentedButton) so the descriptive labels can never overflow on a
/// narrow phone at a large font scale — and roomier for PWD readability.
class _NavScopeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _NavScopeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Material(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(icon,
                                size: 18, color: AppColors.primaryDark),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalibrationHint extends StatelessWidget {
  const _CalibrationHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        'These fix a device where the directions feel reversed. Tap "Try it '
        'now" above, and if a movement picks the wrong side, toggle the '
        'matching switch.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String help;

  const _SliderTile({
    required this.icon,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.help,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryDark, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(valueLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, bottom: 4),
            child: Text(help,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
