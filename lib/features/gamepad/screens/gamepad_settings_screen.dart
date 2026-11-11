import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fit_text.dart';
import '../../../data/models/models.dart' show AppSettings;
import '../../../providers/app_providers.dart'
    show appSettingsForProfileProvider, settingsProvider;
import '../logic/gamepad_speech.dart';
import '../models/gamepad_settings.dart';
import '../providers/gamepad_settings_provider.dart';
import '../providers/gamepad_status_provider.dart';
import '../services/gamepad_service.dart';
import '../widgets/gamepad_guide.dart';
import '../widgets/gaze_uses_controller_notice.dart';
import '../../../widgets/android_app_notice.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../navigation/dpad_keys.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../core/utils/platform_caps.dart';

/// Configuration screen for Bluetooth gamepad control, plus the on-screen copy
/// of the button guide.
///
/// The guide is duplicated here on purpose. Select speaks it, which is what a
/// blind learner needs — but a teacher setting the tablet up for that learner
/// needs to *read* it, and asking them to press buttons on a paired controller
/// to discover the mapping would be a poor substitute for a page they can scan.
///
/// With a [profileId] it edits **that learner's** settings instead of the
/// signed-in profile's — a Teacher or Parent setting a learner up from the
/// learner's card, as Gaze Control does. It used to edit only the signed-in
/// profile's, so a teacher "tuning the controller for a learner" changed their
/// own settings, which never reached the learner.
class GamepadSettingsScreen extends ConsumerWidget {
  const GamepadSettingsScreen({super.key, this.profileId, this.learnerName});

  /// The learner being set up by their teacher or parent; null edits the
  /// signed-in profile.
  final String? profileId;

  /// That learner's name, for the heading.
  final String? learnerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = profileId;
    final GamepadSettings settings;
    final GamepadSettingsEditing notifier;
    final AppSettings appSettings;
    final void Function(double) setSpeed;
    if (id == null) {
      settings = ref.watch(gamepadSettingsProvider);
      notifier = ref.read(gamepadSettingsProvider.notifier);
      appSettings = ref.watch(settingsProvider);
      setSpeed = ref.read(settingsProvider.notifier).updateTtsSpeed;
    } else {
      settings = ref.watch(gamepadSettingsForProfileProvider(id));
      notifier = ref.read(gamepadSettingsForProfileProvider(id).notifier);
      appSettings = ref.watch(appSettingsForProfileProvider(id));
      setSpeed = (v) => ref
          .read(appSettingsForProfileProvider(id).notifier)
          .update(
            ref.read(appSettingsForProfileProvider(id)).copyWith(ttsSpeed: v),
          );
    }
    final name = learnerName ?? '';
    final status = ref.watch(gamepadStatusProvider);

    // No controller to read here (a browser without the Gamepad API): only
    // voice navigation can open this screen, and it should say why nothing on
    // it would work.
    if (!GamepadService.isSupported) {
      return Scaffold(
        appBar: AppBar(title: AppBarTitle(_t(context).gpTitle)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            AndroidAppNotice(message: _t(context).webControllerNeedsApp),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: AppBarTitle(_t(context).gpTitle)),
      body: ListView(
        // Rows come and go here: no row may stay "alive" in a place another
        // has taken (see found_by_pressing_test: Scan Mode).
        addAutomaticKeepAlives: false,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (id != null) ...[
            _LearnerBanner(name: name),
            const SizedBox(height: 12),
          ],
          _StatusCard(connected: status.connected, name: status.name),
          const SizedBox(height: 12),
          GazeUsesControllerNotice(profileId: id),
          // Practising drives the pad with the settings of whoever is at the
          // tablet — the Teacher or Parent here, whose own profile has no
          // controller input. So a grown-up setting a learner up is told how
          // the learner practises instead of being sent to a dead screen.
          if (id == null) ...[
            FilledButton.icon(
              onPressed: () => context.push('/gamepad-practice'),
              icon: const Icon(Icons.school_rounded),
              // The spoken name on the button's own node, with its press and
              // focus (a Semantics around it was a second, dead "button").
              label: Semantics(
                label: _t(context).gpPractise,
                excludeSemantics: true,
                child: Text(_t(context).gpPractiseButtons),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
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
          ] else
            Text(
              _t(context).gpPractiseAsLearner(name),
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
            valueText: (v) => _speedLabel(_t(context), v),
            value: appSettings.ttsSpeed,
            min: 0.2,
            max: 1.0,
            // One stop per named level. Sixteen divisions across five names
            // meant three presses in a row could all announce "Slow", which
            // to a learner driving by ear reads as a dead control.
            divisions: 4,
            onChanged: setSpeed,
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
          // The one control that shares a job on purpose — and the one a
          // learner with an unsteady hand most often knocks, so it can go.
          SwitchListTile.adaptive(
            value: settings.leftStickMoves,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.gamepad_rounded),
            title: Text(_t(context).gpLeftStick),
            subtitle: Text(
              _t(context).gpLeftStickHelp,
            ),
            onChanged: notifier.setLeftStickMoves,
          ),
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
            // "kumpirmasyon" broke in two at 2x in Filipino.
            subtitle: Text(
              _t(context).gpVibrateHelp,
              style: TextStyle(
                fontSize: fittedStyle(
                  context,
                  _t(context).gpVibrateHelp,
                  Theme.of(context).textTheme.bodyMedium,
                )?.fontSize,
              ),
            ),
            onChanged: notifier.setVibrate,
          ),
          _SliderTile(
            icon: Icons.touch_app_rounded,
            title: _t(context).gpDedupe,
            valueText: (v) => _t(context).gpMs((v / 20).round() * 20),
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
              valueText: (v) => _t(context).gpMs((v / 100).round() * 100),
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
              valueText: (v) => _t(context).gpMs((v / 50).round() * 50),
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

/// "Game Controller for Ana" — says whose settings a Teacher or Parent is
/// changing, as Gaze Control's learner page does.
class _LearnerBanner extends StatelessWidget {
  const _LearnerBanner({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    final hc = HCColor.of(context);
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hc.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hc.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.person_rounded, color: hc.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.gpForLearner(name),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.gpForLearnerNote(name),
                    style: TextStyle(color: hc.textSecondary, fontSize: 13),
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

/// How to get a controller seen. A browser shows a page a controller only
/// once one of its buttons is pressed, so there the hint says to press one.
String _pairHint(BuildContext context) =>
    PlatformCaps.isWeb ? _t(context).gpPairBrowser : _t(context).gpPair;

class _StatusCard extends StatelessWidget {
  final bool connected;
  final String? name;

  const _StatusCard({required this.connected, this.name});

  @override
  Widget build(BuildContext context) {
    final color = connected ? HCColor.of(context).primary : Theme.of(context).hintColor;
    return Semantics(
      liveRegion: true,
      // Its texts are the label's own words: "No controller connected" was
      // followed by "No controller" and the pairing hint again.
      excludeSemantics: true,
      label: connected
          ? _t(context).gpConnectedTo(name ?? 'Gamepad')
          : '${_t(context).gpNoController}. ${_pairHint(context)}',
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
                        : _pairHint(context),
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
      child: Semantics(
        container: true,
        header: true,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: HCColor.of(context).readable(AppColors.primaryDark),
          ),
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  /// The value as it is shown and said, for any position — a screen reader
  /// is told the one the slider moves to before the row rebuilds.
  final String Function(double value) valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String help;

  const _SliderTile({
    required this.icon,
    required this.title,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.help,
  });

  @override
  Widget build(BuildContext context) {
    final valueLabel = valueText(value);
    // The slider is the row's stop: named by the title, its value from
    // [valueText] (see [DpadSliderScope.name]). The controller reads both
    // from the slider too, so its voice says "Speech speed. Slow" as before.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Said by the slider below.
          ExcludeSemantics(child: Row(
            children: [
              Icon(icon, size: 20, color: HCColor.of(context).readable(AppColors.primaryDark)),
              const SizedBox(width: 10),
              // FitText: "pananalita" broke in two at 2x in Filipino. Every
              // line it needs: "Huwag pansinin ang umuulit na pindot sa loob
              // ng" lost its end in two (a phone, largest Font Size, 3 Nov).
              Expanded(
                child: FitText(
                  title,
                  maxLines: null,
                  style: DefaultTextStyle.of(context)
                      .style
                      .copyWith(fontWeight: FontWeight.w600),
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
          )),
          DpadSliderScope(
            name: title,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              activeColor: AppColors.primary,
              semanticFormatterCallback: valueText,
              onChanged: onChanged,
            ),
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
