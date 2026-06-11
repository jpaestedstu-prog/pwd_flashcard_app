import '../../../data/models/models.dart';
import 'tutor_models.dart';

/// Everything a tutor brain may need to answer one turn. Built by the screen
/// (where Hive/providers are available) so the brains themselves stay pure.
class TutorContext {
  final String profileId;
  final String studentName;
  final bool isFilipino;
  final LearningProgress progress;

  /// Most recent chat turns, oldest first (already capped by the caller).
  final List<TutorMessage> recentMessages;

  /// Words due for review, pre-formatted as `English (Filipino)` — these are
  /// also the quiz-word candidates offered to the LLM.
  final List<String> dueReviewWords;

  const TutorContext({
    required this.profileId,
    required this.studentName,
    required this.isFilipino,
    required this.progress,
    this.recentMessages = const [],
    this.dueReviewWords = const [],
  });

  /// Category labels below 40% mastery.
  List<String> get weakCategories => [
        for (final e in progress.categoryProgress.entries)
          if (e.value < 0.4) e.key,
      ];
}

/// What kicked off a brain call — used for research logging.
enum TutorTrigger { analyze, question }

/// A brain's answer plus the telemetry the study needs.
class TutorBrainResult {
  final TutorMessage message;

  /// 'rule' or 'llm'.
  final String brainUsed;
  final int latencyMs;

  /// Why the hybrid router fell back to rules (null when the requested brain
  /// answered): disabled, no_key, offline, daily_cap, auth, rate_limited,
  /// overloaded, refusal, timeout, network, malformed, http_<code>.
  final String? fallbackReason;

  const TutorBrainResult({
    required this.message,
    required this.brainUsed,
    required this.latencyMs,
    this.fallbackReason,
  });
}

/// Pure parse result from the Claude API before action materialization.
class ClaudeReply {
  final String content;

  /// none | quickQuiz | practiceRedirect | startLesson | encouragement
  final String actionKind;

  /// English vocabulary word to quiz (only for quickQuiz; validated against
  /// SeedData by the router — the LLM never builds options or answers).
  final String? quizWord;

  const ClaudeReply({
    required this.content,
    required this.actionKind,
    this.quizWord,
  });
}

/// One logged brain interaction, persisted for `tutor_interactions.csv`.
class TutorInteractionEvent {
  final DateTime timestamp;
  final TutorTrigger trigger;
  final String brain;
  final int latencyMs;
  final String? fallbackReason;
  final String actionType;

  const TutorInteractionEvent({
    required this.timestamp,
    required this.trigger,
    required this.brain,
    required this.latencyMs,
    required this.fallbackReason,
    required this.actionType,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'trigger': trigger.name,
        'brain': brain,
        'latencyMs': latencyMs,
        if (fallbackReason != null) 'fallbackReason': fallbackReason,
        'actionType': actionType,
      };

  factory TutorInteractionEvent.fromJson(Map<String, dynamic> json) =>
      TutorInteractionEvent(
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        trigger: json['trigger'] == TutorTrigger.analyze.name
            ? TutorTrigger.analyze
            : TutorTrigger.question,
        brain: json['brain'] as String? ?? 'rule',
        latencyMs: (json['latencyMs'] as num?)?.toInt() ?? 0,
        fallbackReason: json['fallbackReason'] as String?,
        actionType: json['actionType'] as String? ?? 'none',
      );
}
