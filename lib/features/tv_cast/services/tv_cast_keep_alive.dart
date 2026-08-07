import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';


/// Asks Android to keep this process alive while a cast is serving.
///
/// The cast server is plain Dart in the app process, so a backgrounded or
/// screen-off tablet can have it reclaimed in the middle of a lesson — the TV
/// just starts showing "Oops, the teacher is connecting" with nothing on the
/// phone to explain why. The native side runs a `dataSync` foreground service
/// (see `CastForegroundService.kt`) whose ongoing notification is also the
/// out-of-app reminder that a class is still watching.
///
/// **Every method is best-effort and never throws.** A denied notification
/// permission, an OEM background-start restriction, or a non-Android platform
/// simply means the cast behaves exactly as it did before this existed — it
/// keeps working, it just loses the process guarantee. Casting must never fail
/// because a notification couldn't be posted.
class TvCastKeepAlive {
  TvCastKeepAlive._();

  /// Mirrors `MainActivity.CAST_CHANNEL`.
  static const _channel = MethodChannel('flashlearn/tv_cast_keepalive');

  /// Whether the platform has a keep-alive implementation at all. iOS has no
  /// equivalent for a background listening socket, so we don't pretend.
  static bool get isSupported => Platform.isAndroid;

  /// Starts (or refreshes) the ongoing notification. [code] is the cast
  /// session code and [detail] the one-line status shown under the title.
  static Future<void> start({required String code, required String detail}) =>
      _invoke('start', code: code, detail: detail);

  /// Updates the existing notification in place — same call as [start] on the
  /// native side, kept separate so call sites read as what they mean.
  static Future<void> update({
    required String code,
    required String detail,
  }) =>
      _invoke('update', code: code, detail: detail);

  /// Drops the notification and lets the process be reclaimed normally.
  static Future<void> stop() => _invoke('stop');

  static Future<void> _invoke(
    String method, {
    String code = '',
    String detail = '',
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>(method, {
        'code': code,
        'detail': detail,
      });
    } catch (e) {
      // Swallowed on purpose — see the class doc. Surfaced in debug builds
      // only, so a broken channel is findable without ever reaching a teacher.
      if (kDebugMode) debugPrint('TvCastKeepAlive.$method failed: $e');
    }
  }
}
