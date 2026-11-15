import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/focused_label.dart';
import '../../../core/accessibility/spoken_words.dart';
import '../../../core/accessibility/stt_service.dart'
    show dictationMicLease, sttServiceProvider;
import '../../../core/accessibility/tts_service.dart';
import '../../../providers/app_providers.dart' show settingsProvider;
import '../controllers/voice_command_controller.dart';
import '../logic/gaze_focus_driver.dart';
import '../logic/hands_free_pause.dart';
import '../logic/voice_commands.dart';
import '../logic/voice_screen_reading.dart';

/// Shared plumbing for the gaze scopes that layer spoken-command control on top
/// of gaze ([GazeScope] and [GazeDpadScope]). It owns the
/// [VoiceCommandController], repaints the host on each "listening / last heard"
/// change, performs the global scroll gesture, and builds the little mic status
/// chip — so both scopes behave identically and only differ in what a phrase
/// *means* (their own [onVoiceCommand]).
mixin VoiceControlMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  VoiceCommandController? _voice;

  /// Logical pixels a spoken "scroll up/down" moves the list — matches the
  /// gaze step so voice and head scrolling feel the same.
  static const double _voiceScrollStep = 320;

  /// Every mounted gaze scope, oldest first — debug and profile builds only,
  /// for the gaze debug bridge (which can speak a phrase into the one that is
  /// listening, and describe what each scope is doing).
  static final List<VoiceControlMixin> debugScopes = [];

  @override
  void initState() {
    super.initState();
    if (!kReleaseMode) debugScopes.add(this);
  }

  @override
  void dispose() {
    if (!kReleaseMode) debugScopes.remove(this);
    super.dispose();
  }

  /// What this scope is doing right now, for the debug bridge. Scopes add
  /// their own cursor / scanning / traversal state.
  Map<String, Object?> debugDescribe() => {'scope': '$runtimeType'};

  /// True once [startVoiceControl] has armed the microphone.
  bool get voiceActive => _voice != null;

  /// Maps a recognised phrase to an action. Implemented by the host scope.
  void onVoiceCommand(String text);

  /// Arms the microphone and begins listening. Call from `initState` only when
  /// the learner has enabled voice commands (and Gaze Control overall).
  void startVoiceControl() {
    if (_voice != null) return;
    final stt = ref.read(sttServiceProvider);
    final locale =
        ref.read(settingsProvider).locale == 'fil' ? 'fil-PH' : 'en-US';
    final voice = VoiceCommandController(
      stt: stt,
      locale: locale,
      onCommand: _dispatchVoice,
    );
    voice.addListener(_onVoiceUpdate);
    handsFreePaused.addListener(_onVoiceUpdate);
    _voice = voice;
    voice.start();
  }

  void _onVoiceUpdate() {
    if (mounted) setState(() {});
  }

  // ── App-wide commands ───────────────────────────────────────────────────

  /// The last thing voice said back, for "say again" — app-wide, so it
  /// survives moving to another screen (which swaps the listening scope).
  static String? _lastReply;

  /// True while the app is speaking a reply (the microphone is held off so
  /// the reply is never heard as a command).
  bool _replying = false;

  /// Every recognised phrase passes here first: the app-wide commands
  /// ([resolveGlobalVoiceCommand]) are answered by this layer, a paused learner
  /// is heard only for "resume", and everything else goes to the screen.
  void _dispatchVoice(String text) {
    if (!mounted) return;
    final paused = handsFreePaused.value;
    final t = AppLocalizations.of(context);
    switch (resolveGlobalVoiceCommand(text, paused: paused)) {
      case GlobalVoiceIntent.pause:
        pauseHandsFree();
        _reply(t?.vcPausedSay ?? 'Paused. Say “resume” when you want to go on.');
      case GlobalVoiceIntent.resume:
        resumeHandsFree();
        _reply(t?.vcResumedSay ?? 'Listening again.');
      case GlobalVoiceIntent.readScreen:
        _reply(readScreenForVoice(filipino: _filipino));
      case GlobalVoiceIntent.repeat:
        final again = _lastReply ??
            FocusedLabel.of(GazeFocusDriver.focused?.context)?.split('\n').first;
        _reply(again ??
            (t?.vcNothingToRepeat ?? 'There is nothing to say again yet.'));
      case GlobalVoiceIntent.help:
        _reply(t?.vcHelpSay ??
            'Say left, right, up or down to move, and select to open. Or say '
                'a button’s name. You can also say: read the screen, say '
                'again, scroll down, go back, and stop listening.');
      case GlobalVoiceIntent.none:
        if (paused) return;
        onVoiceCommand(text);
    }
  }

  bool get _filipino => ref.read(settingsProvider).locale == 'fil';

  /// Says [text] back: through the screen reader when one is running (its own
  /// voice and queue), otherwise with the app's voice — holding the
  /// microphone off until it has finished, so the reply cannot command the app.
  Future<void> _reply(String text) async {
    _lastReply = text;
    if (MediaQuery.maybeOf(context)?.accessibleNavigation ?? false) {
      final view = WidgetsBinding.instance.platformDispatcher.implicitView;
      if (view == null) return;
      try {
        await SemanticsService.sendAnnouncement(
          view,
          SpokenWords.withoutPictures(text),
          TextDirection.ltr,
        );
      } catch (_) {}
      return;
    }
    final tts = ref.read(ttsServiceProvider);
    dictationMicLease.acquire();
    _replying = true;
    if (mounted) setState(() {});
    try {
      await (_filipino ? tts.speakFilipino(text) : tts.speakEnglish(text));
      await _quiet();
    } catch (_) {
      // No speech engine (a bare test): the reply is still remembered.
    } finally {
      dictationMicLease.release();
      _replying = false;
      if (mounted) setState(() {});
    }
  }

  /// Resolves once the speech engine has stopped speaking (at most 30 s).
  Future<void> _quiet() async {
    final speaking = TtsService.speaking;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!speaking.value) return;
    final done = Completer<void>();
    void check() {
      if (!speaking.value && !done.isCompleted) done.complete();
    }
    speaking.addListener(check);
    try {
      await done.future.timeout(const Duration(seconds: 30), onTimeout: () {});
    } finally {
      speaking.removeListener(check);
    }
  }

  /// Tears the controller down. Call from `dispose`.
  void disposeVoiceControl() {
    handsFreePaused.removeListener(_onVoiceUpdate);
    _voice?.removeListener(_onVoiceUpdate);
    _voice?.dispose();
    _voice = null;
  }

  /// Scrolls whatever is under the screen centre by one step. [dir] is -1 (up)
  /// or 1 (down). Synthesises a wheel event so it drives any normal scrollable
  /// without the scope needing a handle on the list's controller.
  void voiceScroll(int dir) {
    if (!mounted) return;
    final size = MediaQuery.sizeOf(context);
    WidgetsBinding.instance.handlePointerEvent(
      PointerScrollEvent(
        position: Offset(size.width / 2, size.height / 2),
        scrollDelta: Offset(0, dir * _voiceScrollStep),
      ),
    );
  }

  /// The small "Listening… / last heard" mic chip, or null when voice is off.
  /// Purely informational; the host places it (and wraps it in [IgnorePointer]).
  Widget? voiceChip() {
    final voice = _voice;
    if (voice == null) return null;
    final t = AppLocalizations.of(context);
    final text = voice.unavailable
        ? (t?.vcMicUnavailable ?? 'Microphone unavailable')
        : _replying
        ? (t?.vcSpeaking ?? 'Speaking…')
        : handsFreePaused.value
        ? (t?.vcPausedChip ?? 'Paused — say “resume”')
        : voice.pausedForDictation
        ? (t?.vcPausedDictation ?? 'Paused while you speak your message')
        : voice.lastHeard.isNotEmpty
            ? voice.lastHeard
            : (voice.isListening
                  ? (t?.vcListening ?? 'Listening…')
                  : (t?.vcReady ?? 'Voice ready'));
    // A transparent Material gives the text the app's own style. This floats
    // beside a screen's Scaffold, not inside it, so without one the text fell
    // back to Flutter's "missing Material" style — red-yellow double
    // underlines in a monospace font — on every gaze learner's screen.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              voice.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
