import 'dart:convert';
import 'dart:io';

/// Resolves user-friendly *share-page* URLs to the direct media URL that can
/// actually be downloaded.
///
/// The media manifests let you paste the same link you'd share from a browser:
///   • Streamable video pages  (`https://streamable.com/<id>`)
///   • postimg image pages     (`https://postimg.cc/<id>`)
///
/// Neither of those is a direct file, so this resolver turns them into one:
///   • Streamable → the signed CDN `.mp4` (via the public Streamable API).
///     That URL is short-lived, so callers must download + cache it immediately
///     (keyed by card, not by URL) — exactly how [FslAssetsService] handles it.
///   • postimg    → the stable `https://i.postimg.cc/.../file.png` from the
///     page's `og:image` tag (these do not expire).
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

    // Streamable share/embed page → signed mp4.
    if (host == 'streamable.com' || host.endsWith('.streamable.com')) {
      // Already a direct CDN file? leave it.
      if (host.startsWith('cdn')) return pageUrl;
      return _resolveStreamable(pageUrl);
    }

    // postimg share page → direct image. (i.postimg.cc is already direct.)
    if (host == 'postimg.cc' || host == 'www.postimg.cc') {
      return _resolvePostimg(pageUrl);
    }

    // Anything else is assumed to be a direct media URL already.
    return pageUrl;
  }

  // ─── Streamable ───────────────────────────────────────────────────
  static Future<String?> _resolveStreamable(String url) async {
    final id = _streamableId(url);
    if (id == null) return null;
    final body = await _getString(
      Uri.parse('https://api.streamable.com/videos/$id'),
    );
    if (body == null) return null;
    try {
      final data = json.decode(body);
      if (data is! Map<String, dynamic>) return null;
      final files = data['files'];
      if (files is! Map<String, dynamic>) return null;
      final preferred = files['mp4'] ?? files['mp4-mobile'];
      if (preferred is! Map<String, dynamic>) return null;
      final mp4 = preferred['url'];
      if (mp4 is! String || mp4.isEmpty) return null;
      return mp4.startsWith('//') ? 'https:$mp4' : mp4;
    } catch (_) {
      return null;
    }
  }

  static String? _streamableId(String url) {
    final m = RegExp(r'streamable\.com/(?:e/|s/)?([A-Za-z0-9]+)').firstMatch(url);
    return m?.group(1);
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
