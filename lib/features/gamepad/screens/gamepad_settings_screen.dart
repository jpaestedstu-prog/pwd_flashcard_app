import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/app_providers.dart' show settingsProvider;
import '../logic/gamepad_speech.dart';
import '../models/gamepad_settings.dart';
import '../providers/gamepad_settings_provider.dart';
import '../providers/gamepad_status_provider.dart';
import '../widgets/gamepad_guide.dart';

/// Configuration screen for Bluetooth gamepad control, plus the on-screen copy
/// of the button guide.
///
/// The guide is duplicated here on purpose. Select speaks it, which is what a
/// blind learner needs — but a teacher setting the tablet up for that learner
/// needs to *read* it, and asking them to press buttons on a paired controller
/// to discover the mapping would be a poor substitute for a page they can scan.
class GamepadSettingsScreen extends ConsumerWidget {
  const GamepadSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(gamepadSettingsProvider);
    final notifier = ref.read(gamepadSettingsProvider.notifier);
    final status = ref.watch(gamepadStatusProvider);
    final appSettings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('🎮  Game Controller')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _StatusCard(connected: status.connected, name: status.name),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Practise the controller',
            child: FilledButton.icon(
              onPressed: () => context.push('/gamepad-practice'),
              icon: const Icon(Icons.school_rounded),
              label: const Text('Practise the buttons'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Press anything and hear what it does. Nothing in the app moves '
            'while practising.',
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).hintColor,
            ),
          ),
          const SizedBox(height: 16),

          SwitchListTile.adaptive(
            value: settings.enabled,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.sports_esports_rounded),
            title: const Text(
              'Enable controller',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              settings.enabled
                  ? 'A paired controller can drive the app'
                  : 'Off — touch only',
            ),
            onChanged: notifier.setEnabled,
          ),

          const SizedBox(height: 20),
          const _SectionHeader('Speech'),
          SwitchListTile.adaptive(
            value: settings.speak,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.record_voice_over_rounded),
            title: const Text('Say what is happening'),
            subtitle: const Text(
              'Announces each section, each item and every question. Leave this '
              'on for a learner who cannot see the screen.',
            ),
            onChanged: notifier.setSpeak,
          ),
          _SliderTile(
            icon: Icons.speed_rounded,
            title: 'Speech speed',
            valueLabel: _speedLabel(appSettings.ttsSpeed),
            value: appSettings.ttsSpeed,
            min: 0.2,
            max: 1.0,
            // One stop per named level. Sixteen divisions across five names
            // meant three presses in a row could all announce "Slow", which
            // to a learner driving by ear reads as a dead control.
            divisions: 4,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).updateTtsSpeed(v),
            help: 'Experienced listeners often want this faster than it '
                'starts. It sets the speaking speed for the whole app, so '
                'stories and vocabulary read at the same pace.',
          ),
          SwitchListTile.adaptive(
            value: settings.announceItems,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.format_list_numbered_rounded),
            title: const Text('Read each item'),
            subtitle: const Text(
              'Says the name and position — “Games, 3 of 8” — as the cursor '
              'lands on it.',
            ),
            onChanged: settings.speak ? notifier.setAnnounceItems : null,
          ),

          const SizedBox(height: 20),
          const _SectionHeader('Moving between sections'),
          SwitchListTile.adaptive(
            value: settings.confirmSectionChange,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.help_outline_rounded),
            title: const Text('Ask before switching'),
            subtitle: const Text(
              'Left and right ask “Do you want to go to the Cards section?” — '
              'A for yes, B for no. Turn off to switch straight away.',
            ),
            onChanged: notifier.setConfirmSectionChange,
          ),

          const SizedBox(height: 20),
          const _SectionHeader('Comfort'),
          SwitchListTile.adaptive(
            value: settings.vibrate,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.vibration_rounded),
            title: const Text('Vibrate on each press'),
            subtitle: const Text(
              'A silent confirmation that the press registered, even while a '
              'previous sentence is still finishing.',
            ),
            onChanged: notifier.setVibrate,
          ),
          _SliderTile(
            icon: Icons.touch_app_rounded,
            title: 'Ignore repeat presses within',
            valueLabel: '${settings.dedupeMs} ms',
            value: settings.dedupeMs.toDouble(),
            min: GamepadSettings.minDedupeMs.toDouble(),
            max: GamepadSettings.maxDedupeMs.toDouble(),
            divisions:
                (GamepadSettings.maxDedupeMs - GamepadSettings.minDedupeMs) ~/ 20,
            onChanged: (v) => notifier.setDedupeMs((v / 20).round() * 20),
            help: 'Raise this for a learner whose grip produces extra presses. '
                'Lower it if deliberate quick presses are being missed.',
          ),
          SwitchListTile.adaptive(
            value: settings.holdToRepeat,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.repeat_rounded),
            title: const Text('Hold to keep moving'),
            subtitle: const Text(
              'Holding up or down keeps stepping through items, instead of one '
              'press per step. Opening, going back and switching section never '
              'repeat.',
            ),
            onChanged: notifier.setHoldToRepeat,
          ),
          if (settings.holdToRepeat) ...[
            _SliderTile(
              icon: Icons.hourglass_top_rounded,
              title: 'Wait before repeating',
              valueLabel: '${settings.repeatDelayMs} ms',
              value: settings.repeatDelayMs.toDouble(),
              min: GamepadSettings.minRepeatDelayMs.toDouble(),
              max: GamepadSettings.maxRepeatDelayMs.toDouble(),
              divisions: (GamepadSettings.maxRepeatDelayMs -
                      GamepadSettings.minRepeatDelayMs) ~/
                  100,
              onChanged: (v) =>
                  notifier.setRepeatDelayMs((v / 100).round() * 100),
              help: 'Long enough that an ordinary press never starts a repeat.',
            ),
            _SliderTile(
              icon: Icons.timer_rounded,
              title: 'Repeat every',
              valueLabel: '${settings.repeatRateMs} ms',
              value: settings.repeatRateMs.toDouble(),
              min: GamepadSettings.minRepeatRateMs.toDouble(),
              max: GamepadSettings.maxRepeatRateMs.toDouble(),
              divisions: (GamepadSettings.maxRepeatRateMs -
                      GamepadSettings.minRepeatRateMs) ~/
                  50,
              onChanged: (v) => notifier.setRepeatRateMs((v / 50).round() * 50),
              help: 'Slow enough that each item is still announced in full.',
            ),
          ],
          SwitchListTile.adaptive(
            value: settings.swapConfirmButtons,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.swap_horiz_rounded),
            title: const Text('Swap A and B'),
            subtitle: const Text(
              'Only if “yes” and “no” come out backwards — some controllers '
              'label the bottom button B rather than A.',
            ),
            onChanged: notifier.setSwapConfirmButtons,
          ),

          const SizedBox(height: 28),
          const _SectionHeader('Button guide'),
          const SizedBox(height: 8),
          const GamepadGuide(),
          const SizedBox(height: 16),
          Text(
            'The learner can hear this list at any time by pressing Select.',
            style: TextStyle(
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).hintColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Turns the raw 0.2 - 1.0 rate into words. A number means nothing to a
/// teacher deciding whether a learner needs it slower.
/// Five names across the slider's five stops, so every press changes what is
/// announced — the thing that tells a learner their press registered.
String _speedLabel(double v) {
  if (v <= 0.3) return 'Very slow';
  if (v <= 0.5) return 'Slow';
  if (v <= 0.7) return 'Normal';
  if (v <= 0.9) return 'Fast';
  return 'Very fast';
}

class _StatusCard extends StatelessWidget {
  final bool connected;
  final String? name;

  const _StatusCard({required this.connected, this.name});

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.primary : Theme.of(context).hintColor;
    return Semantics(
      liveRegion: true,
      label: connected
          ? 'Controller connected: ${name ?? "Gamepad"}'
          : 'No controller connected',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(
              connected
                  ? Icons.bluetooth_connected_rounded
                  : Icons.bluetooth_disabled_rounded,
              color: color,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connected ? 'Controller connected' : 'No controller',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    connected
                        ? (name ?? 'Gamepad')
                        : 'Pair one in Android Settings → Bluetooth, then come '
                            'back here.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    // One label for the whole row, carried on the control itself: focus lands
    // inside the Slider, far below anything wrapping the row, so a label put
    // further out would never be found.
    return Semantics(
      container: true,
      label: '$title. $valueLabel',
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primaryDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                valueLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppColors.primary,
            label: valueLabel,
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30, bottom: 4),
            child: Text(
              help,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Exposed so the guide widget and the spoken guide can be checked against each
/// other in tests — the two must never drift apart.
const int kSpokenGuideItemCap = GamepadPhrases.maxSpokenItems;
