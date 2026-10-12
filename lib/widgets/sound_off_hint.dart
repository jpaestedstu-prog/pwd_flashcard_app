import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/accessibility/device_sound.dart';
import '../core/accessibility/tts_service.dart';
import '../core/theme/app_colors.dart';
import '../data/models/enums.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';
import '../providers/app_providers.dart';

/// "Your device sound is off": a small note at the top of the screen when the
/// app speaks while the device's media volume is at zero, for learners who
/// listen to the words ([soundOffHintWanted]).
///
/// Found on the tablet: with its media volume at 0 every spoken word was
/// silent and nothing said why. The note never blocks the screen below it,
/// goes by itself after a while and after a fix, and offers to turn the sound
/// up (Android), to dismiss it, or never to show it again. Screen-reader users
/// hear it as an announcement: TalkBack and VoiceOver speak on their own
/// volume, so it still reaches them with the media sound at zero.
///
/// Sits in `MaterialApp.builder`, above the routes and below the lock gates.
class SoundOffHintHost extends ConsumerStatefulWidget {
  const SoundOffHintHost({super.key, required this.child});

  final Widget child;

  /// After "OK", how long before the note may show again.
  static const snooze = Duration(minutes: 10);

  /// How long the note stays when nobody touches it.
  static const showFor = Duration(seconds: 20);

  @override
  ConsumerState<SoundOffHintHost> createState() => _SoundOffHintHostState();
}

class _SoundOffHintHostState extends ConsumerState<SoundOffHintHost>
    with SingleTickerProviderStateMixin {
  // Made in initState, not lazily: a host that never showed the note would
  // otherwise create its controller (and ticker) while being disposed.
  late final AnimationController _anim;
  late final Animation<Offset> _slide;

  bool _visible = false;
  bool _checking = false;
  DateTime? _snoozedUntil;
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
    TtsService.requests.addListener(_onSpeech);
  }

  @override
  void dispose() {
    TtsService.requests.removeListener(_onSpeech);
    _autoHide?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _onSpeech() => unawaited(_check());

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final wanted = soundOffHintWanted(
        ref.read(profileProvider),
        ref.read(settingsProvider),
      );
      if (!wanted) return _hide();
      final off = await DeviceSound.isOff();
      if (!mounted) return;
      if (off == false) return _hide();
      final snoozed =
          _snoozedUntil != null && DateTime.now().isBefore(_snoozedUntil!);
      if (off == true && !_visible && !snoozed) _show();
    } finally {
      _checking = false;
    }
  }

  void _show() {
    setState(() => _visible = true);
    _anim.forward();
    _autoHide?.cancel();
    _autoHide = Timer(SoundOffHintHost.showFor, () => _hide(snooze: true));
    HapticFeedback.mediumImpact();
    final t = _t(context);
    SemanticsService.sendAnnouncement(
      View.of(context),
      '${t.soundOffTitle}. ${t.soundOffBody}',
      Directionality.of(context),
    );
  }

  void _hide({bool snooze = false}) {
    _autoHide?.cancel();
    if (snooze) _snoozedUntil = DateTime.now().add(SoundOffHintHost.snooze);
    if (!_visible || !mounted) return;
    _anim.reverse().then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  Future<void> _turnUp() async {
    final done = await DeviceSound.turnUp();
    if (done) _hide();
  }

  void _neverAgain() {
    final notifier = ref.read(settingsProvider.notifier);
    notifier.update(
      ref.read(settingsProvider).copyWith(soundOffHint: SoundOffHintChoice.off),
    );
    _hide();
  }

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
                    // Its own Material and semantics node: this sits above
                    // the Navigator, where neither is supplied.
                    child: Semantics(
                      container: true,
                      liveRegion: true,
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
      key: const ValueKey('sound-off-hint'),
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
              Icon(Icons.volume_off_rounded, color: hc.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.soundOffTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.soundOffBody,
                      style: TextStyle(fontSize: 14, color: hc.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Wraps rather than overflows at the largest text size on a
          // small phone.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              TextButton(
                onPressed: _neverAgain,
                child: Text(t.soundOffDontRemind),
              ),
              TextButton(
                onPressed: () => _hide(snooze: true),
                child: Text(t.soundOffOk),
              ),
              if (DeviceSound.canTurnUp)
                FilledButton.icon(
                  onPressed: _turnUp,
                  icon: const Icon(Icons.volume_up_rounded, size: 20),
                  label: Text(t.soundOffTurnUp),
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
