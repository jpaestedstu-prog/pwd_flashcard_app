import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether the display stays on while FlashLearn is in front.
///
/// A learner steering by Gaze Control (head movement, blinks, voice commands)
/// makes no touches and presses no keys, so the device's own screen timeout
/// would blank the display under them, and some makers' power managers then
/// freeze the camera and microphone with it. So the app used to keep the
/// screen on for everyone, always: a tablet left open on a desk never slept,
/// and every other learner's battery paid for it. Now it stays on only while
/// the active profile steers hands-free; otherwise the device decides, as for
/// any app. (A game controller or a keyboard counts as use: Android restarts
/// its timeout on every key.)
///
/// Android only (`MainActivity.SCREEN_CHANNEL`), which keeps the screen on at
/// launch until it hears from here. Best-effort: never throws.
abstract final class ScreenAwake {
  static const MethodChannel _channel = MethodChannel('flashlearn/screen');

  static bool? _last;

  /// Asks for the display to stay on ([on]), or to follow the device's own
  /// screen timeout. Called from `build`: repeated calls with the same answer
  /// send nothing.
  static void keepOn(bool on) {
    if (_last == on) return;
    _last = on;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _channel.invokeMethod<void>('keepOn', on).catchError((Object e) {
      if (kDebugMode) debugPrint('ScreenAwake.keepOn failed: $e');
    });
  }

  /// Forgets the last answer, so the next call is sent: one test's state must
  /// not leak into the next.
  @visibleForTesting
  static void reset() => _last = null;
}
