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
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

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
      appBar: AppBar(title: Text(_t(context).gpTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _StatusCard(connected: status.connected, name: status.name),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: _t(context).gpPractise,
            child: FilledButton.icon(
              onPressed: () => context.push('/gamepad-practice'),
              icon: const Icon(Icons.school_rounded),
              label: Text(_t(context).gpPractiseButtons),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t(context).gpPractiseHelp,
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
            title: Text(
              _t(context).gpEnable,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              settings.enabled
                  ? _t(context).gpEnabledOn
                  : _t(context).gpEnabledOff,
            ),
            onChanged: notifier.setEnabled,
          ),

          const SizedBox(height: 20),
          _SectionHeader(_t(context).gpSpeech),
          SwitchListTile.adaptive(
            value: settings.speak,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.record_voice_over_rounded),
            title: Text(_t(context).gpSay),
            subtitle: Text(
              _t(context).gpSayHelp,
            ),
            onChanged: notifier.setSpeak,
          ),
          _SliderTile(
            icon: Icons.speed_rounded,
            title: _t(context).gpSpeed,
            valueLabel: _speedLabel(_t(context), appSettings.ttsSpeed),
            value: appSettings.ttsSpeed,
            min: 0.2,
            max: 1.0,
            // One stop per named level. Sixteen divisions across five names
            // meant three presses in a row could all announce "Slow", which
            // to a learner driving by ear reads as a dead control.
            divisions: 4,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).updateTtsSpeed(v),
            help: _t(context).gpSpeedHelp,
          ),
          SwitchListTile.adaptive(
            value: settings.announceItems,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.format_list_numbered_rounded),
            title: Text(_t(context).gpReadItem),
            subtitle: Text(
              _t(context).gpReadItemHelp,
            ),
            onChanged: settings.speak ? notifier.setAnnounceItems : null,
          ),

          const SizedBox(height: 20),
          _SectionHeader(_t(context).gpMoving),
          SwitchListTile.adaptive(
            value: settings.confirmSectionChange,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.help_outline_rounded),
            title: Text(_t(context).gpAsk),
            subtitle: Text(
              _t(context).gpAskHelp,
            ),
            onChanged: notifier.setConfirmSectionChange,
          ),

          const SizedBox(height: 20),
          _SectionHeader(_t(context).gpComfort),
          SwitchListTile.adaptive(
            value: settings.vibrate,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.vibration_rounded),
            title: Text(_t(context).gpVibrate),
            subtitle: Text(
              _t(context).gpVibrateHelp,
            ),
            onChanged: notifier.setVibrate,
          ),
          _SliderTile(
            icon: Icons.touch_app_rounded,
            title: _t(context).gpDedupe,
            valueLabel: _t(context).gpMs(settings.dedupeMs),
            value: settings.dedupeMs.toDouble(),
            min: GamepadSettings.minDedupeMs.toDouble(),
            max: GamepadSettings.maxDedupeMs.toDouble(),
            divisions:
                (GamepadSettings.maxDedupeMs - GamepadSettings.minDedupeMs) ~/ 20,
            onChanged: (v) => notifier.setDedupeMs((v / 20).round() * 20),
            help: _t(context).gpDedupeHelp,
          ),
          SwitchListTile.adaptive(
            value: settings.holdToRepeat,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.repeat_rounded),
            title: Text(_t(context).gpHold),
            subtitle: Text(
              _t(context).gpHoldHelp,
            ),
            onChanged: notifier.setHoldToRepeat,
          ),
          if (settings.holdToRepeat) ...[
            _SliderTile(
              icon: Icons.hourglass_top_rounded,
              title: _t(context).gpWait,
              valueLabel: _t(context).gpMs(settings.repeatDelayMs),
              value: settings.repeatDelayMs.toDouble(),
              min: GamepadSettings.minRepeatDelayMs.toDouble(),
              max: GamepadSettings.maxRepeatDelayMs.toDouble(),
              divisions: (GamepadSettings.maxRepeatDelayMs -
                      GamepadSettings.minRepeatDelayMs) ~/
                  100,
              onChanged: (v) =>
                  notifier.setRepeatDelayMs((v / 100).round() * 100),
              help: _t(context).gpWaitHelp,
            ),
            _SliderTile(
              icon: Icons.timer_rounded,
              title: _t(context).gpRepeat,
              valueLabel: _t(context).gpMs(settings.repeatRateMs),
              value: settings.repeatRateMs.toDouble(),
              min: GamepadSettings.minRepeatRateMs.toDouble(),
              max: GamepadSettings.maxRepeatRateMs.toDouble(),
              divisions: (GamepadSettings.maxRepeatRateMs -
                      GamepadSettings.minRepeatRateMs) ~/
                  50,
              onChanged: (v) => notifier.setRepeatRateMs((v / 50).round() * 50),
              help: _t(context).gpRepeatHelp,
            ),
          ],
          SwitchListTile.adaptive(
            value: settings.swapConfirmButtons,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.swap_horiz_rounded),
            title: Text(_t(context).gpSwap),
            subtitle: Text(
              _t(context).gpSwapHelp,
            ),
            onChanged: notifier.setSwapConfirmButtons,
          ),

          const SizedBox(height: 28),
          _SectionHeader(_t(context).gpGuide),
          const SizedBox(height: 8),
          const GamepadGuide(),
          const SizedBox(height: 16),
          Text(
            _t(context).gpGuideHelp,
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
String _speedLabel(AppLocalizations t, double v) {
  if (v <= 0.3) return t.gpVerySlow;
  if (v <= 0.5) return t.vgSlow;
  if (v <= 0.7) return t.vgNormal;
  if (v <= 0.9) return t.vgFast;
  return t.gpVeryFast;
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
          ? _t(context).gpConnectedTo(name ?? 'Gamepad')
          : _t(context).gpNoController,
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
                    connected ? _t(context).gpConnected : _t(context).gpNone,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    connected
                        ? (name ?? 'Gamepad')
                        : _t(context).gpPair,
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
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: HCColor.of(context).readable(AppColors.primaryDark),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: HCColor.of(context).primary,
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

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
