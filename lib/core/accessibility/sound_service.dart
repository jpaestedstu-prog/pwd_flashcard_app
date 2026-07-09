import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/error_handler.dart';
import '../../providers/app_providers.dart';

/// Sound effect types used across the app
enum SoundEffect {
  correct,
  wrong,
  starEarned,
  gameComplete,
  buttonTap,
  cardFlip,
  matchFound,
  letterPlace,
}

/// Service for playing short sound effects in games.
///
/// Respects the [AppSettings.soundEffects] toggle — when disabled, all
/// playback calls are silently ignored.
class SoundService {
  final AudioPlayer _player = AudioPlayer();
  bool _enabled;

  SoundService({bool enabled = true}) : _enabled = enabled;

  set enabled(bool value) => _enabled = value;
  bool get isEnabled => _enabled;

  /// Play a named sound effect. Resolves to a no-op when disabled.
  Future<void> play(SoundEffect effect) async {
    if (!_enabled) return;
    try {
      final path = _assetPath(effect);
      await _player.stop();
      await _player.play(AssetSource(path));
    } catch (e, stack) {
      // Swallow harmless playback races that fire when stop() interrupts a
      // play() while the player is still spinning up:
      //   • web: "AbortError" / "interrupted" — stop() aborts a pending
      //     play() promise in the browser.
      //   • native: "Bad state: No element" — audioplayers' internal
      //     event-stream `firstWhere().timeout()` completes empty when the
      //     player is (re)created mid-setup. Common on the very first sound
      //     after launch (e.g. the profile-creation chime).
      // These are non-actionable, so don't even log them.
      final msg = e.toString();
      if (msg.contains('AbortError') ||
          msg.contains('interrupted') ||
          msg.contains('Bad state: No element')) {
        return;
      }
      // Other audio failures: log for diagnostics but never interrupt UX —
      // audio is non-critical. 'SoundService' is a silent ErrorHandler source,
      // so this records to the Hive log without firing the global snackbar.
      ErrorHandler.report(e, stack, 'SoundService');
    }
  }

  /// Convenience shortcuts
  Future<void> playCorrect() => play(SoundEffect.correct);
  Future<void> playWrong() => play(SoundEffect.wrong);
  Future<void> playStar() => play(SoundEffect.starEarned);
  Future<void> playComplete() => play(SoundEffect.gameComplete);
  Future<void> playTap() => play(SoundEffect.buttonTap);
  Future<void> playFlip() => play(SoundEffect.cardFlip);
  Future<void> playMatch() => play(SoundEffect.matchFound);
  Future<void> playLetter() => play(SoundEffect.letterPlace);

  String _assetPath(SoundEffect effect) => switch (effect) {
        SoundEffect.correct => 'sounds/correct.wav',
        SoundEffect.wrong => 'sounds/wrong.wav',
        SoundEffect.starEarned => 'sounds/star.wav',
        SoundEffect.gameComplete => 'sounds/complete.wav',
        SoundEffect.buttonTap => 'sounds/tap.wav',
        SoundEffect.cardFlip => 'sounds/flip.wav',
        SoundEffect.matchFound => 'sounds/match.wav',
        SoundEffect.letterPlace => 'sounds/letter.wav',
      };

  Future<void> dispose() async {
    await _player.dispose();
  }
}

/// Global sound‑effects provider that stays in sync with the settings toggle.
final soundServiceProvider = Provider<SoundService>((ref) {
  final settings = ref.watch(settingsProvider);
  final service = SoundService(enabled: settings.soundEffects);
  ref.onDispose(() => service.dispose());
  return service;
});
