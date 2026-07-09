import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-Text service for voice input in games and Gaze Control voice
/// commands.
///
/// Supports English (en-US) and Filipino (fil-PH), falling back to the closest
/// recognizer locale installed on the device.
/// Use [startListening] to begin recognition and [stopListening] to end.
class SttService {
  // Not final: [reset] replaces it with a fresh instance to recover a wedged
  // recognizer (the plugin caches `_initWorked`, so re-initialising the *same*
  // instance never re-binds the platform recogniser — see [reset]).
  SpeechToText _stt = SpeechToText();
  bool _isAvailable = false;
  Future<bool>? _initInFlight;
  List<LocaleName>? _locales;

  /// Whether speech recognition is available on this device.
  bool get isAvailable => _isAvailable;

  /// Whether the service is currently listening.
  bool get isListening => _stt.isListening;

  /// Initialize the STT engine. Must be called before [startListening].
  ///
  /// Only success is cached: a failed attempt (mic permission not yet granted,
  /// recognizer briefly unavailable) is retried on the next call, so granting
  /// the permission later brings voice input back without an app restart.
  /// Concurrent callers (e.g. a gaze scope and a game) share one attempt.
  Future<bool> init() async {
    if (_isAvailable) return true;
    final inFlight = _initInFlight;
    if (inFlight != null) return inFlight;
    final attempt = _stt.initialize(
      onError: (e) => _log('error: ${e.errorMsg} (permanent: ${e.permanent})'),
      onStatus: (status) => _log('status: $status'),
    );
    _initInFlight = attempt;
    try {
      _isAvailable = await attempt;
    } catch (e) {
      _log('init failed: $e');
      _isAvailable = false;
    } finally {
      _initInFlight = null;
    }
    _log('init → available: $_isAvailable');
    return _isAvailable;
  }

  /// Tears the recogniser down to a clean slate so the next [init] fully
  /// re-binds the platform speech service.
  ///
  /// The plugin's `SpeechToText.initialize()` short-circuits once it has
  /// succeeded (`_initWorked`), so re-initialising the *same* instance can
  /// never recover a recogniser that has wedged into a persistent client-side
  /// error (`error_client` on every session, regardless of spacing). Only a
  /// **fresh** [SpeechToText] re-creates the underlying Android
  /// `SpeechRecognizer` client. The gaze voice loop calls this after a run of
  /// consecutive rejections.
  Future<void> reset() async {
    _log('reset: recreating recogniser');
    try {
      await _stt.cancel();
    } catch (_) {
      // A wedged recogniser may throw on cancel — the replacement below is
      // what actually recovers it, so ignore.
    }
    _stt = SpeechToText();
    _isAvailable = false;
    _initInFlight = null;
    _locales = null;
  }

  /// Start listening for speech. Calls [onResult] with the recognized text
  /// whenever partial or final results arrive.
  ///
  /// [locale] should be 'en-US' or 'fil-PH'.
  /// [onResult] receives the best transcription string.
  /// [listenFor] / [pauseFor] bound the session; the defaults suit dictation
  /// (games), while short-command callers pass a smaller [pauseFor] so a final
  /// result lands sooner after the speaker stops.
  ///
  /// [partialResults] streams the running hypothesis as the learner speaks
  /// (default on). Gaze voice commands rely on it — a command fires from the
  /// first *stable partial* instead of waiting out the full pause window, and
  /// many sessions never deliver a final at all (the recogniser kills them
  /// with `error_no_match`), so a partial is often the only text there is.
  Future<void> startListening({
    required String locale,
    required void Function(String text, bool isFinal) onResult,
    Duration listenFor = const Duration(seconds: 8),
    Duration pauseFor = const Duration(seconds: 3),
    bool partialResults = true,
  }) async {
    if (!await init()) return;

    await _stt.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        localeId: await _resolveLocale(locale),
        listenFor: listenFor,
        pauseFor: pauseFor,
        partialResults: partialResults,
      ),
    );
  }

  /// Maps the requested locale onto one the device's recognizer actually has —
  /// exact match first, then same language (so 'fil-PH' finds 'fil_PH'), else
  /// null to let the recognizer use its own default. Without this, asking for
  /// an uninstalled locale makes every listen session fail silently.
  Future<String?> _resolveLocale(String requested) async {
    try {
      _locales ??= await _stt.locales();
    } catch (e) {
      _log('locales() failed: $e');
      return requested;
    }
    final available = _locales!;
    // Some engines report no locales but still recognize; keep the request.
    if (available.isEmpty) return requested;
    String norm(String id) => id.replaceAll('_', '-').toLowerCase();
    final want = norm(requested);
    for (final l in available) {
      if (norm(l.localeId) == want) return l.localeId;
    }
    final lang = want.split('-').first;
    for (final l in available) {
      if (norm(l.localeId).split('-').first == lang) return l.localeId;
    }
    _log('locale $requested unavailable → recognizer default');
    return null;
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('SttService $message');
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
