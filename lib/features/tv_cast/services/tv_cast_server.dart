import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../../data/local/seed_data.dart';
import '../../../data/models/models.dart';
import '../models/tv_cast_session.dart';
import 'tv_cast_asset_bridge.dart';

/// In-app HTTP server that the TV browser polls. Pure-Dart shelf —
/// listens via `dart:io HttpServer.bind('0.0.0.0', port)` so no native
/// plugins are involved and we don't risk the Flutter 3.44 / Kotlin
/// 2.0.0 conflict that affects native cast SDKs.
///
/// ## Why every route is behind a session code
///
/// The socket binds `0.0.0.0`, so *every* device on the Wi-Fi can reach it —
/// and `/api/state` carries learner names, words learned, streaks, stars, and
/// raised hands. On a school network that is minors' progress data sitting on
/// an open port. So the server mints a random [sessionToken] on each [start]
/// and serves content only under `/c/<token>/…`; the bare origin returns a
/// "ask your teacher for the code" page and nothing else. The token is shown
/// on the educator's phone (and baked into the QR), rotates on every restart,
/// and is never persisted.
///
/// This is deliberately a *shared secret in the URL*, not a login: the TV is a
/// browser someone types a URL into with a remote, so the code has to stay
/// short enough to read off a screen. It raises the bar from "anyone who
/// port-scans the subnet" to "anyone the teacher showed the screen to", which
/// is the actual classroom threat model. [_kTokenLength] + [_bruteForceDelay]
/// keep guessing impractical.
class TvCastServer {
  TvCastServer({
    required this.getSession,
    this.onTvAudioReport,
    this.onRemoteAction,
  });

  /// Alphabet for the session code: uppercase + digits with the characters
  /// that are hard to tell apart on a TV at the back of a room removed
  /// (`0`/`O`, `1`/`I`, `5`/`S`, `8`/`B`, `2`/`Z`). 26 symbols.
  static const _tokenAlphabet = 'ACDEFGHJKLMNPQRTUVWXY34679';

  /// Code length. 26^5 ≈ 11.9M combinations — with [_bruteForceDelay] that is
  /// centuries of guessing on a LAN, while staying typeable on a TV remote.
  static const _kTokenLength = 5;

  /// After this many rejected codes the server starts stalling every further
  /// miss, so a scripted sweep of the keyspace gets nowhere. Legitimate TVs
  /// never hit it (they are handed the right URL).
  static const _bruteForceThreshold = 10;
  static const _bruteForceDelay = Duration(seconds: 2);

  /// Source-of-truth callback the server reads on every request. Lets
  /// the server stay decoupled from the Riverpod notifier (which owns
  /// the actual session state).
  final TvCastSession Function() getSession;

  /// Optional callback fired when a TV reports its Web Speech ability via the
  /// `/api/state` poll (`?tts=…&unlocked=…`). Lets the phone surface *why* the
  /// TV is or isn't speaking. Decoupled like [getSession] so the server doesn't
  /// reach into the notifier.
  final void Function({required bool supported, required bool unlocked})?
      onTvAudioReport;

  /// Fired when a TV drives the cast from its own remote (`/api/nudge`).
  /// Decoupled like [getSession] so the server doesn't reach into the notifier.
  /// Actions are the literal strings `next`, `prev`, `playpause`.
  final void Function(String action)? onRemoteAction;

  HttpServer? _httpServer;
  int? _boundPort;
  String? _sessionToken;
  int _rejectedCodes = 0;

  /// Distinct client IPs that presented the right code in the last 30 s. Backs
  /// the "N viewers connected" indicator on the phone-side UI. Only
  /// authenticated hits count, so a port scan can't inflate the number.
  final Map<String, DateTime> _seenClients = {};

  int get boundPort => _boundPort ?? 0;
  bool get isRunning => _httpServer != null;

  /// The random code guarding this cast, or null while stopped. Shown on the
  /// educator's phone and carried in the URL / QR the TV opens.
  String? get sessionToken => _sessionToken;

  /// Path prefix every TV-facing route lives under (`/c/<token>`), or `''`
  /// while stopped. The phone appends this to the origin to build the cast URL.
  String get basePath => _sessionToken == null ? '' : '/c/$_sessionToken';

  /// How many wrong codes have been presented since [start]. Surfaced so the
  /// educator UI can warn that someone on the network is probing the cast.
  int get rejectedCodeCount => _rejectedCodes;

  /// Snapshot of clients seen within the freshness window.
  int get activeViewerCount {
    final now = DateTime.now();
    _seenClients.removeWhere(
      (_, last) => now.difference(last) > const Duration(seconds: 30),
    );
    return _seenClients.length;
  }

  /// Starts the server. Tries [preferredPort] first, then increments
  /// until [preferredPort + maxAttempts]. Returns the bound port on
  /// success, throws on total failure.
  Future<int> start({int preferredPort = 8088, int maxAttempts = 12}) async {
    if (_httpServer != null) return _boundPort!;

    // A fresh code per cast: stopping and restarting (e.g. after a Wi-Fi hop)
    // invalidates the old URL, so a link that leaked stops working.
    _sessionToken = _generateToken();
    _rejectedCodes = 0;

    final handler = const Pipeline()
        .addMiddleware(_securityHeaders)
        .addMiddleware(_castGate)
        .addHandler(_buildRouter().call);

    Object? lastErr;
    for (int i = 0; i < maxAttempts; i++) {
      final port = preferredPort + i;
      try {
        _httpServer = await shelf_io.serve(
          handler,
          InternetAddress.anyIPv4,
          port,
          shared: true,
        );
        _boundPort = port;
        return port;
      } catch (e) {
        lastErr = e;
        // try next port
      }
    }
    _sessionToken = null;
    throw StateError(
      'TvCastServer: could not bind to ports '
      '$preferredPort..${preferredPort + maxAttempts - 1}: $lastErr',
    );
  }

  Future<void> stop() async {
    final s = _httpServer;
    _httpServer = null;
    _boundPort = null;
    _sessionToken = null;
    _rejectedCodes = 0;
    _seenClients.clear();
    if (s != null) {
      await s.close(force: true);
    }
  }

  /// Cryptographically-random session code. [Random.secure] (not the seeded
  /// default) so the code can't be predicted from the clock by someone who
  /// watched an earlier cast start.
  static String _generateToken() {
    final rng = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < _kTokenLength; i++) {
      buf.write(_tokenAlphabet[rng.nextInt(_tokenAlphabet.length)]);
    }
    return buf.toString();
  }

  /// Length-then-whole-string comparison against the live token. Case is
  /// folded up so a TV browser that "helpfully" lowercases a typed URL still
  /// connects — the alphabet has no lowercase members, so this loses nothing.
  bool _tokenMatches(String candidate) {
    final token = _sessionToken;
    if (token == null || candidate.length != token.length) return false;
    return candidate.toUpperCase() == token;
  }

  // ─── Routes ───────────────────────────────────────────

  Router _buildRouter() {
    final r = Router();

    r.get('/', _serveIndex);
    r.get('/index.html', _serveIndex);
    r.get(
      '/style.css',
      _serveStaticAsset('assets/tv_cast/style.css', 'text/css'),
    );
    r.get(
      '/app.js',
      _serveStaticAsset('assets/tv_cast/app.js', 'application/javascript'),
    );
    r.get('/idle.html', _serveIdle);

    r.get('/api/state', _serveState);
    r.get('/api/nudge', _serveNudge);
    r.get('/api/video/<catIdx>/<wordSlug>', _serveVideo);
    r.get('/api/story-video/<storyId>/<pageIdx>', _serveStoryVideo);
    r.get('/api/story-image/<storyId>/<pageIdx>/<face>', _serveStoryImage);
    r.get('/api/image/<catIdx>/<wordSlug>', _serveImage);
    r.get('/api/cartoon/<catIdx>/<wordSlug>', _serveCartoon);
    r.get('/api/clip/<catIdx>/<wordSlug>', _serveClip);
    r.get('/healthz', (Request _) => Response.ok('ok'));

    return r;
  }

  Future<Response> _serveIndex(Request _) =>
      _serveHtml('assets/tv_cast/index.html');

  Future<Response> _serveIdle(Request _) =>
      _serveHtml('assets/tv_cast/idle.html');

  /// Serves a bundled HTML page with its root-relative asset links rewritten
  /// into the token-scoped namespace, and (for the app shell) the base path
  /// handed to the TV script as `window.CAST_BASE`.
  ///
  /// The HTML files stay written with plain `/style.css` / `/app.js` so they're
  /// readable and testable on their own; this is the single place that knows
  /// about the code prefix.
  Future<Response> _serveHtml(String assetPath) async {
    final raw = await TvCastAssetBridge.loadAssetString(assetPath);
    if (raw == null) {
      return Response.notFound('${assetPath.split('/').last} missing');
    }
    return Response.ok(
      _withBasePath(raw),
      headers: {
        HttpHeaders.contentTypeHeader: 'text/html; charset=utf-8',
        HttpHeaders.cacheControlHeader: 'no-store',
      },
    );
  }

  /// Rewrites `"/style.css"` / `"/app.js"` to sit under [basePath] and exposes
  /// that prefix to `app.js` (which needs it to build `/api/…` URLs). A no-op
  /// when no token is active, so the raw asset still renders in isolation.
  String _withBasePath(String html) {
    final base = basePath;
    if (base.isEmpty) return html;
    return html
        .replaceAll('href="/style.css"', 'href="$base/style.css"')
        .replaceAll(
          '<script src="/app.js"></script>',
          '<script>window.CAST_BASE="$base";</script>\n'
              '  <script src="$base/app.js"></script>',
        );
  }

  Handler _serveStaticAsset(String assetPath, String contentType) {
    return (Request _) async {
      final bytes = await TvCastAssetBridge.loadAssetBytes(assetPath);
      if (bytes == null) return Response.notFound('asset not found');
      return Response.ok(
        bytes,
        headers: {
          HttpHeaders.contentTypeHeader: contentType,
          HttpHeaders.cacheControlHeader: 'public, max-age=300',
        },
      );
    };
  }

  /// The TV driving the cast from its own remote.
  ///
  /// The only write endpoint on the server, so it's deliberately narrow: a
  /// fixed vocabulary of three actions, no payload, and the educator's
  /// `tvRemoteEnabled` switch enforced *here* rather than trusted to the TV —
  /// turning it off on the phone stops an already-loaded TV page from driving
  /// the lesson, which is the whole point of having the switch.
  ///
  /// Still a GET despite mutating: the 2014-era TV browsers this targets have
  /// erratic XHR POST support, and the session-code gate plus the same-origin
  /// (CORS-free) policy already mean only an invited TV can reach it.
  Response _serveNudge(Request request) {
    final session = getSession();
    if (!session.tvRemoteEnabled) {
      return Response.forbidden('remote disabled');
    }
    const allowed = {'next', 'prev', 'playpause'};
    final action = request.url.queryParameters['a'] ?? '';
    if (!allowed.contains(action)) {
      return Response(400, body: 'unknown action');
    }
    onRemoteAction?.call(action);
    return Response.ok(
      '{"ok":true}',
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        HttpHeaders.cacheControlHeader: 'no-store',
      },
    );
  }

  Response _serveState(Request request) {
    // The TV piggybacks its Web Speech ability on the state poll so the phone
    // can explain why audio is/isn't coming out of the TV. Only report when the
    // `tts` flag is present (older clients / direct hits simply omit it).
    final q = request.url.queryParameters;
    final cb = onTvAudioReport;
    if (cb != null && q.containsKey('tts')) {
      cb(supported: q['tts'] == '1', unlocked: q['unlocked'] == '1');
    }

    final session = getSession();
    final body = jsonEncode(_enrichState(session));
    return Response.ok(
      body,
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        HttpHeaders.cacheControlHeader: 'no-store',
      },
    );
  }

  /// Adds resolved content (current flashcard, story page, etc.) to
  /// the plain session JSON so the TV can render in a single round-trip.
  Map<String, dynamic> _enrichState(TvCastSession session) {
    final map = session.toApiJson();
    final cat = session.category;

    if ((session.mode == CastMode.flashcards ||
            session.mode == CastMode.fslVideo) &&
        cat != null) {
      final cards = SeedData.getByCategory(cat);
      if (cards.isNotEmpty) {
        final idx = session.slideIndex % cards.length;
        final card = cards[idx];
        final slideMap = <String, dynamic>{
          'index': idx,
          'total': cards.length,
          'wordEn': card.wordEnglish,
          'wordFil': card.wordFilipino,
          'example': card.exampleSentence,
          'emoji': TvCastAssetBridge.emojiFor(card),
          // Category visuals so the TV paints a card matching the in-app one.
          ...TvCastAssetBridge.categoryVisual(cat),
        };
        final slug = _slugifyForUrl(card.wordEnglish);
        // Real photo / GIF (mirrors the in-app "Cards" image). The file may not
        // be downloaded yet; the TV fetches /api/image and flips to it on tap
        // (and stays on the front face if it never loads).
        if (TvCastAssetBridge.hasPhoto(card)) {
          slideMap['photo'] = {
            'available': true,
            'url': '/api/image/${cat.index}/$slug',
          };
        }
        // Illustrated face — the front of the TV's flip card, so the cast
        // mirrors the in-app cartoon ⇄ real-life pair. Absent for the
        // realistic-only categories, where the TV keeps the emoji front.
        if (TvCastAssetBridge.hasCartoon(card)) {
          slideMap['cartoon'] = {
            'available': true,
            'url': '/api/cartoon/${cat.index}/$slug',
          };
        }
        // "Show Me" action clip (mirrors the in-app "Show Me" button) — a short
        // looping video/GIF of the word in motion. Played on the TV only when
        // the teacher activates Show Me (`showMe` flag); `isGif` tells the TV
        // whether to use a <video> (MP4) or a looping <img> (GIF).
        if (TvCastAssetBridge.hasActionClip(card)) {
          slideMap['clip'] = {
            'available': true,
            'url': '/api/clip/${cat.index}/$slug',
            'isGif': TvCastAssetBridge.actionClipIsGif(card),
          };
        }
        map['slide'] = slideMap;
        if (session.mode == CastMode.fslVideo) {
          // Any source counts — bundled, direct download, or secondary CDN. The
          // clip may not be on disk yet; the TV retries until /api/video can
          // serve it (the phone prefetches in the background, see notifier).
          final available = TvCastAssetBridge.hasFslVideo(card);
          final slug = _slugifyForUrl(card.wordEnglish);
          map['video'] = {
            'available': available,
            'url': available ? '/api/video/${cat.index}/$slug' : null,
          };
        }
      }
    }

    if (session.mode == CastMode.story) {
      final story = TvCastAssetBridge.findStory(session.storyId ?? '');
      if (story != null) {
        final pages = story.sentencesEn;
        final pagesFil = story.sentencesFil;
        final pageIdx = session.storyPageIndex.clamp(0, pages.length - 1);
        final storyMap = <String, dynamic>{
          'titleEn': story.titleEn,
          'titleFil': story.titleFil,
          'emoji': story.emoji,
          'pageIndex': pageIdx,
          'totalPages': pages.length,
          'textEn': pages[pageIdx],
          'textFil': pageIdx < pagesFil.length ? pagesFil[pageIdx] : '',
        };
        // Cartoon ⇄ real-life flip picture for the current page (mirrors the
        // in-app reader's tap-to-flip illustration). When present the TV drops
        // the emoji and shows BOTH pictures, flipping between them on the
        // phone's "Tap to Flip Animation" button (`storyImageFlipped`). Each
        // face downloads + caches on its first /api/story-image request (same
        // host-and-download model as the flashcard photo), keyed so the cast and
        // the in-app reader reuse one file.
        final imagePair = TvCastAssetBridge.storyImagePair(story, pageIdx);
        if (imagePair != null) {
          storyMap['image'] = {
            'available': true,
            'cartoonUrl': '/api/story-image/${story.id}/$pageIdx/cartoon',
            'realUrl': '/api/story-image/${story.id}/$pageIdx/real',
          };
        }
        map['story'] = storyMap;
        // FSL sign-language clip for the current page (mirrors the in-app
        // "Watch in FSL" button). Played on the TV only when the teacher
        // activates the story FSL toggle (`storyFsl` flag). The file may not be
        // on disk yet; the TV retries until /api/story-video can serve it (the
        // phone prefetches in the background, see the notifier).
        final fslUrl = TvCastAssetBridge.storyFslUrl(story, pageIdx);
        if (fslUrl != null) {
          map['storyVideo'] = {
            'available': true,
            'url': '/api/story-video/${story.id}/$pageIdx',
          };
        }
      }
    }

    // Picture / FSL activities reference a flashcard by id — resolve its
    // emoji + words here (same pattern as the slide block) so the TV can show
    // the image/word without a second round-trip.
    final live = map['live'];
    if (live is Map) {
      final activity = live['activity'];
      if (activity is Map) {
        final fcId = activity['flashcardId'] as String?;
        if (fcId != null && fcId.isNotEmpty) {
          final card = _findCardById(fcId);
          if (card != null) {
            activity['word'] = card.wordEnglish;
            activity['wordFil'] = card.wordFilipino;
            activity['emoji'] = TvCastAssetBridge.emojiFor(card);
            _attachActivityMedia(activity, card);
          }
        }
      }
    }

    return map;
  }

  /// Adds the activity card's real media to a live question.
  ///
  /// Without this the TV showed a big emoji for every card-backed question —
  /// including `fslSign`, where the sign *is* the question. A Deaf learner was
  /// being asked to identify a sign the shared screen never showed, with only
  /// "Watch the sign — pick the word on your device" as a caption, so the one
  /// display everybody can see contributed nothing. Resolved here rather than
  /// on the phone so the TV needs a single round-trip, exactly like `slide`.
  ///
  /// URLs stay root-relative; the TV moves them into the session-code
  /// namespace itself (`scopeMediaUrls` in app.js).
  void _attachActivityMedia(Map activity, Flashcard card) {
    final catIdx = card.category.index;
    final slug = _slugifyForUrl(card.wordEnglish);

    // The sign clip — the whole point of an fslSign question. Sent for any
    // card-backed type so a picture question on a Deaf-profile class can still
    // be answered from the sign; the TV decides what to show per type.
    if (TvCastAssetBridge.hasFslVideo(card)) {
      activity['video'] = {
        'available': true,
        'url': '/api/video/$catIdx/$slug',
      };
    }
    // The real photograph, so a `pictureChoice` question shows the actual
    // picture the learners see in-app instead of an emoji stand-in.
    if (TvCastAssetBridge.hasPhoto(card)) {
      activity['photo'] = {
        'available': true,
        'url': '/api/image/$catIdx/$slug',
      };
    }
  }

  /// Looks up a seeded flashcard by id (used to render picture / FSL
  /// activities on the TV). Returns null for custom cards the server can't
  /// see — the TV falls back to the word text in that case.
  Flashcard? _findCardById(String id) {
    for (final card in SeedData.allFlashcards) {
      if (card.id == id) return card;
    }
    return null;
  }

  String _slugifyForUrl(String input) {
    final buf = StringBuffer();
    for (final ch in input.toLowerCase().codeUnits) {
      if ((ch >= 0x61 && ch <= 0x7a) || (ch >= 0x30 && ch <= 0x39)) {
        buf.writeCharCode(ch);
      }
    }
    return buf.toString();
  }

  Future<Response> _serveVideo(
    Request request,
    String catIdxStr,
    String wordSlug,
  ) async {
    final catIdx = int.tryParse(catIdxStr);
    if (catIdx == null) return Response(400, body: 'bad category');

    final card = TvCastAssetBridge.findFlashcard(catIdx, wordSlug);
    if (card == null) return Response.notFound('card not found');

    // Resolve the on-device cached file (downloads from GitHub Releases /
    // Cloudinary on first request). The phone prefetches the current + next
    // card, so by the time the TV asks, the file is usually already cached.
    final File? file = await TvCastAssetBridge.fslVideoFileFor(card);
    if (file == null || !await file.exists()) {
      // Not ready yet (download in flight or no source) — the TV-side player
      // retries on the next state poll.
      return Response.notFound('video not ready for ${card.wordEnglish}');
    }
    return _streamFileRanged(request, file, 'video/mp4', 'video');
  }

  /// Serves the current story page's FSL sign-language clip so the TV can play
  /// the same sign video as the in-app "Watch in FSL" button. The page's
  /// share-page URL (from the story's `sentenceFslUrls`) is resolved + cached on
  /// first request, keyed so the cast and the in-app reader share one file.
  /// Range-streamed as `video/mp4` (reusing [_streamFileRanged]); not ready yet
  /// (download in flight) → 404 and the TV retries on its next poll.
  Future<Response> _serveStoryVideo(
    Request request,
    String storyId,
    String pageIdxStr,
  ) async {
    final pageIdx = int.tryParse(pageIdxStr);
    if (pageIdx == null) return Response(400, body: 'bad page');

    final story = TvCastAssetBridge.findStory(storyId);
    if (story == null) return Response.notFound('story not found');

    final url = TvCastAssetBridge.storyFslUrl(story, pageIdx);
    if (url == null) return Response.notFound('no FSL for this page');

    final cacheKey = TvCastAssetBridge.storyFslCacheKey(story.id, pageIdx);
    final File? file = await TvCastAssetBridge.storyFslVideoFile(url, cacheKey);
    if (file == null || !await file.exists()) {
      // Not ready yet (download in flight or unresolvable) — the TV-side player
      // retries on the next state poll.
      return Response.notFound('story video not ready for ${story.titleEn}');
    }
    return _streamFileRanged(request, file, 'video/mp4', 'story video');
  }

  /// Serves a story page's cartoon or real-life flip picture so the TV can show
  /// the same pair as the in-app reader's tap-to-flip illustration. [face] is
  /// `cartoon` (the front, shown first) or `real` (the back, revealed on flip).
  /// The picture's share-page URL (from the story's `sentenceImages`) is resolved
  /// + cached on first request under a key shared with the reader, so cast +
  /// reader reuse one file and replay offline. Photos are small, so the whole
  /// image is sent in one response (no Range) with the MIME type sniffed from its
  /// bytes; not ready yet (download in flight / unresolvable) → 404 and the TV
  /// retries on its next poll, keeping the page text fully usable meanwhile.
  Future<Response> _serveStoryImage(
    Request request,
    String storyId,
    String pageIdxStr,
    String face,
  ) async {
    final pageIdx = int.tryParse(pageIdxStr);
    if (pageIdx == null) return Response(400, body: 'bad page');

    final story = TvCastAssetBridge.findStory(storyId);
    if (story == null) return Response.notFound('story not found');

    final pair = TvCastAssetBridge.storyImagePair(story, pageIdx);
    if (pair == null) return Response.notFound('no picture for this page');

    final real = face == 'real';
    final url = real ? pair.realUrl : pair.cartoonUrl;
    final cacheKey =
        TvCastAssetBridge.storyImageCacheKey(story.id, pageIdx, real: real);

    final File? file = await TvCastAssetBridge.storyImageFile(url, cacheKey);
    if (file == null || !await file.exists()) {
      return Response.notFound('story image not ready for ${story.titleEn}');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return Response.notFound('empty story image');

    return Response.ok(
      bytes,
      headers: {
        HttpHeaders.contentTypeHeader:
            TvCastAssetBridge.imageContentType(bytes, file.path),
        HttpHeaders.contentLengthHeader: bytes.length.toString(),
        HttpHeaders.cacheControlHeader: 'public, max-age=86400',
      },
    );
  }

  /// Streams [file] off disk with HTTP Range support, so older TV browsers can
  /// fetch a large clip in chunks rather than buffering it whole. Shared by the
  /// FSL video and the "Show Me" action-clip (MP4) routes. `openRead` keeps the
  /// file off the heap; the byte range is parsed defensively and a malformed /
  /// out-of-bounds Range falls back to the full 200 response.
  Future<Response> _streamFileRanged(
    Request request,
    File file,
    String contentType,
    String label,
  ) async {
    final total = await file.length();
    if (total <= 0) return Response.notFound('empty $label');

    final rangeHeader = request.headers['range'];
    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final spec = rangeHeader.substring(6);
      final dash = spec.indexOf('-');
      if (dash >= 0) {
        final startStr = spec.substring(0, dash);
        final endStr = spec.substring(dash + 1);
        final start = startStr.isEmpty ? 0 : (int.tryParse(startStr) ?? 0);
        final end = endStr.isEmpty
            ? total - 1
            : (int.tryParse(endStr) ?? (total - 1)).clamp(0, total - 1);
        if (start >= 0 && start <= end && end < total) {
          // openRead's end bound is exclusive, so pass end + 1.
          return Response(
            206,
            body: file.openRead(start, end + 1),
            headers: {
              HttpHeaders.contentTypeHeader: contentType,
              HttpHeaders.contentLengthHeader: (end - start + 1).toString(),
              HttpHeaders.acceptRangesHeader: 'bytes',
              'Content-Range': 'bytes $start-$end/$total',
              HttpHeaders.cacheControlHeader: 'public, max-age=86400',
            },
          );
        }
      }
    }

    return Response.ok(
      file.openRead(),
      headers: {
        HttpHeaders.contentTypeHeader: contentType,
        HttpHeaders.contentLengthHeader: total.toString(),
        HttpHeaders.acceptRangesHeader: 'bytes',
        HttpHeaders.cacheControlHeader: 'public, max-age=86400',
      },
    );
  }

  /// Serves the current flashcard's "Show Me" action clip so the TV can play
  /// the same demonstration as the in-app "Show Me" button. A GIF is sent whole
  /// as `image/gif` (the TV loops it in an `<img>`); a video container is
  /// Range-streamed as `video/mp4` (the TV plays it muted + looping), reusing
  /// [_streamFileRanged]. Not ready yet (download in flight) → 404 and the TV
  /// retries on its next poll.
  Future<Response> _serveClip(
    Request request,
    String catIdxStr,
    String wordSlug,
  ) async {
    final catIdx = int.tryParse(catIdxStr);
    if (catIdx == null) return Response(400, body: 'bad category');

    final card = TvCastAssetBridge.findFlashcard(catIdx, wordSlug);
    if (card == null) return Response.notFound('card not found');

    final File? file = await TvCastAssetBridge.actionClipFileFor(card);
    if (file == null || !await file.exists()) {
      return Response.notFound('clip not ready for ${card.wordEnglish}');
    }

    if (TvCastAssetBridge.actionClipIsGif(card)) {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return Response.notFound('empty clip');
      return Response.ok(
        bytes,
        headers: {
          HttpHeaders.contentTypeHeader:
              TvCastAssetBridge.imageContentType(bytes, file.path),
          HttpHeaders.contentLengthHeader: bytes.length.toString(),
          HttpHeaders.cacheControlHeader: 'public, max-age=86400',
        },
      );
    }
    return _streamFileRanged(request, file, 'video/mp4', 'clip');
  }

  /// Serves a card's illustrated face. Cartoons are manifest-only (no bundled
  /// asset variant), so this is the photo handler minus the asset branch.
  Future<Response> _serveCartoon(
    Request request,
    String catIdxStr,
    String wordSlug,
  ) async {
    final catIdx = int.tryParse(catIdxStr);
    if (catIdx == null) return Response(400, body: 'bad category');

    final card = TvCastAssetBridge.findFlashcard(catIdx, wordSlug);
    if (card == null) return Response.notFound('card not found');

    final File? file = await TvCastAssetBridge.cartoonFileFor(card);
    if (file == null || !await file.exists()) {
      return Response.notFound('cartoon not ready for ${card.wordEnglish}');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return Response.notFound('empty cartoon');

    return Response.ok(
      bytes,
      headers: {
        HttpHeaders.contentTypeHeader:
            TvCastAssetBridge.imageContentType(bytes, file.path),
        HttpHeaders.contentLengthHeader: bytes.length.toString(),
        HttpHeaders.cacheControlHeader: 'public, max-age=86400',
      },
    );
  }

  /// Serves the current flashcard's real photo / GIF so the TV can show the
  /// same image as the in-app "Cards" section. Bundled asset images are read
  /// from the bundle; manifest photos are downloaded + cached on first request
  /// (same model as [_serveVideo]). Photos are small, so the whole file is sent
  /// in one response (no Range) with the MIME type sniffed from its bytes — the
  /// latter is what lets GIFs animate (they must be served as `image/gif`).
  Future<Response> _serveImage(
    Request request,
    String catIdxStr,
    String wordSlug,
  ) async {
    final catIdx = int.tryParse(catIdxStr);
    if (catIdx == null) return Response(400, body: 'bad category');

    final card = TvCastAssetBridge.findFlashcard(catIdx, wordSlug);
    if (card == null) return Response.notFound('card not found');

    // 1. Bundled asset image (custom cards) — read straight from the bundle.
    final assetPath = TvCastAssetBridge.photoAssetPathFor(card);
    if (assetPath != null) {
      final bytes = await TvCastAssetBridge.loadAssetBytes(assetPath);
      if (bytes != null && bytes.isNotEmpty) {
        return Response.ok(
          bytes,
          headers: {
            HttpHeaders.contentTypeHeader:
                TvCastAssetBridge.imageContentType(bytes, assetPath),
            HttpHeaders.contentLengthHeader: bytes.length.toString(),
            HttpHeaders.cacheControlHeader: 'public, max-age=86400',
          },
        );
      }
    }

    // 2. Manifest photo — downloaded + cached on first request. Not ready yet
    //    (download in flight or no source) → the TV keeps showing the emoji and
    //    retries the image on its next state poll.
    final File? file = await TvCastAssetBridge.photoFileFor(card);
    if (file == null || !await file.exists()) {
      return Response.notFound('photo not ready for ${card.wordEnglish}');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return Response.notFound('empty photo');

    return Response.ok(
      bytes,
      headers: {
        HttpHeaders.contentTypeHeader:
            TvCastAssetBridge.imageContentType(bytes, file.path),
        HttpHeaders.contentLengthHeader: bytes.length.toString(),
        HttpHeaders.cacheControlHeader: 'public, max-age=86400',
      },
    );
  }

  // ─── Middleware ───────────────────────────────────────

  /// Hardening headers on every response.
  ///
  /// There is deliberately **no** `Access-Control-Allow-Origin` any more. The
  /// TV page, its assets, and the API are all one origin, so the cast never
  /// needed CORS — and the previous `*` meant any page a learner opened on the
  /// school Wi-Fi could read the roster out of `/api/state` from JavaScript.
  /// `nosniff` stops a browser from re-interpreting a served photo/clip as
  /// script, and the frame headers keep the cast out of a hostile iframe.
  Middleware get _securityHeaders => (Handler inner) {
    return (Request request) async {
      final response = await inner(request);
      return response.change(
        headers: {
          ...response.headersAll,
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'DENY',
          'Referrer-Policy': 'no-referrer',
        },
      );
    };
  };

  /// Requires the session code on every content route.
  ///
  /// Accepts `/c/<token>/…`, strips that prefix, and hands the original path
  /// to the router — so the routes below stay written as `/api/state` etc. and
  /// the token lives in exactly one place. `/healthz` stays open (it returns
  /// the literal string "ok" and reveals nothing); everything else without a
  /// valid code gets the "ask your teacher" page, never content.
  Middleware get _castGate => (Handler inner) {
    return (Request request) async {
      final segments = request.url.pathSegments;

      if (segments.length == 1 && segments.first == 'healthz') {
        return inner(request);
      }

      if (segments.length >= 2 &&
          segments[0] == 'c' &&
          _tokenMatches(segments[1])) {
        final ctx = request.context['shelf.io.connection_info'];
        if (ctx is HttpConnectionInfo) {
          _seenClients[ctx.remoteAddress.address] = DateTime.now();
        }
        // `change(path:)` moves the prefix from `url` to `handlerPath`, which
        // is exactly what shelf_router does when it mounts a sub-router.
        return inner(request.change(path: '${segments[0]}/${segments[1]}'));
      }

      _rejectedCodes++;
      // Stall repeat guessers. Real TVs are handed the right URL and never
      // land here, so this only ever costs an attacker.
      if (_rejectedCodes > _bruteForceThreshold) {
        await Future<void>.delayed(_bruteForceDelay);
      }
      return _rejectResponse();
    };
  };

  /// Friendly dead end for the bare origin and for mistyped codes. Deliberately
  /// identical for both so it never confirms whether a code was close, and
  /// deliberately 404 so it leaks no structure.
  Response _rejectResponse() {
    const body = '<!doctype html><html lang="en"><head>'
        '<meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>FlashLearn TV</title>'
        '<style>html,body{height:100%;margin:0;background:#0f172a;color:#f8fafc;'
        'font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif}'
        '.w{height:100%;display:flex;flex-direction:column;align-items:center;'
        'justify-content:center;text-align:center;padding:4vh 6vw}'
        'h1{font-size:5vh;margin:0 0 2vh}p{font-size:3vh;margin:0;color:#cbd5e1}'
        '.e{font-size:12vh;line-height:1;margin-bottom:2vh}</style>'
        '</head><body><div class="w"><div class="e">📺</div>'
        '<h1>FlashLearn TV</h1>'
        '<p>Ask your teacher for the cast link shown on their screen.</p>'
        '</div></body></html>';
    return Response.notFound(
      body,
      headers: {
        HttpHeaders.contentTypeHeader: 'text/html; charset=utf-8',
        HttpHeaders.cacheControlHeader: 'no-store',
      },
    );
  }
}
