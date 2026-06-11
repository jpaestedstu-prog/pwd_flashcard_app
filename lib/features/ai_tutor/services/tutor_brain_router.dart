import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/seed_data.dart';
import '../../../data/models/models.dart';
import '../models/tutor_brain_models.dart';
import '../models/tutor_models.dart';
import 'claude_brain.dart';
import 'rule_based_brain.dart';
import 'tutor_brain.dart';
import 'tutor_brain_settings.dart';
import 'tutor_engine.dart';
import 'tutor_interaction_log.dart';

const _uuid = Uuid();

/// The hybrid tutor brain: Claude when enabled + keyed + online + under the
/// daily cap, with silent fallback to the rule engine on ANY failure. The
/// student never sees an error — worst case they get the same answers the
/// app shipped with.
///
/// Every turn (rule or llm) is logged via [TutorInteractionLog] with the
/// brain used, latency, and fallback reason for `tutor_interactions.csv`.
class HybridTutorBrain implements TutorBrain {
  final RuleBasedBrain _rule;
  final ClaudeBrain Function(String apiKey, String model) _claudeFactory;
  final Future<bool> Function() _isOnline;

  HybridTutorBrain({
    RuleBasedBrain rule = const RuleBasedBrain(),
    ClaudeBrain Function(String apiKey, String model)? claudeFactory,
    Future<bool> Function()? isOnline,
  })  : _rule = rule,
        _claudeFactory =
            claudeFactory ?? ((key, model) => ClaudeBrain(apiKey: key, model: model)),
        _isOnline = isOnline ?? _checkConnectivity;

  static Future<bool> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return !results.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      // If the check itself fails, let the API call decide.
      return true;
    }
  }

  @override
  Future<TutorMessage> analyze(TutorContext context) async =>
      (await analyzeWithTelemetry(context)).message;

  @override
  Future<TutorMessage> respondToQuestion(
    String question,
    TutorContext context,
  ) async =>
      (await respondWithTelemetry(question, context)).message;

  /// Telemetry-carrying variants — the screen uses these so it can surface
  /// offline/fallback state.
  Future<TutorBrainResult> analyzeWithTelemetry(TutorContext context) =>
      _run(TutorTrigger.analyze, null, context);

  Future<TutorBrainResult> respondWithTelemetry(
    String question,
    TutorContext context,
  ) =>
      _run(TutorTrigger.question, question, context);

  Future<TutorBrainResult> _run(
    TutorTrigger trigger,
    String? question,
    TutorContext context,
  ) async {
    final stopwatch = Stopwatch()..start();

    String? fallbackReason;
    if (!TutorBrainSettings.isEnabled) {
      fallbackReason = 'disabled';
    } else if (TutorBrainSettings.apiKey.isEmpty) {
      fallbackReason = 'no_key';
    } else if (!TutorBrainSettings.canSpendTurn) {
      fallbackReason = 'daily_cap';
    } else if (!await _isOnline()) {
      fallbackReason = 'offline';
    }

    if (fallbackReason == null) {
      try {
        final claude = _claudeFactory(
          TutorBrainSettings.apiKey,
          TutorBrainSettings.model,
        );
        final reply = trigger == TutorTrigger.analyze
            ? await claude.analyze(context)
            : await claude.respondToQuestion(question!, context);
        final message = materialize(reply, context);
        await TutorBrainSettings.spendTurn();
        return _finish(trigger, context, message, 'llm', stopwatch, null);
      } on TutorBrainException catch (e) {
        fallbackReason = e.reason;
      } catch (_) {
        fallbackReason = 'network';
      }
    }

    final message = trigger == TutorTrigger.analyze
        ? await _rule.analyze(context)
        : await _rule.respondToQuestion(question!, context);
    return _finish(trigger, context, message, 'rule', stopwatch, fallbackReason);
  }

  TutorBrainResult _finish(
    TutorTrigger trigger,
    TutorContext context,
    TutorMessage message,
    String brain,
    Stopwatch stopwatch,
    String? fallbackReason,
  ) {
    stopwatch.stop();
    final result = TutorBrainResult(
      message: message,
      brainUsed: brain,
      latencyMs: stopwatch.elapsedMilliseconds,
      fallbackReason: fallbackReason,
    );
    // Fire-and-forget — research logging must never block the chat.
    // ignore: discarded_futures
    TutorInteractionLog.log(
      context.profileId,
      TutorInteractionEvent(
        timestamp: DateTime.now(),
        trigger: trigger,
        brain: brain,
        latencyMs: result.latencyMs,
        fallbackReason: fallbackReason,
        actionType: message.action?.type.name ?? 'none',
      ),
    );
    return result;
  }

  /// Turns a [ClaudeReply] into a [TutorMessage], building all interactive
  /// mechanics locally:
  /// - quickQuiz: the LLM only *names* a word; options and the answer key
  ///   come from [TutorEngine.quizForWord] over SeedData, and grading stays
  ///   in the screen exactly as for rule-engine quizzes. An unknown word
  ///   silently drops the action.
  /// - startLesson: the plan is built locally from spaced-repetition data.
  TutorMessage materialize(ClaudeReply reply, TutorContext context) {
    TutorAction? action;
    var content = reply.content;

    switch (reply.actionKind) {
      case 'quickQuiz':
        final card = _cardForWord(reply.quizWord);
        if (card != null) {
          final quiz =
              TutorEngine.quizForWord(card, isFilipino: context.isFilipino);
          action = quiz.action;
          content = '$content\n\n'
              '${context.isFilipino ? 'Ano ang Filipino ng "${card.wordEnglish}"?' : 'What is the Filipino for "${card.wordEnglish}"?'}';
        }
      case 'startLesson':
        final plan =
            TutorEngine.buildLearningPlan(context.progress, context.profileId);
        if (plan.isNotEmpty) {
          action = TutorAction(
            type: TutorActionType.startLesson,
            planWordIds: plan.map((c) => c.id).toList(),
          );
        }
      case 'practiceRedirect':
        action = const TutorAction(
          type: TutorActionType.practiceRedirect,
          targetRoute: '/guided-practice',
        );
      case 'encouragement':
        action = const TutorAction(type: TutorActionType.encouragement);
      default:
        action = null;
    }

    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: content,
      timestamp: DateTime.now(),
      action: action,
    );
  }

  static Map<String, Flashcard>? _cardLookupCache;

  Map<String, Flashcard> get _cardLookup => _cardLookupCache ??= {
        for (final card in SeedData.allFlashcards)
          card.wordEnglish.toLowerCase(): card,
      };

  Flashcard? _cardForWord(String? word) {
    if (word == null) return null;
    return _cardLookup[word.trim().toLowerCase()];
  }
}

/// App-wide hybrid brain. Screens read this instead of calling TutorEngine
/// statics so the LLM/rule decision lives in one place.
final tutorBrainProvider = Provider<HybridTutorBrain>(
  (ref) => HybridTutorBrain(),
);
