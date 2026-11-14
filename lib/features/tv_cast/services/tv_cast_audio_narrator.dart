import 'dart:async';

import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/tts_service.dart';

/// Produces the spoken/sound feedback for a cast session **on the teacher's
/// phone** — used when the educator sets the sound to come from "This phone"
/// (the TV plays its own audio otherwise, see `TvCastSpeech`).
///
/// A thin wrapper over the app's existing [TtsService] and [SoundService]
/// (mirrors [TvCastAutoplayController]), so the cast notifier stays lean and
/// this logic stays testable. The notifier owns one instance and decides
/// *when* to call these methods; gating against the accessibility settings is
/// the caller's job.
class TvCastAudioNarrator {
  TvCastAudioNarrator({required this.tts, required this.sfx, this.baseRate});

  final TtsService tts;
  final SoundService sfx;

  /// The app's own speech rate (the Speech Speed setting). The cast's 2×
  /// playback speed is applied on top of it for the length of one narration,
  /// then put back — the engine is the app's, and every other screen speaks
  /// at the learner's chosen pace. Null: the rate is never touched.
  final double Function()? baseRate;

  /// Whether this narrator has the engine at a rate other than [baseRate].
  bool _rateChanged = false;

  Future<void> _useSpeed(double speed) async {
    final base = baseRate;
    if (base == null) return;
    if (speed == 1.0) {
      if (!_rateChanged) return;
      _rateChanged = false;
      await tts.setSpeed(base());
      return;
    }
    _rateChanged = true;
    await tts.setSpeed((base() * speed).clamp(0.1, 2.0).toDouble());
  }

  /// Ends a narration: drops the follow-up and puts the app's rate back.
  void _done() {
    tts.setCompletionHandler(() {});
    unawaited(_useSpeed(1.0));
  }

  /// Speak [en] then [fil] sequentially at [speed] (1 = the app's own pace).
  /// Chains via a one-shot TTS completion handler so Filipino starts only
  /// after English finishes — without changing the shared service's global
  /// `awaitSpeakCompletion`. Either string may be empty (that language is
  /// skipped).
  Future<void> speakBoth(String en, String fil, {double speed = 1.0}) async {
    final hasEn = en.trim().isNotEmpty;
    final hasFil = fil.trim().isNotEmpty;
    await tts.stop();
    if (!hasEn && !hasFil) {
      _done();
      return;
    }
    await _useSpeed(speed);
    if (hasEn && hasFil) {
      tts.setCompletionHandler(() {
        tts.setCompletionHandler(_done); // after the Filipino line
        tts.speakFilipino(fil);
      });
      await tts.speakEnglish(en);
    } else if (hasEn) {
      tts.setCompletionHandler(_done);
      await tts.speakEnglish(en);
    } else {
      tts.setCompletionHandler(_done);
      await tts.speakFilipino(fil);
    }
  }

  /// Speak a single utterance in one language. Backs the on-demand,
  /// per-language "Replay" buttons on the cast screen. Stops any in-flight
  /// speech and clears a pending [speakBoth] follow-up so a queued second
  /// language can't fire over this one. No-op on empty text.
  Future<void> speakOne(
    String text, {
    required bool filipino,
    double speed = 1.0,
  }) async {
    if (text.trim().isEmpty) return;
    await tts.stop();
    tts.setCompletionHandler(_done);
    await _useSpeed(speed);
    if (filipino) {
      await tts.speakFilipino(text);
    } else {
      await tts.speakEnglish(text);
    }
  }

  /// Soft attention chime on slide / page change. Reuses the card-flip effect.
  void cue() => sfx.playFlip();

  /// Stop any in-flight speech — call on pause, idle, or session teardown.
  /// Clears the completion handler so a queued Filipino utterance from
  /// [speakBoth] doesn't fire after the stop, and puts the app's rate back.
  Future<void> stop() async {
    tts.setCompletionHandler(() {});
    await tts.stop();
    await _useSpeed(1.0);
  }
}
