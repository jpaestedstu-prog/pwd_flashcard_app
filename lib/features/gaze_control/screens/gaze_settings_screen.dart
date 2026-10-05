import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/app_providers.dart' show profileProvider;
import '../../gamepad/providers/gamepad_settings_provider.dart';
import '../models/gaze_settings.dart';
import '../providers/gaze_settings_provider.dart';
import '../services/gaze_metrics.dart';
import '../services/gaze_switch_input.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Configuration + launch screen for the Gaze (head + blink) accessibility
/// control. Persists to [GazeSettings] and offers a "Try it now" button into
/// the live preview ([/gaze-control]).
///
/// With a [profileId] it edits **that learner's** settings instead of the
/// signed-in profile's: a teacher or parent setting a learner up from their
/// own profile (Children have no Settings of their own, and a learner who
/// needs gaze is the one least able to tune it themselves).
class GazeSettingsScreen extends ConsumerWidget {
  const GazeSettingsScreen({super.key, this.profileId, this.learnerName});

  /// The learner being set up by their teacher or parent; null edits the
  /// signed-in profile.
  final String? profileId;

  /// That learner's name, for the heading.
  final String? learnerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = _t(context);
    final id = profileId;
    final GazeSettings settings;
    final GazeSettingsEditing notifier;
    if (id == null) {
      settings = ref.watch(gazeSettingsProvider);
      notifier = ref.read(gazeSettingsProvider.notifier);
    } else {
      settings = ref.watch(gazeSettingsForProfileProvider(id));
      notifier = ref.read(gazeSettingsForProfileProvider(id).notifier);
    }
    final self = id == null ? _activeProfile(ref) : null;
    final usageId = id ?? self?.id;
    final usageName = id == null ? (self?.name ?? '') : (learnerName ?? '');
    final camera = settings.usesCamera;
    // A learner changing their own Gaze Control while they are using it can
    // switch off the very thing they are using: Gaze Control itself, or the
    // blink when they move picking to a switch they may not have. Those two
    // changes are kept only once confirmed (see [_keepOrUndo]). A teacher or
    // parent setting a learner up uses touch, so their changes just apply.
    final guarded = id == null && settings.enabled;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.gzsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (id != null) ...[
            _LearnerBanner(name: learnerName ?? ''),
            const SizedBox(height: 12),
          ],
          const _IntroCard(),
          const SizedBox(height: 16),

          SwitchListTile.adaptive(
            value: settings.enabled,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            title: Text(t.gzsEnable,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(settings.enabled ? t.gzsOn : t.gpEnabledOff),
            onChanged: (v) => guarded && !v
                ? _keepOrUndo(
                    context,
                    apply: () => notifier.setEnabled(false),
                    undo: () => notifier.setEnabled(true),
                    message: t.gzsKeepOff,
                  )
                : notifier.setEnabled(v),
          ),

          const SizedBox(height: 8),
          Semantics(
            button: true,
            label: t.gzsTryNow,
            child: FilledButton.icon(
              // A grown-up trying a learner's setup practises with the
              // learner's settings, switched on for the practice.
              onPressed: () => context.push(
                '/gaze-control',
                extra: id == null ? null : settings.copyWith(enabled: true),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(t.gzsTryIt),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),

          const SizedBox(height: 24),
          _SectionHeader(t.gzsHandsFree),
          const _NavScopeHint(),
          _ChoiceOption(
            icon: Icons.space_dashboard_outlined,
            title: t.gzsNavOnly,
            subtitle: t.gzsNavOnlySub,
            selected: settings.navScope == GazeNavScope.bottomNav,
            onTap: () => notifier.setNavScope(GazeNavScope.bottomNav),
          ),
          _ChoiceOption(
            icon: Icons.grid_view_rounded,
            title: t.gzsNavTiles,
            subtitle: t.gzsNavTilesSub,
            selected: settings.navHomeTiles,
            onTap: () =>
                notifier.setNavScope(GazeNavScope.bottomNavAndHomeTiles),
          ),

          // ─── What picks ───
          const SizedBox(height: 24),
          _SectionHeader(t.gzsChoose),
          _ChoiceOption(
            icon: Icons.visibility_rounded,
            title: t.gzsPickBlink,
            subtitle: t.gzsPickBlinkSub,
            selected: settings.pickWith == GazePick.blink,
            onTap: () => notifier.setPickWith(GazePick.blink),
          ),
          _ChoiceOption(
            icon: Icons.sports_esports_rounded,
            title: t.gzsPickSwitch,
            subtitle: t.gzsPickSwitchSub,
            selected: settings.pickWith == GazePick.switchButton,
            onTap: () {
              final before = settings.pickWith;
              if (!guarded || before == GazePick.switchButton) {
                notifier.setPickWith(GazePick.switchButton);
                return;
              }
              _keepOrUndo(
                context,
                apply: () => notifier.setPickWith(GazePick.switchButton),
                undo: () => notifier.setPickWith(before),
                message: t.gzsKeepSwitch,
                keepOnSwitch: true,
              );
            },
          ),
          _ChoiceOption(
            icon: Icons.join_inner_rounded,
            title: t.gzsPickEither,
            subtitle: t.gzsPickEitherSub,
            selected: settings.pickWith == GazePick.either,
            onTap: () => notifier.setPickWith(GazePick.either),
          ),
          // Scanning picks with a blink (or the switch), so while it is on the
          // blink switch shows what is really happening (on) and cannot be
          // turned off — the two together used to leave the highlight moving
          // with no way to pick anything. A switch-only learner's blinks never
          // pick, so it is not offered at all.
          if (settings.pickWith != GazePick.switchButton)
            SwitchListTile.adaptive(
              value: settings.blinkSelects,
              activeTrackColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.visibility_off_rounded),
              title: Text(t.gzsBlink),
              subtitle: Text(
                settings.scanMode ? t.gzsBlinkScanOn : t.gzsBlinkSub,
              ),
              onChanged: settings.scanMode ? null : notifier.setBlinkEnabled,
            ),
          // Look and hold: keeping still on a highlight picks it. Scanning
          // never uses it — the highlight moves by itself there, so "still"
          // would pick whatever the scanner happened to reach.
          if (camera)
            SwitchListTile.adaptive(
              value: settings.dwellSelect && !settings.scanMode,
              activeTrackColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.pan_tool_alt_rounded),
              title: Text(t.gzsDwellSelect),
              subtitle: Text(
                settings.scanMode ? t.gzsDwellSelectScan : t.gzsDwellSelectSub,
              ),
              onChanged: settings.scanMode ? null : notifier.setDwellSelect,
            ),
          if (settings.restSelects)
            _SliderTile(
              icon: Icons.hourglass_bottom_rounded,
              title: t.gzsDwellSelectMs,
              valueLabel: t.gzsSeconds(
                (settings.dwellSelectMs / 1000).toStringAsFixed(1),
              ),
              value: settings.dwellSelectMs.toDouble(),
              min: GazeSettings.minDwellSelectMs.toDouble(),
              max: GazeSettings.maxDwellSelectMs.toDouble(),
              divisions: (GazeSettings.maxDwellSelectMs -
                      GazeSettings.minDwellSelectMs) ~/
                  250,
              onChanged: (v) =>
                  notifier.setDwellSelectMs((v / 250).round() * 250),
              help: t.gzsDwellSelectHelp,
            ),

          const SizedBox(height: 24),
          _SectionHeader(t.gzsVoice),
          SwitchListTile.adaptive(
            value: settings.voiceCommands,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.mic_rounded),
            title: Text(t.gzsVoiceCommands),
            subtitle: Text(t.gzsVoiceSub),
            onChanged: notifier.setVoiceCommands,
          ),
          SwitchListTile.adaptive(
            value: settings.speakHighlight,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.record_voice_over_rounded),
            title: Text(t.gzsSpeak),
            subtitle: Text(t.gzsSpeakSub),
            onChanged: notifier.setSpeakHighlight,
          ),

          const SizedBox(height: 24),
          _SectionHeader(t.gzsTuning),
          if (!camera) _Note(t.gzsCameraOff),
          if (camera) ...[
            _SliderTile(
              icon: Icons.speed_rounded,
              title: t.gzsSensitivity,
              valueLabel: _sensitivityLabel(t, settings.sensitivity),
              value: settings.sensitivity.toDouble(),
              min: GazeSettings.minSensitivity.toDouble(),
              max: GazeSettings.maxSensitivity.toDouble(),
              divisions:
                  GazeSettings.maxSensitivity - GazeSettings.minSensitivity,
              onChanged: (v) => notifier.setSensitivity(v.round()),
              help: t.gzsSensitivityHelp,
            ),
            _SliderTile(
              icon: Icons.timer_rounded,
              title: t.gzsHold,
              valueLabel:
                  t.gzsSeconds((settings.dwellMs / 1000).toStringAsFixed(1)),
              value: settings.dwellMs.toDouble(),
              min: GazeSettings.minDwellMs.toDouble(),
              max: GazeSettings.maxDwellMs.toDouble(),
              divisions:
                  (GazeSettings.maxDwellMs - GazeSettings.minDwellMs) ~/ 100,
              onChanged: (v) => notifier.setDwellMs((v / 100).round() * 100),
              help: t.gzsHoldHelp,
            ),
            const SizedBox(height: 8),
            _SubHeader(t.gzsSmoothing),
            _Note(t.gzsSmoothingHelp),
            _ChoiceOption(
              icon: Icons.bolt_rounded,
              title: t.gzsSmoothOff,
              subtitle: t.gzsSmoothOffSub,
              selected: settings.smoothing == GazeSmoothing.off,
              onTap: () => notifier.setSmoothing(GazeSmoothing.off),
            ),
            _ChoiceOption(
              icon: Icons.waves_rounded,
              title: t.gzsSmoothLight,
              subtitle: t.gzsSmoothLightSub,
              selected: settings.smoothing == GazeSmoothing.light,
              onTap: () => notifier.setSmoothing(GazeSmoothing.light),
            ),
            _ChoiceOption(
              icon: Icons.water_rounded,
              title: t.gzsSmoothStrong,
              subtitle: t.gzsSmoothStrongSub,
              selected: settings.smoothing == GazeSmoothing.strong,
              onTap: () => notifier.setSmoothing(GazeSmoothing.strong),
            ),
          ],

          const SizedBox(height: 24),
          _SectionHeader(t.gzsScanning),

          SwitchListTile.adaptive(
            value: settings.scanMode,
            activeTrackColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.repeat_rounded),
            title: Text(t.gzsScanMode),
            subtitle: Text(t.gzsScanSub),
            onChanged: notifier.setScanMode,
          ),
          if (settings.scanMode)
            _SliderTile(
              icon: Icons.timelapse_rounded,
              title: t.gzsScanSpeed,
              valueLabel: t.gzsSeconds(
                (settings.scanStepMs / 1000).toStringAsFixed(1),
              ),
              value: settings.scanStepMs.toDouble(),
              min: GazeSettings.minScanStepMs.toDouble(),
              max: GazeSettings.maxScanStepMs.toDouble(),
              divisions:
                  (GazeSettings.maxScanStepMs - GazeSettings.minScanStepMs) ~/
                      250,
              onChanged: (v) =>
                  notifier.setScanStepMs((v / 250).round() * 250),
              help: t.gzsScanHelp,
            ),

          if (camera) ...[
            const SizedBox(height: 24),
            _SectionHeader(t.gzsCalibration),
            _RestPositionTile(
              settings: settings,
              onSet: () => context.push(
                id == null ? '/gaze-calibrate' : '/gaze-calibrate?profile=$id',
              ),
              onReset: notifier.clearRestPosition,
            ),
            const SizedBox(height: 8),
            const _CalibrationHint(),
            SwitchListTile.adaptive(
              value: settings.mirrorHorizontal,
              activeTrackColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.swap_horiz_rounded),
              title: Text(t.gzsMirror),
              subtitle: Text(t.gzsMirrorSub),
              onChanged: notifier.setMirrorHorizontal,
            ),
            SwitchListTile.adaptive(
              value: settings.invertVertical,
              activeTrackColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.swap_vert_rounded),
              title: Text(t.gzsInvert),
              subtitle: Text(t.gzsInvertSub),
              onChanged: notifier.setInvertVertical,
            ),
          ],

          if (usageId != null) ...[
            const SizedBox(height: 24),
            _SectionHeader(t.gzmTitle),
            _GazeUsageCard(profileId: usageId, learnerName: usageName),
          ],
        ],
      ),
    );
  }

  /// Makes a change that could leave the learner with no way to use the
  /// app, then keeps it only if they confirm it in time — Keep, or any
  /// switch press when [keepOnSwitch] (the change *is* to the switch, so a
  /// learner who really has one keeps it in one press). Otherwise, or on
  /// Undo, it is undone after [_KeepChangeDialog.seconds]: a blink-only
  /// learner who picks "switch" by mistake, or switches gaze off, gets their
  /// gaze back by waiting.
  static Future<void> _keepOrUndo(
    BuildContext context, {
    required VoidCallback apply,
    required VoidCallback undo,
    required String message,
    bool keepOnSwitch = false,
  }) async {
    apply();
    final keep = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _KeepChangeDialog(message: message, keepOnSwitch: keepOnSwitch),
    );
    if (keep != true) undo();
  }

  static ({String id, String name})? _activeProfile(WidgetRef ref) {
    try {
      final p = ref.watch(profileProvider);
      return p == null ? null : (id: p.id, name: p.name);
    } catch (_) {
      return null;
    }
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

/// "Keep this change?", with a countdown that undoes it when it runs out.
class _KeepChangeDialog extends ConsumerStatefulWidget {
  const _KeepChangeDialog({required this.message, this.keepOnSwitch = false});

  /// How long the learner has to confirm.
  static const int seconds = 15;

  final String message;

  /// A switch press counts as Keep.
  final bool keepOnSwitch;

  @override
  ConsumerState<_KeepChangeDialog> createState() => _KeepChangeDialogState();
}

class _KeepChangeDialogState extends ConsumerState<_KeepChangeDialog> {
  int _left = _KeepChangeDialog.seconds;
  Timer? _timer;
  Object? _switch;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left <= 1) {
        _close(false);
      } else if (mounted) {
        setState(() => _left--);
      }
    });
    // The newest attachment receives the presses, so the press is the
    // dialog's alone — it cannot also press whatever the scanner has lit.
    if (widget.keepOnSwitch) {
      _switch = GazeSwitchInput.instance.attach(onPress: () => _close(true));
    }
  }

  void _releaseSwitch() {
    final token = _switch;
    _switch = null;
    if (token == null) return;
    var gamepadOn = false;
    try {
      gamepadOn = ref.read(gamepadSettingsProvider).enabled;
    } catch (_) {}
    GazeSwitchInput.instance.detach(token, gamepadFeatureOn: gamepadOn);
  }

  void _close(bool keep) {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _releaseSwitch();
    if (mounted) Navigator.of(context).pop(keep);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _releaseSwitch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    return AlertDialog(
      // The largest text sizes make the message taller than a phone screen.
      scrollable: true,
      title: Text(t.gzsKeepTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          Text(
            t.gzsKeepCountdown(_left),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _close(false),
          child: Text(t.gzsUndo),
        ),
        FilledButton(
          onPressed: () => _close(true),
          child: Text(t.gzsKeep),
        ),
      ],
    );
  }
}

/// Says whose settings these are when a grown-up opened a learner's.
class _LearnerBanner extends StatelessWidget {
  const _LearnerBanner({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    final hc = HCColor.of(context);
    return Container(
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
                  t.gzsForLearner(name),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.gzsForLearnerNote(name),
                  style: TextStyle(color: hc.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
  Widget build(BuildContext context) => _Note(_t(context).gzsScopeHint);
}

/// A secondary line of explanation under a header.
class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(color: HCColor.of(context).textSecondary, fontSize: 13),
      ),
    );
  }
}

/// A single, full-width, text-wrapping choice (one of a radio group).
/// Vertical (not a SegmentedButton) so the descriptive labels can never
/// overflow on a narrow phone at a large font scale — and roomier for PWD
/// readability.
class _ChoiceOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceOption({
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

/// Where head movements are measured from, and the way to change it.
class _RestPositionTile extends StatelessWidget {
  const _RestPositionTile({
    required this.settings,
    required this.onSet,
    required this.onReset,
  });

  final GazeSettings settings;
  final VoidCallback onSet;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    final hc = HCColor.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.accessibility_new_rounded,
                color: hc.readable(AppColors.primaryDark), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.gzsRest,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    settings.hasRestPosition ? t.gzsRestSet : t.gzsRestNotSet,
                    style: TextStyle(color: hc.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.gzsRestHelp,
                    style: TextStyle(color: hc.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // One above the other, so ▼ reaches both: side by side, a step down
        // from the row above went to whichever sat nearer the middle and
        // skipped the other.
        Padding(
          padding: const EdgeInsets.only(left: 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton.tonalIcon(
                onPressed: onSet,
                icon: const Icon(Icons.my_location_rounded),
                label: Text(t.gzsRestButton),
              ),
              if (settings.hasRestPosition)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: Text(t.gzsRestReset),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The last seven days of gaze use — the measurements a study of Gaze
/// Control reports — with a CSV export of every recorded day.
class _GazeUsageCard extends StatelessWidget {
  const _GazeUsageCard({required this.profileId, required this.learnerName});

  final String profileId;
  final String learnerName;

  Future<void> _export() async {
    final csv = GazeMetrics.instance.csv(profileId, learner: learnerName);
    final dir = await getTemporaryDirectory();
    final date = DateTime.now().toString().split(' ').first;
    final safe = learnerName.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final file = File('${dir.path}/FlashLearn_Gaze_${safe}_$date.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'FlashLearn PWD - Gaze Control use ($learnerName)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    final hc = HCColor.of(context);
    final week = GazeMetrics.instance.total(profileId);
    String fixed(double? v, [int digits = 1]) =>
        v == null ? '—' : v.toStringAsFixed(digits);
    final rows = <(String, String)>[
      (t.gzmActive, t.gzmMinutes((week.activeMs / 60000).round())),
      (t.gzmSelections, '${week.selections}'),
      (t.gzmPerMinute, fixed(week.selectionsPerMinute)),
      (t.gzmSeconds, fixed(week.avgSecondsToSelect)),
      (
        t.gzmMistakes,
        week.misSelectionRate == null
            ? '—'
            : '${(week.misSelectionRate! * 100).round()}%',
      ),
      if (week.keyboardKeys > 0) (t.gzmKeys, '${week.keyboardKeys}'),
      if (week.calibrations > 0) (t.gzmCalibrations, '${week.calibrations}'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hc.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hc.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (week.isEmpty && week.calibrations == 0)
            Text(t.gzmNone, style: TextStyle(color: hc.textSecondary))
          else
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(label)),
                    const SizedBox(width: 8),
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hc.readable(AppColors.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 8),
          Text(
            t.gzmHelp,
            style: TextStyle(color: hc.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _export,
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(t.gzmExport),
          ),
        ],
      ),
    );
  }
}

class _CalibrationHint extends StatelessWidget {
  const _CalibrationHint();

  @override
  Widget build(BuildContext context) => _Note(_t(context).gzsCalibrationHint);
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

/// A heading inside a section (e.g. Smoothing, under Tuning).
class _SubHeader extends StatelessWidget {
  final String title;
  const _SubHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  /// One notch of the slider.
  double get _step => (max - min) / divisions;

  @override
  Widget build(BuildContext context) {
    final current = value.clamp(min, max);
    final t = _t(context);
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
          // − / + beside the slider: a hands-free learner reaches these by
          // gaze (a slider can be focused but not moved by a head gesture),
          // and they are easier than a drag for anyone with limited hand
          // control.
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded),
                tooltip: t.gzsStepDown(title),
                onPressed: current <= min
                    ? null
                    : () => onChanged((current - _step).clamp(min, max)),
              ),
              Expanded(
                child: Slider(
                  value: current,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: valueLabel,
                  activeColor: AppColors.primary,
                  onChanged: onChanged,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                tooltip: t.gzsStepUp(title),
                onPressed: current >= max
                    ? null
                    : () => onChanged((current + _step).clamp(min, max)),
              ),
            ],
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
