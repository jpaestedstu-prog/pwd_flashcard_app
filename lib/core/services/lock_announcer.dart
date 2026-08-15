import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../accessibility/haptic_service.dart';
import '../accessibility/tts_service.dart';
import '../constants/lock_media.dart';
import '../utils/error_handler.dart';
import 'lock_presentation.dart';

/// Plays the "Time's up" hand-off announcement.
///
/// An interface rather than a bare class so widget tests can substitute a
/// recording fake: the real implementation constructs an [AudioPlayer]
/// and drives `flutter_tts`, and neither survives the test binding.
abstract class LockAnnouncer {
  /// Runs the full announcement for one lock appearance.
  ///
  /// [message] is the already-resolved hand-off line (see
  /// `GuardianAddress.timesUpMessage`). [alarmEnabled] and [voiceEnabled]
  /// are the educator's per-child switches from `ChildTimeLimit`; the
  /// per-profile channel choices come from [presentation].
  ///
  /// Completes when the sequence finishes or is cancelled, and never
  /// throws — audio is a supplementary channel here, and the on-screen
  /// caption is always present.
  Future<void> announce({
    required LockPresentation presentation,
    required String message,
    bool alarmEnabled,
    bool voiceEnabled,
    bool speakFilipino,
  });

  /// Cancels any in-flight announcement and silences every channel.
  Future<void> stop();

  Future<void> dispose();
}

/// The real [LockAnnouncer]: alarm chime first, then the spoken message
/// ("Time's up. Please give your device to Ma'am.").
///
/// Sequenced rather than simultaneous — a chime under a voice makes the
/// voice unintelligible, which defeats the point for the visual profile
/// where speech is the primary channel.
///
/// Owns its own [AudioPlayer] instead of going through `SoundService`
/// because the game Sound Effects toggle must not silence a hand-off cue
/// (educators turn the chime off per child on the Time Limits screen
/// instead), and because it needs to await completion of each step.
///
/// Every step is cancellable: [stop] bumps a generation counter that all
/// awaited steps re-check, so unlocking mid-announcement doesn't leave a
/// voice talking over the home screen.
class AudioLockAnnouncer implements LockAnnouncer {
  AudioLockAnnouncer({
    AudioPlayer? player,
    TtsService? tts,
    HapticService? haptics,
  }) : _player = player ?? AudioPlayer(),
       _tts = tts,
       _haptics = haptics;

  final AudioPlayer _player;
  final TtsService? _tts;
  final HapticService? _haptics;

  /// Incremented by [stop] and [dispose]. Each awaited step compares the
  /// generation it started under against the current one and bails out if
  /// they differ.
  int _generation = 0;

  bool _disposed = false;

  /// Whether [_applyAudioContext] has run for this player.
  bool _audioContextSet = false;

  /// Stops the chime from pausing the FSL video.
  ///
  /// `audioplayers` defaults to `AndroidAudioFocus.gain`, which tells the OS
  /// this app is "the sole source of audio" — Android then pauses every
  /// other player, including the `video_player` showing the sign-language
  /// clip. The result was a frozen first frame for exactly the profile that
  /// cannot hear the chime and depends on the video instead.
  ///
  /// Requesting no focus is right on the merits too: this is a ~1.5 s alert
  /// cue, not media playback, so it has no business ducking or stopping
  /// anything else on the device.
  Future<void> _applyAudioContext() async {
    if (_audioContextSet) return;
    _audioContextSet = true;
    try {
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
    } catch (e, s) {
      // Non-fatal: the chime still plays, it just takes focus as before.
      ErrorHandler.report(e, s, 'LockAnnouncer:silent');
    }
  }

  /// Gap between chime repeats. Long enough to read as separate cues,
  /// short enough that the whole announcement stays under ~6 s.
  static const Duration _repeatGap = Duration(milliseconds: 550);

  /// Pause before the second reading of the spoken message.
  static const Duration _repeatSpeechGap = Duration(milliseconds: 900);

  /// Safety net for awaiting playback completion. `onPlayerComplete`
  /// never fires if the platform drops the audio focus, and an
  /// announcement that hangs forever would block the voice step behind
  /// it, so each wait is bounded.
  static const Duration _playTimeout = Duration(seconds: 4);

  @override
  Future<void> announce({
    required LockPresentation presentation,
    required String message,
    bool alarmEnabled = true,
    bool voiceEnabled = true,
    bool speakFilipino = false,
  }) async {
    if (_disposed) return;
    final gen = ++_generation;

    // Haptic first: it is instantaneous, and for a hearing profile it is
    // the cue that makes the child look at the screen at all.
    if (presentation.haptics) {
      try {
        await _haptics?.error();
      } catch (e, s) {
        ErrorHandler.report(e, s, 'LockAnnouncer:silent');
      }
    }
    if (gen != _generation) return;

    if (alarmEnabled && presentation.playAlarmSound) {
      for (var i = 0; i < presentation.alarmRepeats; i++) {
        if (gen != _generation) return;
        await _playChime(gen);
        if (gen != _generation) return;
        if (i < presentation.alarmRepeats - 1) {
          await Future<void>.delayed(_repeatGap);
        }
      }
    }
    if (gen != _generation) return;

    if (voiceEnabled && presentation.speakMessage && message.isNotEmpty) {
      await Future<void>.delayed(presentation.voiceDelay);
      if (gen != _generation) return;
      await _speak(message, speakFilipino, gen);

      if (presentation.repeatSpokenMessage) {
        await Future<void>.delayed(_repeatSpeechGap);
        if (gen != _generation) return;
        await _speak(message, speakFilipino, gen);
      }
    }
  }

  Future<void> _playChime(int gen) async {
    try {
      await _applyAudioContext();
      if (gen != _generation) return;
      await _player.stop();
      if (gen != _generation) return;
      // `onPlayerComplete` is subscribed *before* play() so a very short
      // clip can't finish between the two calls and strand the await.
      //
      // `.then<void>` before `.timeout` is load-bearing: the stream's
      // element type is `AudioEvent`, so timing out the raw future
      // demands an `onTimeout` that returns an `AudioEvent`. Narrowing to
      // `Future<void>` first lets the timeout simply give up. Without it
      // the call throws a TypeError *after* play() — the chime is heard
      // but nothing waits for it, so repeats and the spoken message
      // stampede over each other.
      final completed = _player.onPlayerComplete.first.then<void>((_) {});
      await _player.play(AssetSource(LockMediaDefaults.alarmSoundAsset));
      await completed.timeout(_playTimeout, onTimeout: () {});
    } catch (e, s) {
      // Same harmless playback races SoundService documents: a stop()
      // interrupting a spinning-up play(). Non-actionable.
      final msg = e.toString();
      if (msg.contains('AbortError') ||
          msg.contains('interrupted') ||
          msg.contains('Bad state: No element')) {
        return;
      }
      ErrorHandler.report(e, s, 'LockAnnouncer:silent');
    }
  }

  Future<void> _speak(String text, bool filipino, int gen) async {
    final tts = _tts;
    if (tts == null) return;
    try {
      if (filipino) {
        await tts.speakFilipino(text);
      } else {
        await tts.speakEnglish(text);
      }
    } catch (e, s) {
      ErrorHandler.report(e, s, 'LockAnnouncer:silent');
    }
  }

  /// Called when the lock is dismissed (PIN accepted, remote unlock, the
  /// rule lapsing) and before navigating to the profile switcher.
  @override
  Future<void> stop() async {
    _generation++;
    try {
      await _player.stop();
    } catch (e, s) {
      ErrorHandler.report(e, s, 'LockAnnouncer:silent');
    }
    try {
      await _tts?.stop();
    } catch (e, s) {
      ErrorHandler.report(e, s, 'LockAnnouncer:silent');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    try {
      await _player.dispose();
    } catch (e, s) {
      ErrorHandler.report(e, s, 'LockAnnouncer:silent');
    }
  }
}
