import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import '../../../core/accessibility/tts_service.dart';

/// Speaks the gamepad's feedback, and remembers the last thing it said.
///
/// A thin wrapper over [TtsService] rather than `VoiceNavigationService`,
/// because the two answer to different switches: voice-guided mode is a
/// setting a sighted teacher turns on for a learner, whereas gamepad speech is
/// the *only* channel a blind learner has once the controller is in their
/// hands. Gating it on `settings.voiceNavigation` would mean a learner who
/// picked up the pad on a profile that had never enabled voice guidance heard
/// nothing at all.
///
/// [interrupt] is the important nuance. Stepping quickly through a list should
/// cut the previous item off — waiting out "Flashcards, one of eight" before
/// hearing item two makes the controller feel broken. But a question
/// ("Do you want to go to the Cards section?") must never be clipped by
/// something arriving behind it, or the learner is left holding a pad whose A
/// and B buttons have silently changed meaning.
class GamepadAnnouncer {
  TtsService _tts;

  /// True while gamepad speech is switched on for this profile.
  bool enabled = true;

  /// 'en' or 'fil' — picks the TTS voice.
  String locale = 'en';

  /// Words-per-minute dial, 0.1 (very slow) … 1.0 (very fast), taken from the
  /// profile's own `ttsSpeed`.
  ///
  /// Applied explicitly before speaking rather than only at engine init.
  /// `TtsService.init` short-circuits once initialised, so a rate changed
  /// mid-session otherwise took effect only if the provider happened to
  /// rebuild the service — which meant the slider appeared to do nothing.
  double rate = 0.5;

  double? _appliedRate;
  String? _last;

  GamepadAnnouncer(this._tts);

  /// Swaps in a new engine, if the provider rebuilt one underneath us.
  set tts(TtsService value) {
    if (identical(value, _tts)) return;
    _tts = value;
    _appliedRate = null; // the new engine has not had our rate applied yet
  }

  /// The last thing spoken, for the repeat button.
  String? get lastMessage => _last;

  Future<void> say(String text) async {
    // Refuse to "announce" nothing. An empty utterance is indistinguishable
    // from a button that did not work, and it would also overwrite the last
    // message the learner might still want repeated.
    if (text.trim().isEmpty) return;
    _last = text;
    // The spoken line is the entire interface for a blind learner, so make it
    // greppable on-device: `adb logcat | grep GamepadSay` shows exactly what
    // they heard. Mirrors the `SttService` debug logging that made voice
    // commands diagnosable without a human in the room.
    if (kDebugMode) debugPrint('GamepadSay: $text');
    if (!enabled) return;
    await _applyRate();
    try {
      if (locale == 'fil') {
        await _tts.speakFilipino(text);
      } else {
        await _tts.speakEnglish(text);
      }
    } catch (_) {
      // A missing TTS engine must not break navigation — the haptic pulse and
      // the on-screen focus ring still tell the learner the press landed.
    }
  }

  /// Says the last message again, or null-safely does nothing when there is
  /// none yet.
  Future<void> repeat() async {
    final text = _last;
    if (text == null) return;
    if (!enabled) return;
    await _applyRate();
    try {
      if (locale == 'fil') {
        await _tts.speakFilipino(text);
      } else {
        await _tts.speakEnglish(text);
      }
    } catch (_) {
      // Ignored, as above.
    }
  }

  /// Pushes the current [rate] to the engine, but only when it has changed —
  /// a platform call before every single utterance would add latency to every
  /// cursor move.
  Future<void> _applyRate() async {
    if (_appliedRate == rate) return;
    try {
      // Bounded, because this sits directly in front of every announcement: a
      // TTS engine that never answers the rate call would otherwise take the
      // learner's *speech* down with it, and speech is the only channel they
      // have. Better to speak at the wrong rate than not at all.
      await _tts.setSpeed(rate).timeout(const Duration(milliseconds: 400));
      _appliedRate = rate;
    } catch (_) {
      // Engine not ready or not answering; the next utterance tries again.
    }
  }

  /// Cuts off whatever is being said. Keeps [lastMessage] so the learner can
  /// still ask for it again.
  Future<void> silence() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Nothing was speaking.
    }
  }
}
