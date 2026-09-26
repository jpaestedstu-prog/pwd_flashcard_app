import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../models/gaze_settings.dart';
import '../providers/gaze_settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

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
        title: Text(_t(context).gzsTitle),
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
            title: Text(_t(context).gzsEnable,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(settings.enabled
                ? _t(context).gzsOn
                : _t(context).gpEnabledOff),
            onChanged: notifier.setEnabled,
          ),

          const SizedBox(height: 8),
          Semantics(
            button: true,
            label: _t(context).gzsTryNow,
            child: FilledButton.icon(
              onPressed: () => context.push('/gaze-control'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(_t(context).gzsTryIt),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                
              ),
            ),
          ),

          const SizedBox(height: 24),
          _SectionHeader(_t(context).gzsHandsFree),
          const _NavScopeHint(),
          _NavScopeOption(
            icon: Icons.space_dashboard_outlined,
            title: _t(context).gzsNavOnly,
            subtitle: _t(context).gzsNavOnlySub,
            selected: settings.navScope == GazeNavScope.bottomNav,
            onTap: () => notifier.setNavScope(GazeNavScope.bottomNav),
          ),
          _NavScopeOption(
            icon: Icons.grid_view_rounded,
            title: _t(context).gzsNavTiles,
            subtitle: _t(context).gzsNavTilesSub,
            selected: settings.navHomeTiles,
            onTap: () =>
                notifier.setNavScope(GazeNavScope.bottomNavAndHomeTiles),
          ),

          const SizedBox(height: 24),
          _SectionHeader(_t(context).gzsVoice),
          SwitchListTile.adaptive(
            value: settings.voiceCommands,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.mic_rounded),
            title: Text(_t(context).gzsVoiceCommands),
            subtitle: Text(_t(context).gzsVoiceSub),
            onChanged: notifier.setVoiceCommands,
          ),

          const SizedBox(height: 24),
          _SectionHeader(_t(context).gzsTuning),

          _SliderTile(
            icon: Icons.speed_rounded,
            title: _t(context).gzsSensitivity,
            valueLabel: _sensitivityLabel(_t(context), settings.sensitivity),
            value: settings.sensitivity.toDouble(),
            min: GazeSettings.minSensitivity.toDouble(),
            max: GazeSettings.maxSensitivity.toDouble(),
            divisions: GazeSettings.maxSensitivity - GazeSettings.minSensitivity,
            onChanged: (v) => notifier.setSensitivity(v.round()),
            help: _t(context).gzsSensitivityHelp,
          ),

          _SliderTile(
            icon: Icons.timer_rounded,
            title: _t(context).gzsHold,
            valueLabel: _t(context).gzsSeconds((settings.dwellMs / 1000).toStringAsFixed(1)),
            value: settings.dwellMs.toDouble(),
            min: GazeSettings.minDwellMs.toDouble(),
            max: GazeSettings.maxDwellMs.toDouble(),
            divisions: (GazeSettings.maxDwellMs - GazeSettings.minDwellMs) ~/ 100,
            onChanged: (v) => notifier.setDwellMs((v / 100).round() * 100),
            help: _t(context).gzsHoldHelp,
          ),

          SwitchListTile.adaptive(
            value: settings.blinkEnabled,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.visibility_off_rounded),
            title: Text(_t(context).gzsBlink),
            subtitle: Text(_t(context).gzsBlinkSub),
            onChanged: notifier.setBlinkEnabled,
          ),

          const SizedBox(height: 24),
          _SectionHeader(_t(context).gzsScanning),

          SwitchListTile.adaptive(
            value: settings.scanMode,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.repeat_rounded),
            title: Text(_t(context).gzsScanMode),
            subtitle: Text(_t(context).gzsScanSub),
            onChanged: notifier.setScanMode,
          ),
          if (settings.scanMode)
            _SliderTile(
              icon: Icons.timelapse_rounded,
              title: _t(context).gzsScanSpeed,
              valueLabel: _t(context).gzsSeconds((settings.scanStepMs / 1000).toStringAsFixed(1)),
              value: settings.scanStepMs.toDouble(),
              min: GazeSettings.minScanStepMs.toDouble(),
              max: GazeSettings.maxScanStepMs.toDouble(),
              divisions:
                  (GazeSettings.maxScanStepMs - GazeSettings.minScanStepMs) ~/ 250,
              onChanged: (v) => notifier.setScanStepMs((v / 250).round() * 250),
              help: _t(context).gzsScanHelp,
            ),

          const SizedBox(height: 24),
          _SectionHeader(_t(context).gzsCalibration),
          const _CalibrationHint(),

          SwitchListTile.adaptive(
            value: settings.mirrorHorizontal,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.swap_horiz_rounded),
            title: Text(_t(context).gzsMirror),
            subtitle: Text(_t(context).gzsMirrorSub),
            onChanged: notifier.setMirrorHorizontal,
          ),

          SwitchListTile.adaptive(
            value: settings.invertVertical,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.swap_vert_rounded),
            title: Text(_t(context).gzsInvert),
            subtitle: Text(_t(context).gzsInvertSub),
            onChanged: notifier.setInvertVertical,
          ),
        ],
      ),
    );
  }

  static String _sensitivityLabel(AppLocalizations t, int s) {
    switch (s) {
      case 1:
        return t.gzsLowest;
      case 2:
        return t.gzsLow;
      case 3:
        return t.gzsBalanced;
      case 4:
        return t.gzsHigh;
      default:
        return t.gzsHighest;
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
        // Deepened just enough for the white words on it.
        gradient: LinearGradient(
          colors: [
            HCColor.of(context).fillFor(AppColors.primaryDark),
            HCColor.of(context).fillFor(AppColors.primary),
          ],
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
      child: Text(
        _t(context).gzsIntro,
        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
      ),
    );
  }
}

class _NavScopeHint extends StatelessWidget {
  const _NavScopeHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        _t(context).gzsScopeHint,
        style: TextStyle(color: HCColor.of(context).textSecondary, fontSize: 13),
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
                        ? HCColor.of(context).primary
                        : HCColor.of(context).textSecondary,
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
                                size: 18, color: HCColor.of(context).readable(AppColors.primaryDark)),
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
                          style: TextStyle(
                              color: HCColor.of(context).textSecondary, fontSize: 13),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        _t(context).gzsCalibrationHint,
        style: TextStyle(color: HCColor.of(context).textSecondary, fontSize: 13),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: HCColor.of(context).readable(AppColors.primaryDark), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(valueLabel,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: HCColor.of(context).readable(
                        AppColors.primaryDark,
                      ))),
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
                style: TextStyle(
                    color: HCColor.of(context).textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
