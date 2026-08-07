import 'dart:convert';
import 'dart:io';

/// Resolves user-friendly *share-page* URLs to the direct media URL that can
/// actually be downloaded.
///
/// Every shipped manifest now stores direct Cloudinary URLs, which pass through
/// untouched — this exists so a share page can still be pasted into a manifest
/// without breaking:
///   • postimg image pages (`https://postimg.cc/<id>`) → the stable
///     `https://i.postimg.cc/.../file.png` from the page's `og:image` tag.
///
/// Streamable used to be handled here too. That branch is gone along with the
/// last Streamable URL: its links expire, which is exactly why the media was
/// re-hosted, so resolving them again would invite the same problem back.
///
/// Any already-direct URL is returned unchanged. All failures return null so
/// callers degrade gracefully (emoji / hidden button).
class MediaUrlResolver {
  MediaUrlResolver._();

  /// A browser-ish UA — some image/video hosts skip social/OG tags or refuse
  /// requests that look like bots.
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';

  /// Resolves [pageUrl] to a directly downloadable URL, or null on failure.
  static Future<String?> resolve(String pageUrl) async {
    final uri = Uri.tryParse(pageUrl.trim());
    if (uri == null || uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase();

    // postimg share page → direct image. (i.postimg.cc is already direct.)
    if (host == 'postimg.cc' || host == 'www.postimg.cc') {
      return _resolvePostimg(pageUrl);
    }

    // Anything else is assumed to be a direct media URL already.
    return pageUrl;
  }

  /// Rewrites [url] so a **video player** can actually open it.
  ///
  /// Today that means one case: an animated GIF hosted on Cloudinary.
  /// `video_player` cannot decode GIF at all, so a pasted
  /// `…/image/upload/…/clip.gif` would fail to initialise and the caller
  /// would show "video unavailable". Cloudinary transcodes on delivery,
  /// so swapping the extension to `.mp4` on the same `image/upload` path
  /// returns a real H.264 file — and a far smaller one (the FSL alarm
  /// clip is 7.7 MB as GIF, 369 KB as MP4).
  ///
  /// Deliberately **not** folded into [resolve]: that method is shared
  /// with the image pipelines (flashcard photos, story illustrations),
  /// where an animated GIF is a perfectly good result and must pass
  /// through untouched. Call this only when the consumer is a video
  /// player.
  ///
  /// Anything it doesn't recognise is returned unchanged, so it is safe
  /// to apply to every URL on a video path.
  static String asPlayableVideo(String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;
    if (uri.host.toLowerCase() != 'res.cloudinary.com') return trimmed;
    if (!uri.path.toLowerCase().endsWith('.gif')) return trimmed;
    // Only the image delivery type transcodes animated GIF → MP4; the
    // video type 404s for an asset that was uploaded as an image.
    if (!uri.path.contains('/image/upload/')) return trimmed;
    final swapped = '${uri.path.substring(0, uri.path.length - 4)}.mp4';
    return uri.replace(path: swapped).toString();
  }

  // ─── postimg ──────────────────────────────────────────────────────
  static Future<String?> _resolvePostimg(String url) async {
    final body = await _getString(Uri.parse(url));
    if (body == null) return null;

    // Preferred: the Open Graph image tag (server-rendered for social cards).
    final og = RegExp(
      r'''<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']''',
    ).firstMatch(body);
    if (og != null) return og.group(1);

    // Fallback: the same tag with attributes in the opposite order.
    final ogAlt = RegExp(
      r'''<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']''',
    ).firstMatch(body);
    if (ogAlt != null) return ogAlt.group(1);

    // Last resort: any direct i.postimg.cc image URL in the page.
    final direct = RegExp(
      r'''https?://i\.postimg\.cc/[^\s"'<>]+\.(?:png|jpe?g|gif|webp)''',
      caseSensitive: false,
    ).firstMatch(body);
    return direct?.group(0);
  }

  // ─── shared HTTP ──────────────────────────────────────────────────
  static Future<String?> _getString(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      return await resp.transform(utf8.decoder).join();
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
