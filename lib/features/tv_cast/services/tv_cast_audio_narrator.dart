import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/tts_service.dart';

/// Produces the spoken/sound feedback for a cast session **on the teacher's
/// phone** — never on the TV browser, which can't reliably do text-to-speech
/// or un-muted audio autoplay on older models.
///
/// A thin wrapper over the app's existing [TtsService] and [SoundService]
/// (mirrors [TvCastAutoplayController]), so the cast notifier stays lean and
/// this logic stays testable. The notifier owns one instance and decides
/// *when* to call these methods; gating against the accessibility settings is
/// the caller's job.
class TvCastAudioNarrator {
  TvCastAudioNarrator({required this.tts, required this.sfx});

  final TtsService tts;
  final SoundService sfx;

  /// Speak [en] then [fil] sequentially. Chains via a one-shot TTS completion
  /// handler so Filipino starts only after English finishes — without changing
  /// the shared service's global `awaitSpeakCompletion`. Either string may be
  /// empty (that language is skipped).
  Future<void> speakBoth(String en, String fil) async {
    final hasEn = en.trim().isNotEmpty;
    final hasFil = fil.trim().isNotEmpty;
    await tts.stop();
    if (hasEn && hasFil) {
      tts.setCompletionHandler(() {
        tts.setCompletionHandler(() {}); // one-shot
        tts.speakFilipino(fil);
      });
      await tts.speakEnglish(en);
    } else if (hasEn) {
      tts.setCompletionHandler(() {});
      await tts.speakEnglish(en);
    } else if (hasFil) {
      tts.setCompletionHandler(() {});
      await tts.speakFilipino(fil);
    }
  }

  /// Speak a single utterance in one language. Backs the on-demand,
  /// per-language "Replay" buttons on the cast screen. Stops any in-flight
  /// speech and clears a pending [speakBoth] follow-up so a queued second
  /// language can't fire over this one. No-op on empty text.
  Future<void> speakOne(String text, {required bool filipino}) async {
    if (text.trim().isEmpty) return;
    await tts.stop();
    tts.setCompletionHandler(() {});
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
  /// [speakBoth] doesn't fire after the stop.
  Future<void> stop() {
    tts.setCompletionHandler(() {});
    return tts.stop();
  }
}
