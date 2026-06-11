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
  TvCastServer({required this.getSession});

  /// Source-of-truth callback the server reads on every request. Lets
  /// the server stay decoupled from the Riverpod notifier (which owns
  /// the actual session state).
  final TvCastSession Function() getSession;

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

  Response _serveState(Request _) {
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
        map['slide'] = {
          'index': idx,
          'total': cards.length,
          'wordEn': card.wordEnglish,
          'wordFil': card.wordFilipino,
          'example': card.exampleSentence,
          'emoji': TvCastAssetBridge.emojiFor(card),
          // Category visuals so the TV paints a card matching the in-app one.
          ...TvCastAssetBridge.categoryVisual(cat),
        };
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
        map['story'] = {
          'titleEn': story.titleEn,
          'titleFil': story.titleFil,
          'emoji': story.emoji,
          'pageIndex': pageIdx,
          'totalPages': pages.length,
          'textEn': pages[pageIdx],
          'textFil': pageIdx < pagesFil.length ? pagesFil[pageIdx] : '',
        };
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

    final total = await file.length();
    if (total <= 0) return Response.notFound('empty video');

    // Honour Range requests for chunked playback on older TV browsers that
    // can't reliably stream a whole 30 MB clip in one shot. Stream straight
    // off disk via openRead so the file is never fully buffered in memory.
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
              HttpHeaders.contentTypeHeader: 'video/mp4',
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
        HttpHeaders.contentTypeHeader: 'video/mp4',
        HttpHeaders.contentLengthHeader: total.toString(),
        HttpHeaders.acceptRangesHeader: 'bytes',
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
