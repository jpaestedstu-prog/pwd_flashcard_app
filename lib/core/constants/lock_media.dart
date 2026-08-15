import '../services/guardian_address.dart';
import '../services/media_cache_key.dart';

/// Media used by the "Time's up" lock screen.
///
/// Kept apart from `AppConstants` because these are *content* pointers
/// that get re-hosted independently of the app's tuning values, and
/// because the FSL URL is expected to be swapped without touching any
/// behaviour.
class LockMediaDefaults {
  const LockMediaDefaults._();

  /// Filipino Sign Language clip of the hand-off, **one per figure**.
  ///
  /// Each clip is a signer saying who the tablet goes to — "Ma'am",
  /// "Sir", "Mommy", "Daddy". Used for hearing (and multiple-disability)
  /// profiles when the educator hasn't set a per-child clip on the Time
  /// Limits screen.
  ///
  /// Per-figure rather than one shared clip because a single generic
  /// "time's up" sign tells a deaf learner *that* the session ended but
  /// not *whom to hand the device to* — which is the whole point of the
  /// hand-off. It pairs with [timesUpImageUrls]: same four figures, same
  /// resolution path, so the two faces of the card always agree.
  ///
  /// Hosting follows the rest of the app's FSL media: a direct-playable
  /// URL (Cloudinary), resolved and disk-cached by
  /// `FslAssetsService.videoSourceForUrl` so the clip plays offline
  /// after the first view — which matters, because the lock can fire
  /// when the device has no connection.
  ///
  /// The source assets were uploaded as animated **GIFs** (5.6–7.1 MB
  /// each). They are referenced here in their `.mp4` form because
  /// `video_player` cannot decode GIF, and because Cloudinary's
  /// on-delivery transcode drops them to ~240–300 KB. A per-child URL
  /// pasted as `.gif` is rewritten the same way at run time — see
  /// [MediaUrlResolver.asPlayableVideo].
  static const Map<HandoffFigure, String> timesUpFslVideoUrls = {
    HandoffFigure.maam:
        'https://res.cloudinary.com/lorjhyp9/image/upload/'
        'v1786366395/MA_AM_ac9hij.mp4',
    HandoffFigure.sir:
        'https://res.cloudinary.com/lorjhyp9/image/upload/'
        'v1786366393/SIR_nso099.mp4',
    HandoffFigure.mommy:
        'https://res.cloudinary.com/lorjhyp9/image/upload/'
        'v1786366396/MOMMY_dihsmu.mp4',
    HandoffFigure.daddy:
        'https://res.cloudinary.com/lorjhyp9/image/upload/'
        'v1786366393/DADDY_gqhdwd.mp4',
  };

  /// The signed hand-off for [figure], or null when the educator's avatar
  /// isn't one of the four gendered ones. Callers fall back to
  /// [timesUpAlarmClipUrl] rather than leaving the card blank.
  static String? timesUpFslVideoUrl(HandoffFigure? figure) =>
      figure == null ? null : timesUpFslVideoUrls[figure];

  /// The animated alarm clock shown to learners who don't sign.
  ///
  /// Deliberately wordless and language-free: a ringing clock reads as
  /// "time is up" to a learner who can't yet read the caption, whatever
  /// their accessibility profile. It is **not** sign language, so nothing
  /// that shows it may label it as FSL.
  ///
  /// Same `.gif` → `.mp4` reasoning as [timesUpFslVideoUrls] (7.7 MB GIF,
  /// 369 KB MP4).
  static const String timesUpAlarmClipUrl =
      'https://res.cloudinary.com/lorjhyp9/image/upload/'
      'v1786368709/ALARM_o11mmb.mp4';

  /// Cache key for any lock-screen clip — a per-figure FSL video, the
  /// alarm animation, or a per-child override.
  ///
  /// The key is derived from the URL rather than fixed, so every figure
  /// gets its own disk entry and re-hosting a clip downloads the new file
  /// instead of replaying a stale cached one. Goes through [MediaCacheKey]
  /// rather than `String.hashCode`: this value is persisted on disk, and
  /// `hashCode` is only stable within a single run, so a Dart upgrade
  /// would silently orphan every cached clip.
  static String clipCacheKey(String url) =>
      MediaCacheKey.forUrl('lock_timesup_clip', url);

  /// The "Time's Up" artwork for each of the four hand-off figures.
  ///
  /// Shown on the lock screen for **every** accessibility profile: a picture
  /// of the adult to hand the tablet to is the one cue that works for a
  /// learner who cannot read the caption, cannot hear the message, and
  /// doesn't sign.
  static const Map<HandoffFigure, String> timesUpImageUrls = {
    HandoffFigure.maam:
        'https://res.cloudinary.com/lorjhyp9/image/upload/'
        'v1785513403/TIME_S_UP_-_MA_AM_gseh1c.png',
    HandoffFigure.sir:
        'https://res.cloudinary.com/lorjhyp9/image/upload/'
        'v1785513403/TIME_S_UP_-_SIR_g49qtb.png',
    HandoffFigure.mommy:
        'https://res.cloudinary.com/lorjhyp9/image/upload/'
        'v1785513403/TIME_S_UP_-_MOMMY_vv5nil.png',
    HandoffFigure.daddy:
        'https://res.cloudinary.com/lorjhyp9/image/upload/'
        'v1785513403/TIME_S_UP_-_DADDY_txf4rd.png',
  };

  /// Artwork URL for [figure], or null when there is no matching picture
  /// (a legacy educator profile still on an animal avatar). Callers hide
  /// the picture rather than showing a placeholder.
  static String? timesUpImageUrl(HandoffFigure? figure) =>
      figure == null ? null : timesUpImageUrls[figure];

  /// Disk-cache slot for a hand-off picture. One slot per figure, with the
  /// URL folded in so re-hosting an artwork re-downloads it.
  static String imageCacheKey(HandoffFigure figure, String url) =>
      MediaCacheKey.forUrl('lock_timesup_img_${figure.name}', url);

  /// Gentle two-tone chime played when the lock appears. Deliberately
  /// soft-attack and short — this is a hand-off cue, not a fire alarm,
  /// and it can fire unannounced in the middle of a game.
  static const String alarmSoundAsset = 'sounds/times_up_alarm.wav';
}
