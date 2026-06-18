import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
class TvCastServer {
  TvCastServer({required this.getSession, this.onTvAudioReport});

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

  HttpServer? _httpServer;
  int? _boundPort;

  /// Distinct client IPs that hit any endpoint in the last 30 s. Backs
  /// the "N viewers connected" indicator on the phone-side UI.
  final Map<String, DateTime> _seenClients = {};

  int get boundPort => _boundPort ?? 0;
  bool get isRunning => _httpServer != null;

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

    final handler = const Pipeline()
        .addMiddleware(_corsHeaders)
        .addMiddleware(_recordClient)
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
    throw StateError(
      'TvCastServer: could not bind to ports '
      '$preferredPort..${preferredPort + maxAttempts - 1}: $lastErr',
    );
  }

  Future<void> stop() async {
    final s = _httpServer;
    _httpServer = null;
    _boundPort = null;
    _seenClients.clear();
    if (s != null) {
      await s.close(force: true);
    }
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
    r.get(
      '/idle.html',
      _serveStaticAsset('assets/tv_cast/idle.html', 'text/html; charset=utf-8'),
    );

    r.get('/api/state', _serveState);
    r.get('/api/video/<catIdx>/<wordSlug>', _serveVideo);
    r.get('/api/story-video/<storyId>/<pageIdx>', _serveStoryVideo);
    r.get('/api/story-image/<storyId>/<pageIdx>/<face>', _serveStoryImage);
    r.get('/api/image/<catIdx>/<wordSlug>', _serveImage);
    r.get('/api/clip/<catIdx>/<wordSlug>', _serveClip);
    r.get('/healthz', (Request _) => Response.ok('ok'));

    return r;
  }

  Future<Response> _serveIndex(Request _) async {
    final body = await TvCastAssetBridge.loadAssetString(
      'assets/tv_cast/index.html',
    );
    if (body == null) {
      return Response.notFound('index.html missing from bundle');
    }
    return Response.ok(
      body,
      headers: {
        HttpHeaders.contentTypeHeader: 'text/html; charset=utf-8',
        HttpHeaders.cacheControlHeader: 'no-store',
      },
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
        // be downloaded yet; the TV fetches /api/image and flips emoji→photo on
        // tap (and stays on the emoji if it never loads).
        if (TvCastAssetBridge.hasPhoto(card)) {
          slideMap['photo'] = {
            'available': true,
            'url': '/api/image/${cat.index}/$slug',
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
          // Any source counts — bundled, direct download, or Streamable. The
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
          }
        }
      }
    }

    return map;
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
    // Streamable on first request). The phone prefetches the current + next
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

  Middleware get _corsHeaders => (Handler inner) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsResponseHeaders);
      }
      final response = await inner(request);
      return response.change(
        headers: {...response.headersAll, ..._corsResponseHeaders},
      );
    };
  };

  static const Map<String, String> _corsResponseHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Range',
  };

  Middleware get _recordClient => (Handler inner) {
    return (Request request) async {
      final ctx = request.context['shelf.io.connection_info'];
      if (ctx is HttpConnectionInfo) {
        _seenClients[ctx.remoteAddress.address] = DateTime.now();
      }
      return inner(request);
    };
  };
}
