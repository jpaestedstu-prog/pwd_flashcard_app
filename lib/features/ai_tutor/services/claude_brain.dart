import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/tutor_brain_models.dart';
import '../models/tutor_models.dart';

/// Raw-HTTP client for the Anthropic Messages API, specialized for the kids'
/// tutor. Pure Dart (injectable transport, no Hive/plugins) so every error
/// path is unit-testable with canned fixtures.
///
/// Safety model:
/// - The system prompt pins a fixed child-safe persona; topics outside the
///   app's vocabulary/FSL/encouragement scope are refused by instruction.
/// - Structured output (`output_config.format` json_schema) constrains the
///   reply to `{content, action, quizWord?}` — the model can *suggest* a quiz
///   word but never produces options or answer keys; those are built and
///   graded locally by the router from SeedData.
/// - No sampling params are sent (removed on current Claude models) and the
///   prompt is far below the prompt-cache minimum, so no cache_control.
class ClaudeBrain {
  static const String endpoint = 'https://api.anthropic.com/v1/messages';
  static const String _anthropicVersion = '2023-06-01';
  static const Duration timeout = Duration(seconds: 12);

  /// Models the educator can choose between (id → label).
  static const Map<String, String> supportedModels = {
    'claude-opus-4-8': 'Best (Opus 4.8)',
    'claude-sonnet-4-6': 'Balanced (Sonnet 4.6)',
    'claude-haiku-4-5': 'Budget (Haiku 4.5)',
  };

  static const String defaultModel = 'claude-opus-4-8';

  final String apiKey;
  final String model;
  final ClaudeTransport _transport;

  ClaudeBrain({
    required this.apiKey,
    this.model = defaultModel,
    ClaudeTransport? transport,
  }) : _transport = transport ?? _httpTransport;

  /// Fixed persona. Keep byte-stable; safety review lives here.
  static const String systemPrompt =
      'You are a friendly learning buddy inside an educational app for deaf '
      'and hard-of-hearing children who are learning English/Filipino '
      'vocabulary and Filipino Sign Language (FSL).\n'
      'Rules you must always follow:\n'
      '- Reply with at most 2 short, simple, warm sentences. Emojis are fine.\n'
      '- Talk only about: the app\'s vocabulary words, FSL practice, '
      'encouragement, and the student\'s own progress numbers given to you.\n'
      '- Never ask for or repeat personal information. Never mention links, '
      'websites, brands, or anything outside the app.\n'
      '- If the student writes in Filipino, answer in Filipino; otherwise '
      'answer in English.\n'
      '- You may attach one action: "quickQuiz" (also set quizWord to ONE '
      'word chosen from the candidate list you were given), "startLesson" '
      '(start today\'s practice plan), "practiceRedirect" (send them to '
      'guided practice), "encouragement", or "none".';

  /// JSON schema mirroring [ClaudeReply].
  static const Map<String, dynamic> replySchema = {
    'type': 'object',
    'properties': {
      'content': {'type': 'string'},
      'action': {
        'type': 'string',
        'enum': [
          'none',
          'quickQuiz',
          'practiceRedirect',
          'startLesson',
          'encouragement',
        ],
      },
      'quizWord': {'type': 'string'},
    },
    'required': ['content', 'action'],
    'additionalProperties': false,
  };

  Future<ClaudeReply> analyze(TutorContext context) {
    final prompt = context.isFilipino
        ? 'Batiin ako at magmungkahi ng isang susunod na hakbang ngayon.'
        : 'Give me a short check-in and suggest one next step for today.';
    return _send(prompt, context);
  }

  Future<ClaudeReply> respondToQuestion(
    String question,
    TutorContext context,
  ) {
    return _send(question, context);
  }

  Future<ClaudeReply> _send(String userText, TutorContext context) async {
    final body = json.encode({
      'model': model,
      'max_tokens': 400,
      'system': systemPrompt,
      'messages': _buildMessages(userText, context),
      'output_config': {
        'format': {'type': 'json_schema', 'schema': replySchema},
      },
    });

    late final ClaudeHttpResponse response;
    try {
      response = await _transport(body, {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': _anthropicVersion,
      }).timeout(timeout);
    } on TimeoutException {
      throw const TutorBrainException('timeout');
    } on TutorBrainException {
      rethrow;
    } catch (_) {
      throw const TutorBrainException('network');
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 401:
      case 403:
        throw const TutorBrainException('auth');
      case 429:
        throw const TutorBrainException('rate_limited');
      case 529:
        throw const TutorBrainException('overloaded');
      default:
        if (response.statusCode >= 500) {
          throw const TutorBrainException('overloaded');
        }
        throw TutorBrainException('http_${response.statusCode}');
    }

    return _parseReply(response.body);
  }

  /// Recent turns (student→user, tutor→assistant) followed by a volatile
  /// user turn carrying the progress snapshot + the new question. History is
  /// trimmed so the first message is a user turn, as the API requires.
  List<Map<String, dynamic>> _buildMessages(
    String userText,
    TutorContext context,
  ) {
    final messages = <Map<String, dynamic>>[];
    var seenUser = false;
    for (final m in context.recentMessages) {
      final isStudent = m.role == TutorMessageRole.student;
      if (!seenUser && !isStudent) continue;
      seenUser = true;
      if (m.content.trim().isEmpty) continue;
      messages.add({
        'role': isStudent ? 'user' : 'assistant',
        'content': m.content,
      });
    }
    messages.add({'role': 'user', 'content': _userTurn(userText, context)});
    return messages;
  }

  String _userTurn(String userText, TutorContext context) {
    final progress = context.progress;
    final buf = StringBuffer()
      ..writeln('[student snapshot]')
      ..writeln('name: ${context.studentName}')
      ..writeln('prefers Filipino: ${context.isFilipino}')
      ..writeln('words learned: ${progress.wordsLearned}')
      ..writeln('stars: ${progress.totalStars}')
      ..writeln('streak days: ${progress.streakDays}');
    final weak = context.weakCategories;
    if (weak.isNotEmpty) {
      buf.writeln('weak categories: ${weak.take(3).join(', ')}');
    }
    if (context.dueReviewWords.isNotEmpty) {
      buf.writeln(
        'quiz word candidates: ${context.dueReviewWords.join(', ')}',
      );
    }
    buf
      ..writeln('[student says]')
      ..write(userText);
    return buf.toString();
  }

  ClaudeReply _parseReply(String responseBody) {
    Map<String, dynamic> decoded;
    try {
      decoded = json.decode(responseBody) as Map<String, dynamic>;
    } catch (_) {
      throw const TutorBrainException('malformed');
    }

    if (decoded['stop_reason'] == 'refusal') {
      throw const TutorBrainException('refusal');
    }

    try {
      final content = (decoded['content'] as List)
          .cast<Map>()
          .firstWhere((b) => b['type'] == 'text');
      final reply =
          json.decode(content['text'] as String) as Map<String, dynamic>;
      final text = (reply['content'] as String?)?.trim() ?? '';
      if (text.isEmpty) throw const TutorBrainException('malformed');
      return ClaudeReply(
        content: text,
        actionKind: reply['action'] as String? ?? 'none',
        quizWord: reply['quizWord'] as String?,
      );
    } on TutorBrainException {
      rethrow;
    } catch (_) {
      throw const TutorBrainException('malformed');
    }
  }

  // ─── Default transport (dart:io, no extra dependency) ───

  static Future<ClaudeHttpResponse> _httpTransport(
    String body,
    Map<String, String> headers,
  ) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(Uri.parse(endpoint));
      headers.forEach(request.headers.set);
      request.add(utf8.encode(body));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      return ClaudeHttpResponse(response.statusCode, responseBody);
    } finally {
      client.close(force: true);
    }
  }
}

/// Injectable transport so tests can feed canned API responses.
typedef ClaudeTransport = Future<ClaudeHttpResponse> Function(
  String requestBodyJson,
  Map<String, String> headers,
);

class ClaudeHttpResponse {
  final int statusCode;
  final String body;
  const ClaudeHttpResponse(this.statusCode, this.body);
}

/// Typed failure with the fallback-reason string the router logs.
class TutorBrainException implements Exception {
  final String reason;
  const TutorBrainException(this.reason);

  @override
  String toString() => 'TutorBrainException($reason)';
}
