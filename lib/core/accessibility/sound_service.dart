import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/error_handler.dart';
import '../../data/models/shop_data.dart';
import '../../providers/app_providers.dart';
import 'sound_pack.dart';

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
  /// Created on the first sound actually played, not on construction.
  ///
  /// The provider rebuilds this service whenever settings change, and an
  /// `AudioPlayer` registers itself with the platform the moment it exists —
  /// so eager construction meant a plugin round-trip per rebuild, and made the
  /// class impossible to subclass in a widget test without one.
  AudioPlayer? _openPlayer;
  AudioPlayer get _player => _openPlayer ??= AudioPlayer();

  bool _enabled;

  /// Where the learner's equipped [SoundPack] comes from.
  ///
  /// Injected, and resolved at play time rather than at construction, for two
  /// reasons: the pack is equipped through `progressProvider`, which also
  /// fires on every star earned — far too often to tear down and rebuild an
  /// [AudioPlayer] for — and reading it lazily keeps this service off
  /// `profileProvider` (and the Firebase-backed streams behind it) until a
  /// sound is actually played.
  final SoundPack Function()? _packResolver;

  SoundService({bool enabled = true, SoundPack Function()? packResolver})
      : _enabled = enabled,
        _packResolver = packResolver;

  set enabled(bool value) => _enabled = value;
  bool get isEnabled => _enabled;

  /// The equipped pack, or [SoundPack.classic] when there is none — and when
  /// resolving one throws. Audio is non-critical: a learner whose pack cannot
  /// be read should hear the standard effect, never silence.
  SoundPack get pack {
    final resolve = _packResolver;
    if (resolve == null) return SoundPack.classic;
    try {
      return resolve();
    } catch (_) {
      return SoundPack.classic;
    }
  }

  /// Play a named sound effect. Resolves to a no-op when disabled.
  ///
  /// [pack] overrides the equipped one, for the Star Shop's "Hear it" preview:
  /// a learner deciding whether to spend 20 stars on the Nature pack has to be
  /// able to hear it first.
  Future<void> play(SoundEffect effect, {SoundPack? pack}) async {
    if (!_enabled) return;
    try {
      final path = assetPathFor(effect, pack ?? this.pack);
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

  /// The file name every pack uses for [effect]. A pack is a folder of these
  /// eight names and nothing else, which is what lets one line of path
  /// arithmetic swap the whole set.
  static String fileNameFor(SoundEffect effect) => switch (effect) {
        SoundEffect.correct => 'correct.wav',
        SoundEffect.wrong => 'wrong.wav',
        SoundEffect.starEarned => 'star.wav',
        SoundEffect.gameComplete => 'complete.wav',
        SoundEffect.buttonTap => 'tap.wav',
        SoundEffect.cardFlip => 'flip.wav',
        SoundEffect.matchFound => 'match.wav',
        SoundEffect.letterPlace => 'letter.wav',
      };

  /// Asset path of [effect] in [pack], relative to `assets/` the way
  /// [AssetSource] wants it.
  static String assetPathFor(SoundEffect effect, SoundPack pack) {
    final file = fileNameFor(effect);
    final folder = pack.folder;
    return folder == null ? 'sounds/$file' : 'sounds/$folder/$file';
  }

  Future<void> dispose() async {
    // Never through the getter: disposing a service that played nothing must
    // not create a player in order to throw it away.
    await _openPlayer?.dispose();
    _openPlayer = null;
  }
}

/// Global sound‑effects provider that stays in sync with the settings toggle.
final soundServiceProvider = Provider<SoundService>((ref) {
  final settings = ref.watch(settingsProvider);
  final service = SoundService(
    enabled: settings.soundEffects,
    packResolver: () => SoundPack.forItemId(
      ref
          .read(progressProvider.notifier)
          .getEquippedItemId(ShopItemType.soundPack),
    ),
  );
  ref.onDispose(() => service.dispose());
  return service;
});
