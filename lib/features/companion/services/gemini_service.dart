import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Optional online answer source for the AI Companion, backed by Google
/// Gemini's free tier.
///
/// This is strictly **opt-in and additive**: the companion's default brain is
/// the offline [TutorEngine], and this service is only consulted for free-form
/// questions when (a) a key was compiled in via
/// `--dart-define=GEMINI_API_KEY=...` and (b) the learner enabled "Smarter
/// Online Answers". Every failure path (no key, offline, timeout, bad response)
/// returns null so the caller can fall straight back to the offline engine —
/// the app never depends on the network.
///
/// Uses `dart:io`'s [HttpClient] so it adds no new package dependency. The key
/// is read from the compile-time environment, never hard-coded; treat a shipped
/// key as public (it is extractable from the APK), so scope/limit it in the
/// Google AI Studio console.
class GeminiService {
  /// Compile-time key: `flutter run --dart-define=GEMINI_API_KEY=xxxx`.
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Overridable model id (free-tier default). `--dart-define=GEMINI_MODEL=...`.
  ///
  /// flash-lite is the deliberate default: it has healthy free-tier quota and
  /// does no "thinking" — on the thinking models (2.5-flash and newer), hidden
  /// reasoning tokens count against maxOutputTokens and truncated every answer
  /// mid-sentence (finishReason MAX_TOKENS) during integration testing.
  static const String _model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash-lite',
  );

  /// True only when a key was baked in at build time.
  static bool get isConfigured => _apiKey.isNotEmpty;

  /// Returns a short, learner-friendly answer to [question], or null on any
  /// failure (so the caller falls back to the offline engine).
  Future<String?> answer({
    required String question,
    String? learnerName,
    bool isFilipino = false,
  }) async {
    if (!isConfigured) return null;

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$_apiKey',
    );
    final payload = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt(learnerName, isFilipino)}
        ]
      },
      'contents': [
        {
          'parts': [
            {'text': question}
          ]
        }
      ],
      // Keep it short and gentle — good for cognitive load and low free-tier
      // token use. The budget leaves headroom so a reply is never cut
      // mid-sentence; the system prompt is what keeps answers short.
      'generationConfig': {
        'maxOutputTokens': 300,
        'temperature': 0.7,
      },
    });

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(payload));
      final response =
          await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        _log('HTTP ${response.statusCode}: $body');
        return null;
      }
      return _extractText(body);
    } catch (e) {
      // Offline / DNS / timeout / TLS — all non-fatal; caller uses the engine.
      _log('request failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Pulls the concatenated text out of a Gemini `generateContent` response.
  String? _extractText(String body) {
    try {
      final data = jsonDecode(body);
      if (data is! Map) return null;
      final candidates = data['candidates'];
      if (candidates is! List || candidates.isEmpty) return null;
      final content = (candidates.first as Map)['content'];
      final parts = content is Map ? content['parts'] : null;
      if (parts is! List) return null;
      final buffer = StringBuffer();
      for (final part in parts) {
        if (part is Map && part['text'] is String) {
          buffer.write(part['text'] as String);
        }
      }
      final out = buffer.toString().trim();
      return out.isEmpty ? null : out;
    } catch (e) {
      _log('parse failed: $e');
      return null;
    }
  }

  String _systemPrompt(String? name, bool isFilipino) {
    final who = (name == null || name.isEmpty) ? 'a young learner' : name;
    return 'You are a warm, patient learning buddy inside FlashLearn, a bilingual '
        '(English and Filipino) vocabulary app for Filipino children and students '
        'with disabilities. You are talking to $who. '
        'Answer in 1 to 3 short, simple sentences a young learner can easily '
        'understand. Be kind and encouraging. Avoid difficult words, bullet '
        'lists, markdown, and code. '
        '${isFilipino ? 'Reply in simple Filipino (Tagalog).' : 'Reply in simple English.'} '
        'If a question is unrelated to learning or is not appropriate, gently '
        'guide the learner back to learning new words.';
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('GeminiService $message');
  }
}

/// Global provider for the optional online answer source.
final geminiServiceProvider = Provider<GeminiService>((ref) => GeminiService());
