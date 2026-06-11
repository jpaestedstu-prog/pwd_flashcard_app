import '../models/tutor_brain_models.dart';
import '../models/tutor_models.dart';

/// A strategy that turns a tutor context (and optionally a student question)
/// into the next tutor message. Implementations: [RuleBasedBrain] (offline,
/// always available) and the hybrid router that adds the Claude API on top.
abstract class TutorBrain {
  /// Proactive check-in after the greeting (progress analysis).
  Future<TutorMessage> analyze(TutorContext context);

  /// Reply to a free-text student question.
  Future<TutorMessage> respondToQuestion(String question, TutorContext context);
}
