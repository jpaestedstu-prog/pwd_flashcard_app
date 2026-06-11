import '../models/tutor_brain_models.dart';
import '../models/tutor_models.dart';
import 'tutor_brain.dart';
import 'tutor_engine.dart';

/// Thin async adapter over the existing rule-based [TutorEngine]. Always
/// available, fully offline — the hybrid router's safety net.
class RuleBasedBrain implements TutorBrain {
  const RuleBasedBrain();

  @override
  Future<TutorMessage> analyze(TutorContext context) async {
    return TutorEngine.analyzeAndRespond(
      context.progress,
      context.studentName,
      context.profileId,
      isFilipino: context.isFilipino,
    );
  }

  @override
  Future<TutorMessage> respondToQuestion(
    String question,
    TutorContext context,
  ) async {
    return TutorEngine.respondToQuestion(
      question,
      context.progress,
      context.profileId,
      isFilipino: context.isFilipino,
    );
  }
}
