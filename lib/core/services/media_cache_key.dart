/// Builds on-disk cache keys for downloaded media.
///
/// Every media cache in the app is keyed by *slot* — the card, story page or
/// quiz option a file is shown in — so a rotated CDN link doesn't invalidate an
/// already-downloaded file. That is the right default, but a slot key alone
/// says nothing about *which* file is in the slot: re-hosting a word with new
/// artwork keeps the slot and changes only the URL, so the cache would keep
/// serving the superseded file to anyone who had already viewed it — a
/// wrong-content bug that a clean install never reproduces.
///
/// [forUrl] mixes the source URL into the key so a re-host is a cache miss
/// instead. The superseded entry simply becomes unreachable and ages out via
/// the store's normal stale/count limits.
class MediaCacheKey {
  MediaCacheKey._();

  /// `<slotKey>_<hash of url>` — stable across runs and Dart versions.
  ///
  /// Uses FNV-1a rather than [String.hashCode] because this value is persisted:
  /// `hashCode` is only guaranteed stable within a single run, so a Dart
  /// upgrade could silently orphan every cached file.
  static String forUrl(String slotKey, String url) =>
      '${slotKey}_${_fnv1a(url)}';

  static String _fnv1a(String s) {
    var hash = 0x811c9dc5;
    for (final unit in s.codeUnits) {
      hash = (hash ^ unit) & 0xffffffff;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }
}
