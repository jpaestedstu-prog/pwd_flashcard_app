import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import 'media_url_resolver.dart';

/// A resolved, on-device "Show Me" clip for an action word.
class ActionClip {
  /// The downloaded, cached file ready to play / display.
  final File file;

  /// True when the clip is an animated GIF (render with `Image.file`); false
  /// for a video container such as MP4/WebM (render with `video_player`).
  final bool isGif;

  const ActionClip({required this.file, required this.isGif});
}

/// Resolves a short looping "Show Me" clip (a character performing an action)
/// for action-word flashcards, served from an on-device cache.
///
/// Same host-and-download model as [FlashcardPhotoService] / [FslAssetsService]
/// — nothing is bundled in the APK. The manifest
/// `assets/data/action_clip_manifest.json` says where clips live:
///
/// ```json
/// {
///   "base_url": "https://example.com/action-clips",
///   "ext": "mp4",
///   "overrides": { "Actions__clap": "https://example.com/clips/clap.gif" }
/// }
/// ```
///
/// URL precedence for a card:
///   1. `overrides["<Category label>__<wordEnglish lowercased>"]`, else
///   2. `<base_url>/<Category label>/<wordEnglish>.<ext>` (percent-encoded).
///
/// Both MP4 (looping video) and GIF (looping image) are supported; the format
/// is inferred from the resolved URL's extension. With an empty `base_url` and
/// no override the card has no clip and the "Show Me" affordance hides itself,
/// so the feature is dormant — and safe — until a real `base_url` is set.
class ActionClipService {
  ActionClipService._();

  static const String _manifestAsset =
      'assets/data/action_clip_manifest.json';

  static String _baseUrl = '';
  static String _ext = 'mp4';
  static final Map<String, String> _overrides = {};

  static Future<void>? _loaded;

  static final BaseCacheManager _clipCache = CacheManager(
    Config(
      'action_clips_cache',
      stalePeriod: const Duration(days: 90),
      maxNrOfCacheObjects: 200,
    ),
  );

  /// Parses the manifest once. Failures leave the feature dormant.
  static Future<void> load() => _loaded ??= _load();

  static Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(_manifestAsset);
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        _baseUrl = (decoded['base_url'] as String?)?.trim() ?? '';
        final ext = (decoded['ext'] as String?)?.trim();
        if (ext != null && ext.isNotEmpty) _ext = ext.replaceAll('.', '');
        final overrides = decoded['overrides'];
        if (overrides is Map) {
          overrides.forEach((k, v) {
            if (v is String && v.trim().isNotEmpty) {
              _overrides[k.toString()] = v.trim();
            }
          });
        }
      }
    } catch (_) {
      // No manifest / malformed → no clips.
    }
  }

  /// Clears parsed manifest state. Used by tests.
  static void reset() {
    _loaded = null;
    _baseUrl = '';
    _ext = 'mp4';
    _overrides.clear();
  }

  static String _keyFor(Flashcard card) =>
      '${card.category.label}__${card.wordEnglish.toLowerCase()}';

  /// Remote URL for [card]'s clip, or null when none is configured.
  static String? urlFor(Flashcard card) {
    final override = _overrides[_keyFor(card)];
    if (override != null) return override;
    if (_baseUrl.isEmpty) return null;
    final cat = Uri.encodeComponent(card.category.label);
    final word = Uri.encodeComponent(card.wordEnglish);
    return '$_baseUrl/$cat/$word.$_ext';
  }

  /// True if a "Show Me" clip source exists for [card].
  static bool hasClip(Flashcard card) => urlFor(card) != null;

  /// True if [card]'s clip is an animated GIF (render as a looping image)
  /// rather than a video container. Inferred synchronously from the *authored*
  /// URL extension — matching [resolveClip]'s decision — so callers (e.g. the
  /// TV Cast server) can pick the right content type without downloading first.
  /// False when there is no clip.
  static bool isGifFor(Flashcard card) {
    final url = urlFor(card);
    return url != null && _looksLikeGif(url);
  }

  static bool _looksLikeGif(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    return path.toLowerCase().endsWith('.gif');
  }

  /// Resolves [card]'s clip to a cached on-device file, downloading on first
  /// call. Share-page URLs (Streamable, postimg) are resolved to a direct media
  /// URL first. Returns null when there is no source or the fetch fails. Never
  /// throws — the caller shows a friendly message instead.
  static Future<ActionClip?> resolveClip(Flashcard card) async {
    final url = urlFor(card);
    if (url == null) return null;
    final key = _keyFor(card);

    // The GIF-vs-video decision is based on the *authored* URL extension, so a
    // Streamable page (no extension) is treated as video and a `.gif` override
    // as an animated image — independent of the resolved CDN URL's query.
    final isGif = _looksLikeGif(url);

    try {
      final cached = await _clipCache.getFileFromCache(key);
      if (cached != null) return ActionClip(file: cached.file, isGif: isGif);
    } catch (_) {
      // fall through to resolve + download
    }

    final direct = await MediaUrlResolver.resolve(url);
    if (direct == null) return null;

    try {
      final file = await _clipCache.getSingleFile(direct, key: key);
      return ActionClip(file: file, isGif: isGif);
    } catch (_) {
      return null;
    }
  }
}
