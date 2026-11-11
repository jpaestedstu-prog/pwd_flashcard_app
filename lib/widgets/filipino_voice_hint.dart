import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/accessibility/device_sound.dart';
import '../core/accessibility/tts_service.dart';
import '../core/theme/app_colors.dart';
import '../data/local/hive_service.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';
import '../providers/app_providers.dart';
import 'sound_off_hint.dart';

/// "No Filipino voice on this device": a small note at the top of the screen
/// when Filipino words are about to be read with the English voice.
///
/// The app (and TalkBack) can only speak Filipino with a Filipino voice, and
/// a device without one reads "Mga Laro" as English letters — the app said
/// nothing about it. The note comes once in a run of the app: the first time
/// the app asks for Filipino speech and gets the English voice
/// ([TtsService.filipinoVoiceMissing]), or as the app opens in Filipino with
/// a screen reader on (whose voice is the device's too). It offers the
/// device's own voice settings (Android), "OK", and "Don't remind me" (for
/// the device). It waits while the sound-off note is up, so the two never
/// cover each other, and screen readers hear it as an announcement.
///
/// Sits in `MaterialApp.builder` with [SoundOffHintHost], above the routes
/// and below the lock gates.
class FilipinoVoiceHintHost extends ConsumerStatefulWidget {
  const FilipinoVoiceHintHost({super.key, required this.child});

  final Widget child;

  /// How long the note stays when nobody touches it.
  static const showFor = Duration(seconds: 20);

  @override
  ConsumerState<FilipinoVoiceHintHost> createState() =>
      _FilipinoVoiceHintHostState();
}

class _FilipinoVoiceHintHostState extends ConsumerState<FilipinoVoiceHintHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<Offset> _slide;

  bool _visible = false;

  /// Once in a run of the app: the voice can only be added outside it.
  bool _shownThisRun = false;

  /// Shown when the sound-off note goes.
  bool _waiting = false;

  bool _checkedForReader = false;
  Timer? _autoHide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    TtsService.filipinoVoiceMissing.addListener(_onMissing);
    SoundOffHintHost.visible.addListener(_onSoundOffNote);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A screen reader speaks the app's Filipino in the device's voice too:
    // tell its user at once, not only once the app's own speech finds out.
    if (!_checkedForReader && MediaQuery.of(context).accessibleNavigation) {
      _checkedForReader = true;
      unawaited(_checkForReader());
    }
  }

  @override
  void dispose() {
    TtsService.filipinoVoiceMissing.removeListener(_onMissing);
    SoundOffHintHost.visible.removeListener(_onSoundOffNote);
    _autoHide?.cancel();
    _anim.dispose();
    super.dispose();
  }

  bool get _wanted {
    if (_shownThisRun || _visible) return false;
    try {
      return !HiveService.filipinoVoiceHintOff();
    } catch (_) {
      // The settings box is closed (a widget test): say it.
      return true;
    }
  }

  Future<void> _checkForReader() async {
    if (ref.read(settingsProvider).locale != 'fil' || !_wanted) return;
    final has = await ref.read(ttsServiceProvider).hasFilipinoVoice();
    if (mounted && has == false) _request();
  }

  void _onMissing() {
    if (_wanted) _request();
  }

  void _request() {
    if (!_wanted) return;
    if (SoundOffHintHost.visible.value) {
      _waiting = true;
      return;
    }
    _show();
  }

  void _onSoundOffNote() {
    if (_waiting && !SoundOffHintHost.visible.value && mounted) {
      _waiting = false;
      _request();
    }
  }

  void _show() {
    _shownThisRun = true;
    setState(() => _visible = true);
    _anim.forward();
    _autoHide?.cancel();
    _autoHide = Timer(FilipinoVoiceHintHost.showFor, _hide);
    HapticFeedback.mediumImpact();
    final t = _t(context);
    SemanticsService.sendAnnouncement(
      View.of(context),
      '${t.fvTitle}. ${_body(t)}',
      Directionality.of(context),
    );
  }

  void _hide() {
    _autoHide?.cancel();
    if (!_visible || !mounted) return;
    _anim.reverse().then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  Future<void> _openSettings() async {
    final opened = await DeviceSound.openVoiceSettings();
    if (opened) _hide();
  }

  void _neverAgain() {
    try {
      unawaited(HiveService.setFilipinoVoiceHintOff(true));
    } catch (_) {
      // A closed box: the note still goes for this run.
    }
    _hide();
  }

  String _body(AppLocalizations t) =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? t.fvBodyAndroid
          : t.fvBodyOther;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_visible)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: SlideTransition(
                position: _slide,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    // Its own Material and semantics node, as the sound-off
                    // note: this sits above the Navigator.
                    child: Semantics(
                      container: true,
                      child: Material(
                        type: MaterialType.transparency,
                        child: _note(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _note(BuildContext context) {
    final hc = HCColor.of(context);
    final t = _t(context);
    return Container(
      key: const ValueKey('filipino-voice-hint'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hc.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.record_voice_over_rounded, color: hc.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.fvTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _body(t),
                      style: TextStyle(fontSize: 14, color: hc.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Wraps rather than overflows at the largest text size on a small
          // phone.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              TextButton(
                onPressed: _neverAgain,
                child: Text(t.soundOffDontRemind),
              ),
              TextButton(
                onPressed: _hide,
                child: Text(t.soundOffOk),
              ),
              if (DeviceSound.canOpenVoiceSettings)
                FilledButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_voice_rounded, size: 20),
                  label: Text(t.fvOpenSettings),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Above the Navigator a test may pump without the localization delegate.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
