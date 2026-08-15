import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/accessibility/haptic_service.dart';
import '../core/accessibility/tts_service.dart';
import '../core/services/fsl_assets_service.dart';
import '../core/services/lock_announcer.dart';

/// The [LockAnnouncer] used by the "Time's up" lock screen.
///
/// Behind a provider rather than constructed inline so widget tests can
/// override it with a recording fake — the real one instantiates an
/// [AudioPlayer] and drives `flutter_tts`, neither of which exists in the
/// test binding. Same seam the FSL screens use for their camera / video
/// loaders.
///
/// `autoDispose` so the player and the TTS engine are released as soon as
/// the lock screen leaves the tree.
final lockAnnouncerProvider = Provider.autoDispose<LockAnnouncer>((ref) {
  final announcer = AudioLockAnnouncer(
    tts: ref.read(ttsServiceProvider),
    haptics: ref.read(hapticServiceProvider),
  );
  ref.onDispose(announcer.dispose);
  return announcer;
});

/// Resolves an FSL clip URL to a playable, disk-cached [VideoSource].
///
/// Signature matches `FslAssetsService.videoSourceForUrl`; injected the
/// same way as [lockAnnouncerProvider] so tests can return a stub (or
/// null, to exercise the "clip unavailable" path) without a network.
typedef LockFslVideoLoader =
    Future<VideoSource?> Function(String url, {required String cacheKey});

final lockFslVideoLoaderProvider = Provider<LockFslVideoLoader>(
  (ref) => FslAssetsService.videoSourceForUrl,
);
