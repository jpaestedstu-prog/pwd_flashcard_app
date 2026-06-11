import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-Text service for voice input in games.
///
/// Supports English (en-US) and Filipino (fil-PH).
/// Use [startListening] to begin recognition and [stopListening] to end.
class SttService {
  final SpeechToText _stt = SpeechToText();
  bool _isInitialized = false;
  bool _isAvailable = false;

  /// Whether speech recognition is available on this device.
  bool get isAvailable => _isAvailable;

  /// Whether the service is currently listening.
  bool get isListening => _stt.isListening;

  /// Initialize the STT engine. Must be called before [startListening].
  Future<bool> init() async {
    if (_isInitialized) return _isAvailable;
    _isAvailable = await _stt.initialize(
      onError: (error) {
        // Silently handle errors; callers should rely on the onResult callback
      },
      onStatus: (status) {
        // Status updates: 'listening', 'notListening', 'done'
      },
    );
    _isInitialized = true;
    return _isAvailable;
  }

  /// Start listening for speech. Calls [onResult] with the recognized text
  /// whenever partial or final results arrive.
  ///
  /// [locale] should be 'en-US' or 'fil-PH'.
  /// [onResult] receives the best transcription string.
  Future<void> startListening({
    required String locale,
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!_isInitialized) await init();
    if (!_isAvailable) return;

    await _stt.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        localeId: locale,
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  /// Stop listening.
  Future<void> stopListening() async {
    await _stt.stop();
  }

  /// Cancel listening without processing results.
  Future<void> cancel() async {
    await _stt.cancel();
  }

  /// Dispose of the STT engine.
  Future<void> dispose() async {
    await _stt.stop();
  }

  // ─── Fuzzy Matching Utilities ───────────────────────

  /// Compare [spoken] to [expected] with fuzzy tolerance.
  /// Returns true if it's a close enough match (Levenshtein distance ≤ 1
  /// for short words, or ≤ ~10% of word length for longer words).
  static bool isFuzzyMatch(String spoken, String expected) {
    final a = spoken.trim().toLowerCase();
    final b = expected.trim().toLowerCase();
    if (a == b) return true;
    final maxDist = b.length <= 5 ? 1 : (b.length * 0.15).ceil();
    return levenshteinDistance(a, b) <= maxDist;
  }

  /// Compute the Levenshtein edit distance between two strings.
  static int levenshteinDistance(String s, String t) {
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    final m = s.length;
    final n = t.length;
    // Use two rows for space efficiency
    var prev = List<int>.generate(n + 1, (i) => i);
    var curr = List<int>.filled(n + 1, 0);
    for (int i = 1; i <= m; i++) {
      curr[0] = i;
      for (int j = 1; j <= n; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1, // deletion
          curr[j - 1] + 1, // insertion
          prev[j - 1] + cost, // substitution
        ].reduce(min);
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }
    return prev[n];
  }
}

/// Global STT provider
final sttServiceProvider = Provider<SttService>((ref) {
  final service = SttService();
  ref.onDispose(() => service.dispose());
  return service;
});
