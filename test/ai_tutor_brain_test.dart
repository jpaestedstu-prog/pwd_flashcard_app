import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/utils/research_export_rows.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/ai_tutor/models/tutor_brain_models.dart';
import 'package:pwdpwdpwd/features/ai_tutor/models/tutor_models.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/claude_brain.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/tutor_brain_router.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/tutor_brain_settings.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/tutor_interaction_log.dart';

const _pid = 'tutor-brain-test';

TutorContext _context({List<TutorMessage> recent = const []}) => TutorContext(
      profileId: _pid,
      studentName: 'Ana',
      isFilipino: false,
      progress: LearningProgress(
        profileId: _pid,
        wordsLearned: 12,
        streakDays: 3,
        lastActivityDate: DateTime(2026, 6, 10),
        categoryProgress: const {'Animals': 0.2, 'Colors & Shapes': 0.9},
      ),
      recentMessages: recent,
      dueReviewWords: const ['Dog (Aso)', 'Cat (Pusa)'],
    );

/// Canned Anthropic Messages API response with a structured-output text block.
String _apiBody({
  String content = 'Great job today!',
  String action = 'none',
  String? quizWord,
  String stopReason = 'end_turn',
}) =>
    json.encode({
      'type': 'message',
      'stop_reason': stopReason,
      'content': [
        {
          'type': 'text',
          'text': json.encode({
            'content': content,
            'action': action,
            'quizWord': ?quizWord,
          }),
        },
      ],
    });

ClaudeTransport _respondWith(int status, String body) =>
    (requestBody, headers) async => ClaudeHttpResponse(status, body);

void main() {
  late Box settingsBox;
  late Box progressBox;

  setUpAll(() async {
    Hive.init('./build/test_cache/ai_tutor_brain');
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
    if (!Hive.isBoxOpen('progress')) await Hive.openBox('progress');
    settingsBox = Hive.box('settings');
    progressBox = Hive.box('progress');
  });

  setUp(() async {
    await settingsBox.clear();
    await progressBox.clear();
  });

  group('ClaudeBrain request shape', () {
    test('sends model, child-safe system prompt and json_schema format',
        () async {
      late Map<String, dynamic> sentBody;
      late Map<String, String> sentHeaders;
      final brain = ClaudeBrain(
        apiKey: 'sk-test',
        transport: (body, headers) async {
          sentBody = json.decode(body) as Map<String, dynamic>;
          sentHeaders = headers;
          return ClaudeHttpResponse(200, _apiBody());
        },
      );

      await brain.respondToQuestion('How am I doing?', _context());

      expect(sentHeaders['x-api-key'], 'sk-test');
      expect(sentHeaders['anthropic-version'], '2023-06-01');
      expect(sentBody['model'], ClaudeBrain.defaultModel);
      expect(sentBody['system'], ClaudeBrain.systemPrompt);
      expect(sentBody['max_tokens'], 400);
      expect(
        ((sentBody['output_config'] as Map)['format'] as Map)['type'],
        'json_schema',
      );
      // No removed sampling params.
      expect(sentBody.containsKey('temperature'), isFalse);
      final lastMessage = (sentBody['messages'] as List).last as Map;
      expect(lastMessage['role'], 'user');
      expect(lastMessage['content'], contains('How am I doing?'));
      expect(lastMessage['content'], contains('Dog (Aso)'));
    });

    test('drops leading assistant turns so history starts with user',
        () async {
      late Map<String, dynamic> sentBody;
      final brain = ClaudeBrain(
        apiKey: 'sk-test',
        transport: (body, headers) async {
          sentBody = json.decode(body) as Map<String, dynamic>;
          return ClaudeHttpResponse(200, _apiBody());
        },
      );

      final recent = [
        TutorMessage(
          id: '1',
          role: TutorMessageRole.tutor,
          content: 'Hello!',
          timestamp: DateTime(2026),
        ),
        TutorMessage(
          id: '2',
          role: TutorMessageRole.student,
          content: 'hi buddy',
          timestamp: DateTime(2026),
        ),
      ];
      await brain.respondToQuestion('quiz me', _context(recent: recent));

      final messages = (sentBody['messages'] as List).cast<Map>();
      expect(messages.first['role'], 'user');
      expect(messages.first['content'], 'hi buddy');
    });
  });

  group('ClaudeBrain response handling', () {
    test('parses a happy-path structured reply', () async {
      final brain = ClaudeBrain(
        apiKey: 'k',
        transport: _respondWith(
          200,
          _apiBody(content: 'Galing mo!', action: 'quickQuiz', quizWord: 'Dog'),
        ),
      );
      final reply = await brain.analyze(_context());
      expect(reply.content, 'Galing mo!');
      expect(reply.actionKind, 'quickQuiz');
      expect(reply.quizWord, 'Dog');
    });

    test('maps API failures to typed fallback reasons', () async {
      Future<void> expectReason(ClaudeTransport transport, String reason) async {
        final brain = ClaudeBrain(apiKey: 'k', transport: transport);
        await expectLater(
          brain.analyze(_context()),
          throwsA(isA<TutorBrainException>()
              .having((e) => e.reason, 'reason', reason)),
        );
      }

      await expectReason(_respondWith(401, '{}'), 'auth');
      await expectReason(_respondWith(429, '{}'), 'rate_limited');
      await expectReason(_respondWith(529, '{}'), 'overloaded');
      await expectReason(_respondWith(500, '{}'), 'overloaded');
      await expectReason(_respondWith(400, '{}'), 'http_400');
      await expectReason(_respondWith(200, 'not json'), 'malformed');
      await expectReason(
        _respondWith(200, _apiBody(stopReason: 'refusal')),
        'refusal',
      );
      await expectReason(
        (b, h) async => throw TimeoutException('slow'),
        'timeout',
      );
      await expectReason((b, h) async => throw Exception('boom'), 'network');
    });
  });

  group('HybridTutorBrain routing', () {
    HybridTutorBrain hybrid({
      ClaudeTransport? transport,
      bool online = true,
    }) =>
        HybridTutorBrain(
          claudeFactory: (key, model) => ClaudeBrain(
            apiKey: key,
            model: model,
            transport: transport ?? _respondWith(200, _apiBody()),
          ),
          isOnline: () async => online,
        );

    test('falls back to rules when disabled / unkeyed / offline / capped',
        () async {
      // Disabled (default).
      var result = await hybrid().respondWithTelemetry('quiz', _context());
      expect(result.brainUsed, 'rule');
      expect(result.fallbackReason, 'disabled');

      // Enabled but no key.
      await TutorBrainSettings.setEnabled(true);
      result = await hybrid().respondWithTelemetry('quiz', _context());
      expect(result.fallbackReason, 'no_key');

      // Keyed but offline.
      await TutorBrainSettings.setApiKey('sk-test');
      result =
          await hybrid(online: false).respondWithTelemetry('quiz', _context());
      expect(result.fallbackReason, 'offline');

      // Daily cap exhausted.
      await TutorBrainSettings.setDailyCap(1);
      await TutorBrainSettings.spendTurn();
      result = await hybrid().respondWithTelemetry('quiz', _context());
      expect(result.fallbackReason, 'daily_cap');

      // Every fallback still produced a usable rule-engine message.
      expect(result.message.content, isNotEmpty);
    });

    test('falls back with the API error reason and still answers', () async {
      await TutorBrainSettings.setEnabled(true);
      await TutorBrainSettings.setApiKey('sk-test');
      final result = await hybrid(transport: _respondWith(401, '{}'))
          .respondWithTelemetry('give me a quiz', _context());
      expect(result.brainUsed, 'rule');
      expect(result.fallbackReason, 'auth');
      expect(result.message.content, isNotEmpty);
    });

    test('LLM quiz suggestion is materialized and graded locally', () async {
      await TutorBrainSettings.setEnabled(true);
      await TutorBrainSettings.setApiKey('sk-test');
      final card = SeedData.allFlashcards.first;

      final result = await hybrid(
        transport: _respondWith(
          200,
          _apiBody(
            content: 'Let\'s try one!',
            action: 'quickQuiz',
            quizWord: card.wordEnglish,
          ),
        ),
      ).respondWithTelemetry('quiz me', _context());

      expect(result.brainUsed, 'llm');
      expect(result.fallbackReason, isNull);
      final action = result.message.action!;
      expect(action.type, TutorActionType.quickQuiz);
      // Options + answer key come from SeedData, not the LLM.
      expect(action.wordId, card.id);
      expect(action.correctAnswer, card.wordFilipino);
      expect(action.options, contains(card.wordFilipino));
      expect(action.options, hasLength(4));
      expect(TutorBrainSettings.turnsToday, 1);
    });

    test('an unknown quiz word silently drops the action', () async {
      await TutorBrainSettings.setEnabled(true);
      await TutorBrainSettings.setApiKey('sk-test');
      final result = await hybrid(
        transport: _respondWith(
          200,
          _apiBody(action: 'quickQuiz', quizWord: 'Jeepney'),
        ),
      ).respondWithTelemetry('quiz me', _context());
      expect(result.brainUsed, 'llm');
      expect(result.message.action, isNull);
    });

    test('startLesson is materialized from local spaced-repetition data',
        () async {
      await TutorBrainSettings.setEnabled(true);
      await TutorBrainSettings.setApiKey('sk-test');
      final result = await hybrid(
        transport: _respondWith(200, _apiBody(action: 'startLesson')),
      ).respondWithTelemetry('teach me', _context());
      expect(result.message.action?.type, TutorActionType.startLesson);
      expect(result.message.action?.planWordIds, isNotEmpty);
    });

    test('every turn is logged for the research export', () async {
      await hybrid().respondWithTelemetry('hello', _context());
      await TutorBrainSettings.setEnabled(true);
      await TutorBrainSettings.setApiKey('sk-test');
      await hybrid().analyzeWithTelemetry(_context());
      // Logging is fire-and-forget — let the queued writes land.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final events = TutorInteractionLog.getEvents(_pid);
      expect(events, hasLength(2));
      expect(events.first.brain, 'rule');
      expect(events.first.fallbackReason, 'disabled');
      expect(events.last.brain, 'llm');
      expect(events.last.trigger, TutorTrigger.analyze);
    });
  });

  group('TutorBrainSettings', () {
    test('defaults are safe: disabled, default model, capped', () {
      expect(TutorBrainSettings.isEnabled, isFalse);
      expect(TutorBrainSettings.apiKey, isEmpty);
      expect(TutorBrainSettings.model, ClaudeBrain.defaultModel);
      expect(TutorBrainSettings.dailyCap, TutorBrainSettings.defaultDailyCap);
      expect(TutorBrainSettings.turnsToday, 0);
      expect(TutorBrainSettings.canSpendTurn, isTrue);
    });

    test('unknown stored model falls back to the default', () async {
      await settingsBox.put('tutor_llm_model', 'gpt-9000');
      expect(TutorBrainSettings.model, ClaudeBrain.defaultModel);
    });

    test('turn spending counts up and blocks at the cap', () async {
      await TutorBrainSettings.setDailyCap(2);
      await TutorBrainSettings.spendTurn();
      await TutorBrainSettings.spendTurn();
      expect(TutorBrainSettings.turnsToday, 2);
      expect(TutorBrainSettings.canSpendTurn, isFalse);
    });
  });

  group('tutor_interactions.csv rows', () {
    test('row column count matches the header', () {
      final rows = ResearchExportRows.tutorInteractionRows(
        studentId: 'S001',
        events: [
          TutorInteractionEvent(
            timestamp: DateTime(2026, 6, 11),
            trigger: TutorTrigger.question,
            brain: 'rule',
            latencyMs: 12,
            fallbackReason: 'offline',
            actionType: 'none',
          ),
        ],
      );
      expect(rows, hasLength(1));
      final headerCols =
          ResearchExportRows.tutorInteractionsHeader.split(',').length;
      expect(rows.single.split(',').length, headerCols);
    });
  });
}
