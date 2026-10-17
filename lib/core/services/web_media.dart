import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../utils/web_download.dart';
import 'media_url_resolver.dart';
import 'shared_media_service.dart';

/// Where the browser version shows or plays a media value from. A browser
/// has no files, and its video player plays addresses only (a downloaded
/// "file" handed to it failed: test questions' linked videos said they could
/// not play), so: a link plays from its own address, and a shared file
/// (`shared://…`) from its bytes held in memory, through a `blob:` address.
///
/// Devices keep using their files (`AssessmentMediaCache.fileFor`,
/// `SharedMediaService.resolve`): those work offline.
abstract final class WebMedia {
  /// Test seam for [objectUrlFor], which only a browser has.
  @visibleForTesting
  static String Function(Uint8List bytes, String mimeType)? debugObjectUrl;

  /// The addresses made so far, by value, oldest first, with the size of
  /// what each holds.
  static final Map<String, ({String url, int size})> _urls = {};

  /// Addresses still being made, so a value asked for twice at once gets
  /// one (an address made twice would never be let go).
  static final Map<String, Future<String?>> _making = {};

  /// How many shared files keep an address at once; the oldest is let go.
  static const int _maxUrls = 40;

  /// How much the addresses may hold together (each is a copy the browser
  /// keeps until it is let go; a shared file is up to 15 MB, so 40 could
  /// pass half a gigabyte on a phone). The oldest is let go first.
  @visibleForTesting
  static int byteBudget = 96 * 1024 * 1024;

  /// The values that hold an address now, oldest first.
  @visibleForTesting
  static List<String> get debugHeld => List.unmodifiable(_urls.keys);

  @visibleForTesting
  static void debugReset() {
    _urls.clear();
    _making.clear();
  }

  /// An address a browser's image, video or audio element can open for
  /// [value], or null: a file on another device, a bundled asset (played
  /// with the asset APIs), or a shared file that could not be fetched.
  /// [video] makes a Cloudinary GIF link the MP4 a video player can play.
  static Future<String?> urlFor(String value, {bool video = false}) async {
    final v = value.trim();
    if (v.startsWith('http://') || v.startsWith('https://')) {
      final direct = await MediaUrlResolver.resolve(v) ?? v;
      return video ? MediaUrlResolver.asPlayableVideo(direct) : direct;
    }
    if (!SharedMediaService.isShared(v)) return null;
    final known = _urls.remove(v);
    if (known != null) {
      _urls[v] = known; // now the most recently shown
      return known.url;
    }
    // A block body: an arrow would hand whenComplete the very future it is
    // completing (remove returns it), and it would wait for itself forever.
    return _making[v] ??= _make(v).whenComplete(() {
      _making.remove(v);
    });
  }

  static Future<String?> _make(String v) async {
    final got = await const SharedMediaService().resolveBytes(v);
    if (got == null) return null;
    final url = (debugObjectUrl ??
        (Uint8List b, String m) => objectUrlFor(b, mimeType: m))(
      got.bytes,
      got.mimeType,
    );
    _urls[v] = (url: url, size: got.bytes.length);
    var total = 0;
    for (final held in _urls.values) {
      total += held.size;
    }
    while (_urls.length > 1 &&
        (_urls.length > _maxUrls || total > byteBudget)) {
      final gone = _urls.remove(_urls.keys.first)!;
      total -= gone.size;
      if (debugObjectUrl == null) revokeObjectUrl(gone.url);
    }
    return url;
  }
}
